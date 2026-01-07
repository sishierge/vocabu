import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 口语练习服务
class SpeakingPracticeService {
  static final SpeakingPracticeService instance = SpeakingPracticeService._();
  SpeakingPracticeService._();

  static const String _keyPracticeRecords = 'speaking_practice_records';
  static const String _keyPracticeStats = 'speaking_practice_stats';
  static const String _keyOnlineDialogues = 'online_dialogues_cache';

  List<PracticeRecord> _records = [];
  int _totalPracticed = 0;
  double _averageScore = 0;
  bool _initialized = false;

  // 在线对话缓存
  List<Map<String, String>> _onlineDialogues = [];

  List<PracticeRecord> get records => _records;
  int get totalPracticed => _totalPracticed;
  double get averageScore => _averageScore;
  int get onlineDialogueCount => _onlineDialogues.length;
  int get totalSentenceCount => builtInSentences.length + _onlineDialogues.length;

  /// 内置口语练习句子
  static final List<Map<String, String>> builtInSentences = [
    // 日常问候
    {'en': 'Good morning! How are you today?', 'cn': '早上好！你今天怎么样？'},
    {'en': 'Nice to meet you. My name is Michael.', 'cn': '很高兴认识你。我叫迈克尔。'},
    {'en': 'How was your weekend?', 'cn': '你周末过得怎么样？'},
    {'en': 'I hope you have a wonderful day!', 'cn': '祝你有美好的一天！'},
    {'en': 'See you later! Take care.', 'cn': '回头见！保重。'},

    // 购物场景
    {'en': 'How much does this cost?', 'cn': '这个多少钱？'},
    {'en': 'Do you have this in a different color?', 'cn': '这个有其他颜色吗？'},
    {'en': 'Can I try this on?', 'cn': '我可以试穿吗？'},
    {'en': 'I would like to return this item.', 'cn': '我想退这件商品。'},
    {'en': 'Do you accept credit cards?', 'cn': '你们收信用卡吗？'},

    // 餐厅点餐
    {'en': 'Could I see the menu, please?', 'cn': '请给我看一下菜单好吗？'},
    {'en': 'I would like to order the grilled salmon.', 'cn': '我想点烤三文鱼。'},
    {'en': 'Could we have the bill, please?', 'cn': '请给我们结账好吗？'},
    {'en': 'This dish is absolutely delicious!', 'cn': '这道菜非常美味！'},
    {'en': 'Do you have any vegetarian options?', 'cn': '你们有素食选项吗？'},

    // 问路
    {'en': 'Excuse me, how do I get to the train station?', 'cn': '打扰一下，怎么去火车站？'},
    {'en': 'Is there a pharmacy nearby?', 'cn': '附近有药店吗？'},
    {'en': 'How far is the airport from here?', 'cn': '机场离这里有多远？'},
    {'en': 'Could you show me on the map?', 'cn': '你能在地图上给我指一下吗？'},
    {'en': 'Turn left at the next intersection.', 'cn': '在下一个路口左转。'},

    // 工作场景
    {'en': 'I have a meeting at three o\'clock.', 'cn': '我三点有个会议。'},
    {'en': 'Could you send me the report by email?', 'cn': '你能把报告通过邮件发给我吗？'},
    {'en': 'Let me check my schedule.', 'cn': '让我查一下我的日程。'},
    {'en': 'The deadline is next Friday.', 'cn': '截止日期是下周五。'},
    {'en': 'I need to finish this project today.', 'cn': '我今天需要完成这个项目。'},

    // 电话交流
    {'en': 'Hello, may I speak with Mr. Johnson?', 'cn': '你好，我可以和约翰逊先生通话吗？'},
    {'en': 'I\'m sorry, he\'s not available right now.', 'cn': '抱歉，他现在不在。'},
    {'en': 'Could you please hold for a moment?', 'cn': '请稍等一下好吗？'},
    {'en': 'I\'ll call you back later.', 'cn': '我稍后给你回电话。'},
    {'en': 'Thank you for calling. Goodbye!', 'cn': '感谢来电。再见！'},

    // 旅行场景
    {'en': 'I would like to book a room for two nights.', 'cn': '我想预订两晚的房间。'},
    {'en': 'What time is check-out?', 'cn': '退房时间是几点？'},
    {'en': 'Is breakfast included in the price?', 'cn': '价格包含早餐吗？'},
    {'en': 'Could you recommend any local attractions?', 'cn': '你能推荐一些当地景点吗？'},
    {'en': 'I need a taxi to the airport.', 'cn': '我需要一辆去机场的出租车。'},

    // 天气话题
    {'en': 'What\'s the weather like today?', 'cn': '今天天气怎么样？'},
    {'en': 'It\'s going to rain this afternoon.', 'cn': '今天下午会下雨。'},
    {'en': 'The temperature is dropping rapidly.', 'cn': '温度正在快速下降。'},
    {'en': 'What a beautiful sunny day!', 'cn': '多么美丽的晴天！'},
    {'en': 'Don\'t forget to bring an umbrella.', 'cn': '别忘了带伞。'},

    // 健康话题
    {'en': 'I have a headache and a sore throat.', 'cn': '我头疼，嗓子也疼。'},
    {'en': 'You should get some rest.', 'cn': '你应该休息一下。'},
    {'en': 'I need to make an appointment with the doctor.', 'cn': '我需要预约医生。'},
    {'en': 'Take this medicine twice a day.', 'cn': '这药每天吃两次。'},
    {'en': 'I hope you feel better soon!', 'cn': '希望你早日康复！'},

    // 表达观点
    {'en': 'In my opinion, technology has changed our lives.', 'cn': '在我看来，科技改变了我们的生活。'},
    {'en': 'I completely agree with you.', 'cn': '我完全同意你的看法。'},
    {'en': 'That\'s an interesting point of view.', 'cn': '那是个有趣的观点。'},
    {'en': 'I\'m not sure I understand what you mean.', 'cn': '我不太确定你的意思。'},
    {'en': 'Could you explain that in more detail?', 'cn': '你能更详细地解释一下吗？'},

    // === 扩展句子 - 社交场合 ===
    {'en': 'It\'s been a while since we last met.', 'cn': '我们好久没见了。'},
    {'en': 'What do you do for a living?', 'cn': '你是做什么工作的？'},
    {'en': 'I\'m looking forward to seeing you again.', 'cn': '期待再次见到你。'},
    {'en': 'Let me introduce you to my colleague.', 'cn': '让我介绍一下我的同事。'},
    {'en': 'We should catch up over coffee sometime.', 'cn': '我们应该找时间喝咖啡聊聊。'},

    // === 扩展句子 - 日常生活 ===
    {'en': 'I usually wake up at seven in the morning.', 'cn': '我通常早上七点起床。'},
    {'en': 'What are your plans for the weekend?', 'cn': '你周末有什么计划？'},
    {'en': 'I enjoy reading books in my free time.', 'cn': '我喜欢在空闲时间看书。'},
    {'en': 'Could you help me with this, please?', 'cn': '你能帮我一下吗？'},
    {'en': 'I\'m running a bit late today.', 'cn': '我今天有点晚了。'},

    // === 扩展句子 - 购物进阶 ===
    {'en': 'Is there a discount for buying in bulk?', 'cn': '批量购买有折扣吗？'},
    {'en': 'The quality of this product is excellent.', 'cn': '这个产品的质量非常好。'},
    {'en': 'I\'d like to compare prices before deciding.', 'cn': '我想在决定之前比较一下价格。'},
    {'en': 'Do you offer free shipping?', 'cn': '你们提供免费送货吗？'},
    {'en': 'Can I get a receipt, please?', 'cn': '请给我一张收据好吗？'},

    // === 扩展句子 - 餐厅进阶 ===
    {'en': 'I\'d like to make a reservation for tonight.', 'cn': '我想预订今晚的位子。'},
    {'en': 'What\'s today\'s special?', 'cn': '今天的特色菜是什么？'},
    {'en': 'I\'m allergic to seafood.', 'cn': '我对海鲜过敏。'},
    {'en': 'Could you bring some more water, please?', 'cn': '请再给我们一些水好吗？'},
    {'en': 'The service here is outstanding.', 'cn': '这里的服务非常出色。'},

    // === 扩展句子 - 交通出行 ===
    {'en': 'Which platform does the train leave from?', 'cn': '火车从哪个站台发车？'},
    {'en': 'Is this seat taken?', 'cn': '这个座位有人吗？'},
    {'en': 'How long does it take to get there?', 'cn': '到那里需要多长时间？'},
    {'en': 'I missed my flight due to traffic.', 'cn': '我因为交通堵塞错过了航班。'},
    {'en': 'Could you drop me off at the corner?', 'cn': '你能在拐角处让我下车吗？'},

    // === 扩展句子 - 工作面试 ===
    {'en': 'I have five years of experience in this field.', 'cn': '我在这个领域有五年的经验。'},
    {'en': 'What are your strengths and weaknesses?', 'cn': '你的优势和劣势是什么？'},
    {'en': 'I\'m a quick learner and work well under pressure.', 'cn': '我学习能力强，能在压力下很好地工作。'},
    {'en': 'When can I expect to hear back from you?', 'cn': '我什么时候能收到你们的回复？'},
    {'en': 'I\'m excited about this opportunity.', 'cn': '我对这个机会感到很兴奋。'},

    // === 扩展句子 - 学习教育 ===
    {'en': 'I\'m preparing for my final exams.', 'cn': '我正在准备期末考试。'},
    {'en': 'Could you explain this concept to me?', 'cn': '你能给我解释一下这个概念吗？'},
    {'en': 'I need to improve my speaking skills.', 'cn': '我需要提高我的口语能力。'},
    {'en': 'What subject are you majoring in?', 'cn': '你主修什么专业？'},
    {'en': 'Practice makes perfect.', 'cn': '熟能生巧。'},

    // === 扩展句子 - 情感表达 ===
    {'en': 'I really appreciate your help.', 'cn': '我非常感谢你的帮助。'},
    {'en': 'I\'m sorry to hear that.', 'cn': '听到这个消息我很难过。'},
    {'en': 'Congratulations on your achievement!', 'cn': '恭喜你取得的成就！'},
    {'en': 'I\'m so happy for you!', 'cn': '我真为你高兴！'},
    {'en': 'Don\'t worry, everything will be fine.', 'cn': '别担心，一切都会好的。'},

    // === 扩展句子 - 请求与建议 ===
    {'en': 'Would you mind if I opened the window?', 'cn': '你介意我开窗吗？'},
    {'en': 'I suggest we take a break.', 'cn': '我建议我们休息一下。'},
    {'en': 'Why don\'t we try a different approach?', 'cn': '我们为什么不试试不同的方法？'},
    {'en': 'I would recommend the seafood pasta.', 'cn': '我推荐海鲜意面。'},
    {'en': 'How about meeting at six o\'clock?', 'cn': '六点见面怎么样？'},

    // === 扩展句子 - 紧急情况 ===
    {'en': 'Please call an ambulance immediately!', 'cn': '请立即叫救护车！'},
    {'en': 'Where is the nearest hospital?', 'cn': '最近的医院在哪里？'},
    {'en': 'I\'ve lost my passport.', 'cn': '我的护照丢了。'},
    {'en': 'Can you help me? It\'s an emergency.', 'cn': '你能帮帮我吗？这是紧急情况。'},
    {'en': 'I need to contact the embassy.', 'cn': '我需要联系大使馆。'},

    // === 扩展句子 - 科技与网络 ===
    {'en': 'What\'s the WiFi password here?', 'cn': 'WiFi密码是多少？'},
    {'en': 'My phone battery is almost dead.', 'cn': '我的手机快没电了。'},
    {'en': 'Could you send me that by email?', 'cn': '你能通过邮件发给我吗？'},
    {'en': 'The internet connection is really slow today.', 'cn': '今天网速真的很慢。'},
    {'en': 'I\'ll add you on social media.', 'cn': '我会在社交媒体上加你。'},
  ];

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 加载练习记录
    final recordsJson = prefs.getString(_keyPracticeRecords);
    if (recordsJson != null) {
      final list = jsonDecode(recordsJson) as List;
      _records = list.map((e) => PracticeRecord.fromJson(e)).toList();
    }

