import 'dart:convert';
import 'dart:math';

/// FSRS (Free Spaced Repetition Scheduler) - 完整实现
///
/// 基于 FSRS-4.5 算法，这是目前最先进的间隔重复算法之一。
/// 相比 SM-2，FSRS 能更准确地预测记忆遗忘曲线。
///
/// ## 核心概念
///
/// - **Stability (稳定性)**: 表示记忆的持久程度，单位为天。
///   稳定性越高，遗忘越慢，复习间隔越长。
///
/// - **Difficulty (难度)**: 1-10 的范围，表示单词的固有难度。
///   难度会根据用户的反馈动态调整。
///
/// - **Retrievability (可提取性)**: 0-1 的概率值，表示当前能回忆起的概率。
///   根据 艾宾浩斯遗忘曲线 计算: R = (1 + t/(9*S))^(-1)
///
/// ## 评分系统
///
/// - 1 = Again (忘记): 完全不记得，需要重新学习
/// - 2 = Hard (困难): 记得但很吃力，需要更多练习
/// - 3 = Good (记得): 正常回忆起来
/// - 4 = Easy (简单): 轻松记得，可以延长间隔
///
/// ## 使用示例
///
/// ```dart
/// final fsrs = FsrsService();
/// var state = FsrsState.initial();
///
/// // 用户回答正确
/// final result = fsrs.schedule(state, 3);
/// print('下次复习: ${result.nextReview}');
/// print('间隔: ${result.intervalDays} 天');
///
/// // 保存状态到数据库
/// final json = FsrsService.toLearnParam(result.newState);
/// ```
class FsrsService {
  // FSRS-4.5 default weights (optimized parameters)
  static const List<double> defaultWeights = [
    0.5701, 1.4436, 4.1386, 10.9355,  // w0-w3: initial stability
    5.1443, 1.2006, 0.8627, 0.0362,   // w4-w7: difficulty
    1.629, 0.1342, 1.0166, 2.1174,    // w8-w11: stability modifiers
    0.0839, 0.3204, 1.4676, 0.219, 2.8237  // w12-w16: forgetting
  ];

  final List<double> weights;
  final double requestRetention;
  final int maximumInterval;

  FsrsService({
    List<double>? weights,
    this.requestRetention = 0.9,  // Target 90% recall
    this.maximumInterval = 36500, // Max ~100 years
  }) : weights = weights ?? defaultWeights;

  /// Schedule next review based on user rating
  /// Rating: 1=Again (忘记), 2=Hard (困难), 3=Good (记得), 4=Easy (简单)
  FsrsResult schedule(FsrsState state, int rating) {
    final now = DateTime.now();
    rating = rating.clamp(1, 4);
    
    double stability = state.stability;
    double difficulty = state.difficulty;
    final elapsedDays = state.lastReview != null 
        ? now.difference(state.lastReview!).inMinutes / 1440.0
        : 0.0;

    // Calculate retrievability (memory strength)
    final retrievability = _retrievability(elapsedDays, stability);
    
    // Update difficulty based on rating
    difficulty = _nextDifficulty(difficulty, rating);
    
    // Update stability based on rating and current state
    if (state.reps == 0) {
      // First review - use initial stability
      stability = _initStability(rating);
    } else if (rating == 1) {
      // Forgot - calculate lapse stability
      stability = _nextForgetStability(difficulty, stability, retrievability);
    } else {
      // Recalled - calculate recall stability
      stability = _nextRecallStability(difficulty, stability, retrievability, rating);
    }

    // Calculate next interval
    int intervalMinutes;
    if (rating == 1) {
      intervalMinutes = 10; // 10 minutes for forgotten cards
    } else if (state.reps == 0 && rating < 4) {
      // Learning phase intervals
      intervalMinutes = [1, 10, 1440][rating - 1]; // 1min, 10min, 1day
    } else {
      // Convert stability to interval in days, then to minutes
      final intervalDays = _stabilityToInterval(stability);
      intervalMinutes = (intervalDays * 1440).round();
    }

    // Apply maximum interval cap
    final maxMinutes = maximumInterval * 1440;
    intervalMinutes = intervalMinutes.clamp(1, maxMinutes);

    final nextReview = now.add(Duration(minutes: intervalMinutes));
    final newStatus = _determineStatus(state.reps + 1, rating, stability);

    return FsrsResult(
      interval: intervalMinutes,
      intervalDays: (intervalMinutes / 1440).round(),
      nextReview: nextReview,
      newState: FsrsState(
        stability: stability,
        difficulty: difficulty,
        reps: state.reps + 1,
        lapses: rating == 1 ? state.lapses + 1 : state.lapses,
        lastReview: now,
        status: newStatus,
      ),
    );
  }

