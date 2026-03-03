import 'dart:async';
import 'package:api_update/database/company_update.dart';
import 'package:api_update/database_update_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/signalr_client.dart' as signalR;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';
import 'database_page.dart';

class ChatPage extends StatefulWidget {
  final String? accessToken;
  const ChatPage(this.accessToken, {super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController userInputController = TextEditingController();
  TextEditingController messageInputController = TextEditingController();
  List<String> messages = [];

  late signalR.HubConnection connection;
  bool isConnected = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  int pingInterval = 5000;
  bool isPinging = false;

  late String _connectionStatus = 'Unknown';
  bool isConnectedStatus() {
    return connection.state == HubConnectionState.Connected;
  }

  late Timer _timer;

  bool hubStatus = false;

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    startConnection();
    checkNetworkConnectivity();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isConnectedStatus()) {
        checkConnectionStatus();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
    _timer.cancel();
  }


  void _updateEventStatus(int eventId, String status, String errorMessage, int retryCount) {
    print("Sending :$eventId");
    print("Sending: $status");
    print("Sending: $errorMessage");
    print("Sending: $retryCount");
    print("Invoking UpdateEventStatus with arguments: UpdateEventStatus(${[eventId, status, errorMessage, retryCount]})");
    connection.invoke("UpdateEventStatus", args: [eventId, status, errorMessage, retryCount]).catchError((error) {
      print("Error updating event status: $error");
    });
  }

  Future<http.Response> pingWebsite(String url) async {
    try {
      return await http.get(Uri.parse(url));
    } catch (e) {
      throw Exception('Failed to ping $url: $e');
    }
  }

  void _updateConnectionStatus(String status) {
    setState(() {
      _connectionStatus = status;
    });
  }

  void checkNetworkConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (connectivityResult == ConnectivityResult.wifi) {
        _updateConnectionStatus('Wi-Fi Available');
        print('Wi-Fi available');
        startConnection();
      } else {
        _updateConnectionStatus('Wi-Fi is not Available');
        print('Wi-Fi is not available');
      }
    });
  }

  Future<void> startConnection() async {
    String? accessToken = widget.accessToken;

    if (accessToken == null) {
      print("Access token is null");
      return;
    }

    connection = signalR.HubConnectionBuilder()
        .withUrl(
      "https://rt-signalr.ihusaan.dev/authhub",
      options: signalR.HttpConnectionOptions(
        accessTokenFactory: () => Future.value(accessToken),
      ),
    )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    connection.on("ReceiveMessage", _receiveMessage);
    connection.on("ReceiveEvent", _onEventReceived);

    connection.onreconnecting(({error}) {
      checkConnectionStatus();
      requestPendingEvents();
    });

    connection.onreconnected(({connectionId}) {
      print('Reconnected');
    });

    print(connection.toString());
    print("connection....");

    try {
      await connection.start();
      setState(() {
        isConnected = true;
      });
      requestPendingEvents();
    } catch (e) {
      print(e.toString());
      print('Here');
    }
  }

  void checkConnectionStatus() async {
    if (connection.state != HubConnectionState.Connected) {
      const String websiteUrl = 'https://rt-signalr.ihusaan.dev';
      Timer.periodic(Duration(milliseconds: pingInterval), (timer) {
        pingWebsite(websiteUrl).then((response) async {
          print('Ping to $websiteUrl: ${response.statusCode}  at interval $pingInterval');
          setState(() {
            isPinging = true;
          });
          if (response.statusCode >= 200 && response.statusCode < 400 && connection.state != HubConnectionState.Connected){
            print('Ping successful. Status code: ${response.statusCode}');
            startConnection();
            isPinging = true;
          }
          if (response.statusCode >= 200 && response.statusCode < 400 && connection.state == HubConnectionState.Connected){
            print('ReConnected');
            isPinging = false;
            timer.cancel();
          }
        }).catchError((error) {
          print('Error pinging $websiteUrl: $error at interval $pingInterval');
          setState(() {
            isPinging = false;
          });
        });
        timer.cancel();
      });
    } else {
      print('Already Connected | Reconnecting failed');

    }
  }

  void _receiveMessage(List<Object?>? arguments) async {
    if (arguments != null && arguments.length >= 2) {
      String user = arguments[0].toString();
      String message = arguments[1].toString();
      setState(() {
        messages.add("$user says $message");
      });
    }
  }

  void _onEventReceived(List<Object?>? parameters) {
    if (parameters != null && parameters.isNotEmpty) {
      final event = parameters[0] as Map<String, dynamic>;
      event['status'] = "PENDING";
      print('Event received: $event');
      _insertEventToDatabase(event);
    }
  }

  void requestPendingEvents() {
    connection.invoke("GetPendingEvents").then((events) {
      if (events is List<Object?>) {
        for (var event in events) {
          if (event is Map<String, dynamic>) {
            event['status'] = "PENDING";
            print('Event received: $event');
            _insertEventToDatabase(event);
          } else {
            print('Invalid event data received: $event');
          }
        }
      } else {
        print('Invalid events format received: $events');
      }
    }).catchError((err) {
      print("Error requesting pending events: $err");
    });
  }



  Future<void> _insertEventToDatabase(Map<String, dynamic> event) async {
    final eventMap = {
      'eventId': event['eventId'],
      'eventType': event['eventType'],
      'createdAt': event['createdAt'],
      'correlationId': event['correlationId'],
      'containsBody': event['containsBody'] ? 1 : 0,
      'payload': event['payload'],
      'status': event['status']
    };

    String errorMessage = 'NULL';
    int retryCount = 0;
    print('containsBody: ${event['containsBody']}');


    if (!event['containsBody']) {
      final url = 'https://rt-signalr.ihusaan.dev/Events/getbody?id=${event['eventId']}';
      print('Fetching data from: $url');

      try {

        final headResponse = await http.head(Uri.parse(url));
        if (headResponse.statusCode == 200) {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            eventMap['payload'] = response.body;
            print('Payload fetched: ${eventMap['payload']}');
          } else {
            throw Exception('Failed to load event body');
          }
        } else {
          throw Exception('URL is not responsive');
        }
      } on Exception catch (error) {
        errorMessage = error.toString();
        print("Error fetching event body: $errorMessage");

      }
    }

    try {
      await _databaseHelper.insertEvent(eventMap);
    } on Exception catch (error) {
      errorMessage = error.toString();
    }

    String eventIdString = event['eventId'].toString();
    print('Update after Receiving event: $eventIdString');
    int eventIdInt = int.parse(eventIdString);
    print('Event ID (as Int): $eventIdInt');
    String status = 'RECEIVED_BY_TERMINAL';
    print("Update after Receiving event: $status");
    print("Update after Receiving event: $errorMessage");
    print("Invoking UpdateEventStatus with arguments: UpdateEventStatus(${[eventIdInt, status, errorMessage, retryCount]})");
    connection.invoke("UpdateEventStatus", args: [eventIdInt, status, errorMessage, retryCount]).catchError((error) {
      print("Error updating event status: $error");
    });
  }




  void sendMessage() {
    String user = userInputController.text;
    String message = messageInputController.text;

    connection.invoke("SendMessage", args: [user, message]);
    messageInputController.clear();
  }



  late Stream<int> timerStream;
  late StreamController<int> streamController;
  int elapsedTime = 0;

  void startTimer() {
    Timer.periodic(Duration(microseconds: 1), (timer) {
      elapsedTime += 1; // increment by picoseconds (1 microsecond = 1,000,000 picoseconds)
      streamController.add(elapsedTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SignalR Chat'),
        actions: [
          DropdownButton<int>(
            value: pingInterval,
            onChanged: (value) {
              setState(() {
                pingInterval = value!;
              });
            },
            items: const [
              DropdownMenuItem<int>(
                value: 5000,
                child: Text('5 seconds'),
              ),
              DropdownMenuItem<int>(
                value: 10000,
                child: Text('10 seconds'),
              ),
              DropdownMenuItem<int>(
                value: 30000,
                child: Text('30 seconds'),
              ),
              DropdownMenuItem<int>(
                value: 60000,
                child: Text('60 seconds'),
              ),
            ],
          ),
          Text(
            isPinging ? 'Pinging' : 'Not Pinging',
            style: TextStyle(
              color: isPinging ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: <Widget>[
            StreamBuilder<int>(
              stream: timerStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    'Elapsed Time: ${snapshot.data} picoseconds',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  );
                } else {
                  return Text(
                    'Elapsed Time: 0 picoseconds',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  );
                }
              },
            ),
            Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              isConnectedStatus() ? 'Connected' : 'Disconnected',
              style: TextStyle(
                color: isConnectedStatus() ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),

            const SizedBox(
              height: 10,
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DatabasePage(
                      sendUpdateEventStatus: _updateEventStatus,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
            ),
            const SizedBox(
              height: 10,
            ),
            IconButton(onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => UpdatePage()),
              );
            },
                icon: const Icon(Icons.account_tree_outlined)
            ),
            const SizedBox(
              height: 10,
            ),
            IconButton(onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CompanyPage()),
              );
            },
                icon: const Icon(Icons.add_business)
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(messages[index]),
                  );
                },
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: userInputController,
                    decoration: const InputDecoration(
                      labelText: 'User',
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: messageInputController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
