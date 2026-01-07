import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 每日金句数据模型
class DailyQuote {
  final String english;
  final String chinese;
  final String? source;
  final DateTime date;

  DailyQuote({
    required this.english,
    required this.chinese,
    this.source,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'english': english,
    'chinese': chinese,
    'source': source,
    'date': date.toIso8601String(),
  };

  factory DailyQuote.fromJson(Map<String, dynamic> json) => DailyQuote(
    english: json['english'] ?? '',
    chinese: json['chinese'] ?? '',
    source: json['source'],
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
  );
}

/// 每日金句服务
class DailyQuoteService {
  static final DailyQuoteService instance = DailyQuoteService._();
  DailyQuoteService._();

  static const String _cacheKey = 'daily_quote_cache';
  DailyQuote? _cachedQuote;

  /// 获取今日金句
  Future<DailyQuote> getTodayQuote() async {
    // 检查缓存
    if (_cachedQuote != null && _isToday(_cachedQuote!.date)) {
      return _cachedQuote!;
    }

    // 尝试从本地存储加载
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final quote = DailyQuote.fromJson(jsonDecode(cached));
        if (_isToday(quote.date)) {
          _cachedQuote = quote;
          return quote;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to parse cached quote: $e');
        }
      }
    }

    // 从网络获取
    final quote = await _fetchFromNetwork();
    _cachedQuote = quote;
    
    // 保存到本地
    await prefs.setString(_cacheKey, jsonEncode(quote.toJson()));
    
    return quote;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// 从网络获取金句
  Future<DailyQuote> _fetchFromNetwork() async {
    // 尝试多个 API 源
    final apis = [
      _fetchFromIciba,
      _fetchFromYoudao,
      _fetchFallback,
    ];

    for (final api in apis) {
      try {
        final quote = await api();
        if (quote != null) return quote;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Quote API failed: $e');
        }
      }
    }

    return _getDefaultQuote();
  }

  /// 金山词霸每日一句
  Future<DailyQuote?> _fetchFromIciba() async {
    try {
      final response = await http.get(
        Uri.parse('https://open.iciba.com/dsapi/'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DailyQuote(
          english: data['content'] ?? '',
          chinese: data['note'] ?? '',
          source: 'iciba',
          date: DateTime.now(),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Iciba API error: $e');
      }
    }
    return null;
  }

  /// 有道每日一句（备用）
  Future<DailyQuote?> _fetchFromYoudao() async {
    try {
      final response = await http.get(
        Uri.parse('https://dict.youdao.com/infoline?mode=publish&date=${_getDateString()}&update=auto&apiversion=5.0'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final item = data[0];
          return DailyQuote(
            english: item['title'] ?? '',
            chinese: item['summary'] ?? '',
            source: 'youdao',
            date: DateTime.now(),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Youdao API error: $e');
      }
    }
    return null;
  }

  /// 静态金句库（离线备用）
  Future<DailyQuote?> _fetchFallback() async {
    final quotes = [
      {'en': 'The only way to do great work is to love what you do.', 'cn': '做出伟大工作的唯一方法是热爱你所做的事。'},
      {'en': 'Success is not final, failure is not fatal: it is the courage to continue that counts.', 'cn': '成功不是终点，失败不是致命的：重要的是继续前进的勇气。'},
      {'en': 'The future belongs to those who believe in the beauty of their dreams.', 'cn': '未来属于那些相信梦想之美的人。'},
      {'en': 'In the middle of difficulty lies opportunity.', 'cn': '困难之中蕴含着机遇。'},
      {'en': 'The best time to plant a tree was 20 years ago. The second best time is now.', 'cn': '种一棵树最好的时间是20年前，其次是现在。'},
      {'en': 'What we think, we become.', 'cn': '我们的思想决定了我们会成为什么样的人。'},
      {'en': 'Life is what happens when you\'re busy making other plans.', 'cn': '当你忙着制定其他计划时，生活就在发生。'},
    ];
    
    final index = DateTime.now().day % quotes.length;
    final q = quotes[index];
    
    return DailyQuote(
      english: q['en']!,
      chinese: q['cn']!,
      source: 'local',
      date: DateTime.now(),
    );
  }

  DailyQuote _getDefaultQuote() {
    return DailyQuote(
      english: 'Every day is a new beginning.',
      chinese: '每一天都是新的开始。',
      date: DateTime.now(),
    );
  }

  String _getDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
