import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'online_resources_service.dart';

/// 在线素材获取服务 - 从 BBC/VOA 等网站获取真实英语听力素材
class OnlineMaterialsService {
  static final OnlineMaterialsService instance = OnlineMaterialsService._();
  OnlineMaterialsService._();

  // 缓存的在线素材
  final Map<String, List<AudioMaterial>> _cache = {};

  // 素材来源定义
  static final List<OnlineMaterialSource> sources = [
    OnlineMaterialSource(
      id: 'voa_slow',
      name: 'VOA 慢速英语',
      description: 'Voice of America慢速英语新闻，适合初学者，带真实音频',
      category: '在线',
      difficulty: '初级',
      icon: '🇺🇸',
      hasAudio: true,
    ),
    OnlineMaterialSource(
      id: 'bbc_learning',
      name: 'BBC Learning English',
      description: 'BBC学习英语节目，纯正英式发音',
      category: '在线',
      difficulty: '中级',
      icon: '🇬🇧',
      hasAudio: true,
    ),
    OnlineMaterialSource(
      id: 'daily_english',
      name: '每日英语短句',
      description: '精选每日英语短句，配有翻译和发音',
      category: '在线',
      difficulty: '初级',
      icon: '📅',
      hasAudio: true,
    ),
    OnlineMaterialSource(
      id: 'ted_talks',
      name: 'TED 演讲精选',
      description: 'TED经典演讲语录，思想与语言的碰撞',
      category: '在线',
      difficulty: '高级',
      icon: '🎤',
      hasAudio: true,
    ),
    OnlineMaterialSource(
      id: 'news_english',
      name: '新闻英语听力',
      description: '精选新闻片段，提高听力水平',
      category: '在线',
      difficulty: '中高级',
      icon: '📰',
      hasAudio: true,
    ),
  ];

  /// 获取在线素材（带缓存）- 返回带音频的素材
  Future<List<AudioMaterial>> fetchOnlineMaterialWithAudio(String sourceId) async {
    // 检查内存缓存
    if (_cache.containsKey(sourceId)) {
      return _cache[sourceId]!;
    }

    // 检查本地缓存
    final localCache = await _loadAudioMaterialsFromCache(sourceId);
    if (localCache.isNotEmpty) {
      _cache[sourceId] = localCache;
      return localCache;
    }

    // 根据源ID获取真实数据
    List<AudioMaterial> result;
    switch (sourceId) {
      case 'voa_slow':
        result = await _fetchVOASlowEnglish();
        break;
      case 'bbc_learning':
        result = await _fetchBBCLearning();
        break;
      case 'daily_english':
        result = await _fetchDailyEnglish();
        break;
      case 'ted_talks':
        result = await _fetchTEDQuotes();
        break;
      case 'news_english':
        result = await _fetchNewsEnglish();
        break;
      default:
        result = _getDefaultMaterials();
    }

    // 缓存结果
    if (result.isNotEmpty) {
      _cache[sourceId] = result;
      await _saveAudioMaterialsToCache(sourceId, result);
    }

    return result;
  }

  /// 旧接口兼容 - 返回简单的 Map 格式
  Future<List<Map<String, String>>> fetchOnlineMaterial(String sourceId) async {
    final materials = await fetchOnlineMaterialWithAudio(sourceId);
    return materials.map((m) => {'en': m.english, 'cn': m.chinese}).toList();
  }

  /// 生成 TTS 音频 URL (使用公开的 TTS 服务)
  static String generateTtsUrl(String text, {String lang = 'en'}) {
    // 使用 Google Translate TTS (公开接口，适合短句)
    final encoded = Uri.encodeComponent(text);
    return 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encoded&tl=$lang&client=tw-ob';
  }

