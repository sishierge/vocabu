import 'package:flutter_test/flutter_test.dart';
import 'package:vocabu/services/fsrs_service.dart';
import 'package:vocabu/services/sm2_service.dart';
import 'package:vocabu/services/leitner_service.dart';

void main() {
  group('FSRS Algorithm Tests', () {
    late FsrsService fsrs;

    setUp(() {
      fsrs = FsrsService();
    });

    test('Initial state should have correct defaults', () {
      final state = FsrsState.initial();
      expect(state.stability, 0);
      expect(state.difficulty, 5.0);
      expect(state.reps, 0);
      expect(state.lapses, 0);
      expect(state.status, 0);
    });

    test('First review with rating 1 (Again) should set short interval', () {
      final state = FsrsState.initial();
      final result = fsrs.schedule(state, 1);

      expect(result.interval, 10); // 10 minutes
      expect(result.newState.reps, 1);
      expect(result.newState.lapses, 1);
    });

    test('First review with rating 3 (Good) should progress normally', () {
      final state = FsrsState.initial();
      final result = fsrs.schedule(state, 3);

      expect(result.newState.reps, 1);
      expect(result.newState.lapses, 0);
      expect(result.newState.stability, greaterThan(0));
    });

    test('First review with rating 4 (Easy) should have longer interval', () {
      final state = FsrsState.initial();
      final resultGood = fsrs.schedule(state, 3);
      final resultEasy = fsrs.schedule(state, 4);

      expect(resultEasy.interval, greaterThanOrEqualTo(resultGood.interval));
    });

    test('Consecutive successful reviews should increase interval', () {
      var state = FsrsState.initial();

      // First review
      var result = fsrs.schedule(state, 3);
      final firstInterval = result.interval;
      state = result.newState;

      // Second review
      result = fsrs.schedule(state, 3);
      final secondInterval = result.interval;

      expect(secondInterval, greaterThan(firstInterval));
    });

    test('Forgetting should reset progress', () {
      var state = FsrsState.initial();

      // Build up some progress
      for (int i = 0; i < 3; i++) {
        final result = fsrs.schedule(state, 3);
        state = result.newState;
      }

      final stableState = state;

      // Forget
      final result = fsrs.schedule(stableState, 1);

      expect(result.interval, 10); // Back to 10 minutes
      expect(result.newState.lapses, stableState.lapses + 1);
    });

    test('Difficulty should increase with Hard rating', () {
      var state = FsrsState.initial();

      // First review to establish baseline
      var result = fsrs.schedule(state, 3);
      state = result.newState;
      final baseDifficulty = state.difficulty;

      // Hard rating
      result = fsrs.schedule(state, 2);

      expect(result.newState.difficulty, lessThan(baseDifficulty));
    });

    test('Preview intervals should return all 4 ratings', () {
      final state = FsrsState.initial();
      final previews = fsrs.previewIntervals(state);

      expect(previews.length, 4);
      expect(previews.containsKey(1), true);
      expect(previews.containsKey(2), true);
      expect(previews.containsKey(3), true);
      expect(previews.containsKey(4), true);
    });

    test('State serialization should be reversible', () {
      final state = FsrsState(
        stability: 5.5,
        difficulty: 4.2,
        reps: 10,
        lapses: 2,
        lastReview: DateTime.now(),
        status: 2,
      );

      final json = FsrsService.toLearnParam(state);
      final restored = FsrsService.parseLearnParam(json);

      expect(restored.stability, state.stability);
      expect(restored.difficulty, state.difficulty);
      expect(restored.reps, state.reps);
      expect(restored.lapses, state.lapses);
      expect(restored.status, state.status);
    });
  });

  group('SM-2 Algorithm Tests', () {
    late Sm2Service sm2;

    setUp(() {
      sm2 = Sm2Service();
    });

    test('Initial state should have correct defaults', () {
      final state = Sm2State.initial();
      expect(state.easeFactor, 2.5);
      expect(state.interval, 0);
      expect(state.reps, 0);
      expect(state.lapses, 0);
    });

    test('First successful review should set interval to 1 day', () {
      final state = Sm2State.initial();
      final result = sm2.schedule(state, 3);

      expect(result.interval, 1);
      expect(result.newState.reps, 1);
    });

    test('Second successful review should set interval to 6 days', () {
      var state = Sm2State.initial();

      // First review
      var result = sm2.schedule(state, 3);
      state = result.newState;

      // Second review
      result = sm2.schedule(state, 3);

      expect(result.interval, 6);
      expect(result.newState.reps, 2);
    });

    test('Failed review should reset reps to 0', () {
      var state = Sm2State.initial();

      // Build up some reps
      for (int i = 0; i < 3; i++) {
        final result = sm2.schedule(state, 3);
        state = result.newState;
      }

      expect(state.reps, 3);

      // Fail
      final result = sm2.schedule(state, 1);

      expect(result.newState.reps, 0);
      expect(result.interval, 1);
      expect(result.newState.lapses, state.lapses + 1);
    });

    test('Easy rating should increase ease factor', () {
      var state = Sm2State.initial();

      // First review with Easy
      final result = sm2.schedule(state, 4);

      expect(result.newState.easeFactor, greaterThan(state.easeFactor));
    });

    test('Ease factor should not go below 1.3', () {
      var state = Sm2State(
        easeFactor: 1.5,
        interval: 6,
        reps: 2,
      );

      // Multiple Hard ratings
      for (int i = 0; i < 10; i++) {
        final result = sm2.schedule(state, 2);
        state = result.newState;
      }

      expect(state.easeFactor, greaterThanOrEqualTo(1.3));
    });

    test('Interval should be capped at 365 days', () {
      var state = Sm2State(
        easeFactor: 3.0,
        interval: 300,
        reps: 10,
      );

      final result = sm2.schedule(state, 4);

      expect(result.interval, lessThanOrEqualTo(365));
    });

    test('State serialization should be reversible', () {
      final state = Sm2State(
        easeFactor: 2.8,
        interval: 14,
        reps: 5,
        lapses: 1,
        lastReview: DateTime.now(),
        status: 2,
      );

      final json = Sm2Service.toLearnParam(state);
      final restored = Sm2Service.parseLearnParam(json);

      expect(restored.easeFactor, state.easeFactor);
      expect(restored.interval, state.interval);
      expect(restored.reps, state.reps);
      expect(restored.lapses, state.lapses);
    });
  });

  group('Leitner Box System Tests', () {
    late LeitnerService leitner;

    setUp(() {
      leitner = LeitnerService();
    });

    test('Initial state should be in box 0', () {
      final state = LeitnerState.initial();
      expect(state.box, 0);
      expect(state.displayBox, 1);
      expect(state.reps, 0);
    });

    test('Correct answer should advance to next box', () {
      final state = LeitnerState.initial();
      final result = leitner.schedule(state, 3);

      expect(result.newState.box, 1);
      expect(result.box, 2); // Display box
      expect(result.newState.reps, 1);
    });

    test('Wrong answer should return to box 1', () {
      var state = LeitnerState(box: 3, reps: 5);

      final result = leitner.schedule(state, 1);

      expect(result.newState.box, 0);
      expect(result.box, 1); // Display box
      expect(result.newState.lapses, 1);
    });

    test('Box should not exceed 4 (display: 5)', () {
      var state = LeitnerState(box: 4, reps: 10);

      final result = leitner.schedule(state, 4);

      expect(result.newState.box, 4);
      expect(result.box, 5);
    });

    test('Interval should match box level', () {
      // Box 0 -> 1 day
      var result = leitner.schedule(LeitnerState(box: 0, reps: 0), 3);
      expect(result.interval, 2); // Box 1 interval

      // Box 2 -> 4 days
      result = leitner.schedule(LeitnerState(box: 2, reps: 3), 3);
      expect(result.interval, 7); // Box 3 interval

      // Box 4 -> 14 days
      result = leitner.schedule(LeitnerState(box: 4, reps: 10), 3);
      expect(result.interval, 14); // Box 4 (max) interval
    });

    test('Preview intervals should show box transitions', () {
      final state = LeitnerState(box: 2, reps: 5);
      final previews = leitner.previewIntervals(state);

      expect(previews.length, 4);
      expect(previews[1], contains('盒子1'));
      expect(previews[3], contains('盒子4'));
    });

    test('Box descriptions should be correct', () {
      expect(LeitnerService.getBoxDescription(0), contains('盒子1'));
      expect(LeitnerService.getBoxDescription(4), contains('盒子5'));
      expect(LeitnerService.getBoxDescription(4), contains('长期记忆'));
    });

    test('Status should reflect progress', () {
      // Box 0 -> status 0 (new)
      var result = leitner.schedule(LeitnerState.initial(), 1);
      expect(result.newState.status, 0);

      // Box 1-2 -> status 1 (learning)
      result = leitner.schedule(LeitnerState(box: 0, reps: 0), 3);
      expect(result.newState.status, 1);

      // Box 3-4 -> status 2 (mastered)
      result = leitner.schedule(LeitnerState(box: 2, reps: 5), 3);
      expect(result.newState.status, 2);
    });

    test('State serialization should be reversible', () {
      final state = LeitnerState(
        box: 3,
        reps: 8,
        lapses: 2,
        lastReview: DateTime.now(),
        status: 2,
      );

      final json = LeitnerService.toLearnParam(state);
      final restored = LeitnerService.parseLearnParam(json);

      expect(restored.box, state.box);
      expect(restored.reps, state.reps);
      expect(restored.lapses, state.lapses);
      expect(restored.status, state.status);
    });
  });

  group('Algorithm Comparison Tests', () {
    test('All algorithms should handle edge cases gracefully', () {
      final fsrs = FsrsService();
      final sm2 = Sm2Service();
      final leitner = LeitnerService();

      // Invalid ratings should be clamped
      final fsrsResult = fsrs.schedule(FsrsState.initial(), 10);
      expect(fsrsResult.newState.reps, 1);

      final sm2Result = sm2.schedule(Sm2State.initial(), -5);
      expect(sm2Result.newState.reps, 0); // Should fail

      final leitnerResult = leitner.schedule(LeitnerState.initial(), 0);
      expect(leitnerResult.newState.box, 0); // Should fail
    });

    test('Parse empty/null learn param should return initial state', () {
      expect(FsrsService.parseLearnParam(null).reps, 0);
      expect(FsrsService.parseLearnParam('').reps, 0);

      expect(Sm2Service.parseLearnParam(null).reps, 0);
      expect(Sm2Service.parseLearnParam('').reps, 0);

      expect(LeitnerService.parseLearnParam(null).reps, 0);
      expect(LeitnerService.parseLearnParam('').reps, 0);
    });

    test('Parse invalid JSON should return initial state', () {
      expect(FsrsService.parseLearnParam('invalid').reps, 0);
      expect(Sm2Service.parseLearnParam('not json').reps, 0);
      expect(LeitnerService.parseLearnParam('{broken').reps, 0);
    });
  });
}
