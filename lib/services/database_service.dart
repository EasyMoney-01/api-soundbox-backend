import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/device_model.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'upi_soundbox.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            vendor TEXT NOT NULL,
            amount REAL NOT NULL,
            targetIP TEXT NOT NULL,
            isSuccess INTEGER NOT NULL,
            status TEXT NOT NULL,
            errorMessage TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE devices (
            id TEXT PRIMARY KEY,
            ip TEXT NOT NULL,
            port INTEGER NOT NULL,
            vendor TEXT,
            isOnline INTEGER NOT NULL,
            discoveredAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Database get _database {
    if (_db == null) throw StateError('DatabaseService not initialized');
    return _db!;
  }

  Future<void> insertTransaction(TransactionModel txn) async {
    await _database.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final rows = await _database.query(
      'transactions',
      orderBy: 'createdAt DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<void> deleteTransaction(String id) async {
    await _database.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllTransactions() async {
    await _database.delete('transactions');
  }

  Future<void> insertDevice(DeviceModel device) async {
    await _database.insert(
      'devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DeviceModel>> getAllDevices() async {
    final rows = await _database.query('devices', orderBy: 'discoveredAt DESC');
    return rows.map(DeviceModel.fromMap).toList();
  }

  Future<void> clearAllDevices() async {
    await _database.delete('devices');
  }
}
