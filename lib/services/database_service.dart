import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/walk_session.dart';
import '../models/saved_route.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  DatabaseService._init();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'walk_tracker_v6.db');
    return openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE walk_sessions (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        date           TEXT NOT NULL,
        duration       INTEGER NOT NULL,
        distance       REAL NOT NULL,
        steps          INTEGER NOT NULL,
        calories       INTEGER NOT NULL,
        avgSpeed       REAL NOT NULL,
        routePoints    TEXT NOT NULL,
        targetDistance REAL NOT NULL,
        tripType       TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE saved_routes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        description TEXT,
        distance    REAL NOT NULL,
        routePoints TEXT NOT NULL,
        createdAt   TEXT NOT NULL,
        isFavorite  INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE badges (
        id       TEXT PRIMARY KEY,
        earned   INTEGER NOT NULL DEFAULT 0,
        earnedAt TEXT,
        progress REAL NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertWalkSession(WalkSession s) async {
    final db = await database;
    return db.insert('walk_sessions', s.toMap()..remove('id'));
  }

  Future<List<WalkSession>> getWalkSessions() async {
    final db = await database;
    final maps = await db.query('walk_sessions', orderBy: 'date DESC');
    return maps.map(WalkSession.fromMap).toList();
  }

  Future<Map<String, dynamic>> getStats() async {
    final sessions = await getWalkSessions();
    double totalDist = 0;
    int    totalSteps = 0;
    int    totalCals  = 0;
    for (final s in sessions) {
      totalDist  += s.distance;
      totalSteps += s.steps;
      totalCals  += s.calories;
    }
    return {
      'totalSessions': sessions.length,
      'totalDistance': totalDist,
      'totalSteps':    totalSteps,
      'totalCalories': totalCals,
    };
  }

  Future<void> deleteWalkSession(int id) async {
    final db = await database;
    await db.delete('walk_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertSavedRoute(SavedRoute r) async {
    final db = await database;
    return db.insert('saved_routes', r.toMap()..remove('id'));
  }

  Future<List<SavedRoute>> getSavedRoutes() async {
    final db = await database;
    final maps = await db.query('saved_routes', orderBy: 'createdAt DESC');
    return maps.map(SavedRoute.fromMap).toList();
  }

  Future<void> deleteSavedRoute(int id) async {
    final db = await database;
    await db.delete('saved_routes', where: 'id = ?', whereArgs: [id]);
  }

  // alias للتوافق مع الشاشات القديمة
  Future<void> deleteRoute(int id) => deleteSavedRoute(id);

  Future<List<SavedRoute>> getFavoriteRoutes() async {
    final db = await database;
    final maps = await db.query('saved_routes',
        where: 'isFavorite = 1', orderBy: 'createdAt DESC');
    return maps.map(SavedRoute.fromMap).toList();
  }

  Future<void> toggleFavorite(int id, bool currentValue) async {
    final db = await database;
    await db.update('saved_routes',
        {'isFavorite': currentValue ? 0 : 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRouteUsage(int id) async {
    // لا يوجد عمود usageCount في المخطط الحالي — نتجاهله بأمان
  }

  Future<void> updateRoute(SavedRoute route) async {
    final db = await database;
    await db.update('saved_routes', route.toMap(),
        where: 'id = ?', whereArgs: [route.id]);
  }

  Future<void> markBadgeEarned(String badgeId) async {
    final db = await database;
    await db.insert('badges', {
      'id': badgeId, 'earned': 1, 'earnedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Set<String>> getEarnedBadgeIds() async {
    final db = await database;
    final rows = await db.query('badges', where: 'earned = 1');
    return rows.map((r) => r['id'] as String).toSet();
  }
}