import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int? _firstIntValue(List<Map<String, dynamic>> result) {
  if (result.isEmpty) return null;
  final firstRow = result.first;
  if (firstRow.isEmpty) return null;
  final value = firstRow.values.first;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}


class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'wordmomo.db';
  static const String _appFolder = 'Vocabu';
  static const String _legacyFolder = 'LovingWord';
  static String? _testDbPath;

  @visibleForTesting
  static void setTestDbPath(String path) {
    _testDbPath = path;
  }

  /// Get the path to the local application document directory
  static Future<String> _getDbPath() async {
    if (_testDbPath != null) return p.join(_testDbPath!, _dbName);

    final docsDir = await getApplicationDocumentsDirectory();

    // 检查并迁移旧数据
    await _migrateFromLegacyPath(docsDir.path);

    final dataDir = Directory(p.join(docsDir.path, _appFolder));
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return p.join(dataDir.path, _dbName);
  }

  /// 从旧路径迁移数据到新路径
  static Future<void> _migrateFromLegacyPath(String docsPath) async {
    final legacyDir = Directory(p.join(docsPath, _legacyFolder));
    final newDir = Directory(p.join(docsPath, _appFolder));

    // 如果旧目录存在且新目录不存在，进行迁移
    if (await legacyDir.exists() && !await newDir.exists()) {
      try {
        if (kDebugMode) {
          debugPrint('Migrating database from $_legacyFolder to $_appFolder...');
        }

        // 创建新目录
        await newDir.create(recursive: true);

        // 复制所有文件
        await for (final entity in legacyDir.list()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final newPath = p.join(newDir.path, fileName);
            await entity.copy(newPath);
            if (kDebugMode) {
              debugPrint('Migrated: $fileName');
            }
          }
        }

        if (kDebugMode) {
          debugPrint('Database migration completed successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error during database migration: $e');
        }
      }
    }
  }

  /// Ensure database file exists, copy from assets if needed
  static Future<void> _ensureDatabaseFromAssets(String dbPath) async {
    final dbFile = File(dbPath);
    final needsCopy = !await dbFile.exists();

    if (needsCopy) {
      try {
        if (kDebugMode) {
          debugPrint('Copying database from assets...');
        }
        final data = await rootBundle.load('assets/wordmomo.db');
        final bytes = data.buffer.asUint8List();
        await dbFile.writeAsBytes(bytes, flush: true);
        if (kDebugMode) {
          debugPrint('Database copied successfully! Size: ${bytes.length} bytes');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error copying database from assets: $e');
        }
      }
    }
  }

  /// Initialize the database connection
  static Future<Database> get database async {
    if (_database != null) return _database!;

    // Initialize FFI for Windows/Linux
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _getDbPath();
    if (kDebugMode) {
      debugPrint('Database path: $dbPath');
    }

    // Ensure database exists from assets
    await _ensureDatabaseFromAssets(dbPath);

    if (kDebugMode) {
      debugPrint('Opening database at: $dbPath');
    }

    _database = await openDatabase(
      dbPath,
      version: 1,
      onOpen: (db) async {
        if (kDebugMode) {
          debugPrint('Database opened successfully');
        }

        // Ensure required tables exist
        await _ensureTablesExist(db);

        // Verify we have data
        if (kDebugMode) {
          try {
            final count = await db.rawQuery('SELECT COUNT(*) FROM WordBook');
            final bookCount = _firstIntValue(count) ?? 0;
            debugPrint('Database has $bookCount word books');
          } catch (e) {
            debugPrint('Error checking database: $e');
          }
        }
      },
    );

    return _database!;
  }

  /// Ensure required tables exist in the database
  static Future<void> _ensureTablesExist(Database db) async {
    // Create CourseSentence table for listening materials
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CourseSentence (
        SentenceId TEXT PRIMARY KEY,
        BookId TEXT,
        SentenceText TEXT,
        Translate TEXT,
        Sort INTEGER DEFAULT 0,
        UpdateTime INTEGER,
        SpellCount INTEGER DEFAULT 0,
        ErrorCount INTEGER DEFAULT 0,
        SentenceStatus INTEGER DEFAULT 0
      )
    ''');

    // Create WordUnit table for book units
    await db.execute('''
      CREATE TABLE IF NOT EXISTS WordUnit (
        UnitId TEXT PRIMARY KEY,
        BookId TEXT,
        UnitName TEXT,
        UnitOrder INTEGER DEFAULT 0,
        WordCount INTEGER DEFAULT 0,
        CreateTime TEXT,
        UpdateTime INTEGER
      )
    ''');

    // Create WordItem table if not exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS WordItem (
        WordId TEXT PRIMARY KEY,
        BookId TEXT,
        UnitId TEXT,
        Word TEXT,
        Translate TEXT,
        Symbol TEXT,
        Example TEXT,
        ExampleTrans TEXT,
        SentenceEn TEXT,
        SentenceCn TEXT,
        LearnStatus INTEGER DEFAULT 0,
        CreateTime TEXT,
        UpdateTime INTEGER,
        ReviewCount INTEGER DEFAULT 0,
        ShowCount INTEGER DEFAULT 0,
        TotalReviewCount INTEGER DEFAULT 0,
        Collected INTEGER DEFAULT 0
      )
    ''');

    // Create EnglishBook table for English reading materials
    await db.execute('''
      CREATE TABLE IF NOT EXISTS EnglishBook (
        bookId TEXT PRIMARY KEY,
        title TEXT,
        author TEXT,
        content TEXT,
        currentPosition INTEGER DEFAULT 0,
        totalChapters INTEGER DEFAULT 0,
        createTime TEXT,
        updateTime INTEGER
      )
    ''');

    if (kDebugMode) {
      debugPrint('All tables ensured');
    }
  }

  /// Check database status
  static Future<Map<String, dynamic>> checkDatabase() async {
    final db = await database;
    final stats = <String, dynamic>{};
    
    try {
      final bookCount = await db.rawQuery('SELECT COUNT(*) FROM WordBook');
      stats['wordBooks'] = _firstIntValue(bookCount) ?? 0;
      
      final wordCount = await db.rawQuery('SELECT COUNT(*) FROM CourseContent');
      stats['words'] = _firstIntValue(wordCount) ?? 0;
      
      stats['status'] = 'ok';
    } catch (e) {
      stats['status'] = 'error';
      stats['error'] = e.toString();
    }
    
    return stats;
  }
}