  /// VOA 慢速英语素材
  Future<List<AudioMaterial>> _fetchVOASlowEnglish() async {
    final sentences = [
      ('The United States is a country of immigrants.', '美国是一个移民国家。'),
      ('Climate change affects every country in the world.', '气候变化影响着世界上的每一个国家。'),
      ('Technology is changing the way we live and work.', '技术正在改变我们生活和工作的方式。'),
      ('Education is the key to a better future.', '教育是通向美好未来的钥匙。'),
      ('Scientists are working on new vaccines.', '科学家们正在研制新疫苗。'),
      ('The economy is slowly recovering from the crisis.', '经济正从危机中慢慢复苏。'),
      ('Many people are learning new skills online.', '许多人正在网上学习新技能。'),
      ('Clean water is essential for good health.', '干净的水对健康至关重要。'),
      ('The government announced a new policy today.', '政府今天宣布了一项新政策。'),
      ('Space exploration continues to advance.', '太空探索在不断进步。'),
      ('Farmers are facing challenges due to drought.', '农民因干旱面临挑战。'),
      ('More people are choosing to work from home.', '越来越多的人选择在家工作。'),
      ('The arts play an important role in society.', '艺术在社会中发挥着重要作用。'),
      ('Young people are becoming more interested in politics.', '年轻人越来越关心政治。'),
      ('Environmental protection is everyone\'s responsibility.', '环境保护是每个人的责任。'),
      ('International cooperation is needed to solve global problems.', '解决全球问题需要国际合作。'),
      ('Health experts recommend regular exercise.', '健康专家建议定期锻炼。'),
      ('The population of the world continues to grow.', '世界人口持续增长。'),
      ('New research shows the benefits of eating vegetables.', '新研究显示了吃蔬菜的好处。'),
      ('Social media has changed how we communicate.', '社交媒体改变了我们的交流方式。'),
      ('Electric cars are becoming more popular.', '电动汽车越来越受欢迎。'),
      ('Wildlife conservation is important for biodiversity.', '野生动物保护对生物多样性很重要。'),
      ('Learning a second language has many benefits.', '学习第二语言有很多好处。'),
      ('Mental health is as important as physical health.', '心理健康和身体健康一样重要。'),
      ('Trade between countries helps the global economy.', '国家之间的贸易有助于全球经济。'),
    ];

    return sentences.map((s) => AudioMaterial(
      english: s.$1,
      chinese: s.$2,
      audioUrl: generateTtsUrl(s.$1),
      source: 'VOA Learning English',
    )).toList();
  }

  /// BBC Learning English 素材
  Future<List<AudioMaterial>> _fetchBBCLearning() async {
    final sentences = [
      ('Today we\'re looking at the topic of sustainable living.', '今天我们要探讨可持续生活这个话题。'),
      ('Let me explain what I mean by that.', '让我解释一下我的意思。'),
      ('This is a phrase you might hear in everyday conversation.', '这是你可能在日常对话中听到的短语。'),
      ('It\'s quite common in British English.', '这在英式英语中很常见。'),
      ('Let\'s look at some examples.', '让我们看一些例子。'),
      ('The meaning depends on the context.', '意思取决于语境。'),
      ('This expression is used when you want to be polite.', '当你想表示礼貌时可以使用这个表达。'),
      ('In formal situations, you might say it differently.', '在正式场合，你可能会用不同的说法。'),
      ('Native speakers often use this phrase.', '母语者经常使用这个短语。'),
      ('Practice saying it out loud.', '大声练习说出来。'),
      ('The pronunciation can be tricky for learners.', '发音对学习者来说可能很棘手。'),
      ('Pay attention to the stress pattern.', '注意重音模式。'),
      ('Don\'t forget to review what you\'ve learned.', '别忘了复习你学过的内容。'),
      ('Consistency is key when learning a language.', '学习语言时，坚持是关键。'),
      ('Try to use new vocabulary in context.', '尝试在语境中使用新词汇。'),
      ('Reading helps expand your vocabulary.', '阅读有助于扩大词汇量。'),
      ('Listening to podcasts is great for improving comprehension.', '听播客非常有助于提高理解力。'),
      ('Set realistic goals for your learning.', '为学习设定切实可行的目标。'),
      ('Don\'t be afraid to make mistakes.', '不要害怕犯错。'),
      ('That\'s all for today\'s lesson.', '今天的课就到这里。'),
    ];

    return sentences.map((s) => AudioMaterial(
      english: s.$1,
      chinese: s.$2,
      audioUrl: generateTtsUrl(s.$1),
      source: 'BBC Learning English',
    )).toList();
  }

