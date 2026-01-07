import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 在线资源服务 - 从公开API获取语法题、阅读文章、励志名言等
class OnlineResourcesService {
  static final OnlineResourcesService instance = OnlineResourcesService._();
  OnlineResourcesService._();

  // 缓存
  final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(hours: 6);

  // ==================== 励志名言API ====================

  /// 从 DummyJSON 获取励志名言
  Future<List<Map<String, String>>> fetchQuotes({int limit = 30}) async {
    const cacheKey = 'quotes_dummyjson';

    // 检查缓存
    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      return List<Map<String, String>>.from(
        (cached as List).map((e) => Map<String, String>.from(e)),
      );
    }

    try {
      final response = await http
          .get(Uri.parse('https://dummyjson.com/quotes?limit=$limit'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quotes = (data['quotes'] as List).map((q) {
          return {
            'en': q['quote'] as String,
            'cn': '', // 需要翻译
            'author': q['author'] as String? ?? '',
          };
        }).toList();

        // 缓存结果
        await _saveToCache(cacheKey, quotes);
        return quotes;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching quotes from DummyJSON: $e');
      }
    }

    // 返回默认数据
    return _getDefaultQuotes();
  }

  /// 从 ZenQuotes 获取名言 (每日更新)
  Future<List<Map<String, String>>> fetchZenQuotes() async {
    const cacheKey = 'quotes_zenquotes';

    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      return List<Map<String, String>>.from(
        (cached as List).map((e) => Map<String, String>.from(e)),
      );
    }

    try {
      final response = await http
          .get(Uri.parse('https://zenquotes.io/api/quotes'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final quotes = data.map((q) {
          return {
            'en': q['q'] as String? ?? '',
            'cn': '',
            'author': q['a'] as String? ?? '',
          };
        }).toList();

        await _saveToCache(cacheKey, quotes);
        return quotes;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching from ZenQuotes: $e');
      }
    }

    return _getDefaultQuotes();
  }

  // ==================== 新闻/阅读文章API ====================

