import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Desktop Overlay Danmu Window
/// This creates a transparent, always-on-top window for displaying word barrage on the desktop.

class DesktopDanmuWindow extends StatefulWidget {
  final Map<String, dynamic> args;
  
  const DesktopDanmuWindow({super.key, required this.args});

  @override
  State<DesktopDanmuWindow> createState() => _DesktopDanmuWindowState();
}

class _DesktopDanmuWindowState extends State<DesktopDanmuWindow> with WindowListener {
  final List<_DanmuItem> _danmuItems = [];
  Timer? _spawnTimer;
  Timer? _animationTimer;
  bool _isPaused = false;
  final Random _random = Random();
  
  // Settings
  late double _speed;
  late int _spawnInterval;
  late bool _showTranslation;
  late String _styleType;
  late List<Map<String, dynamic>> _words;
  
  final List<Color> _colors = [
    const Color(0xFF7B61FF),
    const Color(0xFF2E7D32),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF3F51B5),
    const Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSettings();
    _setupWindow();
  }
  
  void _initSettings() {
    _speed = (widget.args['speed'] as num?)?.toDouble() ?? 1.0;
    _spawnInterval = widget.args['spawnInterval'] as int? ?? 2;
    _showTranslation = widget.args['showTranslation'] as bool? ?? true;
    _styleType = widget.args['styleType'] as String? ?? 'filled';
    
    // Parse words from JSON
    final wordsJson = widget.args['words'] as String? ?? '[]';
    try {
      _words = List<Map<String, dynamic>>.from(jsonDecode(wordsJson));
    } catch (e) {
      _words = [];
    }
  }
  
  Future<void> _setupWindow() async {
    await windowManager.ensureInitialized();
    
    // Get screen size
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final screenSize = primaryDisplay.size;
    
    // Set window to full screen size
    await windowManager.setSize(Size(screenSize.width, screenSize.height));
    await windowManager.setPosition(Offset.zero);
    
    // Configure overlay properties
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    
    // Make window ignore mouse events (click-through)
    await windowManager.setIgnoreMouseEvents(true, forward: true);
    
    _startAnimationLoop();
    _startSpawning();
  }
  
  void _startAnimationLoop() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_isPaused && mounted) {
        setState(() {
          // Move each danmu
          for (final item in _danmuItems) {
            item.x -= item.speed;
          }
          // Remove items that are off screen
          _danmuItems.removeWhere((item) => item.x < -400);
        });
      }
    });
  }
  
  void _startSpawning() {
    _spawnTimer = Timer.periodic(Duration(seconds: _spawnInterval), (_) {
      if (!_isPaused && mounted && _words.isNotEmpty) {
        _spawnDanmu();
      }
    });
    // Spawn first one immediately
    if (_words.isNotEmpty) {
      _spawnDanmu();
    }
  }
  
  void _spawnDanmu() {
    if (_words.isEmpty) return;
    
    final wordData = _words[_random.nextInt(_words.length)];
    final word = wordData['word'] as String? ?? 'Unknown';
    final trans = wordData['trans'] as String? ?? '';
    final color = _colors[_random.nextInt(_colors.length)];
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    _danmuItems.add(_DanmuItem(
      word: word,
      translation: trans,
      color: color,
      x: screenWidth,
      y: 50 + _random.nextDouble() * (screenHeight - 150),
      speed: 2.0 + _random.nextDouble() * 2.0 * _speed,
      isOutlined: _styleType == 'outlined',
      showTranslation: _showTranslation,
    ));
  }
  
  void _close() {
    _spawnTimer?.cancel();
    _animationTimer?.cancel();
    final windowIdStr = widget.args['windowId']?.toString() ?? '0';
    final windowId = int.tryParse(windowIdStr) ?? 0;
    if (windowId > 0) {
      WindowController.fromWindowId(windowId).close();
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _animationTimer?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Danmu items
            ..._danmuItems.map((item) => Positioned(
              left: item.x,
              top: item.y,
              child: _DanmuBubble(item: item),
            )),
            
            // Control panel (only visible when hovered)
            Positioned(
              top: 10,
              right: 10,
              child: MouseRegion(
                onEnter: (_) async {
                  await windowManager.setIgnoreMouseEvents(false);
                },
                onExit: (_) async {
                  await windowManager.setIgnoreMouseEvents(true, forward: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => setState(() => _isPaused = !_isPaused),
                        icon: Icon(
                          _isPaused ? Icons.play_arrow : Icons.pause,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: _isPaused ? '继续' : '暂停',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _close,
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        tooltip: '关闭',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Instructions
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '鼠标移到右上角控制面板可暂停/关闭',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DanmuItem {
  final String word;
  final String translation;
  final Color color;
  double x;
  final double y;
  final double speed;
  final bool isOutlined;
  final bool showTranslation;

  _DanmuItem({
    required this.word,
    required this.translation,
    required this.color,
    required this.x,
    required this.y,
    required this.speed,
    required this.isOutlined,
    required this.showTranslation,
  });
}

class _DanmuBubble extends StatelessWidget {
  final _DanmuItem item;

  const _DanmuBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: item.isOutlined ? Colors.white.withValues(alpha: 0.9) : item.color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: item.isOutlined ? Border.all(color: item.color, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.word,
            style: TextStyle(
              color: item.isOutlined ? item.color : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (item.showTranslation && item.translation.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.translation,
              style: TextStyle(
                color: item.isOutlined ? Colors.grey[700] : Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