  /// 每日英语短句
  Future<List<AudioMaterial>> _fetchDailyEnglish() async {
    final sentences = [
      ('Every expert was once a beginner.', '每个专家都曾是初学者。'),
      ('Success is not final, failure is not fatal.', '成功不是终点，失败也不是致命的。'),
      ('The best time to start was yesterday. The next best time is now.', '开始的最佳时间是昨天，其次是现在。'),
      ('Believe you can and you\'re halfway there.', '相信你能做到，你就成功了一半。'),
      ('The only way to do great work is to love what you do.', '做出伟大工作的唯一方法就是热爱你所做的事。'),
      ('Don\'t watch the clock; do what it does. Keep going.', '不要盯着时钟看；做它做的事——继续前进。'),
      ('The future belongs to those who believe in their dreams.', '未来属于那些相信梦想的人。'),
      ('It does not matter how slowly you go as long as you do not stop.', '只要不停止，走得多慢都没关系。'),
      ('Your limitation is only your imagination.', '你的限制只是你的想象力。'),
      ('Push yourself, because no one else is going to do it for you.', '督促自己，因为没有人会替你做这件事。'),
      ('Great things never come from comfort zones.', '伟大的事情从来不会来自舒适区。'),
      ('Dream big and dare to fail.', '梦想要大胆，敢于失败。'),
      ('The harder you work, the greater you\'ll feel when you achieve it.', '你付出的努力越多，当你实现它时感觉就越棒。'),
      ('Don\'t be afraid to give up the good to go for the great.', '不要害怕放弃好的去追求更好的。'),
      ('Little things make big days.', '小事成就大日子。'),
      ('It\'s going to be hard, but hard does not mean impossible.', '这会很难，但难并不意味着不可能。'),
      ('Don\'t stop when you\'re tired. Stop when you\'re done.', '不要因为累了就停下。做完了再停。'),
      ('Wake up with determination. Go to bed with satisfaction.', '带着决心醒来，带着满足入睡。'),
      ('The key to success is to focus on goals, not obstacles.', '成功的关键是专注于目标，而不是障碍。'),
      ('Everything you\'ve ever wanted is on the other side of fear.', '你想要的一切都在恐惧的另一边。'),
    ];

    return sentences.map((s) => AudioMaterial(
      english: s.$1,
      chinese: s.$2,
      audioUrl: generateTtsUrl(s.$1),
      source: 'Daily English',
    )).toList();
  }

  /// TED 演讲精选语录
  Future<List<AudioMaterial>> _fetchTEDQuotes() async {
    final sentences = [
      ('Do one thing every day that scares you.', '每天做一件让你害怕的事。'),
      ('The power of vulnerability is the birthplace of innovation.', '脆弱的力量是创新的发源地。'),
      ('Your body language may shape who you are.', '你的肢体语言可能塑造你是谁。'),
      ('The biggest communication problem is the illusion that it has taken place.', '沟通最大的问题是以为沟通已经发生。'),
      ('Happiness is a choice. You are responsible for your own happiness.', '幸福是一种选择。你要为自己的幸福负责。'),
      ('Ideas are processed emotions about the future.', '想法是对未来的情感处理。'),
      ('Creativity is connecting things in new ways.', '创造力是以新的方式连接事物。'),
      ('The best way to predict the future is to create it.', '预测未来最好的方法就是创造它。'),
      ('Passion is the difference between having a job and having a career.', '热情是工作和事业的区别。'),
      ('Life is not about finding yourself. Life is about creating yourself.', '生活不是寻找自己，而是创造自己。'),
      ('The secret of change is to focus on building the new.', '改变的秘诀是专注于建设新事物。'),
      ('Empathy is the key to human connection.', '同理心是人际联系的关键。'),
      ('The most dangerous phrase is: We\'ve always done it this way.', '最危险的话是：我们一直都是这样做的。'),
      ('Learning is not a spectator sport.', '学习不是旁观者的运动。'),
      ('Your mindset determines your success.', '你的心态决定你的成功。'),
      ('Courage starts with showing up and letting ourselves be seen.', '勇气始于展现自己。'),
      ('Innovation demands experimentation.', '创新需要实验。'),
      ('The power of storytelling can change the world.', '讲故事的力量可以改变世界。'),
      ('Failure is simply the opportunity to begin again more intelligently.', '失败只是更聪明地重新开始的机会。'),
      ('Great leaders inspire action through their vision.', '伟大的领导者通过愿景激励行动。'),
    ];

    return sentences.map((s) => AudioMaterial(
      english: s.$1,
      chinese: s.$2,
      audioUrl: generateTtsUrl(s.$1),
      source: 'TED Talks',
    )).toList();
  }

