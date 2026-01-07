import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../services/database_helper.dart';

/// Repository for WordBook database operations
class BookRepository {
  Database? _database;
  
  Future<Database> get _db async {
    _database ??= await DatabaseHelper.database;
    return _database!;
  }

  /// Get all word books with statistics
  Future<List<Map<String, dynamic>>> getAllBooks() async {
    final db = await _db;
    
    // Optimized query using subqueries to avoid N+1
    final books = await db.rawQuery('''
      SELECT 
        wb.BookId,
        wb.BookName,
        wb.CreateTime,
        COALESCE(stats.total, 0) as WordCount,
        COALESCE(stats.new_count, 0) as NewCount,
        COALESCE(stats.learning, 0) as LearningCount,
        COALESCE(stats.mastered, 0) as MasteredCount,
        COALESCE(stats.review, 0) as ReviewCount
      FROM WordBook wb
      LEFT JOIN (
        SELECT 
          BookId,
          COUNT(*) as total,
          SUM(CASE WHEN LearnStatus = 0 THEN 1 ELSE 0 END) as new_count,
          SUM(CASE WHEN LearnStatus = 1 THEN 1 ELSE 0 END) as learning,
          SUM(CASE WHEN LearnStatus = 2 THEN 1 ELSE 0 END) as mastered,
          SUM(CASE WHEN NextReviewTime IS NOT NULL AND NextReviewTime <= ? THEN 1 ELSE 0 END) as review
        FROM WordItem
        GROUP BY BookId
      ) stats ON wb.BookId = stats.BookId
      ORDER BY wb.CreateTime DESC
    ''', [DateTime.now().millisecondsSinceEpoch]);
    
    return books;
  }

  /// Get a single book by ID
  Future<Map<String, dynamic>?> getBookById(String bookId) async {
    final db = await _db;
    final results = await db.query(
      'WordBook',
      where: 'BookId = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Get book by name
  Future<Map<String, dynamic>?> getBookByName(String bookName) async {
    final db = await _db;
    final results = await db.query(
      'WordBook',
      where: 'BookName = ?',
      whereArgs: [bookName],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Insert a new book
  Future<int> insertBook(Map<String, dynamic> book) async {
    final db = await _db;
    return await db.insert('WordBook', book);
  }

  /// Delete a book
  Future<int> deleteBook(String bookId) async {
    final db = await _db;
    // Also delete related words
    await db.delete('WordItem', where: 'BookId = ?', whereArgs: [bookId]);
    return await db.delete('WordBook', where: 'BookId = ?', whereArgs: [bookId]);
  }
}
