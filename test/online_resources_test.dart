// 在线资源功能测试脚本
// 运行: dart test/online_resources_test.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== 在线资源功能测试 ===\n');

  // 测试 1: DummyJSON Quotes API
  await testDummyJsonQuotes();

  // 测试 2: ZenQuotes API
  await testZenQuotes();

  // 测试 3: RSS2JSON (BBC News) - 替代Guardian
  await testRSSNews();

  // 测试 4: Trivia API
  await testTriviaApi();

  // 测试 5: Free Dictionary API
  await testDictionaryApi();

  // 测试 6: Wikipedia Simple English API
  await testWikipediaApi();

  print('\n=== 测试完成 ===');
}

Future<void> testDummyJsonQuotes() async {
  print('📝 测试 DummyJSON Quotes API...');
  try {
    final response = await http.get(
      Uri.parse('https://dummyjson.com/quotes?limit=3'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final quotes = data['quotes'] as List;
      print('   ✅ 成功! 获取到 ${quotes.length} 条名言');
      if (quotes.isNotEmpty) {
        print('   示例: "${quotes[0]['quote']}"');
        print('   作者: ${quotes[0]['author']}');
      }
    } else {
      print('   ❌ 失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ 错误: $e');
  }
  print('');
}

Future<void> testZenQuotes() async {
  print('🧘 测试 ZenQuotes API...');
  try {
    final response = await http.get(
      Uri.parse('https://zenquotes.io/api/quotes'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> quotes = jsonDecode(response.body);
      print('   ✅ 成功! 获取到 ${quotes.length} 条名言');
      if (quotes.isNotEmpty) {
        print('   示例: "${quotes[0]['q']}"');
        print('   作者: ${quotes[0]['a']}');
      }
    } else {
      print('   ❌ 失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ 错误: $e');
  }
  print('');
}

Future<void> testRSSNews() async {
  print('📰 测试 RSS2JSON (BBC News)...');
  try {
    final rssUrl = 'https://feeds.bbci.co.uk/news/world/rss.xml';
    final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=$rssUrl&count=3';

    final response = await http.get(
      Uri.parse(apiUrl),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'ok') {
        final items = data['items'] as List? ?? [];
        print('   ✅ 成功! 获取到 ${items.length} 篇文章');
        if (items.isNotEmpty) {
          print('   标题: ${items[0]['title']}');
          print('   来源: ${data['feed']?['title'] ?? 'BBC News'}');
        }
      } else {
        print('   ❌ RSS解析失败: ${data['message']}');
      }
    } else {
      print('   ❌ 失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ 错误: $e');
  }
  print('');
}

Future<void> testTriviaApi() async {
  print('🎯 测试 Trivia API...');
  try {
    final response = await http.get(
      Uri.parse('https://the-trivia-api.com/v2/questions?limit=3'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> questions = jsonDecode(response.body);
      print('   ✅ 成功! 获取到 ${questions.length} 道题目');
      if (questions.isNotEmpty) {
        print('   问题: ${questions[0]['question']['text']}');
        print('   答案: ${questions[0]['correctAnswer']}');
      }
    } else {
      print('   ❌ 失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ 错误: $e');
  }
  print('');
}

Future<void> testDictionaryApi() async {
  print('📖 测试 Free Dictionary API...');
  try {
    final response = await http.get(
      Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/hello'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        final word = data[0]['word'];
        final meanings = data[0]['meanings'] as List? ?? [];
        print('   ✅ 成功! 查询单词: $word');
        if (meanings.isNotEmpty) {
          final defs = meanings[0]['definitions'] as List? ?? [];
          if (defs.isNotEmpty) {
            print('   释义: ${defs[0]['definition']}');
          }
        }
      }
    } else {
      print('   ❌ 失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ 错误: $e');
  }
  print('');
}

Future<void> testWikipediaApi() async {
  print('📚 测试 Wikipedia Simple English API...');
  try {
    final response = await http.get(
      Uri.parse('https://simple.wikipedia.org/api/rest_v1/page/random/summary'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('   ✅ 成功! 获取随机文章');
      print('   标题: ${data['title']}');
      final extract = data['extract'] as String? ?? '';
      if (extract.length > 100) {
        print('   摘要: ${extract.substring(0, 100)}...');
      } else {
        print('   摘要: $extract');
      }
    } else {
      print('   ❌ 失败: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ 错误: $e');
  }
  print('');
}