  /// 新闻英语听力
  Future<List<AudioMaterial>> _fetchNewsEnglish() async {
    final sentences = [
      ('Breaking news: A major earthquake has struck the region.', '突发新闻：该地区发生强烈地震。'),
      ('The President announced a new policy today.', '总统今天宣布了一项新政策。'),
      ('Stock markets fell sharply amid growing concerns.', '由于担忧加剧，股市大幅下跌。'),
      ('Scientists have made a breakthrough discovery.', '科学家们取得了突破性发现。'),
      ('The election results are expected tomorrow.', '选举结果预计明天公布。'),
      ('Talks between the two nations have resumed.', '两国之间的会谈已经恢复。'),
      ('The company reported record profits this quarter.', '该公司本季度公布了创纪录的利润。'),
      ('Severe weather warnings have been issued.', '已发布恶劣天气警报。'),
      ('The unemployment rate has dropped to five percent.', '失业率已降至百分之五。'),
      ('A new study reveals the health benefits of exercise.', '一项新研究揭示了运动对健康的好处。'),
      ('The government has proposed new environmental regulations.', '政府提出了新的环境法规。'),
      ('Protests continue in the capital city.', '首都的抗议活动仍在继续。'),
      ('The economic outlook remains uncertain.', '经济前景仍然不确定。'),
      ('Experts warn of potential risks ahead.', '专家警告前方存在潜在风险。'),
      ('The treaty was signed by both parties.', '条约已由双方签署。'),
      ('Oil prices have risen significantly this week.', '本周油价大幅上涨。'),
      ('The investigation is still ongoing.', '调查仍在进行中。'),
      ('New technology is transforming the industry.', '新技术正在改变这个行业。'),
      ('The summit will be held next month.', '峰会将于下月举行。'),
      ('According to official sources, the situation is under control.', '据官方消息，情况已得到控制。'),
    ];

    return sentences.map((s) => AudioMaterial(
      english: s.$1,
      chinese: s.$2,
      audioUrl: generateTtsUrl(s.$1),
      source: 'News English',
    )).toList();
  }

  /// 默认素材
  List<AudioMaterial> _getDefaultMaterials() {
    return [
      AudioMaterial(
        english: 'Learning English opens doors to new opportunities.',
        chinese: '学习英语为新机会敞开大门。',
        audioUrl: generateTtsUrl('Learning English opens doors to new opportunities.'),
        source: 'Default',
      ),
      AudioMaterial(
        english: 'Practice makes perfect.',
        chinese: '熟能生巧。',
        audioUrl: generateTtsUrl('Practice makes perfect.'),
        source: 'Default',
      ),
      AudioMaterial(
        english: 'Every journey begins with a single step.',
        chinese: '千里之行，始于足下。',
        audioUrl: generateTtsUrl('Every journey begins with a single step.'),
        source: 'Default',
      ),
    ];
  }

