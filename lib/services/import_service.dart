import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:uuid/uuid.dart';
import 'database_helper.dart';

class ImportService {
  static final ImportService instance = ImportService._();
  ImportService._();

  /// Import a book from a raw JSON string
  /// Expected Format:
  /// {
  ///   "bookName": "My Book",
  ///   "words": [
  ///     {"word": "apple", "trans": "苹果", "symbol": "[...]", "example": "..."}
  ///   ]
  /// }
  Future<String> importBookFromJson(String jsonContent) async {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      
      final String bookName = data['bookName'] as String? ?? 'Imported Book';
      final List<dynamic> words = data['words'] as List<dynamic>? ?? [];
      
      if (words.isEmpty) {
        return 'No words found in JSON';
      }

      final db = await DatabaseHelper.database;
      final batch = db.batch();
      
      // 1. Create Book Record
      final String bookId = const Uuid().v4();
      final int wordCount = words.length;
      final int nowMillis = DateTime.now().millisecondsSinceEpoch;
      final String createTimeStr = DateTime.now().toIso8601String();
      
      batch.insert('WordBook', {
        'BookId': bookId,
        'BookName': bookName,
        'ReviewType': 'FSRS',
        'CreateTime': createTimeStr,
        'UpdateTime': nowMillis,
        'Sort': '1',
      });
      
      // 2. Insert Words
      for (var w in words) {
        final String wordText = w['word'] ?? w['Word'] ?? '';
        if (wordText.isEmpty) continue;
        
        final String wordId = const Uuid().v4();
        
        // Handle different possible JSON key formats
        final String translate = w['trans'] ?? w['translation'] ?? w['mean'] ?? w['Translate'] ?? '';
        final String symbol = w['symbol'] ?? w['phonetic'] ?? w['Symbol'] ?? '';
        final String example = w['example'] ?? w['sentence'] ?? w['Example'] ?? '';
        
        batch.insert('WordItem', {
          'WordId': wordId,
          'BookId': bookId,
          'Word': wordText,
          'Translate': translate,
          'Symbol': symbol,
          'LearnStatus': 0, // New
          'CreateTime': createTimeStr,
          'UpdateTime': nowMillis,
          'ReviewCount': 0,
          'ShowCount': 0,
          'TotalReviewCount': 0,
        });

        if (example.isNotEmpty) {
           batch.insert('CourseSentence', {
             'SentenceId': const Uuid().v4(),
             'BookId': bookId,
             'SentenceText': example,
             'Translate': translate,
             'UpdateTime': nowMillis,
             'SpellCount': 0,
             'ErrorCount': 0,
             'SentenceStatus': 0,
           });
        }
      }
      
      await batch.commit(noResult: true);
      
      return 'Success: Imported "$bookName" with $wordCount words.';

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Import Error: $e');
      }
      return 'Error: $e';
    }
  }

  /// Import listening materials (sentences) for a book
  /// Expected Format:
  /// {
  ///   "sentences": [
  ///     {"en": "Hello, how are you?", "cn": "你好，你好吗？"},
  ///     {"en": "I am fine, thank you.", "cn": "我很好，谢谢。"}
  ///   ]
  /// }
  /// Or plain text format with en/cn pairs separated by newlines
  Future<String> importListeningMaterials(String bookId, String content) async {
    try {
      final db = await DatabaseHelper.database;
      final batch = db.batch();
      final int nowMillis = DateTime.now().millisecondsSinceEpoch;
      int count = 0;

      if (kDebugMode) {
        debugPrint('Importing listening materials for book: $bookId');
        debugPrint('Content length: ${content.length}');
      }

      // Try JSON format first
      try {
        final data = jsonDecode(content);
        List<dynamic> sentences = [];

        if (data is Map && data['sentences'] != null) {
          sentences = data['sentences'] as List<dynamic>;
        } else if (data is List) {
          sentences = data;
        }

        if (kDebugMode) {
          debugPrint('Found ${sentences.length} sentences in JSON');
        }

        for (int i = 0; i < sentences.length; i++) {
          final s = sentences[i];
          final String en = s['en'] ?? s['english'] ?? s['sentence'] ?? s['text'] ?? '';
          final String cn = s['cn'] ?? s['chinese'] ?? s['translation'] ?? s['trans'] ?? '';

          if (en.isEmpty) continue;

          batch.insert('CourseSentence', {
            'SentenceId': const Uuid().v4(),
            'BookId': bookId,
            'SentenceText': en,
            'Translate': cn,
            'Sort': i,
            'UpdateTime': nowMillis,
            'SpellCount': 0,
            'ErrorCount': 0,
            'SentenceStatus': 0,
          });
          count++;
        }
      } catch (jsonError) {
        if (kDebugMode) {
          debugPrint('JSON parse failed, trying plain text: $jsonError');
        }
        // Not JSON, try plain text format
        // Format: English sentence\nChinese translation\n\n (repeat)
        final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

        for (int i = 0; i < lines.length; i += 2) {
          final String en = lines[i];
          final String cn = i + 1 < lines.length ? lines[i + 1] : '';

          // Skip if the line looks like Chinese (first line should be English)
          if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(en) && !RegExp(r'[a-zA-Z]').hasMatch(en)) {
            continue;
          }

          batch.insert('CourseSentence', {
            'SentenceId': const Uuid().v4(),
            'BookId': bookId,
            'SentenceText': en,
            'Translate': cn,
            'Sort': count,
            'UpdateTime': nowMillis,
            'SpellCount': 0,
            'ErrorCount': 0,
            'SentenceStatus': 0,
          });
          count++;
        }
      }

      if (count == 0) {
        return '未找到有效的句子内容';
      }

      if (kDebugMode) {
        debugPrint('Committing $count sentences to database...');
      }
      await batch.commit(noResult: true);
      if (kDebugMode) {
        debugPrint('Successfully imported $count sentences');
      }
      return '成功导入 $count 个句子';
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Import Listening Error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return '导入失败: $e';
    }
  }

  /// Clear all listening materials for a book
  Future<void> clearListeningMaterials(String bookId) async {
    final db = await DatabaseHelper.database;
    await db.delete('CourseSentence', where: 'BookId = ?', whereArgs: [bookId]);
  }
}
