import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_helper.dart';

/// Repository for Word database operations
class WordRepository {
  Database? _database;
  
  Future<Database> get _db async {
    _database ??= await DatabaseHelper.database;
    return _database!;
  }

  /// Get words for a book with optional filters
  Future<List<Map<String, dynamic>>> getWordsForBook(
    String bookId, {
    int? status,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _db;
    
    String where = 'BookId = ?';
    List<dynamic> args = [bookId];
    
    if (status != null) {
      where += ' AND LearnStatus = ?';
      args.add(status);
    }
    
    return await db.query(
      'WordItem',
      where: where,
      whereArgs: args,
      limit: limit,
      offset: offset,
      orderBy: 'Sort ASC',
    );
  }

  /// Get words due for review
  Future<List<Map<String, dynamic>>> getWordsForReview(
    String bookId, {
    int limit = 100,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.query(
      'WordItem',
      where: 'BookId = ? AND NextReviewTime IS NOT NULL AND NextReviewTime <= ?',
      whereArgs: [bookId, now],
      limit: limit,
    );
  }

  /// Get collected (favorite) words
  Future<List<Map<String, dynamic>>> getCollectedWords({int limit = 100}) async {
    final db = await _db;
    return await db.query(
      'WordItem',
      where: 'Collected = 1',
      limit: limit,
    );
  }

  /// Get words with errors (error book)
  Future<List<Map<String, dynamic>>> getErrorWords({int limit = 100}) async {
    final db = await _db;
    return await db.query(
      'WordItem',
      where: 'ErrorCount > 0',
      orderBy: 'ErrorCount DESC',
      limit: limit,
    );
  }

  /// Get a single word by ID
  Future<Map<String, dynamic>?> getWordById(String wordId) async {
    final db = await _db;
    final results = await db.query(
      'WordItem',
      where: 'WordId = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update word learning status
  Future<int> updateWordStatus({
    required String wordId,
    required int status,
    String? learnParam,
    String? nextReviewTime,
  }) async {
    final db = await _db;
    
    final updates = <String, dynamic>{
      'LearnStatus': status,
      'UpdateTime': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    if (learnParam != null) updates['LearnParam'] = learnParam;
    if (nextReviewTime != null) updates['NextReviewTime'] = nextReviewTime;
    
    return await db.update(
      'WordItem',
      updates,
      where: 'WordId = ?',
      whereArgs: [wordId],
    );
  }

  /// Mark word as mastered
  Future<int> setMastered(String wordId) async {
    final db = await _db;
    return await db.update(
      'WordItem',
      {
        'LearnStatus': 2,
        'MasterTime': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      where: 'WordId = ?',
      whereArgs: [wordId],
    );
  }

  /// Toggle word collection (favorite)
  Future<int> toggleCollected(String wordId, bool collected) async {
    final db = await _db;
    return await db.update(
      'WordItem',
      {'Collected': collected ? 1 : 0},
      where: 'WordId = ?',
      whereArgs: [wordId],
    );
  }

  /// Increment error count for a word
  Future<int> incrementErrorCount(String wordId) async {
    final db = await _db;
    return await db.rawUpdate(
      'UPDATE WordItem SET ErrorCount = ErrorCount + 1 WHERE WordId = ?',
      [wordId],
    );
  }

  /// Clear error count for a word (remove from error book)
  Future<int> clearErrorCount(String wordId) async {
    final db = await _db;
    return await db.update(
      'WordItem',
      {'ErrorCount': 0},
      where: 'WordId = ?',
      whereArgs: [wordId],
    );
  }

  /// Insert a new word
  Future<int> insertWord(Map<String, dynamic> word) async {
    final db = await _db;
    return await db.insert('WordItem', word);
  }

  /// Batch insert words
  Future<void> insertWords(List<Map<String, dynamic>> words) async {
    final db = await _db;
    final batch = db.batch();
    for (final word in words) {
      batch.insert('WordItem', word);
    }
    await batch.commit(noResult: true);
  }

  /// Search words by text
  Future<List<Map<String, dynamic>>> searchWords(
    String query, {
    int limit = 50,
  }) async {
    final db = await _db;
    return await db.query(
      'WordItem',
      where: 'Word LIKE ? OR Translate LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: limit,
    );
  }
}