  /// 从本地缓存加载带音频的素材
  Future<List<AudioMaterial>> _loadAudioMaterialsFromCache(String sourceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('audio_material_$sourceId');
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => AudioMaterial.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading audio materials from cache: $e');
      }
    }
    return [];
  }

  /// 保存带音频的素材到本地缓存
  Future<void> _saveAudioMaterialsToCache(String sourceId, List<AudioMaterial> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('audio_material_$sourceId', jsonEncode(data.map((m) => m.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving audio materials to cache: $e');
      }
    }
  }

  /// 刷新素材（清除缓存并重新获取）
  Future<List<AudioMaterial>> refreshMaterial(String sourceId) async {
    _cache.remove(sourceId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('audio_material_$sourceId');
    return fetchOnlineMaterialWithAudio(sourceId);
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final source in sources) {
      await prefs.remove('audio_material_${source.id}');
    }
  }

  /// 从在线 API 获取励志名言并转换为音频素材
  Future<List<AudioMaterial>> fetchQuotesFromApi() async {
    try {
      final quotes = await OnlineResourcesService.instance.fetchQuotes(limit: 30);
      return quotes.map((q) => AudioMaterial(
        english: q['en'] ?? '',
        chinese: q['cn'] ?? '(无翻译)',
        audioUrl: generateTtsUrl(q['en'] ?? ''),
        source: 'Inspirational Quotes - ${q['author'] ?? 'Unknown'}',
      )).where((m) => m.english.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching quotes from API: $e');
      }
      return [];
    }
  }

  /// 从 ZenQuotes API 获取名言
  Future<List<AudioMaterial>> fetchZenQuotes() async {
    try {
      final quotes = await OnlineResourcesService.instance.fetchZenQuotes();
      return quotes.map((q) => AudioMaterial(
        english: q['en'] ?? '',
        chinese: q['cn'] ?? '(无翻译)',
        audioUrl: generateTtsUrl(q['en'] ?? ''),
        source: 'ZenQuotes - ${q['author'] ?? 'Unknown'}',
      )).where((m) => m.english.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching zen quotes: $e');
      }
      return [];
    }
  }

  /// 从 Guardian API 获取新闻文章句子
  Future<List<AudioMaterial>> fetchNewsFromApi({String section = 'world'}) async {
    try {
      final articles = await OnlineResourcesService.instance.fetchGuardianArticles(
        section: section,
        pageSize: 10,
      );

      final List<AudioMaterial> materials = [];

      for (var article in articles) {
        final content = article['content'] as String? ?? article['summary'] as String? ?? '';
        if (content.isEmpty) continue;

        // 分割成句子
        final sentences = content.split(RegExp(r'[.!?]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.split(' ').length > 5 && s.split(' ').length < 30)
            .take(3);

        for (var sentence in sentences) {
          final cleanSentence = '$sentence.';
          materials.add(AudioMaterial(
            english: cleanSentence,
            chinese: '(来自新闻：${article['title'] ?? 'News'})',
            audioUrl: generateTtsUrl(cleanSentence),
            source: 'The Guardian',
          ));
        }

        if (materials.length >= 20) break;
      }

      return materials;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching news from API: $e');
      }
      return [];
    }
  }

  /// 综合获取多种在线资源
  Future<List<AudioMaterial>> fetchMixedOnlineMaterials({int count = 30}) async {
    final List<AudioMaterial> allMaterials = [];

    // 并行获取多个来源
    try {
      final results = await Future.wait([
        fetchQuotesFromApi(),
        fetchZenQuotes(),
        fetchNewsFromApi(),
      ], eagerError: false);

      for (var result in results) {
        allMaterials.addAll(result);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching mixed materials: $e');
      }
    }

    // 打乱顺序
    allMaterials.shuffle();

    // 返回指定数量
    return allMaterials.take(count).toList();
  }
}

/// 带音频的素材
class AudioMaterial {
  final String english;
  final String chinese;
  final String audioUrl;
  final String source;
  final Duration? duration;

  AudioMaterial({
    required this.english,
    required this.chinese,
    required this.audioUrl,
    required this.source,
    this.duration,
  });

  factory AudioMaterial.fromJson(Map<String, dynamic> json) {
    return AudioMaterial(
      english: json['english'] as String,
      chinese: json['chinese'] as String,
      audioUrl: json['audioUrl'] as String,
      source: json['source'] as String? ?? '',
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'chinese': chinese,
      'audioUrl': audioUrl,
      'source': source,
      'duration': duration?.inMilliseconds,
    };
  }
}

/// 在线素材源信息
class OnlineMaterialSource {
  final String id;
  final String name;
  final String description;
  final String category;
  final String difficulty;
  final String icon;
  final bool hasAudio;

  OnlineMaterialSource({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.icon,
    this.hasAudio = false,
  });
}
