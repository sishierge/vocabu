import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider for night mode support
class ThemeProvider extends ChangeNotifier {
  static ThemeProvider? _instance;
  ThemeMode _themeMode = ThemeMode.light;

  static ThemeProvider get instance {
    _instance ??= ThemeProvider._();
    return _instance!;
  }

  ThemeProvider._() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Load saved theme preference
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    notifyListeners();
  }

  /// Material 3 - Deep Purple Seed
  static const Color m3Seed = Color(0xFF6750A4); // M3 Deep Purple

  /// Light theme data with system fonts (Chinese Support)
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: m3Seed,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    fontFamily: 'Microsoft YaHei',
    appBarTheme: const AppBarTheme(
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );

  /// Dark theme data with system fonts (Chinese Support)
  /// Enhanced for better text contrast
  static ThemeData get darkTheme {
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: m3Seed,
      brightness: Brightness.dark,
    ).copyWith(
      // 增强深色模式下的文字对比度
      onSurface: const Color(0xFFE8E8E8),          // 主要文字 - 更亮
      onSurfaceVariant: const Color(0xFFB8B8B8),   // 次要文字 - 更亮
      surface: const Color(0xFF1E1E1E),             // 背景 - 稍亮
      surfaceContainerLowest: const Color(0xFF161616),
      surfaceContainerHighest: const Color(0xFF2D2D2D),
      outlineVariant: const Color(0xFF404040),      // 边框 - 更清晰
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      useMaterial3: true,
      fontFamily: 'Microsoft YaHei',
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: darkColorScheme.surface,
        foregroundColor: darkColorScheme.onSurface,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: darkColorScheme.surface,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkColorScheme.surface,
        titleTextStyle: TextStyle(
          color: darkColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: darkColorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkColorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: darkColorScheme.onSurface),
      ),
    );
  }
}
