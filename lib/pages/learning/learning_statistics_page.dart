import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/learning_statistics_service.dart';

/// 学习统计报告页面
class LearningStatisticsPage extends StatefulWidget {
  const LearningStatisticsPage({super.key});

  @override
  State<LearningStatisticsPage> createState() => _LearningStatisticsPageState();
}

class _LearningStatisticsPageState extends State<LearningStatisticsPage> {
  bool _isLoading = true;
  List<DailyStats> _weeklyStats = [];
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    await LearningStatisticsService.instance.initialize();
    final weekly = await LearningStatisticsService.instance.getWeeklyStats();
    final streak = await LearningStatisticsService.instance.getStreakDays();

    if (mounted) {
      setState(() {
        _weeklyStats = weekly;
        _streakDays = streak;
        _isLoading = false;
      });
    }
  }

  DailyStats get _todayStats => LearningStatisticsService.instance.todayStats;
  TotalStats get _totalStats => LearningStatisticsService.instance.totalStats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习统计',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 连续学习天数卡片
                    _buildStreakCard(),
                    const SizedBox(height: 16),

                    // 今日概览
                    _buildSectionTitle('今日学习'),
                    const SizedBox(height: 12),
                    _buildTodayOverview(),
                    const SizedBox(height: 24),

                    // 本周学习时长图表
                    _buildSectionTitle('本周学习时长'),
                    const SizedBox(height: 12),
                    _buildWeeklyChart(),
                    const SizedBox(height: 24),

                    // 学习能力分析
                    _buildSectionTitle('学习能力'),
                    const SizedBox(height: 12),
                    _buildAbilityAnalysis(),
                    const SizedBox(height: 24),

                    // 累计统计
                    _buildSectionTitle('累计统计'),
                    const SizedBox(height: 12),
                    _buildTotalStats(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStreakCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '连续学习',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_streakDays',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '天',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            _streakDays >= 7 ? Icons.emoji_events : Icons.trending_up,
            color: Colors.white.withValues(alpha: 0.8),
            size: 40,
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOverview() {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard(
          icon: Icons.timer_outlined,
          label: '学习时长',
          value: '${_todayStats.studyMinutes}',
          unit: '分钟',
          color: colorScheme.primary,
        ),
        _buildStatCard(
          icon: Icons.format_list_numbered,
          label: '练习句子',
          value: '${_todayStats.practicedSentences}',
          unit: '句',
          color: Colors.teal,
        ),
        _buildStatCard(
          icon: Icons.replay,
          label: '播放次数',
          value: '${_todayStats.playCount}',
          unit: '次',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.mic,
          label: '跟读评分',
          value: _todayStats.pronunciationCount > 0
              ? _todayStats.averagePronunciationScore.toStringAsFixed(0)
              : '-',
          unit: '分',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(color: colorScheme.outline, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final colorScheme = Theme.of(context).colorScheme;

    // 准备图表数据
    final now = DateTime.now();
    final weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final chartData = <BarChartGroupData>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final stats = _weeklyStats.firstWhere(
        (s) => s.date.year == date.year && s.date.month == date.month && s.date.day == date.day,
        orElse: () => DailyStats.empty(),
      );

      chartData.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: stats.studyMinutes.toDouble(),
              color: date.day == now.day ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.5),
              width: 24,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    // 计算最大值
    double maxY = _weeklyStats.isNotEmpty
        ? _weeklyStats.map((s) => s.studyMinutes.toDouble()).reduce((a, b) => a > b ? a : b)
        : 60;
    maxY = maxY < 10 ? 60 : maxY * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: colorScheme.inverseSurface,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} 分钟',
                  TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  final date = now.subtract(Duration(days: 6 - index));
                  final weekday = date.weekday;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      weekDays[weekday - 1],
                      style: TextStyle(
                        color: date.day == now.day ? colorScheme.primary : colorScheme.outline,
                        fontSize: 11,
                        fontWeight: date.day == now.day ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox();
                  return Text(
                    '${value.toInt()}',
                    style: TextStyle(color: colorScheme.outline, fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: chartData,
        ),
      ),
    );
  }

  Widget _buildAbilityAnalysis() {
    final colorScheme = Theme.of(context).colorScheme;

    // 计算各项能力指标（0-100）
    final listeningScore = _calculateListeningScore();
    final dictationScore = (_todayStats.dictationAccuracy * 100).clamp(0, 100).toInt();
    final pronunciationScore = _todayStats.averagePronunciationScore.clamp(0, 100).toInt();
    final persistenceScore = (_streakDays * 10).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _buildAbilityRow('听力理解', listeningScore, colorScheme.primary),
          const SizedBox(height: 16),
          _buildAbilityRow('听写准确', dictationScore, Colors.teal),
          const SizedBox(height: 16),
          _buildAbilityRow('发音标准', pronunciationScore, Colors.purple),
          const SizedBox(height: 16),
          _buildAbilityRow('学习坚持', persistenceScore, Colors.orange),
        ],
      ),
    );
  }

  int _calculateListeningScore() {
    // 基于今日学习时长和练习句子数计算
    final timeScore = (_todayStats.studyMinutes / 30 * 50).clamp(0, 50);
    final sentenceScore = (_todayStats.practicedSentences / 20 * 50).clamp(0, 50);
    return (timeScore + sentenceScore).toInt();
  }

  Widget _buildAbilityRow(String label, int score, Color color) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            '$score',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalStats() {
    final colorScheme = Theme.of(context).colorScheme;

    // 累计统计 = 历史总计 + 今日数据
    final totalMinutes = _totalStats.totalStudyMinutes + _todayStats.studyMinutes;
    final totalSentences = _totalStats.totalPracticedSentences + _todayStats.practicedSentences;
    final totalPlayCount = _totalStats.totalPlayCount + _todayStats.playCount;
    final totalDays = _totalStats.totalDays + (_todayStats.studyMinutes > 0 ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTotalStatItem(
                  icon: Icons.calendar_today,
                  label: '学习天数',
                  value: '$totalDays',
                  unit: '天',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildTotalStatItem(
                  icon: Icons.timer,
                  label: '累计时长',
                  value: (totalMinutes / 60).toStringAsFixed(1),
                  unit: '小时',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTotalStatItem(
                  icon: Icons.format_list_numbered,
                  label: '练习句子',
                  value: '$totalSentences',
                  unit: '句',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildTotalStatItem(
                  icon: Icons.replay,
                  label: '播放次数',
                  value: '$totalPlayCount',
                  unit: '次',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.outline, size: 20),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: TextStyle(color: colorScheme.outline, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}
