// SpeakingPracticeService Unit Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabu/services/speaking_practice_service.dart';

void main() {
  group('SpeakingPracticeService', () {
    group('Static Data', () {
      test('should have built-in sentences available', () {
        final sentences = SpeakingPracticeService.builtInSentences;
        expect(sentences.isNotEmpty, true);
        expect(sentences.length, greaterThan(40));
      });

      test('all sentences should have English and Chinese', () {
        for (final sentence in SpeakingPracticeService.builtInSentences) {
          expect(sentence.containsKey('en'), true,
              reason: 'Should have English key');
          expect(sentence.containsKey('cn'), true,
              reason: 'Should have Chinese key');
          expect(sentence['en']!.isNotEmpty, true,
              reason: 'English should not be empty');
          expect(sentence['cn']!.isNotEmpty, true,
              reason: 'Chinese should not be empty');
        }
      });

      test('sentences should cover various scenarios', () {
        final sentences = SpeakingPracticeService.builtInSentences;
        final englishTexts = sentences.map((s) => s['en']!.toLowerCase()).toList();

        // Check for greetings
        expect(
          englishTexts.any((s) => s.contains('morning') || s.contains('hello')),
          true,
          reason: 'Should have greeting sentences',
        );

        // Check for questions
        expect(
          englishTexts.any((s) => s.contains('?')),
          true,
          reason: 'Should have question sentences',
        );

        // Check for shopping
        expect(
          englishTexts.any((s) => s.contains('cost') || s.contains('buy')),
          true,
          reason: 'Should have shopping sentences',
        );

        // Check for directions
        expect(
          englishTexts.any((s) => s.contains('station') || s.contains('airport')),
          true,
          reason: 'Should have direction sentences',
        );
      });
    });
  });

  group('PracticeRecord', () {
    test('should serialize to JSON correctly', () {
      final record = PracticeRecord(
        sentence: 'Hello, how are you?',
        score: 85.5,
        practiceTime: DateTime(2024, 1, 15, 10, 30),
      );

      final json = record.toJson();

      expect(json['sentence'], 'Hello, how are you?');
      expect(json['score'], 85.5);
      expect(json['practiceTime'], '2024-01-15T10:30:00.000');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'sentence': 'Good morning!',
        'score': 92.0,
        'practiceTime': '2024-01-15T10:30:00.000',
      };

      final record = PracticeRecord.fromJson(json);

      expect(record.sentence, 'Good morning!');
      expect(record.score, 92.0);
      expect(record.practiceTime.year, 2024);
      expect(record.practiceTime.month, 1);
      expect(record.practiceTime.day, 15);
    });

    test('should handle missing fields in JSON', () {
      final json = <String, dynamic>{};

      final record = PracticeRecord.fromJson(json);

      expect(record.sentence, '');
      expect(record.score, 0.0);
      expect(record.practiceTime.year, DateTime.now().year);
    });

    test('should handle null score', () {
      final json = {
        'sentence': 'Test sentence',
        'score': null,
        'practiceTime': '2024-01-15T10:30:00.000',
      };

      final record = PracticeRecord.fromJson(json);

      expect(record.score, 0.0);
    });
  });
}