  /// 获取新闻文章 - 自动选择可用的API源
  Future<List<Map<String, dynamic>>> fetchNewsArticles({
    String category = 'world',
    int pageSize = 10,
  }) async {
    final cacheKey = 'news_$category';

    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached as List);
    }

    // 按优先级尝试多个新闻源
    List<Map<String, dynamic>> articles = [];

    // 1. 首先尝试 NewsData.io (免费API，每天200请求)
    articles = await _fetchFromNewsDataIO(category, pageSize);
    if (articles.isNotEmpty) {
      await _saveToCache(cacheKey, articles);
      return articles;
    }

    // 2. 尝试 GNews API
    articles = await _fetchFromGNews(category, pageSize);
    if (articles.isNotEmpty) {
      await _saveToCache(cacheKey, articles);
      return articles;
    }

    // 3. 尝试 Guardian API (可能限流)
    articles = await _fetchFromGuardian(category, pageSize);
    if (articles.isNotEmpty) {
      await _saveToCache(cacheKey, articles);
      return articles;
    }

    // 4. 使用RSS备用方案
    articles = await _fetchFromRSS(category, pageSize);
    if (articles.isNotEmpty) {
      await _saveToCache(cacheKey, articles);
      return articles;
    }

    return _getDefaultArticles();
  }

  /// NewsData.io API (免费tier: 200请求/天)
  Future<List<Map<String, dynamic>>> _fetchFromNewsDataIO(String category, int pageSize) async {
    try {
      // 公开演示API (生产环境应使用自己的API key)
      final categoryMap = {
        'world': 'world',
        'science': 'science',
        'technology': 'technology',
        'business': 'business',
        'entertainment': 'entertainment',
        'sports': 'sports',
      };
      final apiCategory = categoryMap[category] ?? 'world';

      final response = await http.get(
        Uri.parse('https://newsdata.io/api/1/news?country=us&language=en&category=$apiCategory&apikey=pub_61aborpub'),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];

        return results.take(pageSize).map((article) {
          final content = article['content'] as String? ?? article['description'] as String? ?? '';
          return {
            'id': article['article_id'] ?? '',
            'title': article['title'] as String? ?? '',
            'summary': article['description'] as String? ?? '',
            'content': _cleanHtml(content),
            'category': article['category']?.first ?? category,
            'wordCount': _estimateWordCount(content),
            'url': article['link'] as String? ?? '',
            'source': article['source_id'] ?? 'NewsData',
          };
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NewsData.io error: $e');
      }
    }
    return [];
  }

  /// GNews API (免费tier: 100请求/天)
  Future<List<Map<String, dynamic>>> _fetchFromGNews(String category, int pageSize) async {
    try {
      final categoryMap = {
        'world': 'world',
        'science': 'science',
        'technology': 'technology',
        'business': 'business',
        'entertainment': 'entertainment',
        'sports': 'sports',
      };
      final apiCategory = categoryMap[category] ?? 'general';

      final response = await http.get(
        Uri.parse('https://gnews.io/api/v4/top-headlines?category=$apiCategory&lang=en&max=$pageSize&apikey=demo'),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final articles = data['articles'] as List? ?? [];

        return articles.map((article) {
          final content = article['content'] as String? ?? article['description'] as String? ?? '';
          return {
            'id': article['url']?.hashCode.toString() ?? '',
            'title': article['title'] as String? ?? '',
            'summary': article['description'] as String? ?? '',
            'content': _cleanHtml(content),
            'category': category,
            'wordCount': _estimateWordCount(content),
            'url': article['url'] as String? ?? '',
            'source': article['source']?['name'] ?? 'GNews',
          };
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GNews error: $e');
      }
    }
    return [];
  }

  /// Guardian API (test key 有限流)
  Future<List<Map<String, dynamic>>> _fetchFromGuardian(String category, int pageSize) async {
    try {
      final url = 'https://content.guardianapis.com/search'
          '?section=$category'
          '&show-fields=headline,trailText,body,wordcount'
          '&page-size=$pageSize'
          '&api-key=test';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['response']['results'] as List? ?? [];

        return results.map((article) {
          final fields = article['fields'] as Map<String, dynamic>? ?? {};
          String body = fields['body'] as String? ?? '';
          body = _cleanHtml(body);

          return {
            'id': article['id'] as String? ?? '',
            'title': fields['headline'] as String? ?? article['webTitle'] as String? ?? '',
            'summary': fields['trailText'] as String? ?? '',
            'content': body,
            'category': article['sectionName'] as String? ?? category,
            'wordCount': fields['wordcount'] ?? _estimateWordCount(body),
            'url': article['webUrl'] as String? ?? '',
            'source': 'The Guardian',
          };
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Guardian error: $e');
      }
    }
    return [];
  }

  /// RSS 备用方案 - 使用 rss2json 服务
  Future<List<Map<String, dynamic>>> _fetchFromRSS(String category, int pageSize) async {
    try {
      // 使用HTTPS版本的BBC RSS
      final rssUrls = {
        'world': 'https://feeds.bbci.co.uk/news/world/rss.xml',
        'science': 'https://feeds.bbci.co.uk/news/science_and_environment/rss.xml',
        'technology': 'https://feeds.bbci.co.uk/news/technology/rss.xml',
        'business': 'https://feeds.bbci.co.uk/news/business/rss.xml',
      };
      final rssUrl = rssUrls[category] ?? rssUrls['world']!;

      // 使用 rss2json.com 转换RSS为JSON (免费tier: 10000请求/天)
      final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=$rssUrl&count=$pageSize';

      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          final items = data['items'] as List? ?? [];

          return items.map((item) {
            final content = item['content'] as String? ?? item['description'] as String? ?? '';
            final cleanContent = _cleanHtml(content);
            return {
              'id': item['guid'] ?? item['link']?.hashCode.toString() ?? '',
              'title': item['title'] as String? ?? '',
              'summary': _cleanHtml(item['description'] as String? ?? ''),
              'content': cleanContent,
              'category': category,
              'wordCount': _estimateWordCount(cleanContent),
              'url': item['link'] as String? ?? '',
              'source': data['feed']?['title'] ?? 'BBC News',
            };
          }).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RSS error: $e');
      }
    }
    return [];
  }

  /// 清理HTML标签
  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 兼容旧接口 - 从 Guardian API 获取新闻文章
  Future<List<Map<String, dynamic>>> fetchGuardianArticles({
    String section = 'world',
    int pageSize = 10,
  }) async {
    // 使用新的多源获取方法
    return fetchNewsArticles(category: section, pageSize: pageSize);
  }

  /// 从 Wikipedia API 获取简单英语文章
  Future<List<Map<String, dynamic>>> fetchWikipediaArticles({
    int count = 5,
  }) async {
    const cacheKey = 'wikipedia_simple';

    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached as List);
    }

    try {
      // 使用简单英语维基百科 - 适合英语学习者
      final response = await http
          .get(Uri.parse(
              'https://simple.wikipedia.org/api/rest_v1/page/random/summary'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final articles = <Map<String, dynamic>>[];

        articles.add({
          'id': data['pageid']?.toString() ?? '',
          'title': data['title'] as String? ?? '',
          'summary': data['extract'] as String? ?? '',
          'content': data['extract'] as String? ?? '',
          'category': '百科',
          'wordCount': _estimateWordCount(data['extract'] as String? ?? ''),
          'source': 'Simple Wikipedia',
        });

        await _saveToCache(cacheKey, articles);
        return articles;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching from Wikipedia: $e');
      }
    }

    return [];
  }

  // ==================== Trivia/问答API ====================

  /// 从 The Trivia API 获取问答题
  Future<List<Map<String, dynamic>>> fetchTriviaQuestions({
    String category = 'general_knowledge',
    String difficulty = 'medium',
    int limit = 10,
  }) async {
    final cacheKey = 'trivia_${category}_$difficulty';

    final cached = await _loadFromCache(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached as List);
    }

    try {
      final url =
          'https://the-trivia-api.com/v2/questions?limit=$limit&difficulties=$difficulty';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final questions = data.map((q) {
          final incorrectAnswers = List<String>.from(q['incorrectAnswers']);
          final correctAnswer = q['correctAnswer'] as String;
          final allAnswers = [...incorrectAnswers, correctAnswer]..shuffle();

          return {
            'question': q['question']['text'] as String? ?? '',
            'options': allAnswers,
            'correctIndex': allAnswers.indexOf(correctAnswer),
            'category': q['category'] as String? ?? '',
            'difficulty': q['difficulty'] as String? ?? '',
          };
        }).toList();

        await _saveToCache(cacheKey, questions);
        return questions;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching from Trivia API: $e');
      }
    }

    return [];
  }

  // ==================== 综合英语学习API ====================

  /// 从 Free Dictionary API 获取单词定义
  Future<Map<String, dynamic>?> fetchWordDefinition(String word) async {
    try {
      final response = await http
          .get(Uri.parse(
              'https://api.dictionaryapi.dev/api/v2/entries/en/$word'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final entry = data[0];
          final meanings = entry['meanings'] as List? ?? [];

          List<String> definitions = [];
          String? phonetic;

          // 获取音标
          final phonetics = entry['phonetics'] as List? ?? [];
          for (var p in phonetics) {
            if (p['text'] != null && (p['text'] as String).isNotEmpty) {
              phonetic = p['text'];
              break;
            }
          }

          // 获取定义
          for (var meaning in meanings) {
            final defs = meaning['definitions'] as List? ?? [];
            for (var def in defs) {
              definitions.add(def['definition'] as String? ?? '');
              if (definitions.length >= 3) break;
            }
            if (definitions.length >= 3) break;
          }

          return {
            'word': entry['word'] as String? ?? word,
            'phonetic': phonetic ?? '',
            'definitions': definitions,
            'partOfSpeech':
                meanings.isNotEmpty ? meanings[0]['partOfSpeech'] : '',
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching word definition: $e');
      }
    }
    return null;
  }

  /// 从 Datamuse API 获取相关单词 (同义词、押韵词等)
  Future<List<String>> fetchRelatedWords(String word,
      {String relation = 'ml'}) async {
    // relation types: ml=meaning like, sl=sounds like, sp=spelled like, rel_syn=synonyms
    try {
      final response = await http
          .get(Uri.parse('https://api.datamuse.com/words?$relation=$word&max=10'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((w) => w['word'] as String).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching related words: $e');
      }
    }
    return [];
  }

  // ==================== 缓存管理 ====================

  Future<void> _saveToCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('online_cache_$key', jsonEncode(cacheData));
      _cache[key] = data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving to cache: $e');
      }
    }
  }

  Future<dynamic> _loadFromCache(String key) async {
    // 先检查内存缓存
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('online_cache_$key');
      if (json != null) {
        final cacheData = jsonDecode(json);
        final timestamp = cacheData['timestamp'] as int;
        final age = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(timestamp));

        if (age < _cacheExpiry) {
          _cache[key] = cacheData['data'];
          return cacheData['data'];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading from cache: $e');
      }
    }
    return null;
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('online_cache_'));
    for (var key in keys) {
      await prefs.remove(key);
    }
  }

  /// 刷新特定资源
  Future<void> refreshResource(String cacheKey) async {
    _cache.remove(cacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('online_cache_$cacheKey');
  }

  // ==================== 辅助方法 ====================

  int _estimateWordCount(String text) {
    return text.split(RegExp(r'\s+')).length;
  }

  List<Map<String, String>> _getDefaultQuotes() {
    return [
      {
        'en': 'The only way to do great work is to love what you do.',
        'cn': '做出伟大工作的唯一方法就是热爱你所做的事。',
        'author': 'Steve Jobs'
      },
      {
        'en': 'Success is not final, failure is not fatal.',
        'cn': '成功不是终点，失败也不是致命的。',
        'author': 'Winston Churchill'
      },
      {
        'en': 'The best time to plant a tree was 20 years ago. The second best time is now.',
        'cn': '种树最好的时间是20年前，其次是现在。',
        'author': 'Chinese Proverb'
      },
      {
        'en': 'Believe you can and you\'re halfway there.',
        'cn': '相信你能做到，你就成功了一半。',
        'author': 'Theodore Roosevelt'
      },
      {
        'en': 'The future belongs to those who believe in the beauty of their dreams.',
        'cn': '未来属于那些相信梦想之美的人。',
        'author': 'Eleanor Roosevelt'
      },
    ];
  }

  List<Map<String, dynamic>> _getDefaultArticles() {
    return [
      {
        'id': 'default_1',
        'title': 'The Benefits of Learning a New Language',
        'summary': 'Learning a new language offers numerous cognitive and social benefits.',
        'content':
            'Learning a new language is one of the most rewarding experiences you can have. It not only opens doors to new cultures and opportunities but also provides significant cognitive benefits. Studies have shown that bilingual individuals often have better memory, improved problem-solving skills, and enhanced creativity. Moreover, learning a new language can delay the onset of dementia and keep your brain sharp as you age. Whether you are learning for travel, work, or personal enrichment, the journey of language learning is always worthwhile.',
        'category': 'Education',
        'wordCount': 89,
        'source': 'Default',
      },
    ];
  }
}

