import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

/// 数据备份恢复服务
class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  /// 备份数据结构版本
  static const int backupVersion = 1;

  /// 导出学习数据为JSON
  Future<BackupResult> exportData() async {
    try {
      final db = await DatabaseHelper.database;

      // 获取所有词书
      final books = await db.query('WordBook');

      // 获取所有单词（包含学习进度）
      final words = await db.query('WordItem');

      // 获取每日学习记录
      final dailyStats = await db.query('DailyLearnInfo');

      // 获取收藏的句子（如果表存在）
      List<Map<String, dynamic>> sentences = [];
      try {
        sentences = await db.query('CollectedSentence');
      } catch (e) {
        // 表可能不存在
      }

      // 构建备份数据
      final backupData = {
        'version': backupVersion,
        'exportTime': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'data': {
          'books': books,
          'words': words,
          'dailyStats': dailyStats,
          'sentences': sentences,
        },
        'summary': {
          'bookCount': books.length,
          'wordCount': words.length,
          'masteredCount': words.where((w) => w['LearnStatus'] == 2).length,
          'collectedCount': words.where((w) => w['Collected'] == 1).length,
          'daysLearned': dailyStats.length,
        },
      };

      // 生成JSON
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);

      // 保存到文件
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'vocabu_backup_$timestamp.json';
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      await file.writeAsString(jsonStr);

      return BackupResult(
        success: true,
        filePath: filePath,
        summary: BackupSummary(
          bookCount: books.length,
          wordCount: words.length,
          masteredCount: words.where((w) => w['LearnStatus'] == 2).length,
          daysLearned: dailyStats.length,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Export error: $e');
      }
      return BackupResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 从JSON文件恢复数据
  Future<RestoreResult> importData(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return RestoreResult(success: false, error: '文件不存在');
      }

      final jsonStr = await file.readAsString();
      final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 验证版本
      final version = backupData['version'] as int? ?? 0;
      if (version > backupVersion) {
        return RestoreResult(success: false, error: '备份文件版本过高，请更新应用');
      }

      final data = backupData['data'] as Map<String, dynamic>;
      final books = (data['books'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final words = (data['words'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final dailyStats = (data['dailyStats'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final db = await DatabaseHelper.database;

      int booksRestored = 0;
      int wordsRestored = 0;
      int statsRestored = 0;

      // 在事务中恢复数据
      await db.transaction((txn) async {
        // 恢复词书
        for (final book in books) {
          final existing = await txn.query(
            'WordBook',
            where: 'BookId = ?',
            whereArgs: [book['BookId']],
          );

          if (existing.isEmpty) {
            await txn.insert('WordBook', book);
            booksRestored++;
          }
        }

        // 恢复单词
        for (final word in words) {
          final existing = await txn.query(
            'WordItem',
            where: 'WordId = ?',
            whereArgs: [word['WordId']],
          );

          if (existing.isEmpty) {
            await txn.insert('WordItem', word);
            wordsRestored++;
          } else {
            // 更新学习进度（只更新学习相关字段）
            await txn.update(
              'WordItem',
              {
                'LearnStatus': word['LearnStatus'],
                'LearnParam': word['LearnParam'],
                'NextReviewTime': word['NextReviewTime'],
                'Collected': word['Collected'],
                'UpdateTime': word['UpdateTime'],
              },
              where: 'WordId = ?',
              whereArgs: [word['WordId']],
            );
            wordsRestored++;
          }
        }

        // 恢复每日统计
        for (final stat in dailyStats) {
          final existing = await txn.query(
            'DailyLearnInfo',
            where: 'LearnDate = ?',
            whereArgs: [stat['LearnDate']],
          );

          if (existing.isEmpty) {
            await txn.insert('DailyLearnInfo', stat);
            statsRestored++;
          }
        }
      });

      return RestoreResult(
        success: true,
        booksRestored: booksRestored,
        wordsRestored: wordsRestored,
        statsRestored: statsRestored,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Import error: $e');
      }
      return RestoreResult(success: false, error: e.toString());
    }
  }

  /// 验证备份文件
  Future<BackupValidation> validateBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return BackupValidation(valid: false, error: '文件不存在');
      }

      final jsonStr = await file.readAsString();
      final backupData = jsonDecode(jsonStr) as Map<String, dynamic>;

      final version = backupData['version'] as int? ?? 0;
      final exportTime = backupData['exportTime'] as String?;
      final summary = backupData['summary'] as Map<String, dynamic>?;

      if (version == 0 || summary == null) {
        return BackupValidation(valid: false, error: '无效的备份文件格式');
      }

      return BackupValidation(
        valid: true,
        version: version,
        exportTime: exportTime != null ? DateTime.parse(exportTime) : null,
        summary: BackupSummary(
          bookCount: summary['bookCount'] as int? ?? 0,
          wordCount: summary['wordCount'] as int? ?? 0,
          masteredCount: summary['masteredCount'] as int? ?? 0,
          daysLearned: summary['daysLearned'] as int? ?? 0,
        ),
      );
    } catch (e) {
      return BackupValidation(valid: false, error: '解析文件失败: $e');
    }
  }

  /// 获取备份文件列表
  Future<List<BackupFileInfo>> listBackups() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('vocabu_backup_') && f.path.endsWith('.json'))
          .toList();

      final backups = <BackupFileInfo>[];

      for (final file in files) {
        final stat = await file.stat();
        final validation = await validateBackupFile(file.path);

        backups.add(BackupFileInfo(
          path: file.path,
          fileName: file.path.split(Platform.pathSeparator).last,
          size: stat.size,
          modified: stat.modified,
          validation: validation,
        ));
      }

      // 按修改时间倒序
      backups.sort((a, b) => b.modified.compareTo(a.modified));

      return backups;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('List backups error: $e');
      }
      return [];
    }
  }

  /// 删除备份文件
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// 备份结果
class BackupResult {
  final bool success;
  final String? filePath;
  final String? error;
  final BackupSummary? summary;

  BackupResult({
    required this.success,
    this.filePath,
    this.error,
    this.summary,
  });
}

/// 恢复结果
class RestoreResult {
  final bool success;
  final String? error;
  final int booksRestored;
  final int wordsRestored;
  final int statsRestored;

  RestoreResult({
    required this.success,
    this.error,
    this.booksRestored = 0,
    this.wordsRestored = 0,
    this.statsRestored = 0,
  });
}

/// 备份摘要
class BackupSummary {
  final int bookCount;
  final int wordCount;
  final int masteredCount;
  final int daysLearned;

  BackupSummary({
    required this.bookCount,
    required this.wordCount,
    required this.masteredCount,
    required this.daysLearned,
  });
}

/// 备份验证结果
class BackupValidation {
  final bool valid;
  final String? error;
  final int? version;
  final DateTime? exportTime;
  final BackupSummary? summary;

  BackupValidation({
    required this.valid,
    this.error,
    this.version,
    this.exportTime,
    this.summary,
  });
}

/// 备份文件信息
class BackupFileInfo {
  final String path;
  final String fileName;
  final int size;
  final DateTime modified;
  final BackupValidation validation;

  BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.size,
    required this.modified,
    required this.validation,
  });

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
