import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Translation service using multiple APIs for better results
class TranslationService {
  static TranslationService? _instance;

  static TranslationService get instance {
    _instance ??= TranslationService._();
    return _instance!;
  }

  TranslationService._();

  /// Query word definition - tries multiple sources for best results
  Future<WordDefinition?> lookupWord(String word) async {
    if (word.trim().isEmpty) return null;

    final cleanWord = word.trim().toLowerCase();

    // Try Youdao first (best for Chinese translation)
    WordDefinition? result = await _lookupYoudao(cleanWord);

    // If Youdao failed or no Chinese translation, try iCiba
    if (result == null || (result.translation.isEmpty && result.definitions.isEmpty)) {
      final icibaResult = await _lookupIciba(cleanWord);
      if (icibaResult != null) {
        result = icibaResult;
      }
    }

    // Enhance with Free Dictionary API for more examples
    if (result != null) {
      final freeDict = await _lookupFreeDictionary(cleanWord);
      if (freeDict != null) {
        // Merge examples if we got more
        if (freeDict.examples.length > result.examples.length) {
          result = WordDefinition(
            word: result.word,
            phoneticUs: result.phoneticUs.isEmpty ? freeDict.phoneticUs : result.phoneticUs,
            phoneticUk: result.phoneticUk.isEmpty ? freeDict.phoneticUk : result.phoneticUk,
            audioUs: result.audioUs.isEmpty ? freeDict.audioUs : result.audioUs,
            audioUk: result.audioUk.isEmpty ? freeDict.audioUk : result.audioUk,
            definitions: result.definitions,
            definitionsEn: freeDict.definitionsEn,
            examples: freeDict.examples,
            exampleTranslations: result.exampleTranslations,
            translation: result.translation,
            partOfSpeech: result.partOfSpeech.isEmpty ? freeDict.partOfSpeech : result.partOfSpeech,
          );
        }
      }
    }

    // Final fallback
    result ??= WordDefinition(
      word: cleanWord,
      phoneticUs: '',
      phoneticUk: '',
      audioUs: '',
      audioUk: '',
      definitions: ['查询失败，请检查网络连接'],
      definitionsEn: [],
      examples: [],
      exampleTranslations: [],
      translation: '',
      partOfSpeech: [],
    );

    return result;
  }

