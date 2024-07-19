import 'dart:async';
import 'dart:ui';

import 'foo_database.dart';

class IsolateData {
  final RootIsolateToken token;
  final String name;

  IsolateData(this.token, this.name);
}

Future<void> writeToDb(String name) async {
  // final name = 'Foo ${DateTime.now().toIso8601String()}';
  String writeName = name;

  final db = FooDatabase();
  await db.insertFoo(writeName);
  print('Wrote $name to the database');
}

Future<void> readFromDb() async {
  final db = FooDatabase();
  final foos = await db.getFoos();
  print('Read from the database: ${foos.length}');
  print('Read from the database: ${foos}')
}