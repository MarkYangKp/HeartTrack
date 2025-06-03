import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/health_data.dart';

class DatabaseService {
  static Database? _database;
  static const String tableName = 'health_data';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'health_monitor.db');
    return await openDatabase(
      path,
      version: 2, // 增加版本号
      onCreate: _createTable,
      onUpgrade: _upgradeTable,
    );
  }

  Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        heartRate INTEGER NOT NULL,
        oxygenSaturation INTEGER NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeTable(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 删除旧表并创建新表
      await db.execute('DROP TABLE IF EXISTS $tableName');
      await _createTable(db, newVersion);
    }
  }

  Future<int> insertHealthData(HealthData data) async {
    final db = await database;
    return await db.insert(tableName, data.toMap());
  }

  Future<List<HealthData>> getAllHealthData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => HealthData.fromMap(maps[i]));
  }

  Future<List<HealthData>> getRecentHealthData(int days) async {
    final db = await database;
    final timestamp = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'timestamp > ?',
      whereArgs: [timestamp],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => HealthData.fromMap(maps[i]));
  }

  Future<void> deleteHealthData(int id) async {
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }
}
