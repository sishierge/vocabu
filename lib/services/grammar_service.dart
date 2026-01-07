import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'online_resources_service.dart';

/// 语法练习服务
class GrammarService {
  static final GrammarService instance = GrammarService._();
  GrammarService._();

  static const String _keyGrammarRecords = 'grammar_practice_records';
  static const String _keyGrammarStats = 'grammar_practice_stats';
  static const String _keyOnlineQuestions = 'online_grammar_questions';

  List<GrammarRecord> _records = [];
  int _totalPracticed = 0;
  int _correctCount = 0;
  bool _initialized = false;

  // 在线获取的题目缓存
  List<GrammarQuestion> _onlineQuestions = [];

  List<GrammarRecord> get records => _records;
  int get totalPracticed => _totalPracticed;
  int get correctCount => _correctCount;
  double get accuracy => _totalPracticed > 0 ? _correctCount / _totalPracticed : 0;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 加载练习记录
    final recordsJson = prefs.getString(_keyGrammarRecords);
    if (recordsJson != null) {
      final list = jsonDecode(recordsJson) as List;
      _records = list.map((e) => GrammarRecord.fromJson(e)).toList();
    }

    // 加载统计数据
    final statsJson = prefs.getString(_keyGrammarStats);
    if (statsJson != null) {
      final stats = jsonDecode(statsJson);
      _totalPracticed = stats['totalPracticed'] ?? 0;
      _correctCount = stats['correctCount'] ?? 0;
    }

