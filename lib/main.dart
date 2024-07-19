import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'stress_testing.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final credentials = await getClientCredentials();
  final tokenData = await getToken(credentials['_clientId']!, credentials['_clientSecret']!);
  final accessToken = tokenData?['accessToken'];
  runApp(MyApp(accessToken));

}


class MyApp extends StatelessWidget {
  final String? accessToken;

  const MyApp(this.accessToken, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignalR Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatPage(accessToken),
    );
  }
}

Future<Map<String, String>> getClientCredentials() async {
  String url = 'https://rt-signalr.ihusaan.dev/home/createclient';

  try {
    final response = await http.get(Uri.parse(url));

    print('Status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      String clientId = responseData['_clientId'];
      String clientSecret = responseData['_clientSecret'];

      print(clientSecret);
      print(clientId);

      return {'_clientId': clientId, '_clientSecret': clientSecret};
    } else {
      throw Exception('Failed to retrieve client credentials. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print(e);
    throw Exception('Error retrieving client credentials: $e');

  }
}

Future<Map<String, dynamic>?> getToken(String clientId, String clientSecret) async {
  try {
    String connect = 'https://rt-signalr.ihusaan.dev/connect/token';
    Uri uri = Uri.parse(connect);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
        'scope': 'api',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );
    // print(clientId);
    // print(clientSecret);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final accessToken = data['access_token'];
      return {'accessToken': accessToken, 'clientId': clientId, 'clientSecret': clientSecret};
    } else {
      throw Exception(
          'Failed to get access token. Status code: ${response.statusCode}');
    }

  } catch (e) {
    print('Error getting access token: $e');
    return null;
  }
}