  /// Lookup using Youdao Dictionary (best for Chinese)
  Future<WordDefinition?> _lookupYoudao(String word) async {
    try {
      // Use Youdao's suggest API for word lookup
      final response = await http.get(
        Uri.parse('https://dict.youdao.com/suggest?num=1&doctype=json&q=${Uri.encodeComponent(word)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entries = data['data']?['entries'] as List?;
        if (entries != null && entries.isNotEmpty) {
          final entry = entries[0];
          final explain = entry['explain'] as String? ?? '';
          final entryWord = entry['entry'] as String? ?? word;

          // 验证返回的单词是否与查询词匹配（忽略大小写）
          // 如果不匹配，返回 null 让其他 API 尝试
          if (entryWord.toLowerCase() != word.toLowerCase()) {
            if (kDebugMode) {
              debugPrint('Youdao: word mismatch - queried "$word" but got "$entryWord"');
            }
            return null;
          }

          if (explain.isNotEmpty) {
            // Parse the explain field (format: "n. 名词释义; v. 动词释义")
            final definitions = _parseYoudaoExplain(explain);

            // Get more details from jsonapi
            final detailResult = await _getYoudaoDetail(entryWord);

            return WordDefinition(
              word: entryWord,
              phoneticUs: detailResult?['phoneticUs'] ?? '',
              phoneticUk: detailResult?['phoneticUk'] ?? '',
              audioUs: '',
              audioUk: '',
              definitions: definitions,
              definitionsEn: detailResult?['definitionsEn'] ?? [],
              examples: detailResult?['examples'] ?? [],
              exampleTranslations: detailResult?['exampleTrans'] ?? [],
              translation: explain,
              partOfSpeech: _extractPartsOfSpeech(explain),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Youdao lookup error: $e');
      }
    }
    return null;
  }

  /// Get detailed info from Youdao
  Future<Map<String, dynamic>?> _getYoudaoDetail(String word) async {
    try {
      final response = await http.get(
        Uri.parse('https://dict.youdao.com/jsonapi?q=${Uri.encodeComponent(word)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String phoneticUs = '';
        String phoneticUk = '';
        List<String> definitionsEn = [];
        List<String> examples = [];
        List<String> exampleTrans = [];

        // Parse EC (English-Chinese) data
        final ec = data['ec'];
        if (ec != null) {
          final wordList = ec['word'];
          if (wordList != null && wordList is List && wordList.isNotEmpty) {
            final wordData = wordList[0];

            // 验证返回的单词是否匹配
            final returnWord = wordData['return-phrase']?['l']?['i'] as String? ?? '';
            if (returnWord.isNotEmpty && returnWord.toLowerCase() != word.toLowerCase()) {
              if (kDebugMode) {
                debugPrint('YoudaoDetail: word mismatch - queried "$word" but got "$returnWord"');
              }
              return null;
            }

            // Get phonetics
            phoneticUs = wordData['usphone'] as String? ?? '';
            phoneticUk = wordData['ukphone'] as String? ?? '';

            // Get translations
            final trs = wordData['trs'];
            if (trs != null && trs is List) {
              for (var tr in trs) {
                final trStr = tr['tr']?[0]?['l']?['i']?[0] as String?;
                if (trStr != null && definitionsEn.length < 5) {
                  definitionsEn.add(trStr);
                }
              }
            }
          }
        }

        // Parse blng_sents_part (bilingual examples)
        final blngSents = data['blng_sents_part'];
        if (blngSents != null) {
          final pairs = blngSents['sentence-pair'];
          if (pairs != null && pairs is List) {
            for (var pair in pairs) {
              if (examples.length >= 3) break;
              final sentence = pair['sentence'] as String?;
              final trans = pair['sentence-translation'] as String?;
              if (sentence != null) {
                examples.add(_cleanHtmlTags(sentence));
                if (trans != null) {
                  exampleTrans.add(trans);
                }
              }
            }
          }
        }

        return {
          'phoneticUs': phoneticUs,
          'phoneticUk': phoneticUk,
          'definitionsEn': definitionsEn,
          'examples': examples,
          'exampleTrans': exampleTrans,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Youdao detail error: $e');
      }
    }
    return null;
  }

  /// Lookup using iCiba (Kingsoft) Dictionary
  Future<WordDefinition?> _lookupIciba(String word) async {
    try {
      final response = await http.get(
        Uri.parse('https://dict-co.iciba.com/api/dictionary.php?w=${Uri.encodeComponent(word)}&type=json'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final wordName = data['word_name'] as String? ?? word;

        // 验证返回的单词是否与查询词匹配
        if (wordName.toLowerCase() != word.toLowerCase()) {
          if (kDebugMode) {
            debugPrint('iCiba: word mismatch - queried "$word" but got "$wordName"');
          }
          return null;
        }

        // Parse symbols (phonetics and meanings)
        final symbols = data['symbols'] as List?;
        if (symbols != null && symbols.isNotEmpty) {
          final symbol = symbols[0];

          final phoneticUs = symbol['ph_am'] as String? ?? '';
          final phoneticUk = symbol['ph_en'] as String? ?? '';

          List<String> definitions = [];
          List<String> partOfSpeech = [];

          final parts = symbol['parts'] as List?;
          if (parts != null) {
            for (var part in parts) {
              final pos = part['part'] as String? ?? '';
              final means = part['means'] as List?;

              if (pos.isNotEmpty && !partOfSpeech.contains(pos)) {
                partOfSpeech.add(pos);
              }

              if (means != null) {
                for (var mean in means) {
                  String meaningStr;
                  if (mean is String) {
                    meaningStr = mean;
                  } else if (mean is Map) {
                    meaningStr = mean['word_mean'] as String? ?? '';
                  } else {
                    continue;
                  }

                  if (meaningStr.isNotEmpty && definitions.length < 6) {
                    definitions.add(pos.isNotEmpty ? '$pos $meaningStr' : meaningStr);
                  }
                }
              }
            }
          }

          // Get sentences
          List<String> examples = [];
          List<String> exampleTrans = [];

          final sentences = data['sentence'] as List?;
          if (sentences != null) {
            for (var sent in sentences) {
              if (examples.length >= 3) break;
              final orig = sent['orig'] as String?;
              final trans = sent['trans'] as String?;
              if (orig != null) {
                examples.add(_cleanHtmlTags(orig));
                if (trans != null) {
                  exampleTrans.add(_cleanHtmlTags(trans));
                }
              }
            }
          }

          return WordDefinition(
            word: wordName,
            phoneticUs: phoneticUs,
            phoneticUk: phoneticUk,
            audioUs: '',
            audioUk: '',
            definitions: definitions,
            definitionsEn: [],
            examples: examples,
            exampleTranslations: exampleTrans,
            translation: definitions.join('; '),
            partOfSpeech: partOfSpeech,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('iCiba lookup error: $e');
      }
    }
    return null;
  }

  /// Lookup using Free Dictionary API (for English definitions and examples)
  Future<WordDefinition?> _lookupFreeDictionary(String word) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return _parseFreeDictionaryResponse(data[0]);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FreeDictionary lookup error: $e');
      }
    }
    return null;
  }

  WordDefinition _parseFreeDictionaryResponse(Map<String, dynamic> data) {
    final word = data['word'] as String? ?? '';
    String phoneticUs = '';
    String phoneticUk = '';
    String audioUs = '';
    String audioUk = '';

    // Parse phonetics
    final phonetics = data['phonetics'] as List<dynamic>? ?? [];
    for (var p in phonetics) {
      if (p is Map) {
        final text = p['text'] as String? ?? '';
        final audio = p['audio'] as String? ?? '';

        if (audio.contains('-us')) {
          phoneticUs = text;
          audioUs = audio;
        } else if (audio.contains('-uk') || audio.contains('-gb')) {
          phoneticUk = text;
          audioUk = audio;
        } else if (phoneticUs.isEmpty && text.isNotEmpty) {
          phoneticUs = text;
        }
      }
    }

    if (phoneticUk.isEmpty) phoneticUk = phoneticUs;

    // Parse meanings
    List<String> definitionsEn = [];
    List<String> examples = [];
    List<String> partOfSpeech = [];

    final meanings = data['meanings'] as List<dynamic>? ?? [];
    for (var meaning in meanings) {
      if (meaning is Map) {
        final pos = meaning['partOfSpeech'] as String? ?? '';
        if (pos.isNotEmpty && !partOfSpeech.contains(pos)) {
          partOfSpeech.add(pos);
        }

        final defs = meaning['definitions'] as List<dynamic>? ?? [];
        for (var def in defs) {
          if (def is Map) {
            final definition = def['definition'] as String? ?? '';
            if (definition.isNotEmpty && definitionsEn.length < 5) {
              definitionsEn.add('$pos. $definition');
            }

            final example = def['example'] as String? ?? '';
            if (example.isNotEmpty && examples.length < 3) {
              examples.add(example);
            }
          }
        }
      }
    }

    return WordDefinition(
      word: word,
      phoneticUs: phoneticUs,
      phoneticUk: phoneticUk,
      audioUs: audioUs,
      audioUk: audioUk,
      definitions: [],
      definitionsEn: definitionsEn,
      examples: examples,
      exampleTranslations: [],
      translation: '',
      partOfSpeech: partOfSpeech,
    );
  }

  /// Parse Youdao explain string into definitions list
  List<String> _parseYoudaoExplain(String explain) {
    // Format: "n. 名词; v. 动词" or "代表，象征"
    List<String> definitions = [];

    // Split by semicolon or newline
    final parts = explain.split(RegExp(r'[;；\n]'));
    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        definitions.add(trimmed);
      }
    }

    return definitions;
  }

  /// Extract parts of speech from explain string
  List<String> _extractPartsOfSpeech(String explain) {
    List<String> pos = [];
    final regex = RegExp(r'\b(n|v|adj|adv|prep|conj|pron|int|vt|vi|art)\.');
    final matches = regex.allMatches(explain);
    for (var match in matches) {
      final p = match.group(1);
      if (p != null && !pos.contains(p)) {
        pos.add(p);
      }
    }
    return pos;
  }

  /// Clean HTML tags from string
  String _cleanHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Translate sentence/phrase to Chinese using multiple sources
  Future<String> translateText(String text) async {
    if (text.trim().isEmpty) return '';

    // Try Youdao translation first
    try {
      final response = await http.get(
        Uri.parse('https://dict.youdao.com/suggest?num=1&doctype=json&q=${Uri.encodeComponent(text)}'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entries = data['data']?['entries'] as List?;
        if (entries != null && entries.isNotEmpty) {
          final explain = entries[0]['explain'] as String?;
          if (explain != null && explain.isNotEmpty) {
            return explain;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Youdao translate error: $e');
      }
    }

    // Fallback to MyMemory
    try {
      final response = await http.get(
        Uri.parse('https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|zh'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['responseData']?['translatedText'] as String? ?? text;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MyMemory translate error: $e');
      }
    }

    return text;
  }
}

/// Word definition result with comprehensive data
class WordDefinition {
  final String word;
  final String phoneticUs;
  final String phoneticUk;
  final String audioUs;
  final String audioUk;
  final List<String> definitions;      // Chinese definitions
  final List<String> definitionsEn;    // English definitions
  final List<String> examples;         // Example sentences
  final List<String> exampleTranslations; // Chinese translations of examples
  final String translation;            // Simple translation
  final List<String> partOfSpeech;     // Parts of speech

  WordDefinition({
    required this.word,
    required this.phoneticUs,
    required this.phoneticUk,
    required this.audioUs,
    required this.audioUk,
    required this.definitions,
    required this.definitionsEn,
    required this.examples,
    required this.exampleTranslations,
    required this.translation,
    required this.partOfSpeech,
  });

  /// Check if we have meaningful content
  bool get hasContent =>
    definitions.isNotEmpty ||
    definitionsEn.isNotEmpty ||
    translation.isNotEmpty;
}
