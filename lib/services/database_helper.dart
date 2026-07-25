import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS pending_emails (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL
  )
''');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE tasks (
  id $idType,
  title $textType,
  description $textType,
  date $textType,
  time $textType,
  recipientEmail $textType,
  recurrenceType $textType,
  customDates $textType,
  isCompleted $intType
  )
''');

    await db.execute('''
CREATE TABLE pending_emails (
  id $idType,
  email $textType,
  title $textType,
  description $textType
  )
''');
  }

  Future<Task> create(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    task.id = id;
    return task;
  }

  Future<List<Task>> readAllTasks() async {
    final db = await instance.database;
    final orderBy = 'date ASC, time ASC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<Task?> getTask(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      columns: ['id', 'title', 'description', 'date', 'time', 'recipientEmail', 'recurrenceType', 'customDates', 'isCompleted'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> update(Task task) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Pending Emails ---

  Future<void> insertPendingEmail(String email, String title, String description) async {
    final db = await instance.database;
    await db.insert('pending_emails', {
      'email': email,
      'title': title,
      'description': description,
    });
  }

  Future<List<Map<String, dynamic>>> readAllPendingEmails() async {
    final db = await instance.database;
    return await db.query('pending_emails');
  }

  Future<void> deletePendingEmail(int id) async {
    final db = await instance.database;
    await db.delete(
      'pending_emails',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