    _initialized = true;
  }

  /// 添加练习记录
  Future<void> addPracticeRecord({
    required String question,
    required bool isCorrect,
    required String category,
  }) async {
    final record = GrammarRecord(
      question: question,
      isCorrect: isCorrect,
      category: category,
      practiceTime: DateTime.now(),
    );

    _records.insert(0, record);
    if (_records.length > 500) {
      _records = _records.sublist(0, 500);
    }

    _totalPracticed++;
    if (isCorrect) _correctCount++;

    await _save();
  }

  /// 获取今日统计
  Map<String, dynamic> getTodayStats() {
    final today = DateTime.now();
    final todayRecords = _records.where((r) =>
      r.practiceTime.year == today.year &&
      r.practiceTime.month == today.month &&
      r.practiceTime.day == today.day
    ).toList();

    if (todayRecords.isEmpty) {
      return {'count': 0, 'correct': 0, 'accuracy': 0.0};
    }

    final correct = todayRecords.where((r) => r.isCorrect).length;

    return {
      'count': todayRecords.length,
      'correct': correct,
      'accuracy': correct / todayRecords.length,
    };
  }

  /// 获取随机语法选择题
  List<GrammarQuestion> getRandomQuestions({int count = 10, String? category}) {
    List<GrammarQuestion> pool = category != null
        ? allQuestions.where((q) => q.category == category).toList()
        : allQuestions.toList();

    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  /// 获取随机句子改错题
  List<SentenceCorrectionQuestion> getRandomCorrections({int count = 10}) {
    final pool = allCorrections.toList();
    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  /// 从在线API获取题目 (Trivia API)
  Future<List<GrammarQuestion>> fetchOnlineQuestions({int count = 10}) async {
    try {
      final triviaData = await OnlineResourcesService.instance.fetchTriviaQuestions(
        limit: count,
        difficulty: 'medium',
      );

      if (triviaData.isNotEmpty) {
        final questions = triviaData.map((q) {
          final options = List<String>.from(q['options'] as List);
          return GrammarQuestion(
            question: q['question'] as String,
            options: options,
            correctIndex: q['correctIndex'] as int,
            explanation: 'Category: ${q['category']}',
            category: '在线题目',
          );
        }).toList();

        _onlineQuestions = questions;
        await _saveOnlineQuestions();
        return questions;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching online questions: $e');
      }
    }

    // 如果在线获取失败，尝试从缓存加载
    return _loadOnlineQuestions();
  }

  /// 获取混合题目（本地 + 在线）
  Future<List<GrammarQuestion>> getMixedQuestions({
    int count = 10,
    String? category,
    bool includeOnline = true,
  }) async {
    List<GrammarQuestion> pool = [];

    // 添加本地题目
    if (category != null) {
      pool.addAll(allQuestions.where((q) => q.category == category));
    } else {
      pool.addAll(allQuestions);
    }

    // 添加在线题目
    if (includeOnline) {
      if (_onlineQuestions.isEmpty) {
        _onlineQuestions = await _loadOnlineQuestions();
      }
      if (_onlineQuestions.isEmpty) {
        // 尝试在线获取
        await fetchOnlineQuestions(count: 20);
      }
      pool.addAll(_onlineQuestions);
    }

    pool.shuffle(Random());
    return pool.take(count).toList();
  }

  /// 刷新在线题目
  Future<void> refreshOnlineQuestions() async {
    await OnlineResourcesService.instance.refreshResource('trivia_general_knowledge_medium');
    _onlineQuestions.clear();
    await fetchOnlineQuestions(count: 20);
  }

  Future<void> _saveOnlineQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_onlineQuestions.map((q) => {
        'question': q.question,
        'options': q.options,
        'correctIndex': q.correctIndex,
        'explanation': q.explanation,
        'category': q.category,
      }).toList());
      await prefs.setString(_keyOnlineQuestions, json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving online questions: $e');
      }
    }
  }

  Future<List<GrammarQuestion>> _loadOnlineQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyOnlineQuestions);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => GrammarQuestion(
          question: e['question'] as String,
          options: List<String>.from(e['options']),
          correctIndex: e['correctIndex'] as int,
          explanation: e['explanation'] as String,
          category: e['category'] as String,
        )).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading online questions: $e');
      }
    }
    return [];
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // 保存记录
    final recordsJson = jsonEncode(_records.map((r) => r.toJson()).toList());
    await prefs.setString(_keyGrammarRecords, recordsJson);

    // 保存统计
    final statsJson = jsonEncode({
      'totalPracticed': _totalPracticed,
      'correctCount': _correctCount,
    });
    await prefs.setString(_keyGrammarStats, statsJson);
  }

  /// 所有语法选择题
  static final List<GrammarQuestion> allQuestions = [
    // 时态 - Tenses
    GrammarQuestion(
      question: 'She ___ to the gym every morning.',
      options: ['go', 'goes', 'going', 'gone'],
      correctIndex: 1,
      explanation: '主语是第三人称单数 she，一般现在时动词加 s/es。',
      category: '时态',
    ),
    GrammarQuestion(
      question: 'I ___ my homework when you called.',
      options: ['do', 'did', 'was doing', 'have done'],
      correctIndex: 2,
      explanation: '过去进行时表示过去某一时刻正在进行的动作。',
      category: '时态',
    ),
    GrammarQuestion(
      question: 'By next year, I ___ here for ten years.',
      options: ['will work', 'will be working', 'will have worked', 'work'],
      correctIndex: 2,
      explanation: '将来完成时表示到将来某一时刻已完成的动作。',
      category: '时态',
    ),
    GrammarQuestion(
      question: 'He ___ in London since 2010.',
      options: ['lives', 'lived', 'has lived', 'is living'],
      correctIndex: 2,
      explanation: 'since + 过去时间点，用现在完成时。',
      category: '时态',
    ),
    GrammarQuestion(
      question: 'The train ___ by the time we arrive.',
      options: ['leaves', 'left', 'will leave', 'will have left'],
      correctIndex: 3,
      explanation: 'by the time + 一般现在时，主句用将来完成时。',
      category: '时态',
    ),

    // 冠词 - Articles
    GrammarQuestion(
      question: '___ sun rises in ___ east.',
      options: ['A, an', 'The, the', 'A, the', 'The, an'],
      correctIndex: 1,
      explanation: '独一无二的事物和方位前用定冠词 the。',
      category: '冠词',
    ),
    GrammarQuestion(
      question: 'She is ___ honest woman.',
      options: ['a', 'an', 'the', '不填'],
      correctIndex: 1,
      explanation: 'honest 以元音音素开头，用 an。',
      category: '冠词',
    ),
    GrammarQuestion(
      question: 'I bought ___ umbrella yesterday.',
      options: ['a', 'an', 'the', '不填'],
      correctIndex: 1,
      explanation: 'umbrella 以元音音素 /ʌ/ 开头，用 an。',
      category: '冠词',
    ),
    GrammarQuestion(
      question: '___ Mount Everest is the highest mountain.',
      options: ['A', 'An', 'The', '不填'],
      correctIndex: 3,
      explanation: '山峰名称前通常不加冠词。',
      category: '冠词',
    ),

    // 介词 - Prepositions
    GrammarQuestion(
      question: 'I am interested ___ learning English.',
      options: ['in', 'on', 'at', 'for'],
      correctIndex: 0,
      explanation: 'be interested in 是固定搭配，表示对...感兴趣。',
      category: '介词',
    ),
    GrammarQuestion(
      question: 'She arrived ___ the airport at 6 PM.',
      options: ['in', 'on', 'at', 'to'],
      correctIndex: 2,
      explanation: 'arrive at + 小地点（机场、车站等）。',
      category: '介词',
    ),
    GrammarQuestion(
      question: 'The book is ___ the table.',
      options: ['in', 'on', 'at', 'under'],
      correctIndex: 1,
      explanation: 'on 表示在...上面（接触表面）。',
      category: '介词',
    ),
    GrammarQuestion(
      question: 'I have been waiting ___ two hours.',
      options: ['since', 'for', 'in', 'during'],
      correctIndex: 1,
      explanation: 'for + 一段时间，since + 时间点。',
      category: '介词',
    ),
    GrammarQuestion(
      question: 'He is good ___ playing basketball.',
      options: ['in', 'on', 'at', 'for'],
      correctIndex: 2,
      explanation: 'be good at 是固定搭配，表示擅长...。',
      category: '介词',
    ),

    // 从句 - Clauses
    GrammarQuestion(
      question: 'This is the book ___ I bought yesterday.',
      options: ['who', 'whom', 'which', 'what'],
      correctIndex: 2,
      explanation: '先行词是物（book），关系代词用 which 或 that。',
      category: '从句',
    ),
    GrammarQuestion(
      question: 'The man ___ is standing there is my father.',
      options: ['who', 'whom', 'which', 'what'],
      correctIndex: 0,
      explanation: '先行词是人（man）且在从句中作主语，用 who。',
      category: '从句',
    ),
    GrammarQuestion(
      question: 'I don\'t know ___ he will come.',
      options: ['that', 'if', 'what', 'which'],
      correctIndex: 1,
      explanation: 'if/whether 引导不确定的宾语从句，表示是否。',
      category: '从句',
    ),
    GrammarQuestion(
      question: '___ you study hard, you will pass the exam.',
      options: ['If', 'Unless', 'Although', 'Because'],
      correctIndex: 0,
      explanation: 'If 引导条件状语从句，表示如果。',
      category: '从句',
    ),
    GrammarQuestion(
      question: 'I will wait here ___ you come back.',
      options: ['until', 'since', 'because', 'although'],
      correctIndex: 0,
      explanation: 'until 表示直到...为止。',
      category: '从句',
    ),

    // 被动语态 - Passive Voice
    GrammarQuestion(
      question: 'The letter ___ yesterday.',
      options: ['wrote', 'was written', 'is written', 'writes'],
      correctIndex: 1,
      explanation: '被动语态：be + 过去分词，yesterday 表示过去时。',
      category: '被动语态',
    ),
    GrammarQuestion(
      question: 'English ___ all over the world.',
      options: ['speaks', 'is spoken', 'spoke', 'speaking'],
      correctIndex: 1,
      explanation: '表示客观事实的被动语态用一般现在时。',
      category: '被动语态',
    ),
    GrammarQuestion(
      question: 'The bridge ___ next year.',
      options: ['will build', 'will be built', 'is built', 'built'],
      correctIndex: 1,
      explanation: '将来时的被动语态：will be + 过去分词。',
      category: '被动语态',
    ),

    // 比较级 - Comparatives
    GrammarQuestion(
      question: 'She is ___ than her sister.',
      options: ['tall', 'taller', 'tallest', 'more tall'],
      correctIndex: 1,
      explanation: '单音节形容词比较级加 -er。',
      category: '比较级',
    ),
    GrammarQuestion(
      question: 'This book is ___ interesting than that one.',
      options: ['more', 'most', 'much', 'very'],
      correctIndex: 0,
      explanation: '多音节形容词比较级用 more + 形容词。',
      category: '比较级',
    ),
    GrammarQuestion(
      question: 'Of all the students, she studies ___.',
      options: ['hard', 'harder', 'hardest', 'the hardest'],
      correctIndex: 3,
      explanation: '三者及以上比较用最高级，前加 the。',
      category: '比较级',
    ),
    GrammarQuestion(
      question: 'This is ___ movie I have ever seen.',
      options: ['good', 'better', 'the best', 'best'],
      correctIndex: 2,
      explanation: '最高级前要加定冠词 the。',
      category: '比较级',
    ),

    // 情态动词 - Modal Verbs
    GrammarQuestion(
      question: 'You ___ smoke here. It\'s forbidden.',
      options: ['mustn\'t', 'needn\'t', 'can\'t', 'shouldn\'t'],
      correctIndex: 0,
      explanation: 'mustn\'t 表示禁止，不可以。',
      category: '情态动词',
    ),
    GrammarQuestion(
      question: 'You look tired. You ___ take a rest.',
      options: ['must', 'should', 'can', 'may'],
      correctIndex: 1,
      explanation: 'should 表示建议，应该。',
      category: '情态动词',
    ),
    GrammarQuestion(
      question: '___ I use your phone?',
      options: ['Must', 'Should', 'May', 'Need'],
      correctIndex: 2,
      explanation: 'May I...? 用于礼貌地请求许可。',
      category: '情态动词',
    ),
    GrammarQuestion(
      question: 'He ___ be at home. I saw him at school.',
      options: ['mustn\'t', 'can\'t', 'needn\'t', 'shouldn\'t'],
      correctIndex: 1,
      explanation: 'can\'t 表示不可能（推测）。',
      category: '情态动词',
    ),

    // 虚拟语气 - Subjunctive Mood
    GrammarQuestion(
      question: 'If I ___ you, I would accept the offer.',
      options: ['am', 'was', 'were', 'be'],
      correctIndex: 2,
      explanation: '虚拟语气中，if 从句用过去式，be 动词一律用 were。',
      category: '虚拟语气',
    ),
    GrammarQuestion(
      question: 'I wish I ___ a bird.',
      options: ['am', 'was', 'were', 'be'],
      correctIndex: 2,
      explanation: 'wish 后的从句用虚拟语气，be 动词用 were。',
      category: '虚拟语气',
    ),
    GrammarQuestion(
      question: 'If I had studied harder, I ___ the exam.',
      options: ['would pass', 'would have passed', 'will pass', 'passed'],
      correctIndex: 1,
      explanation: '与过去事实相反的虚拟语气，主句用 would have + 过去分词。',
      category: '虚拟语气',
    ),
  ];

  /// 所有句子改错题
  static final List<SentenceCorrectionQuestion> allCorrections = [
    SentenceCorrectionQuestion(
      wrongSentence: 'He don\'t like coffee.',
      correctSentence: 'He doesn\'t like coffee.',
      explanation: '第三人称单数主语用 doesn\'t，不用 don\'t。',
      category: '主谓一致',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'She is more taller than me.',
      correctSentence: 'She is taller than me.',
      explanation: '单音节形容词比较级直接加 -er，不用 more。',
      category: '比较级',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'I have went to Paris.',
      correctSentence: 'I have been to Paris.',
      explanation: '现在完成时用 have been to 表示去过某地。',
      category: '时态',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'He gave me a advice.',
      correctSentence: 'He gave me some advice.',
      explanation: 'advice 是不可数名词，不能用 a，应用 some。',
      category: '名词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'There are many informations.',
      correctSentence: 'There is much information.',
      explanation: 'information 是不可数名词，用 much 修饰，be 动词用 is。',
      category: '名词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'I am agree with you.',
      correctSentence: 'I agree with you.',
      explanation: 'agree 是动词，不需要 be 动词。',
      category: '动词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'She suggested me to go.',
      correctSentence: 'She suggested that I go.',
      explanation: 'suggest 后接 that 从句（虚拟语气）或动名词，不接 sb. to do。',
      category: '动词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'I look forward to see you.',
      correctSentence: 'I look forward to seeing you.',
      explanation: 'look forward to 中的 to 是介词，后接动名词。',
      category: '动词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'Although it rained, but we went out.',
      correctSentence: 'Although it rained, we went out.',
      explanation: 'although 和 but 不能同时使用，二选一。',
      category: '连词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'Because of he was ill, he stayed home.',
      correctSentence: 'Because he was ill, he stayed home.',
      explanation: 'because 后接从句，because of 后接名词短语。',
      category: '连词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'The news are very exciting.',
      correctSentence: 'The news is very exciting.',
      explanation: 'news 是不可数名词，动词用单数形式。',
      category: '主谓一致',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'Everyone have their own opinion.',
      correctSentence: 'Everyone has their own opinion.',
      explanation: 'everyone 是单数，谓语动词用 has。',
      category: '主谓一致',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'I have been to there.',
      correctSentence: 'I have been there.',
      explanation: 'there 是副词，前面不加介词 to。',
      category: '介词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'He married with her.',
      correctSentence: 'He married her.',
      explanation: 'marry 是及物动词，直接接宾语，不加介词。',
      category: '动词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'I am boring.',
      correctSentence: 'I am bored.',
      explanation: '表示人的感受用 -ed 形式（bored），表示事物的特征用 -ing 形式。',
      category: '形容词',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'The meeting will held tomorrow.',
      correctSentence: 'The meeting will be held tomorrow.',
      explanation: '被动语态：will + be + 过去分词。',
      category: '被动语态',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'I have seen him yesterday.',
      correctSentence: 'I saw him yesterday.',
      explanation: 'yesterday 表示过去明确时间，用一般过去时，不用现在完成时。',
      category: '时态',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'She is knowing the answer.',
      correctSentence: 'She knows the answer.',
      explanation: 'know 是状态动词，不能用进行时态。',
      category: '时态',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'The price of vegetables have increased.',
      correctSentence: 'The price of vegetables has increased.',
      explanation: '主语是 the price（单数），谓语用 has。',
      category: '主谓一致',
    ),
    SentenceCorrectionQuestion(
      wrongSentence: 'Neither he nor I are going.',
      correctSentence: 'Neither he nor I am going.',
      explanation: 'neither...nor... 遵循就近原则，谓语与 I 一致用 am。',
      category: '主谓一致',
    ),
  ];

  /// 语法类别列表
  static final List<String> categories = [
    '时态',
    '冠词',
    '介词',
    '从句',
    '被动语态',
    '比较级',
    '情态动词',
    '虚拟语气',
  ];
}

/// 语法选择题
class GrammarQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String category;

  GrammarQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
  });
}

/// 句子改错题
class SentenceCorrectionQuestion {
  final String wrongSentence;
  final String correctSentence;
  final String explanation;
  final String category;

  SentenceCorrectionQuestion({
    required this.wrongSentence,
    required this.correctSentence,
    required this.explanation,
    required this.category,
  });
}

/// 练习记录
class GrammarRecord {
  final String question;
  final bool isCorrect;
  final String category;
  final DateTime practiceTime;

  GrammarRecord({
    required this.question,
    required this.isCorrect,
    required this.category,
    required this.practiceTime,
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'isCorrect': isCorrect,
    'category': category,
    'practiceTime': practiceTime.toIso8601String(),
  };

  factory GrammarRecord.fromJson(Map<String, dynamic> json) {
    return GrammarRecord(
      question: json['question'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
      category: json['category'] ?? '',
      practiceTime: json['practiceTime'] != null
          ? DateTime.parse(json['practiceTime'])
          : DateTime.now(),
    );
  }
}
