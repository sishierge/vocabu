import 'dart:convert';

/// Model class representing a word item from the database
class WordItem {
  final String wordId;
  final String bookId;
  final String word;
  final String translate;
  final String symbol; // phonetic
  final int learnStatus; // 0=new, 1=learning, 2=mastered
  final int sort;
  final String? createTime;
  final String? learnTime;
  final String? masterTime;
  final int reviewCount;
  final int showCount;
  final int collected; // 0 or 1
  final String? learnParam; // JSON string for FSRS state
  final String? updateTime;
  final String? nextReviewTime;
  final int totalReviewCount;
  final String? unitId;
  final int errorCount;
  final double scoreValue;

  WordItem({
    required this.wordId,
    required this.bookId,
    required this.word,
    required this.translate,
    required this.symbol,
    required this.learnStatus,
    required this.sort,
    this.createTime,
    this.learnTime,
    this.masterTime,
    required this.reviewCount,
    required this.showCount,
    required this.collected,
    this.learnParam,
    this.updateTime,
    this.nextReviewTime,
    required this.totalReviewCount,
    this.unitId,
    required this.errorCount,
    required this.scoreValue,
  });

  factory WordItem.fromMap(Map<String, dynamic> map) {
    return WordItem(
      wordId: map['WordId'] as String,
      bookId: map['BookId'] as String,
      word: map['Word'] as String,
      translate: map['Translate'] as String? ?? '',
      symbol: map['Symbol'] as String? ?? '',
      learnStatus: map['LearnStatus'] as int? ?? 0,
      sort: map['Sort'] as int? ?? 0,
      createTime: map['CreateTime'] as String?,
      learnTime: map['LearnTime'] as String?,
      masterTime: map['MasterTime'] as String?,
      reviewCount: map['ReviewCount'] as int? ?? 0,
      showCount: map['ShowCount'] as int? ?? 0,
      collected: map['Collected'] as int? ?? 0,
      learnParam: map['LearnParam'] as String?,
      updateTime: map['UpdateTime'] as String?,
      nextReviewTime: map['NextReviewTime'] as String?,
      totalReviewCount: map['TotalReviewCount'] as int? ?? 0,
      unitId: map['UnitId'] as String?,
      errorCount: map['ErrorCount'] as int? ?? 0,
      scoreValue: (map['ScoreValue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'WordId': wordId,
      'BookId': bookId,
      'Word': word,
      'Translate': translate,
      'Symbol': symbol,
      'LearnStatus': learnStatus,
      'Sort': sort,
      'CreateTime': createTime,
      'LearnTime': learnTime,
      'MasterTime': masterTime,
      'ReviewCount': reviewCount,
      'ShowCount': showCount,
      'Collected': collected,
      'LearnParam': learnParam,
      'UpdateTime': updateTime,
      'NextReviewTime': nextReviewTime,
      'TotalReviewCount': totalReviewCount,
      'UnitId': unitId,
      'ErrorCount': errorCount,
      'ScoreValue': scoreValue,
    };
  }

  /// Get the FSRS state from learnParam JSON
  Map<String, dynamic>? get fsrsState {
    if (learnParam == null || learnParam!.isEmpty) return null;
    try {
      return jsonDecode(learnParam!);
    } catch (e) {
      return null;
    }
  }

  bool get isNew => learnStatus == 0;
  bool get isLearning => learnStatus == 1;
  bool get isMastered => learnStatus == 2;
  bool get isFavorite => collected == 1;

  /// Check if word is due for review
  bool get isDueForReview {
    if (nextReviewTime == null) return false;
    try {
      final nextReview = int.parse(nextReviewTime!);
      return DateTime.now().millisecondsSinceEpoch >= nextReview;
    } catch (e) {
      return false;
    }
  }

  WordItem copyWith({
    String? wordId,
    String? bookId,
    String? word,
    String? translate,
    String? symbol,
    int? learnStatus,
    int? sort,
    String? createTime,
    String? learnTime,
    String? masterTime,
    int? reviewCount,
    int? showCount,
    int? collected,
    String? learnParam,
    String? updateTime,
    String? nextReviewTime,
    int? totalReviewCount,
    String? unitId,
    int? errorCount,
    double? scoreValue,
  }) {
    return WordItem(
      wordId: wordId ?? this.wordId,
      bookId: bookId ?? this.bookId,
      word: word ?? this.word,
      translate: translate ?? this.translate,
      symbol: symbol ?? this.symbol,
      learnStatus: learnStatus ?? this.learnStatus,
      sort: sort ?? this.sort,
      createTime: createTime ?? this.createTime,
      learnTime: learnTime ?? this.learnTime,
      masterTime: masterTime ?? this.masterTime,
      reviewCount: reviewCount ?? this.reviewCount,
      showCount: showCount ?? this.showCount,
      collected: collected ?? this.collected,
      learnParam: learnParam ?? this.learnParam,
      updateTime: updateTime ?? this.updateTime,
      nextReviewTime: nextReviewTime ?? this.nextReviewTime,
      totalReviewCount: totalReviewCount ?? this.totalReviewCount,
      unitId: unitId ?? this.unitId,
      errorCount: errorCount ?? this.errorCount,
      scoreValue: scoreValue ?? this.scoreValue,
    );
  }
}