    // 加载统计数据
    final statsJson = prefs.getString(_keyPracticeStats);
    if (statsJson != null) {
      final stats = jsonDecode(statsJson);
      _totalPracticed = stats['totalPracticed'] ?? 0;
      _averageScore = (stats['averageScore'] ?? 0).toDouble();
    }

    // 加载在线对话缓存
    await _loadOnlineDialogues();

    _initialized = true;
  }

  // ==================== 在线对话API ====================

  /// 从 DailyDialog 数据集获取对话 (通过 Hugging Face API)
  Future<List<Map<String, String>>> fetchOnlineDialogues({int count = 50}) async {
    try {
      // 使用 Hugging Face Datasets API
      final response = await http.get(
        Uri.parse('https://datasets-server.huggingface.co/rows?dataset=li2017dailydialog%2Fdaily_dialog&config=default&split=train&offset=0&length=$count'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rows = data['rows'] as List? ?? [];

        final dialogues = <Map<String, String>>[];

        for (var row in rows) {
          final dialog = row['row']?['dialog'] as List? ?? [];
          // 将对话中的每个句子提取出来
          for (var utterance in dialog) {
            final sentence = (utterance as String?)?.trim() ?? '';
            if (sentence.isNotEmpty && sentence.length > 10 && sentence.length < 150) {
              dialogues.add({
                'en': sentence,
                'cn': '', // 暂无翻译，可后续添加翻译功能
              });
            }
          }
        }

        if (dialogues.isNotEmpty) {
          _onlineDialogues = dialogues;
          await _saveOnlineDialogues();
          if (kDebugMode) {
            debugPrint('Loaded ${dialogues.length} online dialogues');
          }
          return dialogues;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching online dialogues: $e');
      }
    }

    // 如果在线获取失败，使用缓存
    return _onlineDialogues;
  }

  /// 获取随机句子（本地 + 在线混合）
  Future<List<Map<String, String>>> getMixedSentences({
    int count = 10,
    bool includeOnline = true,
  }) async {
    List<Map<String, String>> pool = List.from(builtInSentences);

    // 添加在线对话
    if (includeOnline) {
      if (_onlineDialogues.isEmpty) {
        await fetchOnlineDialogues(count: 100);
      }
      pool.addAll(_onlineDialogues);
    }

    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  /// 获取随机内置句子
  List<Map<String, String>> getRandomSentences({int count = 10}) {
    final pool = List<Map<String, String>>.from(builtInSentences);
    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  /// 刷新在线对话
  Future<void> refreshOnlineDialogues() async {
    _onlineDialogues.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnlineDialogues);
    await fetchOnlineDialogues(count: 100);
  }

  Future<void> _saveOnlineDialogues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_onlineDialogues);
      await prefs.setString(_keyOnlineDialogues, json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving online dialogues: $e');
      }
    }
  }

  Future<void> _loadOnlineDialogues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyOnlineDialogues);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        _onlineDialogues = list.map((e) => Map<String, String>.from(e as Map)).toList();
        if (kDebugMode) {
          debugPrint('Loaded ${_onlineDialogues.length} cached online dialogues');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading online dialogues: $e');
      }
    }
  }

  // ==================== 场景分类 ====================

  /// 获取所有场景类别
  static final List<String> categories = [
    '日常问候',
    '购物场景',
    '餐厅点餐',
    '问路',
    '工作场景',
    '电话交流',
    '旅行场景',
    '天气话题',
    '健康话题',
    '表达观点',
    '社交场合',
    '日常生活',
    '工作面试',
    '学习教育',
    '情感表达',
    '请求与建议',
    '紧急情况',
    '科技与网络',
  ];

  /// 添加练习记录
  Future<void> addPracticeRecord({
    required String sentence,
    required double score,
  }) async {
    final record = PracticeRecord(
      sentence: sentence,
      score: score,
      practiceTime: DateTime.now(),
    );

    _records.insert(0, record);
    if (_records.length > 500) {
      _records = _records.sublist(0, 500);
    }

    // 更新统计
    _totalPracticed++;
    _averageScore = ((_averageScore * (_totalPracticed - 1)) + score) / _totalPracticed;

    await _save();
  }

  /// 获取今日练习统计
  Map<String, dynamic> getTodayStats() {
    final today = DateTime.now();
    final todayRecords = _records.where((r) =>
      r.practiceTime.year == today.year &&
      r.practiceTime.month == today.month &&
      r.practiceTime.day == today.day
    ).toList();

    if (todayRecords.isEmpty) {
      return {'count': 0, 'average': 0.0};
    }

    final avgScore = todayRecords.map((r) => r.score).reduce((a, b) => a + b) / todayRecords.length;

    return {
      'count': todayRecords.length,
      'average': avgScore,
    };
  }

  /// 获取最近7天练习趋势
  List<Map<String, dynamic>> getWeeklyTrend() {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayRecords = _records.where((r) =>
        r.practiceTime.year == date.year &&
        r.practiceTime.month == date.month &&
        r.practiceTime.day == date.day
      ).toList();

      double avgScore = 0;
      if (dayRecords.isNotEmpty) {
        avgScore = dayRecords.map((r) => r.score).reduce((a, b) => a + b) / dayRecords.length;
      }

      result.add({
        'date': date,
        'count': dayRecords.length,
        'average': avgScore,
      });
    }

    return result;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // 保存记录
    final recordsJson = jsonEncode(_records.map((r) => r.toJson()).toList());
    await prefs.setString(_keyPracticeRecords, recordsJson);

    // 保存统计
    final statsJson = jsonEncode({
      'totalPracticed': _totalPracticed,
      'averageScore': _averageScore,
    });
    await prefs.setString(_keyPracticeStats, statsJson);
  }
}

/// 练习记录
class PracticeRecord {
  final String sentence;
  final double score;
  final DateTime practiceTime;

  PracticeRecord({
    required this.sentence,
    required this.score,
    required this.practiceTime,
  });

  Map<String, dynamic> toJson() => {
    'sentence': sentence,
    'score': score,
    'practiceTime': practiceTime.toIso8601String(),
  };

  factory PracticeRecord.fromJson(Map<String, dynamic> json) {
    return PracticeRecord(
      sentence: json['sentence'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      practiceTime: json['practiceTime'] != null
          ? DateTime.parse(json['practiceTime'])
          : DateTime.now(),
    );
  }
}
