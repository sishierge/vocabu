import 'package:flutter/foundation.dart';

/// 日志服务 - 可控制的调试输出
///
/// 在生产环境中自动禁用日志输出，在开发环境中启用
/// 使用方法: Log.d('message') 代替 debugPrint('message')
class Log {
  /// 是否启用日志 (仅在 debug 模式下启用)
  static bool enabled = kDebugMode;

  /// 是否启用详细日志 (默认关闭，用于调试特定问题)
  static bool verbose = false;

  /// 调试日志 - 仅在开发模式下输出
  static void d(String message, [String? tag]) {
    if (!enabled) return;
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('$prefix$message');
    }
  }

  /// 详细日志 - 仅在 verbose 模式下输出
  static void v(String message, [String? tag]) {
    if (!enabled || !verbose) return;
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('[V] $prefix$message');
    }
  }

  /// 信息日志 - 重要信息，始终输出
  static void i(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('[I] $prefix$message');
    }
  }

  /// 警告日志 - 始终输出
  static void w(String message, [String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('[W] $prefix$message');
    }
  }

  /// 错误日志 - 始终输出
  static void e(String message, [Object? error, String? tag]) {
    final prefix = tag != null ? '[$tag] ' : '';
    if (kDebugMode) {
      debugPrint('[E] $prefix$message');
      if (error != null) {
        debugPrint('[E] Error: $error');
      }
    }
  }

  /// 禁用所有日志 (用于生产环境)
  static void disableAll() {
    enabled = false;
    verbose = false;
  }

  /// 启用详细日志 (用于调试)
  static void enableVerbose() {
    enabled = true;
    verbose = true;
  }
}
