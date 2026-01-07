import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';

/// 英语书籍服务
class EnglishBookService {
  static final EnglishBookService instance = EnglishBookService._();
  EnglishBookService._();

  /// 获取所有英语书籍
  Future<List<EnglishBook>> getBooks() async {
    try {
      final db = await DatabaseHelper.database;

      // 确保表存在
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

      final results = await db.query('EnglishBook', orderBy: 'updateTime DESC');
      return results.map((r) => EnglishBook.fromMap(r)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting English books: $e');
      }
      return [];
    }
  }

  /// 添加英语书籍
  Future<String?> addBook({
    required String title,
    required String content,
    String? author,
  }) async {
    try {
      final db = await DatabaseHelper.database;
      final bookId = const Uuid().v4();
      final now = DateTime.now();

      // 解析章节数
      final chapters = _parseChapters(content);

      await db.insert('EnglishBook', {
        'bookId': bookId,
        'title': title,
        'author': author ?? 'Unknown',
        'content': content,
        'currentPosition': 0,
        'totalChapters': chapters.length,
        'createTime': now.toIso8601String(),
        'updateTime': now.millisecondsSinceEpoch,
      });

      return bookId;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding English book: $e');
      }
      return null;
    }
  }

  /// 获取书籍内容
  Future<String?> getBookContent(String bookId) async {
    try {
      final db = await DatabaseHelper.database;
      final results = await db.query(
        'EnglishBook',
        columns: ['content'],
        where: 'bookId = ?',
        whereArgs: [bookId],
      );
      if (results.isNotEmpty) {
        return results.first['content'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting book content: $e');
      }
      return null;
    }
  }

  /// 更新阅读位置
  Future<void> updateReadingPosition(String bookId, int position) async {
    try {
      final db = await DatabaseHelper.database;
      await db.update(
        'EnglishBook',
        {
          'currentPosition': position,
          'updateTime': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'bookId = ?',
        whereArgs: [bookId],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating reading position: $e');
      }
    }
  }

  /// 删除书籍
  Future<bool> deleteBook(String bookId) async {
    try {
      final db = await DatabaseHelper.database;
      await db.delete('EnglishBook', where: 'bookId = ?', whereArgs: [bookId]);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting book: $e');
      }
      return false;
    }
  }

  /// 解析章节
  List<BookChapter> _parseChapters(String content) {
    final chapters = <BookChapter>[];
    final lines = content.split('\n');

    int currentStart = 0;
    String currentTitle = 'Chapter 1';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      // 检测章节标题
      if (line.toLowerCase().startsWith('chapter') ||
          line.startsWith('第') && line.contains('章') ||
          RegExp(r'^[IVX]+\.').hasMatch(line) ||
          RegExp(r'^\d+\.').hasMatch(line)) {
        if (i > currentStart) {
          chapters.add(BookChapter(
            title: currentTitle,
            startLine: currentStart,
            endLine: i - 1,
          ));
        }
        currentTitle = line;
        currentStart = i;
      }
    }

    // 添加最后一个章节
    if (lines.isNotEmpty) {
      chapters.add(BookChapter(
        title: currentTitle,
        startLine: currentStart,
        endLine: lines.length - 1,
      ));
    }

    return chapters.isEmpty
        ? [BookChapter(title: 'Full Text', startLine: 0, endLine: lines.length - 1)]
        : chapters;
  }

  /// 示例书籍
  static List<Map<String, String>> get sampleBooks => [
    {
      'title': 'The Little Prince',
      'author': 'Antoine de Saint-Exupéry',
      'preview': 'Once when I was six years old I saw a magnificent picture in a book...',
    },
    {
      'title': 'Alice in Wonderland',
      'author': 'Lewis Carroll',
      'preview': 'Alice was beginning to get very tired of sitting by her sister...',
    },
    {
      'title': 'Pride and Prejudice',
      'author': 'Jane Austen',
      'preview': 'It is a truth universally acknowledged, that a single man in possession of a good fortune...',
    },
  ];
}

/// 英语书籍模型
class EnglishBook {
  final String bookId;
  final String title;
  final String author;
  final int currentPosition;
  final int totalChapters;
  final DateTime createTime;
  final int updateTime;

  EnglishBook({
    required this.bookId,
    required this.title,
    required this.author,
    required this.currentPosition,
    required this.totalChapters,
    required this.createTime,
    required this.updateTime,
  });

  factory EnglishBook.fromMap(Map<String, dynamic> map) {
    return EnglishBook(
      bookId: map['bookId'] as String,
      title: map['title'] as String? ?? 'Untitled',
      author: map['author'] as String? ?? 'Unknown',
      currentPosition: map['currentPosition'] as int? ?? 0,
      totalChapters: map['totalChapters'] as int? ?? 0,
      createTime: DateTime.tryParse(map['createTime'] as String? ?? '') ?? DateTime.now(),
      updateTime: map['updateTime'] as int? ?? 0,
    );
  }
}

/// 章节模型
class BookChapter {
  final String title;
  final int startLine;
  final int endLine;

  BookChapter({
    required this.title,
    required this.startLine,
    required this.endLine,
  });
}
