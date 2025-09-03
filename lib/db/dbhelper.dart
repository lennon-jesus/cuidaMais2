import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medic.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medic.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medicine(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medName TEXT,
            medDose TEXT,
            medTimes TEXT,
            imagePath TEXT,
            observations TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertMed(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicine', medicine.toMap());
  }

  Future<List<Medicine>> getMed() async {
    final db = await database;
    final maps = await db.query('medicine');
    return maps.map((map) => Medicine.fromMap(map)).toList();
  }

  Future<int> updateMed(Medicine medicine) async {
    final db = await database;
    return await db.update(
      'medicine',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMed(int id) async {
    final db = await database;
    return await db.delete('medicine', where: 'id = ?', whereArgs: [id]);
  }
}
