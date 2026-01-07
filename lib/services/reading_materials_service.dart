import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'online_resources_service.dart';

/// 阅读素材服务
class ReadingMaterialsService {
  static final ReadingMaterialsService instance = ReadingMaterialsService._();
  ReadingMaterialsService._();

  static const String _keyCustomArticles = 'custom_reading_articles';
  static const String _keyMarkedWords = 'reading_marked_words';
  static const String _keyOnlineArticles = 'online_reading_articles';

  List<ReadingArticle> _customArticles = [];
  List<ReadingArticle> _onlineArticles = []; // 在线获取的文章
  Map<String, Set<String>> _markedWords = {}; // articleId -> set of marked words
  bool _initialized = false;

  List<ReadingArticle> get customArticles => _customArticles;
  List<ReadingArticle> get onlineArticles => _onlineArticles;

  /// 预置文章列表
  static final List<ReadingArticle> builtInArticles = [
    ReadingArticle(
      id: 'tech_ai_future',
      title: 'The Future of Artificial Intelligence',
      category: '科技',
      difficulty: '中级',
      content: '''Artificial intelligence is rapidly transforming our world. From virtual assistants on our smartphones to self-driving cars on our roads, AI is becoming an integral part of daily life.

Machine learning, a subset of AI, allows computers to learn from experience without being explicitly programmed. This technology powers recommendation systems on streaming platforms, fraud detection in banking, and even medical diagnosis tools.

However, the rise of AI also brings challenges. Concerns about job displacement, privacy, and the ethical use of AI are growing. Experts emphasize the need for responsible development and regulation.

Looking ahead, AI promises to revolutionize healthcare, education, and environmental protection. The key lies in balancing innovation with ethical considerations to ensure AI benefits humanity as a whole.''',
      wordCount: 120,
      readingTime: 3,
    ),
    ReadingArticle(
      id: 'travel_japan',
      title: 'Exploring the Beauty of Japan',
      category: '旅行',
      difficulty: '初级',
      content: '''Japan is a country of fascinating contrasts. Ancient temples stand alongside modern skyscrapers, and traditional tea ceremonies coexist with cutting-edge technology.

Tokyo, the bustling capital, offers endless shopping, dining, and entertainment options. The famous Shibuya Crossing sees thousands of people cross at once, creating a mesmerizing spectacle.

For a more peaceful experience, Kyoto preserves Japan's traditional culture. The city is home to over 2,000 temples and shrines, including the iconic golden pavilion Kinkaku-ji.

Japanese cuisine is another highlight. From sushi and ramen to tempura and wagyu beef, the country offers a rich culinary journey. Many visitors also enjoy the unique experience of staying in a traditional ryokan inn.

Cherry blossom season in spring and colorful autumn leaves make Japan a year-round destination for travelers seeking both natural beauty and cultural immersion.''',
      wordCount: 150,
      readingTime: 4,
    ),
    ReadingArticle(
      id: 'science_climate',
      title: 'Understanding Climate Change',
      category: '科学',
      difficulty: '中级',
      content: '''Climate change is one of the most pressing issues of our time. The Earth's average temperature has risen by about 1.1 degrees Celsius since the pre-industrial era, primarily due to human activities.

The burning of fossil fuels releases greenhouse gases, particularly carbon dioxide, into the atmosphere. These gases trap heat, causing global temperatures to rise. This phenomenon is known as the greenhouse effect.

The consequences are already visible: melting ice caps, rising sea levels, more frequent extreme weather events, and shifting ecosystems. Scientists warn that without significant action, these effects will intensify.

Solutions exist at multiple levels. Governments can implement carbon pricing and invest in renewable energy. Businesses can adopt sustainable practices. Individuals can reduce their carbon footprint through choices in transportation, diet, and consumption.

The transition to a sustainable future requires global cooperation and immediate action. Every effort, no matter how small, contributes to addressing this global challenge.''',
      wordCount: 160,
      readingTime: 5,
    ),
    ReadingArticle(
      id: 'culture_coffee',
      title: 'The Global Culture of Coffee',
      category: '文化',
      difficulty: '初级',
      content: '''Coffee is more than just a beverage; it's a global phenomenon that connects people across cultures. From Ethiopian coffee ceremonies to Italian espresso bars, coffee traditions vary around the world.

The coffee plant originated in Ethiopia, where legend says a goat herder discovered its energizing effects. Today, Brazil, Vietnam, and Colombia are the world's largest coffee producers.

In Italy, coffee culture centers around the espresso bar. Locals stand at the counter, quickly enjoying their shot of espresso before continuing their day. In contrast, Scandinavian countries have embraced "fika" – a coffee break that emphasizes relaxation and connection.

The specialty coffee movement has transformed how we appreciate this drink. Third-wave coffee shops focus on bean origin, roasting techniques, and brewing methods, treating coffee as an artisanal product.

Whether you prefer a strong Turkish coffee or a creamy Vietnamese ca phe sua da, coffee offers a window into diverse cultures and traditions.''',
      wordCount: 155,
      readingTime: 4,
    ),
    ReadingArticle(
      id: 'health_sleep',
      title: 'The Science of Better Sleep',
      category: '健康',
      difficulty: '中级',
      content: '''Sleep is essential for physical and mental health, yet millions of people struggle with sleep problems. Understanding the science of sleep can help improve both quality and quantity of rest.

Our bodies follow a circadian rhythm, an internal clock that regulates sleepiness and alertness over a 24-hour period. This rhythm is influenced by light exposure, making morning sunlight and evening darkness important for healthy sleep patterns.

Sleep occurs in cycles, alternating between REM (rapid eye movement) and non-REM stages. Each stage serves different functions: non-REM sleep supports physical recovery, while REM sleep is crucial for memory consolidation and emotional processing.

Common sleep disruptors include caffeine, alcohol, screen time before bed, and irregular schedules. Creating a consistent sleep routine, keeping the bedroom cool and dark, and limiting stimulants can significantly improve sleep quality.

Adults typically need 7-9 hours of sleep per night. Chronic sleep deprivation is linked to obesity, heart disease, depression, and weakened immunity. Prioritizing sleep is an investment in overall health.''',
      wordCount: 175,
      readingTime: 5,
    ),
    ReadingArticle(
      id: 'business_remote',
      title: 'The Rise of Remote Work',
      category: '商业',
      difficulty: '中级',
      content: '''Remote work has transformed from a rare perk to a mainstream practice. The global pandemic accelerated this shift, proving that many jobs can be performed effectively from home.

Companies have discovered benefits including reduced office costs, access to global talent, and often increased productivity. Employees appreciate the flexibility, eliminated commute time, and improved work-life balance.

However, remote work presents challenges. Communication can be more difficult without face-to-face interaction. Some workers struggle with isolation and the blurring of work-home boundaries. Managers must adapt their leadership styles to virtual environments.

Hybrid models are emerging as a popular solution, combining remote flexibility with in-person collaboration. Many organizations now offer employees choices about where and when they work.

Technology plays a crucial role in enabling remote work. Video conferencing, project management tools, and cloud computing have made virtual collaboration seamless. As technology continues to evolve, remote work capabilities will only expand.

The future of work is likely to be more flexible than ever before. Organizations that embrace this change will have advantages in attracting and retaining talent.''',
      wordCount: 180,
      readingTime: 5,
    ),
  ];

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 加载自定义文章
    final articlesJson = prefs.getString(_keyCustomArticles);
    if (articlesJson != null) {
      final list = jsonDecode(articlesJson) as List;
      _customArticles = list.map((e) => ReadingArticle.fromJson(e)).toList();
    }

