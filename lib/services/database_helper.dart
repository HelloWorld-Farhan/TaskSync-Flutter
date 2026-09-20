import 'dart:convert';
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
      version: 5,
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
    if (oldVersion < 4) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS routines (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  days_of_week TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL
  )
''');
      await db.execute('''
CREATE TABLE IF NOT EXISTS routine_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  routine_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  completed_start INTEGER NOT NULL,
  completed_end INTEGER NOT NULL,
  score INTEGER NOT NULL
  )
''');
    }
    if (oldVersion < 5) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS daily_scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT NOT NULL UNIQUE,
  earned_points INTEGER NOT NULL DEFAULT 0,
  total_points INTEGER NOT NULL DEFAULT 0,
  breakdown_json TEXT NOT NULL DEFAULT '[]'
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

    await db.execute('''
CREATE TABLE routines (
  id $idType,
  title $textType,
  description $textType,
  days_of_week $textType,
  start_time $textType,
  end_time $textType
  )
''');

    await db.execute('''
CREATE TABLE routine_history (
  id $idType,
  routine_id $intType,
  date $textType,
  completed_start $intType,
  completed_end $intType,
  score $intType
  )
''');

    await db.execute('''
CREATE TABLE daily_scores (
  id $idType,
  date $textType UNIQUE,
  earned_points $intType DEFAULT 0,
  total_points $intType DEFAULT 0,
  breakdown_json TEXT NOT NULL DEFAULT '[]'
  )