/// 在线资源提供者 - 用于UI中选择不同的在线资源
class OnlineResourceProvider {
  static final List<OnlineResourceInfo> grammarResources = [
    OnlineResourceInfo(
      id: 'trivia_english',
      name: 'Trivia 英语问答',
      description: '来自 The Trivia API 的英语相关问答题',
      icon: '🎯',
    ),
  ];

  static final List<OnlineResourceInfo> readingResources = [
    OnlineResourceInfo(
      id: 'guardian_world',
      name: 'Guardian 世界新闻',
      description: '来自卫报的世界新闻文章',
      icon: '🌍',
    ),
    OnlineResourceInfo(
      id: 'guardian_science',
      name: 'Guardian 科学',
      description: '来自卫报的科学类文章',
      icon: '🔬',
    ),
    OnlineResourceInfo(
      id: 'guardian_technology',
      name: 'Guardian 科技',
      description: '来自卫报的科技类文章',
      icon: '💻',
    ),
    OnlineResourceInfo(
      id: 'guardian_culture',
      name: 'Guardian 文化',
      description: '来自卫报的文化类文章',
      icon: '🎭',
    ),
    OnlineResourceInfo(
      id: 'wikipedia_simple',
      name: 'Simple Wikipedia',
      description: '简单英语维基百科文章，适合学习者',
      icon: '📚',
    ),
  ];

  static final List<OnlineResourceInfo> quoteResources = [
    OnlineResourceInfo(
      id: 'dummyjson_quotes',
      name: '励志名言',
      description: '来自 DummyJSON 的励志名言',
      icon: '💡',
    ),
    OnlineResourceInfo(
      id: 'zenquotes',
      name: 'Zen Quotes',
      description: '来自 ZenQuotes 的每日名言',
      icon: '🧘',
    ),
  ];
}

class OnlineResourceInfo {
  final String id;
  final String name;
  final String description;
  final String icon;

  OnlineResourceInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}