  /// Calculate retrievability (probability of recall)
  double _retrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0;
    return pow(1 + elapsedDays / (9 * stability), -1).toDouble();
  }

  /// Initial stability for first review
  double _initStability(int rating) {
    return max(0.1, weights[(rating - 1).clamp(0, 3)]);
  }

  /// Update difficulty based on rating
  double _nextDifficulty(double currentDifficulty, int rating) {
    // D = D + w5 * (rating - 3)
    final newDifficulty = currentDifficulty + weights[5] * (rating - 3);
    // Mean reversion: D = (1-w6) * D + w6 * D_default
    final meanReverted = (1 - weights[6]) * newDifficulty + weights[6] * 5.0;
    return meanReverted.clamp(1.0, 10.0);
  }

  /// Stability after successful recall
  double _nextRecallStability(double d, double s, double r, int rating) {
    final hardPenalty = rating == 2 ? weights[15] : 1.0;
    final easyBonus = rating == 4 ? weights[16] : 1.0;
    
    return (s * (1 + exp(weights[8]).toDouble() *
        (11 - d) *
        pow(s, -weights[9]).toDouble() *
        (exp((1 - r) * weights[10]).toDouble() - 1) *
        hardPenalty *
        easyBonus)).toDouble();
  }

  /// Stability after forgetting (lapse)
  double _nextForgetStability(double d, double s, double r) {
    return (weights[11] *
        pow(d, -weights[12]).toDouble() *
        (pow(s + 1, weights[13]).toDouble() - 1) *
        exp((1 - r) * weights[14]).toDouble()).toDouble();
  }

  /// Convert stability to review interval
  double _stabilityToInterval(double stability) {
    if (stability <= 0) return 1;
    return 9 * stability * (1 / requestRetention - 1);
  }

  /// Determine learning status based on progress
  int _determineStatus(int reps, int rating, double stability) {
    if (reps <= 1 && rating == 1) return 0; // New
    if (stability < 7) return 1; // Learning
    return 2; // Mastered
  }

  /// Get preview of intervals for all ratings
  Map<int, String> previewIntervals(FsrsState state) {
    final previews = <int, String>{};
    for (int rating = 1; rating <= 4; rating++) {
      final result = schedule(state, rating);
      previews[rating] = _formatInterval(result.interval);
    }
    return previews;
  }

  String _formatInterval(int minutes) {
    if (minutes < 60) return '$minutes分钟';
    if (minutes < 1440) return '${(minutes / 60).round()}小时';
    if (minutes < 43200) return '${(minutes / 1440).round()}天';
    if (minutes < 525600) return '${(minutes / 43200).round()}月';
    return '${(minutes / 525600).round()}年';
  }

  /// Parse LearnParam JSON from database
  static FsrsState parseLearnParam(String? learnParam) {
    if (learnParam == null || learnParam.isEmpty) {
      return FsrsState.initial();
    }
    
    try {
      final json = jsonDecode(learnParam);
      return FsrsState(
        stability: (json['stability'] ?? json['ease'] as num?)?.toDouble() ?? 2.5,
        difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
        reps: (json['reps'] ?? json['repetitions'] as num?)?.toInt() ?? 0,
        lapses: (json['lapses'] as num?)?.toInt() ?? 0,
        lastReview: json['lastReview'] != null 
            ? DateTime.fromMillisecondsSinceEpoch((json['lastReview'] as num).toInt())
            : null,
        status: (json['status'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return FsrsState.initial();
    }
  }

  /// Convert state to JSON for database storage
  static String toLearnParam(FsrsState state) {
    return jsonEncode({
      'stability': state.stability,
      'difficulty': state.difficulty,
      'reps': state.reps,
      'lapses': state.lapses,
      'lastReview': state.lastReview?.millisecondsSinceEpoch,
      'status': state.status,
    });
  }
}

/// Memory state for a card
class FsrsState {
  final double stability;   // Memory stability (days)
  final double difficulty;  // Difficulty (1-10)
  final int reps;          // Review count
  final int lapses;        // Forget count
  final DateTime? lastReview;
  final int status;        // 0=new, 1=learning, 2=mastered

  FsrsState({
    required this.stability,
    required this.difficulty,
    required this.reps,
    this.lapses = 0,
    this.lastReview,
    this.status = 0,
  });

  factory FsrsState.initial() => FsrsState(
    stability: 0,
    difficulty: 5.0,
    reps: 0,
    lapses: 0,
    status: 0,
  );

  /// Memory strength as percentage (0-100%)
  double get memoryStrength {
    if (stability <= 0 || lastReview == null) return 0;
    final elapsed = DateTime.now().difference(lastReview!).inMinutes / 1440.0;
    return (pow(1 + elapsed / (9 * stability), -1).toDouble() * 100).clamp(0.0, 100.0);
  }
}

/// Result of scheduling calculation
class FsrsResult {
  final int interval;        // Next interval in minutes
  final int intervalDays;    // Next interval in days
  final DateTime nextReview; // Next review timestamp
  final FsrsState newState;  // Updated state

  FsrsResult({
    required this.interval,
    required this.intervalDays,
    required this.nextReview,
    required this.newState,
  });
}
