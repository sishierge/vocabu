import 'dart:convert';
import 'fsrs_service.dart';
import 'sm2_service.dart';
import 'leitner_service.dart';
import 'settings_service.dart';

/// 统一的算法调度结果
class ScheduleResult {
  final int newStatus;        // 0=new, 1=learning, 2=mastered
  final String learnParam;    // JSON 格式的学习参数
  final DateTime nextReview;  // 下次复习时间
  final int reps;             // 复习次数

  ScheduleResult({
    required this.newStatus,
    required this.learnParam,
    required this.nextReview,
    required this.reps,
  });
}

/// 统一算法调度服务
/// 根据用户设置自动选择正确的算法
class AlgorithmScheduler {
  static final AlgorithmScheduler instance = AlgorithmScheduler._();
  AlgorithmScheduler._();

  final FsrsService _fsrs = FsrsService();
  final Sm2Service _sm2 = Sm2Service();
  final LeitnerService _leitner = LeitnerService();

  /// 获取当前使用的算法名称
  String get currentAlgorithm => SettingsService.instance.algorithm;

  /// 根据用户设置调度下次复习
  /// rating: 1=忘记, 2=困难, 3=记得, 4=简单
  ScheduleResult schedule(String? learnParam, int rating) {
    final algorithm = currentAlgorithm;

    switch (algorithm) {
      case 'sm2':
        return _scheduleSm2(learnParam, rating);
      case 'leitner':
        return _scheduleLeitner(learnParam, rating);
      case 'fsrs':
      default:
        return _scheduleFsrs(learnParam, rating);
    }
  }

  /// FSRS 算法调度
  ScheduleResult _scheduleFsrs(String? learnParam, int rating) {
    final state = FsrsService.parseLearnParam(learnParam);
    final result = _fsrs.schedule(state, rating);

    return ScheduleResult(
      newStatus: result.newState.status,
      learnParam: FsrsService.toLearnParam(result.newState),
      nextReview: result.nextReview,
      reps: result.newState.reps,
    );
  }

  /// SM-2 算法调度
  ScheduleResult _scheduleSm2(String? learnParam, int rating) {
    final state = Sm2Service.parseLearnParam(learnParam);
    final result = _sm2.schedule(state, rating);

    return ScheduleResult(
      newStatus: result.newState.status,
      learnParam: Sm2Service.toLearnParam(result.newState),
      nextReview: result.nextReview,
      reps: result.newState.reps,
    );
  }

  /// Leitner 盒子算法调度
  ScheduleResult _scheduleLeitner(String? learnParam, int rating) {
    final state = LeitnerService.parseLearnParam(learnParam);
    final result = _leitner.schedule(state, rating);

    return ScheduleResult(
      newStatus: result.newState.status,
      learnParam: LeitnerService.toLearnParam(result.newState),
      nextReview: result.nextReview,
      reps: result.newState.reps,
    );
  }

  /// 预览各评分的间隔（用于按钮显示）
  Map<int, String> previewIntervals(String? learnParam) {
    final algorithm = currentAlgorithm;

    switch (algorithm) {
      case 'sm2':
        final state = Sm2Service.parseLearnParam(learnParam);
        return _sm2.previewIntervals(state);
      case 'leitner':
        final state = LeitnerService.parseLearnParam(learnParam);
        return _leitner.previewIntervals(state);
      case 'fsrs':
      default:
        final state = FsrsService.parseLearnParam(learnParam);
        return _fsrs.previewIntervals(state);
    }
  }

  /// 获取当前算法的显示名称
  String get algorithmDisplayName {
    switch (currentAlgorithm) {
      case 'sm2':
        return 'SM-2';
      case 'leitner':
        return 'Leitner';
      case 'fsrs':
      default:
        return 'FSRS';
    }
  }

  /// 获取复习次数（从 learnParam 解析）
  int getReps(String? learnParam) {
    if (learnParam == null || learnParam.isEmpty) return 0;

    try {
      final json = jsonDecode(learnParam);
      return (json['reps'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
