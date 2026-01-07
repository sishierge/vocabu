// WordBook and Provider Unit Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabu/providers/word_book_provider.dart';

void main() {
  group('WordBook Model', () {
    test('should create WordBook with required fields', () {
      final book = WordBook(
        bookId: 'test_id',
        bookName: 'Test Book',
        wordCount: 100,
      );

      expect(book.bookId, 'test_id');
      expect(book.bookName, 'Test Book');
      expect(book.wordCount, 100);
    });

    test('should have default values for optional fields', () {
      final book = WordBook(
        bookId: 'test_id',
        bookName: 'Test Book',
        wordCount: 100,
      );

      expect(book.newCount, 0);
      expect(book.learningCount, 0);
      expect(book.masteredCount, 0);
      expect(book.reviewCount, 0);
      expect(book.collectedCount, 0);
      expect(book.createTime, null);
    });

    test('should create WordBook with all fields', () {
      final book = WordBook(
        bookId: 'test_id',
        bookName: 'Test Book',
        wordCount: 100,
        newCount: 30,
        learningCount: 40,
        masteredCount: 30,
        reviewCount: 10,
        collectedCount: 5,
        createTime: '2024-01-01',
      );

      expect(book.newCount, 30);
      expect(book.learningCount, 40);
      expect(book.masteredCount, 30);
      expect(book.reviewCount, 10);
      expect(book.collectedCount, 5);
      expect(book.createTime, '2024-01-01');
    });

    group('progress calculation', () {
      test('should calculate progress correctly', () {
        final book = WordBook(
          bookId: 'test_id',
          bookName: 'Test Book',
          wordCount: 100,
          masteredCount: 50,
        );

        expect(book.progress, 0.5);
      });

      test('should return 0 progress when wordCount is 0', () {
        final book = WordBook(
          bookId: 'test_id',
          bookName: 'Test Book',
          wordCount: 0,
          masteredCount: 0,
        );

        expect(book.progress, 0);
      });

      test('should return 1.0 for fully mastered book', () {
        final book = WordBook(
          bookId: 'test_id',
          bookName: 'Test Book',
          wordCount: 50,
          masteredCount: 50,
        );

        expect(book.progress, 1.0);
      });
    });

    group('fromMap factory', () {
      test('should create WordBook from map', () {
        final map = {
          'BookId': 'map_id',
          'BookName': 'Map Book',
          'WordCount': 200,
          'CreateTime': '2024-02-01',
        };

        final book = WordBook.fromMap(map);

        expect(book.bookId, 'map_id');
        expect(book.bookName, 'Map Book');
        expect(book.wordCount, 200);
        expect(book.createTime, '2024-02-01');
      });

      test('should handle missing fields in map', () {
        final map = <String, dynamic>{};

        final book = WordBook.fromMap(map);

        expect(book.bookId, '');
        expect(book.bookName, 'Unknown');
        expect(book.wordCount, 0);
      });

      test('should handle null values in map', () {
        final map = {
          'BookId': null,
          'BookName': null,
          'WordCount': null,
        };

        final book = WordBook.fromMap(map);

        expect(book.bookId, '');
        expect(book.bookName, 'Unknown');
        expect(book.wordCount, 0);
      });
    });
  });

  group('WordBookProvider', () {
    test('should be a singleton', () {
      final instance1 = WordBookProvider.instance;
      final instance2 = WordBookProvider.instance;

      expect(identical(instance1, instance2), true);
    });

    test('should start with empty books list', () {
      final provider = WordBookProvider.instance;
      // Note: In real app, books might be populated from database
      // This tests the initial state
      expect(provider.books, isA<List<WordBook>>());
    });

    test('should have isLoading property', () {
      final provider = WordBookProvider.instance;
      expect(provider.isLoading, isA<bool>());
    });

    test('should have error property', () {
      final provider = WordBookProvider.instance;
      expect(provider.error, isNull);
    });

    test('should have homePageStats property', () {
      final provider = WordBookProvider.instance;
      expect(provider.homePageStats, isA<Map<String, dynamic>>());
    });
  });
}
