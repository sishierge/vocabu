// GrammarService Unit Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabu/services/grammar_service.dart';

void main() {
  group('GrammarService', () {
    group('Static Data', () {
      test('should have grammar questions available', () {
        expect(GrammarService.allQuestions.isNotEmpty, true);
        expect(GrammarService.allQuestions.length, greaterThan(20));
      });

      test('should have sentence corrections available', () {
        expect(GrammarService.allCorrections.isNotEmpty, true);
        expect(GrammarService.allCorrections.length, greaterThan(10));
      });

      test('should have categories defined', () {
        expect(GrammarService.categories.isNotEmpty, true);
        expect(GrammarService.categories, contains('时态'));
        expect(GrammarService.categories, contains('冠词'));
        expect(GrammarService.categories, contains('介词'));
      });

      test('all questions should have valid structure', () {
        for (final q in GrammarService.allQuestions) {
          expect(q.question.isNotEmpty, true, reason: 'Question should not be empty');
          expect(q.options.length, 4, reason: 'Should have 4 options');
          expect(q.correctIndex, inInclusiveRange(0, 3), reason: 'Correct index should be 0-3');
          expect(q.explanation.isNotEmpty, true, reason: 'Explanation should not be empty');
          expect(q.category.isNotEmpty, true, reason: 'Category should not be empty');
        }
      });

      test('all corrections should have valid structure', () {
        for (final c in GrammarService.allCorrections) {
          expect(c.wrongSentence.isNotEmpty, true, reason: 'Wrong sentence should not be empty');
          expect(c.correctSentence.isNotEmpty, true, reason: 'Correct sentence should not be empty');
          expect(c.wrongSentence != c.correctSentence, true, reason: 'Wrong and correct should differ');
          expect(c.explanation.isNotEmpty, true, reason: 'Explanation should not be empty');
          expect(c.category.isNotEmpty, true, reason: 'Category should not be empty');
        }
      });
    });

    group('getRandomQuestions', () {
      late GrammarService service;

      setUp(() async {
        service = GrammarService.instance;
        // Note: In real tests, we'd need to mock SharedPreferences
        // For now, we test the static data methods
      });

      test('should return requested number of questions', () {
        final questions = service.getRandomQuestions(count: 5);
        expect(questions.length, 5);
      });

      test('should return fewer questions if pool is smaller', () {
        // Get a category with few questions
        final tenseQuestions = GrammarService.allQuestions
            .where((q) => q.category == '虚拟语气')
            .toList();

        final questions = service.getRandomQuestions(
          count: 100,
          category: '虚拟语气',
        );

        expect(questions.length, lessThanOrEqualTo(tenseQuestions.length));
      });

      test('should filter by category when specified', () {
        final questions = service.getRandomQuestions(count: 5, category: '时态');

        for (final q in questions) {
          expect(q.category, '时态');
        }
      });

      test('should return questions from all categories when no filter', () {
        final questions = service.getRandomQuestions(count: 20);
        final categories = questions.map((q) => q.category).toSet();

        // Should have multiple categories represented
        expect(categories.length, greaterThan(1));
      });
    });

    group('getRandomCorrections', () {
      late GrammarService service;

      setUp(() {
        service = GrammarService.instance;
      });

      test('should return requested number of corrections', () {
        final corrections = service.getRandomCorrections(count: 5);
        expect(corrections.length, 5);
      });

      test('should return all corrections if count exceeds pool', () {
        final corrections = service.getRandomCorrections(count: 100);
        expect(corrections.length, GrammarService.allCorrections.length);
      });
    });
  });

  group('GrammarQuestion', () {
    test('should create question with all fields', () {
      final question = GrammarQuestion(
        question: 'Test question',
        options: ['A', 'B', 'C', 'D'],
        correctIndex: 1,
        explanation: 'Test explanation',
        category: 'Test category',
      );

      expect(question.question, 'Test question');
      expect(question.options.length, 4);
      expect(question.correctIndex, 1);
      expect(question.explanation, 'Test explanation');
      expect(question.category, 'Test category');
    });
  });

  group('SentenceCorrectionQuestion', () {
    test('should create correction with all fields', () {
      final correction = SentenceCorrectionQuestion(
        wrongSentence: 'He go to school.',
        correctSentence: 'He goes to school.',
        explanation: 'Third person singular needs -s',
        category: '主谓一致',
      );

      expect(correction.wrongSentence, 'He go to school.');
      expect(correction.correctSentence, 'He goes to school.');
      expect(correction.explanation, 'Third person singular needs -s');
      expect(correction.category, '主谓一致');
    });
  });

  group('GrammarRecord', () {
    test('should serialize to JSON correctly', () {
      final record = GrammarRecord(
        question: 'Test question',
        isCorrect: true,
        category: 'Test category',
        practiceTime: DateTime(2024, 1, 15, 10, 30),
      );

      final json = record.toJson();

      expect(json['question'], 'Test question');
      expect(json['isCorrect'], true);
      expect(json['category'], 'Test category');
      expect(json['practiceTime'], '2024-01-15T10:30:00.000');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'question': 'Test question',
        'isCorrect': false,
        'category': 'Test category',
        'practiceTime': '2024-01-15T10:30:00.000',
      };

      final record = GrammarRecord.fromJson(json);

      expect(record.question, 'Test question');
      expect(record.isCorrect, false);
      expect(record.category, 'Test category');
      expect(record.practiceTime.year, 2024);
      expect(record.practiceTime.month, 1);
      expect(record.practiceTime.day, 15);
    });

    test('should handle missing fields in JSON', () {
      final json = <String, dynamic>{};

      final record = GrammarRecord.fromJson(json);

      expect(record.question, '');
      expect(record.isCorrect, false);
      expect(record.category, '');
      // practiceTime should default to now
      expect(record.practiceTime.year, DateTime.now().year);
    });
  });
}
