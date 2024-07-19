import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'database/company_database_helper.dart';
import 'database_helper.dart';
import 'database_helper_update.dart';

enum EventStatus { pending, completed }
enum EventTypes { companyupdate, normalupdate }

final Map<EventStatus, String> statusMap = {
  EventStatus.pending: 'PENDING',
  EventStatus.completed: 'COMPLETED',
};

final Map<EventTypes, String> eventMap = {
  EventTypes.companyupdate: 'Company_Update',
  EventTypes.normalupdate: 'Normal_Update',
};

class DatabasePage extends StatefulWidget {
  final Function(int, String, String, int) sendUpdateEventStatus; //Call Back
  DatabasePage({required this.sendUpdateEventStatus});

  @override
  _DatabasePageState createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final DatabaseHelper databaseHelper = DatabaseHelper();
  final PayloadDatabaseHelper payloadDatabaseHelper = PayloadDatabaseHelper();
  final CompanyDatabaseHelper companyDatabaseHelper = CompanyDatabaseHelper();



  @override
  void initState() {
    super.initState();
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final startTime = DateTime.now();
      List<Map<String, dynamic>> pendingEvents = await databaseHelper.getEvents(status: EventStatus.pending);
      Queue<int> pendingEventIds = Queue<int>.from(pendingEvents.map((event) => event['eventId'] as int));

      while (pendingEventIds.isNotEmpty) {
        int eventId = pendingEventIds.removeFirst();
        String newStatus = 'TERMINAL_PROCESSING_STARTED';
        String errorMessage = 'NULL';
        int retryCount = 0;

        widget.sendUpdateEventStatus(eventId, newStatus, errorMessage, retryCount);

        try {
          Map<String, dynamic>? event = pendingEvents.firstWhere((event) => event['eventId'] == eventId);
          if (event != null) {
            int eventId = event['eventId'] as int;
            await _sendPayload(event['payload'], eventId);
          }

          newStatus = 'COMPLETED';
          errorMessage = 'NULL';
          retryCount = 0;
          widget.sendUpdateEventStatus(eventId, newStatus, errorMessage, retryCount);
        } catch (error) {
          errorMessage = 'Retrying $retryCount times: $error';
          retryCount++;
          if (retryCount == 3) {
            newStatus = 'FAULTED';
          } else {
            newStatus = 'TERMINAL_RETRY_QUEUED';
            await Future.delayed(const Duration(seconds: 1));
          }
          widget.sendUpdateEventStatus(eventId, newStatus, errorMessage, retryCount);
        }

        await databaseHelper.updateAllEventsToCompleted();
        final endTime = DateTime.now();
        final elapsedTime = endTime.difference(startTime);
        print('Insertion took: ${elapsedTime.inMilliseconds} ms');
      }
    });
  }


  Future<void> _sendPayload(String? payloadJson, int eventId) async {
    final startTime = DateTime.now();
    if (payloadJson != null) {
      print('Payload JSON: $payloadJson');
      Map<String, dynamic>? event = await databaseHelper.getEventById(eventId);
      if (event != null) {
        String eventType = event['eventType'] as String;
        final Map<String, Future<void> Function(Map<String, dynamic>)> eventActions = {
          'Company_Update': (payloadMap) => companyDatabaseHelper.sendPayloadToAnotherTable(payloadMap),
          'Normal_Update': (payloadMap) => payloadDatabaseHelper.sendPayloadToAnotherTable(payloadMap),
        };

        Map<String, dynamic> payloadMap = json.decode(payloadJson);

        if (eventActions.containsKey(eventType)) {
          await eventActions[eventType]!(payloadMap);
        } else {
          print('Unsupported event type: $eventType');
        }
      } else {
        print('Event not found for eventId: $eventId');
      }
    } else {
      print('Payload JSON is null');
    }
    final endTime = DateTime.now();
    final elapsedTime = endTime.difference(startTime);
    print('Sending payload took: ${elapsedTime.inMilliseconds} ms');
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Contents'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: databaseHelper.getEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No data available'),
            );
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Event ID')),
                  DataColumn(label: Text('Event Type')),
                  DataColumn(label: Text('Created At')),
                  DataColumn(label: Text('Correlation ID')),
                  DataColumn(label: Text('Contains Body')),
                  DataColumn(label: Text('Payload')),
                  DataColumn(label: Text('Send')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: snapshot.data!.map((event) {
                  return DataRow(cells: [
                    DataCell(Text('${event['eventId']}')),
                    DataCell(Text('${event['eventType']}')),
                    DataCell(Text('${event['createdAt']}')),
                    DataCell(Text('${event['correlationId']}')),
                    DataCell(Text('${event['containsBody']}')),
                    DataCell(
                      Text('${event['payload']}'),
                    ),
                    DataCell(
                      IconButton(
                        onPressed: () async {
                          int eventId = event['eventId'];
                          String newStatus;
                          String errorMessage = 'NULL';
                          int retryCount= 0;

                          try {
                            _sendPayload(event['payload'], eventId);
                            newStatus = 'COMPLETED';
                            retryCount= 0;
                            print(newStatus);

                          } catch (error) {
                            errorMessage = error.toString();
                            newStatus = 'FAULTED';
                            retryCount= 1;
                            print(newStatus);
                          }

                          widget.sendUpdateEventStatus(eventId, newStatus, errorMessage, retryCount);
                        },
                        icon: const Icon(Icons.send),
                      ),
                    ),
                    DataCell(Text('${event['status']}')),
                    DataCell(IconButton( // Add a delete button
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        _deleteEvent(event['id']);
                      },
                    )),
                  ]);
                }).toList(),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteEvent(int eventId) async {
    await databaseHelper.deleteEvent(eventId);
  }

}