    // 加载标记的生词
    final markedJson = prefs.getString(_keyMarkedWords);
    if (markedJson != null) {
      final map = jsonDecode(markedJson) as Map<String, dynamic>;
      _markedWords = map.map((key, value) =>
        MapEntry(key, Set<String>.from(value as List)));
    }

    _initialized = true;
  }

  /// 获取所有文章（预置 + 自定义 + 在线）
  List<ReadingArticle> getAllArticles({bool includeOnline = true}) {
    if (includeOnline) {
      return [...builtInArticles, ..._customArticles, ..._onlineArticles];
    }
    return [...builtInArticles, ..._customArticles];
  }

  /// 从 Guardian API 获取在线文章
  Future<List<ReadingArticle>> fetchOnlineArticles({
    String section = 'world',
    int count = 10,
  }) async {
    try {
      final articles = await OnlineResourcesService.instance.fetchGuardianArticles(
        section: section,
        pageSize: count,
      );

      if (articles.isNotEmpty) {
        final readingArticles = articles.map((a) {
          final content = a['content'] as String? ?? a['summary'] as String? ?? '';
          final wordCount = content.split(RegExp(r'\s+')).length;

          return ReadingArticle(
            id: 'online_${a['id'] ?? DateTime.now().millisecondsSinceEpoch}',
            title: a['title'] as String? ?? 'Untitled',
            category: _mapCategory(a['category'] as String? ?? section),
            difficulty: _estimateDifficulty(wordCount),
            content: content,
            wordCount: wordCount,
            readingTime: (wordCount / 200).ceil(),
            isCustom: false,
            createdAt: DateTime.now(),
          );
        }).toList();

        _onlineArticles = readingArticles;
        await _saveOnlineArticles();
        return readingArticles;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching online articles: $e');
      }
    }

    // 尝试从缓存加载
    return _loadOnlineArticles();
  }

  /// 从 Wikipedia 获取简单英语文章
  Future<List<ReadingArticle>> fetchWikipediaArticles({int count = 5}) async {
    final List<ReadingArticle> articles = [];

    try {
      for (int i = 0; i < count; i++) {
        final wikiArticles = await OnlineResourcesService.instance.fetchWikipediaArticles();

        for (var a in wikiArticles) {
          final content = a['content'] as String? ?? a['summary'] as String? ?? '';
          final wordCount = content.split(RegExp(r'\s+')).length;

          articles.add(ReadingArticle(
            id: 'wiki_${a['id'] ?? DateTime.now().millisecondsSinceEpoch}_$i',
            title: a['title'] as String? ?? 'Wikipedia Article',
            category: '百科',
            difficulty: _estimateDifficulty(wordCount),
            content: content,
            wordCount: wordCount,
            readingTime: (wordCount / 200).ceil(),
            isCustom: false,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (articles.isNotEmpty) {
        _onlineArticles.addAll(articles);
        await _saveOnlineArticles();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching Wikipedia articles: $e');
      }
    }

    return articles;
  }

  /// 获取混合文章（本地 + 在线）
  Future<List<ReadingArticle>> getMixedArticles({
    int count = 20,
    String? category,
    bool includeOnline = true,
  }) async {
    List<ReadingArticle> pool = [];

    // 添加本地文章
    if (category != null) {
      pool.addAll(builtInArticles.where((a) => a.category == category));
      pool.addAll(_customArticles.where((a) => a.category == category));
    } else {
      pool.addAll(builtInArticles);
      pool.addAll(_customArticles);
    }

    // 添加在线文章
    if (includeOnline) {
      if (_onlineArticles.isEmpty) {
        _onlineArticles = await _loadOnlineArticles();
      }
      if (_onlineArticles.isEmpty) {
        await fetchOnlineArticles(count: 10);
      }

      if (category != null) {
        pool.addAll(_onlineArticles.where((a) => a.category == category));
      } else {
        pool.addAll(_onlineArticles);
      }
    }

    // 按创建时间排序，最新的在前
    pool.sort((a, b) {
      final aTime = a.createdAt ?? DateTime(2000);
      final bTime = b.createdAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return pool.take(count).toList();
  }

  /// 刷新在线文章
  Future<void> refreshOnlineArticles() async {
    await OnlineResourcesService.instance.refreshResource('guardian_world');
    _onlineArticles.clear();
    await fetchOnlineArticles(count: 10);
  }

  /// 映射分类名称
  String _mapCategory(String category) {
    final mapping = {
      'world': '世界',
      'science': '科学',
      'technology': '科技',
      'culture': '文化',
      'business': '商业',
      'sport': '体育',
      'environment': '环境',
      'education': '教育',
    };
    return mapping[category.toLowerCase()] ?? category;
  }

  /// 根据词数估算难度
  String _estimateDifficulty(int wordCount) {
    if (wordCount < 150) return '初级';
    if (wordCount < 300) return '中级';
    return '高级';
  }

  /// 保存在线文章到缓存
  Future<void> _saveOnlineArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_onlineArticles.map((a) => a.toJson()).toList());
      await prefs.setString(_keyOnlineArticles, json);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving online articles: $e');
      }
    }
  }

  /// 从缓存加载在线文章
  Future<List<ReadingArticle>> _loadOnlineArticles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyOnlineArticles);
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        return list.map((e) => ReadingArticle.fromJson(e)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading online articles: $e');
      }
    }
    return [];
  }

  /// 按分类获取文章
  List<ReadingArticle> getArticlesByCategory(String category) {
    return getAllArticles().where((a) => a.category == category).toList();
  }

  /// 获取所有分类
  List<String> getCategories() {
    final categories = getAllArticles().map((a) => a.category).toSet().toList();
    categories.sort();
    return categories;
  }

  /// 添加自定义文章
  Future<ReadingArticle> addArticle({
    required String title,
    required String content,
    String category = '自定义',
    String difficulty = '中级',
  }) async {
    final wordCount = content.split(RegExp(r'\s+')).length;
    final readingTime = (wordCount / 200).ceil(); // 约200词/分钟

    final article = ReadingArticle(
      id: const Uuid().v4(),
      title: title,
      category: category,
      difficulty: difficulty,
      content: content,
      wordCount: wordCount,
      readingTime: readingTime,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    _customArticles.insert(0, article);
    await _saveCustomArticles();
    return article;
  }

  /// 删除自定义文章
  Future<void> deleteArticle(String articleId) async {
    _customArticles.removeWhere((a) => a.id == articleId);
    _markedWords.remove(articleId);
    await _saveCustomArticles();
    await _saveMarkedWords();
  }

  /// 标记生词
  Future<void> markWord(String articleId, String word) async {
    _markedWords.putIfAbsent(articleId, () => {});
    _markedWords[articleId]!.add(word.toLowerCase());
    await _saveMarkedWords();
  }

  /// 取消标记生词
  Future<void> unmarkWord(String articleId, String word) async {
    _markedWords[articleId]?.remove(word.toLowerCase());
    await _saveMarkedWords();
  }

  /// 检查单词是否已标记
  bool isWordMarked(String articleId, String word) {
    return _markedWords[articleId]?.contains(word.toLowerCase()) ?? false;
  }

  /// 获取文章中标记的生词列表
  List<String> getMarkedWords(String articleId) {
    return _markedWords[articleId]?.toList() ?? [];
  }

  /// 获取所有标记的生词（去重）
  Set<String> getAllMarkedWords() {
    final all = <String>{};
    for (var words in _markedWords.values) {
      all.addAll(words);
    }
    return all;
  }

  Future<void> _saveCustomArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_customArticles.map((a) => a.toJson()).toList());
    await prefs.setString(_keyCustomArticles, json);
  }

  Future<void> _saveMarkedWords() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _markedWords.map((key, value) => MapEntry(key, value.toList()));
    await prefs.setString(_keyMarkedWords, jsonEncode(map));
  }
}

/// 阅读文章
class ReadingArticle {
  final String id;
  final String title;
  final String category;
  final String difficulty;
  final String content;
  final int wordCount;
  final int readingTime; // 分钟
  final bool isCustom;
  final DateTime? createdAt;

  ReadingArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.content,
    required this.wordCount,
    required this.readingTime,
    this.isCustom = false,
    this.createdAt,
  });

  /// 获取文章段落
  List<String> get paragraphs {
    return content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'difficulty': difficulty,
    'content': content,
    'wordCount': wordCount,
    'readingTime': readingTime,
    'isCustom': isCustom,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory ReadingArticle.fromJson(Map<String, dynamic> json) {
    return ReadingArticle(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '自定义',
      difficulty: json['difficulty'] ?? '中级',
      content: json['content'] ?? '',
      wordCount: json['wordCount'] ?? 0,
      readingTime: json['readingTime'] ?? 1,
      isCustom: json['isCustom'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}
