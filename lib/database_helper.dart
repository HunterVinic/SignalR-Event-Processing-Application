import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'database_page.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'events.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY,
        eventId INTEGER,
        eventType TEXT,
        createdAt TEXT,
        correlationId TEXT,
        containsBody INTEGER,
        payload TEXT,
        status TEXT,
        UNIQUE (eventId, eventType, createdAt, correlationId, payload, status)
      )
    ''');
    await db.execute('CREATE INDEX idx_status ON events (status)');
    await db.execute('CREATE INDEX idx_eventId ON events (eventId)');
    await db.execute('CREATE INDEX idx_eventId ON events (eventType)');
  }

  Future<void> insertEvent(Map<String, dynamic> event) async {
    final db = await database;
    await db.insert(
      'events',
      event,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    Timer(const Duration(milliseconds: 1000), () => removeDuplicateEvents());
  }

  Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeDuplicateEvents() async {
    final db = await database;

    var duplicates = await db.rawQuery('''
    SELECT eventId, eventType, createdAt, correlationId, payload, status, COUNT(*)
    FROM events
    GROUP BY eventId, eventType, createdAt, correlationId, payload, status
    HAVING COUNT(*) > 1
  ''');

    for (var duplicate in duplicates) {
      print('Duplicate found: $duplicate');

      var eventId = duplicate['eventId'];
      var eventType = duplicate['eventType'];
      var createdAt = duplicate['createdAt'];
      var correlationId = duplicate['correlationId'];
      var payload = duplicate['payload'];
      var status = duplicate['status'];

      await db.rawDelete('''
      DELETE FROM events
      WHERE eventId = ? AND eventType = ? AND createdAt = ? AND correlationId = ? AND payload = ? AND status = ?
      AND id NOT IN (
        SELECT MIN(id)
        FROM events
        WHERE eventId = ? AND eventType = ? AND createdAt = ? AND correlationId = ? AND payload = ? AND status = ?
      )
    ''', [eventId, eventType, createdAt, correlationId, payload, status,
        eventId, eventType, createdAt, correlationId, payload, status]);
    }
  }

  Future<void> updateAllEventsToCompleted() async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE events
      SET status = 'COMPLETED'
      WHERE status = 'PENDING'
    ''');
  }

  Future<bool> eventExists(int eventId) async {
    final db = await database;
    var result = await db.query(
        'events',
        where: 'eventId = ?',
        whereArgs: [eventId]
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getEvents({EventStatus? status}) async {
    final db = await database;
    if (status != null) {
      return await db.query('events', where: 'status = ?', whereArgs: [statusMap[status]]);
    } else {
      return await db.query('events');
    }
  }

  Future<Map<String, dynamic>?> getEventById(int eventId) async {
    final db = await database;
    List<Map<String, dynamic>> events = await db.query('events', where: 'eventId = ?', whereArgs: [eventId]);
    if (events.isNotEmpty) {
      return events.first;
    } else {
      return null;
    }
  }

}

