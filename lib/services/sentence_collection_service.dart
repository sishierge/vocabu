import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 句子收藏服务
class SentenceCollectionService {
  static final SentenceCollectionService instance = SentenceCollectionService._();
  SentenceCollectionService._();

  static const String _keyCollected = 'collected_sentences';
  static const String _keyDifficult = 'difficult_sentences';

  List<CollectedSentence> _collected = [];
  List<CollectedSentence> _difficult = [];
  bool _initialized = false;

  List<CollectedSentence> get collected => _collected;
  List<CollectedSentence> get difficult => _difficult;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 加载收藏句子
    final collectedJson = prefs.getString(_keyCollected);
    if (collectedJson != null) {
      final list = jsonDecode(collectedJson) as List;
      _collected = list.map((e) => CollectedSentence.fromJson(e)).toList();
    }

    // 加载难句
    final difficultJson = prefs.getString(_keyDifficult);
    if (difficultJson != null) {
      final list = jsonDecode(difficultJson) as List;
      _difficult = list.map((e) => CollectedSentence.fromJson(e)).toList();
    }

    _initialized = true;
  }

  /// 收藏句子
  Future<void> collectSentence(CollectedSentence sentence) async {
    if (!_collected.any((s) => s.english == sentence.english)) {
      _collected.insert(0, sentence);
      await _saveCollected();
    }
  }

  /// 取消收藏
  Future<void> uncollectSentence(String english) async {
    _collected.removeWhere((s) => s.english == english);
    await _saveCollected();
  }

  /// 标记为难句
  Future<void> markAsDifficult(CollectedSentence sentence) async {
    if (!_difficult.any((s) => s.english == sentence.english)) {
      _difficult.insert(0, sentence);
      await _saveDifficult();
    }
  }

  /// 取消难句标记
  Future<void> unmarkDifficult(String english) async {
    _difficult.removeWhere((s) => s.english == english);
    await _saveDifficult();
  }

  /// 检查是否已收藏
  bool isCollected(String english) {
    return _collected.any((s) => s.english == english);
  }

  /// 检查是否是难句
  bool isDifficult(String english) {
    return _difficult.any((s) => s.english == english);
  }

  Future<void> _saveCollected() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_collected.map((s) => s.toJson()).toList());
    await prefs.setString(_keyCollected, json);
  }

  Future<void> _saveDifficult() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_difficult.map((s) => s.toJson()).toList());
    await prefs.setString(_keyDifficult, json);
  }
}

/// 收藏的句子
class CollectedSentence {
  final String english;
  final String chinese;
  final String? materialName;
  final String? audioUrl;
  final DateTime collectedAt;

  CollectedSentence({
    required this.english,
    required this.chinese,
    this.materialName,
    this.audioUrl,
    DateTime? collectedAt,
  }) : collectedAt = collectedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'english': english,
    'chinese': chinese,
    'materialName': materialName,
    'audioUrl': audioUrl,
    'collectedAt': collectedAt.toIso8601String(),
  };

  factory CollectedSentence.fromJson(Map<String, dynamic> json) {
    return CollectedSentence(
      english: json['english'] ?? '',
      chinese: json['chinese'] ?? '',
      materialName: json['materialName'],
      audioUrl: json['audioUrl'],
      collectedAt: json['collectedAt'] != null
          ? DateTime.parse(json['collectedAt'])
          : DateTime.now(),
    );
  }
}
