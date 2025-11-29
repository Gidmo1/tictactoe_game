import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  LocalDb._privateConstructor();
  static final LocalDb instance = LocalDb._privateConstructor();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    await init();
    return _db!;
  }

  Future<void> init() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tictactoe_game.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE players(
            google_id TEXT PRIMARY KEY,
            display_name TEXT,
            avatar_name TEXT,
            avatar_url TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE guest_scores(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT,
            wins INTEGER,
            draws INTEGER,
            losses INTEGER,
            points INTEGER,
            timestamp TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE game_stats(
            user_id TEXT PRIMARY KEY,
            level INTEGER,
            highscore INTEGER
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // Player methods
  Future<void> upsertPlayer({
    required String googleId,
    String? displayName,
    String? avatarName,
    String? avatarUrl,
  }) async {
    final db = await database;
    await db.insert('players', {
      'google_id': googleId,
      'display_name': displayName,
      'avatar_name': avatarName,
      'avatar_url': avatarUrl,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getPlayer(String googleId) async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'google_id = ?',
      whereArgs: [googleId],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // Guest score methods
  Future<void> saveGuestScore(
    String playerId,
    Map<String, dynamic> score,
  ) async {
    final db = await database;
    await db.insert('guest_scores', {
      'player_id': playerId,
      'wins': score['wins'] ?? 0,
      'draws': score['draws'] ?? 0,
      'losses': score['losses'] ?? 0,
      'points': score['points'] ?? 0,
      'timestamp': score['timestamp'] ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getGuestScores(String playerId) async {
    final db = await database;
    return await db.query(
      'guest_scores',
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllGuestScores() async {
    final db = await database;
    return await db.query('guest_scores');
  }

  Future<void> deleteGuestScoresFor(String playerId) async {
    final db = await database;
    await db.delete(
      'guest_scores',
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
  }

  // Game stats
  Future<void> upsertGameStats({
    required String userId,
    int? level,
    int? highscore,
  }) async {
    final db = await database;
    await db.insert('game_stats', {
      'user_id': userId,
      'level': level ?? 1,
      'highscore': highscore ?? 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getGameStats(String userId) async {
    final db = await database;
    final rows = await db.query(
      'game_stats',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }
}
