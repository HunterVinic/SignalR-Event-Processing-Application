import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class CompanyDatabaseHelper {
  static final CompanyDatabaseHelper _instance = CompanyDatabaseHelper._internal();
  static Database? _database;

  factory CompanyDatabaseHelper() {
    return _instance;
  }

  CompanyDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'company.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE company (
        id INTEGER PRIMARY KEY,
        Code TEXT,
        Name TEXT,
        Description TEXT,
        Brand TEXT,
        MerchandisingCategory INTEGER,
        Image TEXT,
        BasePrice TEXT,
        BaseUom TEXT,
        IsBatchItem TEXT,
        TaxId TEXT
      )
    ''');
  }

  Future<void> sendPayloadToAnotherTable(Map<String, dynamic> payloadMap) async {
    try {
      final db = await database;
      int insertedId = await db.insert(
        'company',
        {
          'Code': payloadMap['Code'],
          'Name': payloadMap['Name'],
          'Description': payloadMap['Description'],
          'Brand': payloadMap['Brand'],
          'MerchandisingCategory': payloadMap['MerchandisingCategory'],
          'Image': payloadMap['Image'],
          'BasePrice': payloadMap['BasePrice'],
          'BaseUom': payloadMap['BaseUom'],
          'IsBatchItem': payloadMap['IsBatchItem'],
          'TaxId': payloadMap['TaxId'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (insertedId != 0) {
        print('Payload sent successfully');
      } else {
        print('Failed to send payload');
      }
    } catch (e) {
      print('Error sending payload: $e');
    }
  }


  Future<List<Map<String, dynamic>>> getPayload() async {
    final db = await database;
    return await db.query('company');
  }

  Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.delete('company', where: 'id = ?', whereArgs: [id]);
  }
}
