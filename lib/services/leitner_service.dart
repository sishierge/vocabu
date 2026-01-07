import 'dart:convert';

/// Leitner 盒子系统实现
/// 简单直观的 5 盒子复习系统
/// 
/// 规则：
/// - 盒子 1: 每天复习
/// - 盒子 2: 隔1天复习
/// - 盒子 3: 隔3天复习
/// - 盒子 4: 隔7天复习
/// - 盒子 5: 隔14天复习（已掌握）
/// 
/// 答对：进入下一个盒子
/// 答错：回到盒子 1
class LeitnerService {
  // 各盒子的复习间隔（天）
  static const List<int> boxIntervals = [1, 2, 4, 7, 14];
  
  /// 计算下次复习时间
  LeitnerResult schedule(LeitnerState state, int rating) {
    final now = DateTime.now();
    rating = rating.clamp(1, 4);
    
    int box = state.box;
    int reps = state.reps + 1;
    int lapses = state.lapses;
    
    // 判断对错
    // 1 = 忘记（回到盒子1）, 2-4 = 记得（进入下一个盒子）
    if (rating == 1) {
      // 答错：回到盒子 1
      box = 0;
      lapses++;
    } else {
      // 答对：进入下一个盒子（最多盒子 5）
      box = (box + 1).clamp(0, 4);
    }
    
    // 计算下次复习间隔
    final interval = boxIntervals[box];
    final nextReview = now.add(Duration(days: interval));
    
    // 确定状态
    final status = _determineStatus(box);
    
    return LeitnerResult(
      interval: interval,
      box: box + 1, // 显示为 1-5
      nextReview: nextReview,
      newState: LeitnerState(
        box: box,
        reps: reps,
        lapses: lapses,
        lastReview: now,
        status: status,
      ),
    );
  }
  
  int _determineStatus(int box) {
    if (box == 0) return 0; // New / 重新开始
    if (box < 3) return 1;  // Learning
    return 2; // Mastered (盒子 4-5)
  }
  
  /// 预览各评分的间隔
  Map<int, String> previewIntervals(LeitnerState state) {
    final previews = <int, String>{};
    for (int rating = 1; rating <= 4; rating++) {
      final result = schedule(state, rating);
      previews[rating] = rating == 1 
          ? '回到盒子1 (1天)' 
          : '盒子${result.box} (${result.interval}天)';
    }
    return previews;
  }
  
  /// 解析数据库存储的状态
  static LeitnerState parseLearnParam(String? learnParam) {
    if (learnParam == null || learnParam.isEmpty) {
      return LeitnerState.initial();
    }
    
    try {
      final json = jsonDecode(learnParam);
      return LeitnerState(
        box: (json['box'] as num?)?.toInt() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
        lapses: (json['lapses'] as num?)?.toInt() ?? 0,
        lastReview: json['lastReview'] != null 
            ? DateTime.fromMillisecondsSinceEpoch((json['lastReview'] as num).toInt())
            : null,
        status: (json['status'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return LeitnerState.initial();
    }
  }
  
  /// 转换为 JSON 存储
  static String toLearnParam(LeitnerState state) {
    return jsonEncode({
      'box': state.box,
      'reps': state.reps,
      'lapses': state.lapses,
      'lastReview': state.lastReview?.millisecondsSinceEpoch,
      'status': state.status,
      'algorithm': 'leitner',
    });
  }
  
  /// 获取盒子描述
  static String getBoxDescription(int box) {
    const descriptions = [
      '盒子1: 每天复习 (刚开始学习)',
      '盒子2: 隔1天复习 (初步记忆)',
      '盒子3: 隔3天复习 (短期记忆)',
      '盒子4: 隔7天复习 (中期记忆)',
      '盒子5: 隔14天复习 (长期记忆)',
    ];
    return descriptions[box.clamp(0, 4)];
  }
}

/// Leitner 状态
class LeitnerState {
  final int box;             // 当前盒子 (0-4, 显示为 1-5)
  final int reps;            // 复习次数
  final int lapses;          // 遗忘次数
  final DateTime? lastReview;
  final int status;          // 0=new, 1=learning, 2=mastered

  LeitnerState({
    required this.box,
    required this.reps,
    this.lapses = 0,
    this.lastReview,
    this.status = 0,
  });

  factory LeitnerState.initial() => LeitnerState(
    box: 0,
    reps: 0,
    lapses: 0,
    status: 0,
  );
  
  /// 显示用的盒子编号 (1-5)
  int get displayBox => box + 1;
}

/// Leitner 结果
class LeitnerResult {
  final int interval;        // 下次间隔（天）
  final int box;             // 新盒子编号 (1-5)
  final DateTime nextReview; // 下次复习时间
  final LeitnerState newState;

  LeitnerResult({
    required this.interval,
    required this.box,
    required this.nextReview,
    required this.newState,
  });
}
