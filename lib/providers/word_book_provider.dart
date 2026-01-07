import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_helper.dart';

// Helper function to replace Sqflite.firstIntValue
int? _firstIntValue(List<Map<String, dynamic>> result) {
  if (result.isEmpty) return null;
  final firstRow = result.first;
  if (firstRow.isEmpty) return null;
  final value = firstRow.values.first;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

class WordBook {
  final String bookId;
  final String bookName;
  final int wordCount;
  final int newCount;
  final int learningCount;
  final int masteredCount;
  final int reviewCount;
  final int collectedCount;
  final String? createTime;

  WordBook({
    required this.bookId,
    required this.bookName,
    required this.wordCount,
    this.newCount = 0,
    this.learningCount = 0,
    this.masteredCount = 0,
    this.reviewCount = 0,
    this.collectedCount = 0,
    this.createTime,
  });

  double get progress => wordCount > 0 ? masteredCount / wordCount : 0;

  factory WordBook.fromMap(Map<String, dynamic> map) {
    return WordBook(
      bookId: map['BookId'] as String? ?? '',
      bookName: map['BookName'] as String? ?? 'Unknown',
      wordCount: map['WordCount'] as int? ?? 0,
      createTime: map['CreateTime'] as String?,
    );
  }
}

class WordBookProvider extends ChangeNotifier {
  static WordBookProvider? _instance;
  Database? _database;
  List<WordBook> _books = [];
  bool _isLoading = false;
  String? _error;

  List<WordBook> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static WordBookProvider get instance {
    _instance ??= WordBookProvider();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    try {
      _database = await DatabaseHelper.database;
      if (kDebugMode) {
        debugPrint('Database initialized in Provider');
      }
      await loadBooks();
    } catch (e) {
      _error = 'Database init error: $e';
      if (kDebugMode) {
        debugPrint(_error);
      }
    }
  }

  Map<String, dynamic> _homePageStats = {};
  Map<String, dynamic> get homePageStats => _homePageStats;

  Future<void> loadBooks() async {
    if (_database == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _loadStats();

      // 获取所有词书
      final bookRows = await _database!.query('WordBook');

      // 使用单个查询获取所有词书的统计数据（解决N+1查询问题）
      final now = DateTime.now().millisecondsSinceEpoch;
      final statsRows = await _database!.rawQuery('''
        SELECT
          BookId,
          COUNT(*) as total,
          SUM(CASE WHEN LearnStatus = 0 THEN 1 ELSE 0 END) as newWords,
          SUM(CASE WHEN LearnStatus = 1 THEN 1 ELSE 0 END) as learning,
          SUM(CASE WHEN LearnStatus = 2 THEN 1 ELSE 0 END) as mastered,
          SUM(CASE WHEN NextReviewTime IS NOT NULL AND CAST(NextReviewTime AS INTEGER) <= ? THEN 1 ELSE 0 END) as review
        FROM WordItem
        GROUP BY BookId
      ''', [now]);

      // 将统计数据转为Map方便查找
      final statsMap = <String, Map<String, int>>{};
      for (final row in statsRows) {
        final bookId = row['BookId'] as String? ?? '';
        statsMap[bookId] = {
          'total': (row['total'] as int?) ?? 0,
          'newWords': (row['newWords'] as int?) ?? 0,
          'learning': (row['learning'] as int?) ?? 0,
          'mastered': (row['mastered'] as int?) ?? 0,
          'review': (row['review'] as int?) ?? 0,
        };
      }

      // 组装词书列表
      final booksList = <WordBook>[];
      for (final row in bookRows) {
        final bookId = row['BookId'] as String? ?? '';
        final stats = statsMap[bookId] ?? {'total': 0, 'newWords': 0, 'learning': 0, 'mastered': 0, 'review': 0};

        booksList.add(WordBook(
          bookId: bookId,
          bookName: row['BookName'] as String? ?? 'Unknown',
          wordCount: stats['total']!,
          newCount: stats['newWords']!,
          learningCount: stats['learning']!,
          masteredCount: stats['mastered']!,
          reviewCount: stats['review']!,
          createTime: row['CreateTime'] as String?,
        ));
      }

      _books = booksList;
      if (kDebugMode) {
        debugPrint('Loaded ${_books.length} books');
      }
    } catch (e) {
      _error = 'Error loading books: $e';
      if (kDebugMode) {
        debugPrint(_error);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadStats() async {
    try {
      final rows = await _database!.query('DailyLearnInfo', orderBy: 'LearnDate DESC', limit: 365);
      
      int todayDuration = 0;
      int totalDays = rows.length;
      
      final Map<DateTime, int> heatmapData = {};
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      for (var row in rows) {
        final dateVal = row['LearnDate'];
        String dateStr = '';
        if (dateVal is String) dateStr = dateVal;
        
        final duration = row['LearnTime'] as int? ?? 0; 
        
        DateTime? date;
        try {
          if (dateStr.contains('-')) {
            date = DateTime.parse(dateStr);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to parse date: $dateStr, error: $e');
          }
        }
        
        if (date != null) {
          heatmapData[date] = (duration / 60).round();
          if (dateStr == todayStr) {
            todayDuration = duration;
          }
        }
      }
      
      _homePageStats = {
        'todayDuration': (todayDuration / 60).round(),
        'totalDays': totalDays,
        'heatmap': heatmapData,
      };

      // 计算正确率（已掌握 / 已学习过的单词）
      await _calculateAccuracy();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading stats: $e');
      }
    }
  }

  Future<void> _calculateAccuracy() async {
    try {
      // 统计所有词书的学习情况
      final masteredCount = _firstIntValue(await _database!.rawQuery(
        'SELECT COUNT(*) FROM WordItem WHERE LearnStatus = 2')) ?? 0;
      final learnedCount = _firstIntValue(await _database!.rawQuery(
        'SELECT COUNT(*) FROM WordItem WHERE LearnStatus > 0')) ?? 0;

      // 计算掌握率
      final accuracy = learnedCount > 0
          ? ((masteredCount / learnedCount) * 100).round()
          : 0;

      _homePageStats['accuracy'] = accuracy;
      _homePageStats['masteredTotal'] = masteredCount;
      _homePageStats['learnedTotal'] = learnedCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating accuracy: $e');
      }
      _homePageStats['accuracy'] = 0;
    }
  }

  Future<List<Map<String, dynamic>>> getWordsForBook(String bookId, {int? status, int limit = 100}) async {
    if (_database == null) return [];
    
    String where = 'BookId = ?';
    List<dynamic> args = [bookId];
    
    if (status != null) {
      where += ' AND LearnStatus = ?';
      args.add(status);
    }
    
    return await _database!.query('WordItem', where: where, whereArgs: args, limit: limit);
  }

  Future<List<Map<String, dynamic>>> getWordsForReview(String bookId, {int limit = 100}) async {
    if (_database == null) return [];

    final now = DateTime.now().millisecondsSinceEpoch;
    // 只查询已学习过的单词 (LearnStatus >= 1) 且到达复习时间的
    // LearnStatus: 0=新单词, 1=学习中, 2=已掌握
    return await _database!.query('WordItem',
      where: 'BookId = ? AND LearnStatus >= 1 AND NextReviewTime IS NOT NULL AND NextReviewTime <= ?',
      whereArgs: [bookId, now],
      limit: limit);
  }

  Future<List<Map<String, dynamic>>> getUnitsForBook(String bookId) async {
    if (_database == null) return [];
    try {
      // Query safely - try with UnitOrder first, fallback to UnitId if column doesn't exist
      List<Map<String, dynamic>> units;
      try {
        units = await _database!.query('WordUnit',
          where: 'BookId = ?',
          whereArgs: [bookId],
          orderBy: 'UnitOrder ASC');
      } catch (e) {
        // UnitOrder column might not exist, try without ordering or with UnitId
        units = await _database!.query('WordUnit',
          where: 'BookId = ?',
          whereArgs: [bookId],
          orderBy: 'UnitId ASC');
      }

      if (units.isEmpty) return [];

      if (kDebugMode) {
        debugPrint('📚 getUnitsForBook: found ${units.length} units for bookId=$bookId');
      }

      // 从数据库获取每个单元的实际单词数量
      final unitWordCounts = await _getWordCountsPerUnit(bookId);

      // 计算每个单元的 startIndex（基于前面单元的累计词数）
      List<Map<String, dynamic>> unitsWithIndex = [];
      int cumulativeIndex = 0;

      for (final unit in units) {
        final unitMap = Map<String, dynamic>.from(unit);
        final unitId = unit['UnitId'] as String? ?? '';

        // 尝试多种方式获取单词数量:
        // 1. 首先尝试从数据库查询的实际单词数
        // 2. 然后尝试 WordCount 字段 (大写)
        // 3. 最后尝试 wordCount 字段 (小写)
        int wordCount = unitWordCounts[unitId] ??
                        (unit['WordCount'] as int?) ??
                        (unit['wordCount'] as int?) ??
                        0;

        // 如果仍然是0，尝试实时查询该单元的单词数
        if (wordCount == 0 && unitId.isNotEmpty) {
          wordCount = await _getWordCountForUnit(bookId, unitId);
        }

        unitMap['startIndex'] = cumulativeIndex;
        unitMap['wordCount'] = wordCount;
        unitMap['WordCount'] = wordCount; // 同时设置两个版本

        if (kDebugMode && unitsWithIndex.length < 3) {
          debugPrint('📚 Unit ${unitsWithIndex.length}: ${unit['UnitName']}, wordCount=$wordCount');
        }

        unitsWithIndex.add(unitMap);
        cumulativeIndex += wordCount;
      }

      return unitsWithIndex;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting units (table may not exist): $e');
      }
      return [];
    }
  }

  /// 获取每个单元的单词数量（批量查询）
  Future<Map<String, int>> _getWordCountsPerUnit(String bookId) async {
    if (_database == null) return {};

    try {
      final result = await _database!.rawQuery('''
        SELECT UnitId, COUNT(*) as count
        FROM WordItem
        WHERE BookId = ? AND UnitId IS NOT NULL AND UnitId != ''
        GROUP BY UnitId
      ''', [bookId]);

      final Map<String, int> counts = {};
      for (final row in result) {
        final unitId = row['UnitId'] as String? ?? '';
        final count = row['count'] as int? ?? 0;
        if (unitId.isNotEmpty) {
          counts[unitId] = count;
        }
      }
      return counts;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting word counts per unit: $e');
      }
      return {};
    }
  }

  /// 获取单个单元的单词数量
  Future<int> _getWordCountForUnit(String bookId, String unitId) async {
    if (_database == null) return 0;

    try {
      final result = await _database!.rawQuery('''
        SELECT COUNT(*) as count
        FROM WordItem
        WHERE BookId = ? AND UnitId = ?
      ''', [bookId, unitId]);

      if (result.isNotEmpty) {
        return result.first['count'] as int? ?? 0;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting word count for unit: $e');
      }
    }
    return 0;
  }

  Future<void> updateWordStatus(String wordId, int status, String? learnParam, String? nextReviewTime) async {
    if (_database == null) return;
    
    final updates = <String, dynamic>{
      'LearnStatus': status,
      'UpdateTime': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    if (learnParam != null) updates['LearnParam'] = learnParam;
    if (nextReviewTime != null) updates['NextReviewTime'] = nextReviewTime;
    
    await _database!.update('WordItem', updates, where: 'WordId = ?', whereArgs: [wordId]);
    
    await _updateDailyLearnInfo();
    await loadBooks();
  }

  Future<void> _updateDailyLearnInfo() async {
    if (_database == null) return;

    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    try {
      final rows = await _database!.query('DailyLearnInfo', where: 'LearnDate = ?', whereArgs: [dateStr]);
      
      if (rows.isNotEmpty) {
        final currentDuration = rows.first['LearnTime'] as int? ?? 0;
        await _database!.update('DailyLearnInfo', {
          'LearnTime': currentDuration + 30, 
          'UpdateTime': now.millisecondsSinceEpoch,
        }, where: 'LearnDate = ?', whereArgs: [dateStr]);
      } else {
        await _database!.insert('DailyLearnInfo', {
          'LearnDate': dateStr,
          'LearnTime': 30,
          'ContinuityDays': 1,
          'UpdateTime': now.millisecondsSinceEpoch,
        });
      }
      
      await _loadStats();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating daily stats: $e');
      }
    }
  }

  Future<void> collectWord(String wordId, bool collected) async {
    if (_database == null) return;
    
    await _database!.update(
      'WordItem',
      {'Collected': collected ? 1 : 0},
      where: 'WordId = ?',
      whereArgs: [wordId],
    );
    notifyListeners();
  }

  Future<void> setMastered(String wordId) async {
    if (_database == null) return;
    
    await _database!.update(
      'WordItem',
      {
        'LearnStatus': 2,
        'MasterTime': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      where: 'WordId = ?',
      whereArgs: [wordId],
    );
    await loadBooks();
  }

  Future<List<Map<String, dynamic>>> getCollectedWords({int limit = 100}) async {
    if (_database == null) return [];

    return await _database!.query(
      'WordItem',
      where: 'Collected = 1',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getCollectedWordsForBook(String bookId, {int limit = 100}) async {
    if (_database == null) return [];

    return await _database!.query(
      'WordItem',
      where: 'BookId = ? AND Collected = 1',
      whereArgs: [bookId],
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getSentencesForBook(String? bookId, {int limit = 50}) async {
    if (_database == null || bookId == null) return [];
    
    return await _database!.query(
      'CourseSentence',
      where: 'BookId = ?',
      whereArgs: [bookId],
      orderBy: 'Sort ASC',
      limit: limit,
    );
  }

  Future<bool> migrateFromOriginal() async {
    // Database is now bundled with the app, migration is not needed
    if (kDebugMode) {
      debugPrint('Database is bundled with app, no migration required');
    }
    await loadBooks();
    return true;
  }

  /// Add a new word to a word book
  Future<bool> addWordToBook({
    required String bookId,
    required String word,
    required String translation,
    String? phonetic,
    String? example,
    String? exampleTranslation,
  }) async {
    if (_database == null) return false;

    try {
      // Check if word already exists in this book
      final existing = await _database!.query(
        'WordItem',
        where: 'BookId = ? AND Word = ?',
        whereArgs: [bookId, word],
      );

      if (existing.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('Word "$word" already exists in book $bookId');
        }
        return false;
      }

      // Generate a unique WordId
      final wordId = '${bookId}_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch.toString();

      // Insert the new word
      await _database!.insert('WordItem', {
        'WordId': wordId,
        'BookId': bookId,
        'Word': word,
        'Translate': translation,
        'SymbolUs': phonetic ?? '',
        'SymbolEn': phonetic ?? '',
        'SentenceEn': example ?? '',
        'SentenceCn': exampleTranslation ?? '',
        'LearnStatus': 0,
        'Collected': 0,
        'CreateTime': now,
        'UpdateTime': now,
      });

      if (kDebugMode) {
        debugPrint('Added word "$word" to book $bookId');
      }

      // Reload books to update word counts
      await loadBooks();

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding word to book: $e');
      }
      return false;
    }
  }

  /// Create a new word book
  Future<String?> createWordBook(String bookName) async {
    if (_database == null) return null;

    try {
      final bookId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch.toString();

      await _database!.insert('WordBook', {
        'BookId': bookId,
        'BookName': bookName,
        'WordCount': 0,
        'CreateTime': now,
        'UpdateTime': now,
      });

      await loadBooks();
      return bookId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating word book: $e');
      }
      return null;
    }
  }

  /// Delete a word book and all its words
  Future<bool> deleteWordBook(String bookId) async {
    if (_database == null) return false;

    try {
      // Delete all words in this book
      await _database!.delete('WordItem', where: 'BookId = ?', whereArgs: [bookId]);

      // Delete all sentences in this book
      await _database!.delete('CourseSentence', where: 'BookId = ?', whereArgs: [bookId]);

      // Delete all units in this book
      await _database!.delete('WordUnit', where: 'BookId = ?', whereArgs: [bookId]);

      // Delete the book itself
      await _database!.delete('WordBook', where: 'BookId = ?', whereArgs: [bookId]);

      if (kDebugMode) {
        debugPrint('Deleted word book: $bookId');
      }
      await loadBooks();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting word book: $e');
      }
      return false;
    }
  }

  /// Get words for a book with pagination (for unit-based learning)
  Future<List<Map<String, dynamic>>> getWordsForBookByRange(String bookId, {int offset = 0, int limit = 30}) async {
    if (_database == null) return [];

    if (kDebugMode) {
      debugPrint('getWordsForBookByRange: bookId=$bookId, offset=$offset, limit=$limit');
    }

    // 使用 Sort 列或 WordId 排序以确保一致的顺序
    final result = await _database!.query(
      'WordItem',
      where: 'BookId = ?',
      whereArgs: [bookId],
      orderBy: 'Sort ASC, WordId ASC',
      limit: limit,
      offset: offset,
    );

    if (kDebugMode) {
      debugPrint('Query returned ${result.length} words, first: ${result.isNotEmpty ? result.first['Word'] : 'none'}');
    }
    return result;
  }

  /// Get words with pagination and optional status filter (optimized for large books)
  Future<List<Map<String, dynamic>>> getWordsForBookPaginated({
    required String bookId,
    int? status,
    bool? collected,
    int offset = 0,
    int limit = 50,
  }) async {
    if (_database == null) return [];

    String where = 'BookId = ?';
    List<dynamic> args = [bookId];

    if (status != null) {
      where += ' AND LearnStatus = ?';
      args.add(status);
    }

    if (collected == true) {
      where += ' AND Collected = 1';
    }

    return await _database!.query(
      'WordItem',
      where: where,
      whereArgs: args,
      orderBy: 'Sort ASC, WordId ASC',
      limit: limit,
      offset: offset,
    );
  }

  /// Get total word count with optional filters (for pagination info)
  Future<int> getWordCountForBook({
    required String bookId,
    int? status,
    bool? collected,
  }) async {
    if (_database == null) return 0;

    String where = 'BookId = ?';
    List<dynamic> args = [bookId];

    if (status != null) {
      where += ' AND LearnStatus = ?';
      args.add(status);
    }

    if (collected == true) {
      where += ' AND Collected = 1';
    }

    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM WordItem WHERE $where',
      args,
    );

    return result.first['count'] as int? ?? 0;
  }
}
