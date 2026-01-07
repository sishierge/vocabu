/// Model class representing a word book
class WordBook {
  final String bookId;
  final String bookName;
  final int wordCount;
  final int newCount;
  final int learningCount;
  final int masteredCount;
  final int reviewCount;
  final String? createTime;

  WordBook({
    required this.bookId,
    required this.bookName,
    required this.wordCount,
    this.newCount = 0,
    this.learningCount = 0,
    this.masteredCount = 0,
    this.reviewCount = 0,
    this.createTime,
  });

  /// Progress percentage (0.0 - 1.0)
  double get progress => wordCount > 0 ? masteredCount / wordCount : 0;

  /// Create from database map
  factory WordBook.fromMap(Map<String, dynamic> map) {
    return WordBook(
      bookId: map['BookId'] as String? ?? '',
      bookName: map['BookName'] as String? ?? 'Unknown',
      wordCount: map['WordCount'] as int? ?? 0,
      newCount: map['NewCount'] as int? ?? 0,
      learningCount: map['LearningCount'] as int? ?? 0,
      masteredCount: map['MasteredCount'] as int? ?? 0,
      reviewCount: map['ReviewCount'] as int? ?? 0,
      createTime: map['CreateTime'] as String?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'BookId': bookId,
      'BookName': bookName,
      'WordCount': wordCount,
      'CreateTime': createTime,
    };
  }

  /// Copy with new values
  WordBook copyWith({
    String? bookId,
    String? bookName,
    int? wordCount,
    int? newCount,
    int? learningCount,
    int? masteredCount,
    int? reviewCount,
    String? createTime,
  }) {
    return WordBook(
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      wordCount: wordCount ?? this.wordCount,
      newCount: newCount ?? this.newCount,
      learningCount: learningCount ?? this.learningCount,
      masteredCount: masteredCount ?? this.masteredCount,
      reviewCount: reviewCount ?? this.reviewCount,
      createTime: createTime ?? this.createTime,
    );
  }
}
