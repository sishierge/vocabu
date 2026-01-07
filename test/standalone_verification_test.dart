import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

void main() {
  late Database db;
  final dbFileName = 'test_vocabu_${DateTime.now().millisecondsSinceEpoch}.db';

  setUpAll(() async {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Cleanup old test DB files
    final dir = Directory('.');
    await for (final file in dir.list()) {
      if (file.path.contains('test_vocabu_') && file.path.endsWith('.db')) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  });

  tearDownAll(() async {
    // Cleanup test DB
    try {
      await db.close();
    } catch (_) {}
    final dbFile = File(dbFileName);
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  });

  test('Database schema creation works correctly', () async {
    debugPrint('--- Step 1: Create Database ---');
    db = await openDatabase(dbFileName, version: 1);
    expect(db.isOpen, true);
    debugPrint('Database opened: ${db.isOpen}');

    debugPrint('--- Step 2: Create Tables ---');
    // Create WordBook table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS WordBook (
        BookId TEXT PRIMARY KEY,
        BookName TEXT,
        Description TEXT,
        WordCount INTEGER DEFAULT 0,
        LearnedCount INTEGER DEFAULT 0,
        MasteredCount INTEGER DEFAULT 0,
        CreateTime TEXT,
        UpdateTime INTEGER
      )
    ''');

    // Create WordItem table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS WordItem (
        WordId TEXT PRIMARY KEY,
        BookId TEXT,
        Word TEXT,
        Translate TEXT,
        Symbol TEXT,
        Example TEXT,
        LearnStatus INTEGER DEFAULT 0,
        MasterTime TEXT,
        Collected INTEGER DEFAULT 0,
        ErrorCount INTEGER DEFAULT 0,
        Sort INTEGER DEFAULT 0
      )
    ''');

    // Verify tables exist
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    final tableNames = tables.map((t) => t['name']).toList();
    debugPrint('Tables created: $tableNames');

    expect(tableNames.contains('WordBook'), true);
    expect(tableNames.contains('WordItem'), true);
  });

  test('Word book CRUD operations work correctly', () async {
    debugPrint('--- Step 3: Insert Word Book ---');
    await db.insert('WordBook', {
      'BookId': 'test-book-001',
      'BookName': 'Test Vocabulary',
      'Description': 'A test word book',
      'WordCount': 0,
      'CreateTime': DateTime.now().toIso8601String(),
    });

    final books = await db.query('WordBook');
    expect(books.length, 1);
    expect(books.first['BookName'], 'Test Vocabulary');
    debugPrint('Book inserted: ${books.first['BookName']}');

    debugPrint('--- Step 4: Insert Words ---');
    final testWords = [
      {'WordId': 'w1', 'BookId': 'test-book-001', 'Word': 'apple', 'Translate': '苹果'},
      {'WordId': 'w2', 'BookId': 'test-book-001', 'Word': 'banana', 'Translate': '香蕉'},
      {'WordId': 'w3', 'BookId': 'test-book-001', 'Word': 'cherry', 'Translate': '樱桃'},
    ];

    for (final word in testWords) {
      await db.insert('WordItem', word);
    }

    final words = await db.query('WordItem', where: 'BookId = ?', whereArgs: ['test-book-001']);
    expect(words.length, 3);
    debugPrint('Words inserted: ${words.length}');

    // Update word count
    await db.update(
      'WordBook',
      {'WordCount': words.length},
      where: 'BookId = ?',
      whereArgs: ['test-book-001'],
    );

    final updatedBook = await db.query('WordBook', where: 'BookId = ?', whereArgs: ['test-book-001']);
    expect(updatedBook.first['WordCount'], 3);
    debugPrint('Word count updated: ${updatedBook.first['WordCount']}');
  });

  test('Word mastery marking works correctly', () async {
    debugPrint('--- Step 5: Mark Word as Mastered ---');

    // Mark first word as mastered (LearnStatus = 2)
    await db.update(
      'WordItem',
      {
        'LearnStatus': 2,
        'MasterTime': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      where: 'WordId = ?',
      whereArgs: ['w1'],
    );

    final masteredWords = await db.query(
      'WordItem',
      where: 'LearnStatus = ?',
      whereArgs: [2],
    );
    expect(masteredWords.length, 1);
    expect(masteredWords.first['Word'], 'apple');
    debugPrint('Mastered word: ${masteredWords.first['Word']}');
  });

  test('Word search works correctly', () async {
    debugPrint('--- Step 6: Search Words ---');

    final searchResults = await db.query(
      'WordItem',
      where: 'Word LIKE ? OR Translate LIKE ?',
      whereArgs: ['%an%', '%an%'],
    );

    expect(searchResults.length, 1);
    expect(searchResults.first['Word'], 'banana');
    debugPrint('Search found: ${searchResults.first['Word']}');
  });

  test('Word collection toggle works correctly', () async {
    debugPrint('--- Step 7: Toggle Word Collection ---');

    await db.update(
      'WordItem',
      {'Collected': 1},
      where: 'WordId = ?',
      whereArgs: ['w2'],
    );

    final collectedWords = await db.query(
      'WordItem',
      where: 'Collected = ?',
      whereArgs: [1],
    );
    expect(collectedWords.length, 1);
    expect(collectedWords.first['Word'], 'banana');
    debugPrint('Collected word: ${collectedWords.first['Word']}');
  });

  test('Error count increment works correctly', () async {
    debugPrint('--- Step 8: Increment Error Count ---');

    await db.rawUpdate(
      'UPDATE WordItem SET ErrorCount = ErrorCount + 1 WHERE WordId = ?',
      ['w3'],
    );
    await db.rawUpdate(
      'UPDATE WordItem SET ErrorCount = ErrorCount + 1 WHERE WordId = ?',
      ['w3'],
    );

    final errorWord = await db.query(
      'WordItem',
      where: 'WordId = ?',
      whereArgs: ['w3'],
    );
    expect(errorWord.first['ErrorCount'], 2);
    debugPrint('Error count: ${errorWord.first['ErrorCount']}');

    debugPrint('--- All Database Tests Passed! ---');
    await db.close();
  });
}