''');
  }

  // --- Tasks ---
  Future<Task> create(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    task.id = id;
    return task;
  }

  Future<List<Task>> readAllTasks() async {
    final db = await instance.database;
    const orderBy = 'date ASC, time ASC';
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
    if (maps.isNotEmpty) return Task.fromMap(maps.first);
    return null;
  }

  Future<int> update(Task task) async {
    final db = await instance.database;
    return db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // --- Pending Emails ---
  Future<void> insertPendingEmail(String email, String title, String description) async {
    final db = await instance.database;
    await db.insert('pending_emails', {'email': email, 'title': title, 'description': description});
  }

  Future<List<Map<String, dynamic>>> readAllPendingEmails() async {
    final db = await instance.database;
    return await db.query('pending_emails');
  }

  Future<void> deletePendingEmail(int id) async {
    final db = await instance.database;
    await db.delete('pending_emails', where: 'id = ?', whereArgs: [id]);
  }

  // --- Routines ---
  Future<int> createRoutine(Map<String, dynamic> routine) async {
    final db = await instance.database;
    return await db.insert('routines', routine);
  }

  Future<List<Map<String, dynamic>>> readAllRoutines() async {
    final db = await instance.database;
    return await db.query('routines');
  }

  Future<Map<String, dynamic>?> getRoutine(int id) async {
    final db = await instance.database;
    final maps = await db.query('routines', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> updateRoutine(Map<String, dynamic> routine) async {
    final db = await instance.database;
    return db.update('routines', routine, where: 'id = ?', whereArgs: [routine['id']]);
  }

  Future<int> deleteRoutine(int id) async {
    final db = await instance.database;
    await db.delete('routine_history', where: 'routine_id = ?', whereArgs: [id]);
    return await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  // --- Routine History ---
  Future<int> createRoutineHistory(Map<String, dynamic> history) async {
    final db = await instance.database;
    return await db.insert('routine_history', history);
  }

  Future<List<Map<String, dynamic>>> readRoutineHistory(int routineId) async {
    final db = await instance.database;
    return await db.query('routine_history',
        where: 'routine_id = ?', whereArgs: [routineId], orderBy: 'date DESC');
  }

  Future<Map<String, dynamic>?> getRoutineHistoryByDate(int routineId, String date) async {
    final db = await instance.database;
    final maps = await db.query('routine_history',
        where: 'routine_id = ? AND date = ?', whereArgs: [routineId, date]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> updateRoutineHistory(Map<String, dynamic> history) async {
    final db = await instance.database;
    return db.update('routine_history', history, where: 'id = ?', whereArgs: [history['id']]);
  }

  // --- Daily Scores ---

  /// Saves or updates today's score snapshot
  Future<void> saveDailyScore({
    required String date,
    required int earnedPoints,
    required int totalPoints,
    required List<Map<String, dynamic>> breakdown,
  }) async {
    final db = await instance.database;
    final existing = await db.query('daily_scores', where: 'date = ?', whereArgs: [date]);
    final data = {
      'date': date,
      'earned_points': earnedPoints,
      'total_points': totalPoints,
      'breakdown_json': jsonEncode(breakdown),
    };
    if (existing.isEmpty) {
      await db.insert('daily_scores', data);
    } else {
      await db.update('daily_scores', data, where: 'date = ?', whereArgs: [date]);
    }
  }

  /// Gets today's score record
  Future<Map<String, dynamic>?> getDailyScore(String date) async {
    final db = await instance.database;
    final maps = await db.query('daily_scores', where: 'date = ?', whereArgs: [date]);
    if (maps.isNotEmpty) {
      final row = Map<String, dynamic>.from(maps.first);
      row['breakdown'] = jsonDecode(row['breakdown_json'] as String);
      return row;
    }
    return null;
  }

  /// Gets all past daily scores ordered by date desc
  Future<List<Map<String, dynamic>>> getDailyScoreHistory() async {
    final db = await instance.database;
    final results = await db.query('daily_scores', orderBy: 'date DESC');
    return results.map((row) {
      final r = Map<String, dynamic>.from(row);
      r['breakdown'] = jsonDecode(r['breakdown_json'] as String);
      return r;
    }).toList();
  }

  /// Calculate today's score from tasks and routines
  Future<Map<String, dynamic>> calculateTodayScore(String todayDate, String todayDayShort) async {
    final db = await instance.database;

    List<Map<String, dynamic>> breakdown = [];
    int earned = 0;
    int total = 0;

    // --- Tasks scheduled for today ---
    final tasks = await db.query('tasks', where: "date = ? AND recurrenceType = 'Once'", whereArgs: [todayDate]);
    // Daily recurring tasks
    final dailyTasks = await db.query('tasks', where: "recurrenceType = 'Daily'");
    // Custom tasks that include today
    final customTasks = await db.query('tasks', where: "recurrenceType = 'Custom'");
    final now = DateTime.now();
    final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (var t in [...tasks, ...dailyTasks]) {
      int pts = 0;
      String status = 'pending';
      if ((t['isCompleted'] as int) == 1) {
        pts = 100;
        status = 'done';
        total += 100;
        earned += 100;
      } else if ((t['isCompleted'] as int) == 2) {
        pts = 0;
        status = 'missed';
        total += 100;
      } else {
        pts = 0; 
        status = 'pending';
      }
      breakdown.add({
        'type': 'reminder',
        'title': t['title'],
        'time': t['time'],
        'status': status,
        'points': pts,
        'max': 100,
      });
    }

    for (var t in customTasks) {
      final customDates = (t['customDates'] as String).split(',');
      if (customDates.contains(todayDate)) {
        int pts = 0;
        String status = 'pending';
        if ((t['isCompleted'] as int) == 1) {
          pts = 100;
          status = 'done';
          total += 100;
          earned += 100;
        } else if ((t['isCompleted'] as int) == 2) {
          pts = 0;
          status = 'missed';
          total += 100;
        } else {
          pts = 0; 
          status = 'pending';
        }
        breakdown.add({
          'type': 'reminder',
          'title': t['title'],
          'time': t['time'],
          'status': status,
          'points': pts,
          'max': 100,
        });
      }
    }

    // --- Routines for today's day ---
    final routines = await db.query('routines');
    for (var r in routines) {
      final days = (r['days_of_week'] as String).split(',');
      if (days.contains(todayDayShort)) {
        // Check history for completion today
        final history = await db.query('routine_history',
            where: "routine_id = ? AND date = ?", whereArgs: [r['id'], todayDate]);
        int pts = 0;
        String status = 'pending';
        
        if (history.isNotEmpty) {
          int hPts = history.first['score'] as int;
          if (hPts == -1) {
            pts = 0;
            status = 'pending';
          } else {
            pts = hPts;
            status = pts > 0 ? 'done' : 'missed';
            total += 100;
            earned += pts;
          }
        } else {
          pts = 0; 
          status = 'pending';
        }
        breakdown.add({
          'type': 'routine',
          'title': r['title'],
          'time': '${r['start_time']} - ${r['end_time']}',
          'status': status,
          'points': pts,
          'max': 100,
        });
      }
    }

    return {
      'earned': earned,
      'total': total,
      'breakdown': breakdown,
    };
  }
}
