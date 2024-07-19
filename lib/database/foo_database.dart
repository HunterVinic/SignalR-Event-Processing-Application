import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqflite_dev.dart';

class FooDatabase {
  DatabaseFactory get databaseFactory => sqfliteDatabaseFactoryDefault;

  Future<Database> getDatabase() async {
    // Initialize the database
    return databaseFactory.openDatabase(
      'foo.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) {
          return db.execute(
            'CREATE TABLE foo(id INTEGER PRIMARY KEY, name TEXT)',
          );
        },
      ),
    );
  }

  Future<void> insertFoo(String name) async {
    final db = await getDatabase();
    await db.insert(
      'foo',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFoos() async {
    final db = await getDatabase();
    return db.query('foo');
  }
}