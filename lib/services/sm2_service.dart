import 'dart:convert';
import 'dart:math';

/// SM-2 算法实现 (SuperMemo 2)
/// 经典的间隔重复算法，被 Anki 采用
class Sm2Service {
  /// SM-2 算法核心
  /// Rating: 0-2 = 失败, 3-5 = 成功 (我们映射为 1-4)
  /// 
  /// 公式:
  /// EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
  /// I(1) = 1, I(2) = 6, I(n) = I(n-1) * EF
  
  Sm2Result schedule(Sm2State state, int rating) {
    final now = DateTime.now();
    rating = rating.clamp(1, 4);
    
    // 将 1-4 映射到 SM-2 的 0-5 评分
    // 1 (忘记) -> 0, 2 (困难) -> 3, 3 (记得) -> 4, 4 (简单) -> 5
    final q = [0, 3, 4, 5][rating - 1];
    
    double ef = state.easeFactor;
    int reps = state.reps;
    int interval;
    
    if (q < 3) {
      // 失败：重置复习次数
      reps = 0;
      interval = 1; // 明天再复习
    } else {
      // 成功：更新 EF 并计算新间隔
      // EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
      ef = ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
      ef = max(1.3, ef); // EF 最小为 1.3
      
      reps++;
      if (reps == 1) {
        interval = 1;
      } else if (reps == 2) {
        interval = 6;
      } else {
        interval = (state.interval * ef).round();
      }
    }
    
    // 限制最大间隔为 365 天
    interval = interval.clamp(1, 365);
    
    final nextReview = now.add(Duration(days: interval));
    final newStatus = _determineStatus(reps, rating);
    
    return Sm2Result(
      interval: interval,
      nextReview: nextReview,
      newState: Sm2State(
        easeFactor: ef,
        interval: interval,
        reps: reps,
        lapses: rating == 1 ? state.lapses + 1 : state.lapses,
        lastReview: now,
        status: newStatus,
      ),
    );
  }
  
  int _determineStatus(int reps, int rating) {
    if (reps == 0) return 0; // New
    if (reps < 3) return 1; // Learning
    return 2; // Mastered
  }
  
  /// 预览各评分的间隔
  Map<int, String> previewIntervals(Sm2State state) {
    final previews = <int, String>{};
    for (int rating = 1; rating <= 4; rating++) {
      final result = schedule(state, rating);
      previews[rating] = '${result.interval}天';
    }
    return previews;
  }
  
  /// 解析数据库存储的状态
  static Sm2State parseLearnParam(String? learnParam) {
    if (learnParam == null || learnParam.isEmpty) {
      return Sm2State.initial();
    }
    
    try {
      final json = jsonDecode(learnParam);
      return Sm2State(
        easeFactor: (json['easeFactor'] ?? json['ease'] as num?)?.toDouble() ?? 2.5,
        interval: (json['interval'] as num?)?.toInt() ?? 0,
        reps: (json['reps'] ?? json['repetitions'] as num?)?.toInt() ?? 0,
        lapses: (json['lapses'] as num?)?.toInt() ?? 0,
        lastReview: json['lastReview'] != null 
            ? DateTime.fromMillisecondsSinceEpoch((json['lastReview'] as num).toInt())
            : null,
        status: (json['status'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return Sm2State.initial();
    }
  }
  
  /// 转换为 JSON 存储
  static String toLearnParam(Sm2State state) {
    return jsonEncode({
      'easeFactor': state.easeFactor,
      'interval': state.interval,
      'reps': state.reps,
      'lapses': state.lapses,
      'lastReview': state.lastReview?.millisecondsSinceEpoch,
      'status': state.status,
      'algorithm': 'sm2',
    });
  }
}

/// SM-2 状态
class Sm2State {
  final double easeFactor;  // 难度因子 (EF), 默认 2.5
  final int interval;       // 当前间隔（天）
  final int reps;          // 连续正确次数
  final int lapses;        // 遗忘次数
  final DateTime? lastReview;
  final int status;        // 0=new, 1=learning, 2=mastered

  Sm2State({
    required this.easeFactor,
    required this.interval,
    required this.reps,
    this.lapses = 0,
    this.lastReview,
    this.status = 0,
  });

  factory Sm2State.initial() => Sm2State(
    easeFactor: 2.5,
    interval: 0,
    reps: 0,
    lapses: 0,
    status: 0,
  );
}

/// SM-2 结果
class Sm2Result {
  final int interval;        // 下次间隔（天）
  final DateTime nextReview; // 下次复习时间
  final Sm2State newState;   // 新状态

  Sm2Result({
    required this.interval,
    required this.nextReview,
    required this.newState,
  });
}
