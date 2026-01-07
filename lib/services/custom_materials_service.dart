import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 自定义素材管理服务
class CustomMaterialsService {
  static final CustomMaterialsService instance = CustomMaterialsService._();
  CustomMaterialsService._();

  static const String _keyCustomMaterials = 'custom_materials';

  List<CustomMaterial> _materials = [];
  bool _initialized = false;

  List<CustomMaterial> get materials => _materials;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCustomMaterials);

    if (json != null) {
      final list = jsonDecode(json) as List;
      _materials = list.map((e) => CustomMaterial.fromJson(e)).toList();
    }

    _initialized = true;
  }

  /// 添加自定义素材
  Future<CustomMaterial> addMaterial({
    required String name,
    required List<MaterialSentence> sentences,
    String? description,
    String? category,
    String difficulty = '自定义',
  }) async {
    final material = CustomMaterial(
      id: const Uuid().v4(),
      name: name,
      description: description ?? '',
      category: category ?? '自定义',
      difficulty: difficulty,
      sentences: sentences,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _materials.insert(0, material);
    await _save();
    return material;
  }

  /// 更新素材名称
  Future<void> updateMaterialName(String id, String newName) async {
    final index = _materials.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _materials[index] = _materials[index].copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 更新素材描述
  Future<void> updateMaterialDescription(String id, String description) async {
    final index = _materials.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _materials[index] = _materials[index].copyWith(
        description: description,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 更新素材难度
  Future<void> updateMaterialDifficulty(String id, String difficulty) async {
    final index = _materials.indexWhere((m) => m.id == id);
    if (index >= 0) {
      _materials[index] = _materials[index].copyWith(
        difficulty: difficulty,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 添加句子到素材
  Future<void> addSentence(String materialId, MaterialSentence sentence) async {
    final index = _materials.indexWhere((m) => m.id == materialId);
    if (index >= 0) {
      final sentences = List<MaterialSentence>.from(_materials[index].sentences);
      sentences.add(sentence);
      _materials[index] = _materials[index].copyWith(
        sentences: sentences,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 更新句子
  Future<void> updateSentence(String materialId, int sentenceIndex, MaterialSentence newSentence) async {
    final index = _materials.indexWhere((m) => m.id == materialId);
    if (index >= 0 && sentenceIndex < _materials[index].sentences.length) {
      final sentences = List<MaterialSentence>.from(_materials[index].sentences);
      sentences[sentenceIndex] = newSentence;
      _materials[index] = _materials[index].copyWith(
        sentences: sentences,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 删除句子
  Future<void> deleteSentence(String materialId, int sentenceIndex) async {
    final index = _materials.indexWhere((m) => m.id == materialId);
    if (index >= 0 && sentenceIndex < _materials[index].sentences.length) {
      final sentences = List<MaterialSentence>.from(_materials[index].sentences);
      sentences.removeAt(sentenceIndex);
      _materials[index] = _materials[index].copyWith(
        sentences: sentences,
        updatedAt: DateTime.now(),
      );
      await _save();
    }
  }

  /// 删除素材
  Future<void> deleteMaterial(String id) async {
    _materials.removeWhere((m) => m.id == id);
    await _save();
  }

  /// 获取素材内容
  CustomMaterial? getMaterial(String id) {
    try {
      return _materials.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取素材句子列表（格式化为标准格式）
  List<Map<String, String>> getMaterialSentences(String id) {
    final material = getMaterial(id);
    if (material == null) return [];

    return material.sentences.map((s) => {
      'en': s.english,
      'cn': s.chinese,
    }).toList();
  }

  /// 导出素材为JSON
  String exportMaterial(String id) {
    final material = getMaterial(id);
    if (material == null) return '{}';

    return jsonEncode({
      'name': material.name,
      'sentences': material.sentences.map((s) => {
        'en': s.english,
        'cn': s.chinese,
      }).toList(),
    });
  }

  /// 从JSON导入素材
  Future<CustomMaterial?> importFromJson(String json) async {
    try {
      final data = jsonDecode(json);
      String name = data['name'] ?? '导入的素材';

      List<dynamic> sentencesList = [];
      if (data['sentences'] != null) {
        sentencesList = data['sentences'] as List;
      } else if (data is List) {
        sentencesList = data;
      }

      if (sentencesList.isEmpty) return null;

      final sentences = sentencesList.map((s) => MaterialSentence(
        english: s['en'] ?? s['english'] ?? '',
        chinese: s['cn'] ?? s['chinese'] ?? s['translation'] ?? '',
      )).where((s) => s.english.isNotEmpty).toList();

      if (sentences.isEmpty) return null;

      return addMaterial(
        name: name,
        sentences: sentences,
        description: '从JSON导入',
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_materials.map((m) => m.toJson()).toList());
    await prefs.setString(_keyCustomMaterials, json);
  }
}

/// 自定义素材
class CustomMaterial {
  final String id;
  final String name;
  final String description;
  final String category;
  final String difficulty;
  final List<MaterialSentence> sentences;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomMaterial({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.sentences,
    required this.createdAt,
    required this.updatedAt,
  });

  int get sentenceCount => sentences.length;

  CustomMaterial copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? difficulty,
    List<MaterialSentence>? sentences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      sentences: sentences ?? this.sentences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'difficulty': difficulty,
    'sentences': sentences.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CustomMaterial.fromJson(Map<String, dynamic> json) {
    return CustomMaterial(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '自定义',
      difficulty: json['difficulty'] ?? '自定义',
      sentences: (json['sentences'] as List?)
          ?.map((s) => MaterialSentence.fromJson(s))
          .toList() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }
}

/// 素材句子
class MaterialSentence {
  final String english;
  final String chinese;

  MaterialSentence({
    required this.english,
    required this.chinese,
  });

  Map<String, dynamic> toJson() => {
    'english': english,
    'chinese': chinese,
  };

  factory MaterialSentence.fromJson(Map<String, dynamic> json) {
    return MaterialSentence(
      english: json['english'] ?? json['en'] ?? '',
      chinese: json['chinese'] ?? json['cn'] ?? '',
    );
  }
}
