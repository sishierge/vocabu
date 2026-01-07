import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'extensions/danmu_plugin_page.dart';
import '../services/tts_service.dart';
import '../services/danmu_pipe_service.dart';
import '../services/carousel_pipe_service.dart';
import '../services/sticky_pipe_service.dart';
import '../services/extension_settings_service.dart';
import '../providers/word_book_provider.dart';

class ExtensionsPage extends StatefulWidget {
  const ExtensionsPage({super.key});

  @override
  State<ExtensionsPage> createState() => _ExtensionsPageState();
}

class _ExtensionsPageState extends State<ExtensionsPage> {
  int _selectedPlugin = 0;

  List<Map<String, dynamic>> _plugins = [];
  
  // 定时刷新插件状态的计时器
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPluginStates();
    // 每2秒刷新一次插件状态
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadPluginStates();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPluginStates() async {
    // 检查实际进程状态
    final danmuRunning = await DanmuPipeService.checkProcessRunning();
    final carouselRunning = await CarouselPipeService.checkProcessRunning();
    final stickyRunning = await StickyPipeService.checkProcessRunning();
    
    if (mounted) {
      setState(() {
        _plugins = [
          {'icon': Icons.subtitles_outlined, 'name': '弹幕插件', 'enabled': danmuRunning},
          {'icon': Icons.view_carousel_outlined, 'name': '轮播插件', 'enabled': carouselRunning},
          {'icon': Icons.sticky_note_2_outlined, 'name': '贴纸插件', 'enabled': stickyRunning},
          {'icon': Icons.record_voice_over_outlined, 'name': '离线语音引擎', 'enabled': false},
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
          // Plugin list
        Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.extension_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('扩展功能', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(_plugins.length, (index) {
                final plugin = _plugins[index];
                final isSelected = _selectedPlugin == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(plugin['icon'], size: 18, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
                    title: Text(
                      plugin['name'],
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                    trailing: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: plugin['enabled'] ? Colors.green : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    onTap: () => setState(() => _selectedPlugin = index),
                  ),
                );
              }),
            ],
          ),
        ),
        // Divider
        VerticalDivider(width: 1, thickness: 1, color: colorScheme.outlineVariant),
        // Plugin content
        Expanded(
          child: Container(
            color: colorScheme.surfaceContainerLowest,
            child: _buildPluginContent(_selectedPlugin),
          ),
        ),
      ],
    );
  }

  Widget _buildPluginContent(int index) {
    switch (index) {
      case 0:
        return const DanmuPluginPage();
      case 1:
        return const _CarouselPluginPage();
      case 2:
        return const _StickerPluginPage();
      case 3:
        return const _OfflineTtsPage();
      default:
        return const SizedBox();
    }
  }
}

// ============ CAROUSEL PLUGIN ============
class _CarouselPluginPage extends StatefulWidget {
  const _CarouselPluginPage();

  @override
  State<_CarouselPluginPage> createState() => _CarouselPluginPageState();
}

class _CarouselPluginPageState extends State<_CarouselPluginPage> {
  bool _isRunning = false;
  late int _interval;
  late String _position;
  late int _styleIndex;

  final List<String> _positions = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];
  final List<String> _positionLabels = ['左上角', '右上角', '左下角', '右下角'];
  final List<Color> _styleColors = [
    const Color(0xFF5B6CFF),
    const Color(0xFF2E7D32),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _checkRunningState();
  }

  Future<void> _checkRunningState() async {
    final running = await CarouselPipeService.checkProcessRunning();
    if (mounted) {
      setState(() => _isRunning = running);
    }
  }

  void _loadConfig() {
    final config = ExtensionSettingsService.instance.getCarouselConfig();
    _interval = (config['interval'] as num?)?.toInt() ?? 8;
    _position = config['position'] as String? ?? 'bottom-right';
    _styleIndex = (config['styleIndex'] as num?)?.toInt() ?? 0;
  }

  Future<void> _saveConfigSilently() async {
    await ExtensionSettingsService.instance.saveCarouselConfig({
      'interval': _interval,
      'position': _position,
      'styleIndex': _styleIndex,
    });
  }

  @override
  void dispose() {
    // 不再在 dispose 时自动停止轮播，让用户手动控制
    // 这样切换到其他插件页面时轮播仍可继续运行
    super.dispose();
  }

  Future<void> _enableCarousel() async {
    if (!mounted) return;

    final provider = Provider.of<WordBookProvider>(context, listen: false);
    final books = provider.books;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加词书')),
      );
      return;
    }

    final wordsMap = await provider.getWordsForBook(books.first.bookId, limit: 50);

    final success = await CarouselPipeService.launchCarouselOverlay(
      words: wordsMap,
      interval: _interval,
      position: _position,
      styleIndex: _styleIndex,
    );

    if (mounted) {
      if (success) {
        setState(() => _isRunning = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('桌面轮播已启动！')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('启动失败，请确保 CarouselOverlay.exe 已编译')),
        );
      }
    }
  }

  Future<void> _stopCarousel() async {
    await CarouselPipeService.stop();
    if (mounted) {
      setState(() => _isRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('轮播已停止')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          const Text('插件介绍', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            '在桌面角落显示单词卡片，按设定的时间间隔自动切换，支持自定义卡片样式和播放设置。',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildSettings(),
          const SizedBox(height: 24),
          _buildStyleSelector(),
          const SizedBox(height: 24),
          _buildPreview(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isRunning ? Colors.green : const Color(0xFF5B6CFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isRunning ? Icons.view_carousel : Icons.view_carousel_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('轮播插件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              _isRunning ? '运行中' : '桌面单词卡片轮播',
              style: TextStyle(fontSize: 13, color: _isRunning ? Colors.green : Colors.grey[500]),
            ),
          ],
        ),
        const Spacer(),
        if (_isRunning)
          ElevatedButton.icon(
            onPressed: _stopCarousel,
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('停止'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _enableCarousel,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('启用轮播'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B6CFF),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('基本设置', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(width: 100, child: Text('切换间隔')),
            Expanded(
              child: Slider(
                value: _interval.toDouble(),
                min: 2,
                max: 30,
                divisions: 14,
                label: '$_interval秒',
                onChanged: (v) {
                  setState(() => _interval = v.toInt());
                  _saveConfigSilently();
                  if (_isRunning) {
                    CarouselPipeService.updateConfig(interval: _interval);
                  }
                },
              ),
            ),
            SizedBox(width: 50, child: Text('$_interval秒')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 100, child: Text('显示位置')),
            const SizedBox(width: 16),
            ...List.generate(_positions.length, (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_positionLabels[i]),
                selected: _position == _positions[i],
                onSelected: (_) {
                  setState(() => _position = _positions[i]);
                  _saveConfigSilently();
                  if (_isRunning) {
                    CarouselPipeService.updateConfig(position: _position);
                  }
                },
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('卡片样式', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: List.generate(_styleColors.length, (i) {
            final isSelected = _styleIndex == i;
            return GestureDetector(
              onTap: () {
                setState(() => _styleIndex = i);
                _saveConfigSilently();
                if (_isRunning) {
                  CarouselPipeService.updateConfig(styleIndex: _styleIndex);
                }
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _styleColors[i],
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('效果预览', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _styleColors[_styleIndex],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('represent', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('/reprɪˈzent/', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
              const SizedBox(height: 8),
              const Text('v. 代表; 表现', style: TextStyle(fontSize: 15, color: Color(0xFFFFD700))),
            ],
          ),
        ),
      ],
    );
  }
}

// ============ STICKER PLUGIN ============
class _StickerPluginPage extends StatefulWidget {
  const _StickerPluginPage();

  @override
  State<_StickerPluginPage> createState() => _StickerPluginPageState();
}

class _StickerPluginPageState extends State<_StickerPluginPage> {
  bool _isRunning = false;

  // === 数据源设置 ===
  String? _selectedBookId;
  late int _stickerCount;

  // === 样式设置 ===
  late double _fontSize;
  late double _opacity;
  late Color _bgColor;
  late Color _wordColor;
  late Color _transColor;
  late int _styleIndex;

  // === 布局设置 ===
  late String _layout;
  late double _spacing;

  // 预设背景颜色
  final List<Color> _presetBgColors = [
    const Color(0xFF5B6CFF),  // 蓝紫
    const Color(0xFF2E7D32),  // 深绿
    const Color(0xFFE91E63),  // 粉红
    const Color(0xFF00BCD4),  // 青色
    const Color(0xFFFF9800),  // 橙色
    const Color(0xFF9C27B0),  // 紫色
    const Color(0xFF333333),  // 深灰
    Colors.white,
    const Color(0xFF1A237E),  // 深蓝
    const Color(0xFF006064),  // 深青
    const Color(0xFFBF360C),  // 深橙
    const Color(0xFF4A148C),  // 深紫
  ];

  // 预设文字颜色
  final List<Color> _presetTextColors = [
    Colors.white,
    const Color(0xFFFFD700),  // 金色
    const Color(0xFF00FF00),  // 亮绿
    const Color(0xFF00BFFF),  // 天蓝
    const Color(0xFFFF69B4),  // 粉色
    const Color(0xFF333333),  // 深灰
    const Color(0xFF666666),  // 中灰
    Colors.black,
    const Color(0xFFFFA500),  // 橙色
    const Color(0xFF00FFFF),  // 青色
    const Color(0xFFFF6347),  // 番茄红
    const Color(0xFF98FB98),  // 淡绿
  ];

  // 预设样式主题
  static const List<Map<String, dynamic>> _styleThemes = [
    {'name': '经典蓝', 'icon': Icons.water_drop, 'bg': 0xFF5B6CFF, 'word': 0xFFFFFFFF, 'trans': 0xFFFFD700},
    {'name': '森林绿', 'icon': Icons.forest, 'bg': 0xFF2E7D32, 'word': 0xFFFFFFFF, 'trans': 0xFF90EE90},
    {'name': '玫瑰红', 'icon': Icons.local_florist, 'bg': 0xFFE91E63, 'word': 0xFFFFFFFF, 'trans': 0xFFFFB6C1},
    {'name': '深邃夜', 'icon': Icons.nightlight, 'bg': 0xFF1A1A2E, 'word': 0xFFE0E0E0, 'trans': 0xFF64B5F6},
    {'name': '暖阳橙', 'icon': Icons.wb_sunny, 'bg': 0xFFFF9800, 'word': 0xFF333333, 'trans': 0xFF5D4037},
    {'name': '薰衣草', 'icon': Icons.spa, 'bg': 0xFF9C27B0, 'word': 0xFFFFFFFF, 'trans': 0xFFE1BEE7},
    {'name': '极简白', 'icon': Icons.brightness_high, 'bg': 0xFFFFFFFF, 'word': 0xFF333333, 'trans': 0xFF5B6CFF},
    {'name': '商务灰', 'icon': Icons.business, 'bg': 0xFF37474F, 'word': 0xFFFFFFFF, 'trans': 0xFF80CBC4},
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _checkRunningState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WordBookProvider>(context, listen: false);
      if (provider.books.isNotEmpty) {
        setState(() {
          _selectedBookId = provider.books.first.bookId;
        });
      }
    });
  }

  Future<void> _checkRunningState() async {
    final running = await StickyPipeService.checkProcessRunning();
    if (mounted) {
      setState(() => _isRunning = running);
    }
  }

  void _loadConfig() {
    final config = ExtensionSettingsService.instance.getStickerConfig();
    _stickerCount = (config['stickerCount'] as num?)?.toInt() ?? 8;
    _fontSize = (config['fontSize'] as num?)?.toDouble() ?? 16.0;
    _opacity = (config['opacity'] as num?)?.toDouble() ?? 0.95;
    _layout = config['layout'] as String? ?? 'random';
    _spacing = (config['spacing'] as num?)?.toDouble() ?? 25.0;
    _styleIndex = (config['styleIndex'] as num?)?.toInt() ?? 0;
    _bgColor = Color((config['bgColor'] as num?)?.toInt() ?? 0xFF5B6CFF);
    _wordColor = Color((config['wordColor'] as num?)?.toInt() ?? 0xFFFFFFFF);
    _transColor = Color((config['transColor'] as num?)?.toInt() ?? 0xFFFFD700);
  }

  Future<void> _saveConfigSilently() async {
    await ExtensionSettingsService.instance.saveStickerConfig({
      'stickerCount': _stickerCount,
      'fontSize': _fontSize,
      'opacity': _opacity,
      'layout': _layout,
      'spacing': _spacing,
      'styleIndex': _styleIndex,
      'bgColor': _colorToInt(_bgColor),
      'wordColor': _colorToInt(_wordColor),
      'transColor': _colorToInt(_transColor),
    });
  }

  /// Convert Color to int (ARGB format)
  int _colorToInt(Color color) {
    return (color.a * 255).round() << 24 |
           (color.r * 255).round() << 16 |
           (color.g * 255).round() << 8 |
           (color.b * 255).round();
  }

  @override
  void dispose() {
    // 不再在 dispose 时自动停止贴纸，让用户手动控制
    // 这样切换到其他插件页面时贴纸仍可继续运行
    super.dispose();
  }

  Future<void> _startSticky() async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<WordBookProvider>(context, listen: false);

    if (_selectedBookId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先选择词书')),
      );
      return;
    }

    // 获取单词
    final wordsMap = await provider.getWordsForBook(_selectedBookId!, limit: _stickerCount);

    if (wordsMap.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('选中的词书没有单词')),
        );
      }
      return;
    }

    // 启动贴纸overlay
    final result = await StickyPipeService.launchStickyOverlay();

    if (mounted) {
      if (result.success) {
        setState(() => _isRunning = true);

        // 根据布局方式计算位置
        final stickers = _generateStickerPositions(wordsMap);
        await StickyPipeService.loadSpace(stickers);

        messenger.showSnackBar(
          const SnackBar(content: Text('桌面贴纸已启动！可拖拽移动贴纸')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? '启动失败，请确保 StickyOverlay.exe 已编译')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _generateStickerPositions(List<Map<String, dynamic>> words) {
    final List<Map<String, dynamic>> stickers = [];
    final random = DateTime.now().millisecond;

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      double x, y;

      switch (_layout) {
        case 'grid':
          // 网格布局
          const cols = 4;
          x = 50.0 + (i % cols) * (200 + _spacing);
          y = 50.0 + (i ~/ cols) * (100 + _spacing);
          break;
        case 'cascade':
          // 阶梯布局
          x = 50.0 + i * 30.0;
          y = 50.0 + i * 80.0;
          break;
        default:
          // 随机布局
          x = 50.0 + ((random + i * 137) % 800).toDouble();
          y = 50.0 + ((random + i * 97) % 500).toDouble();
      }

      stickers.add({
        'word': word['Word'] ?? '',
        'phonetic': word['SymbolUs'] ?? '',
        'translation': word['Translate'] ?? '',
        'x': x,
        'y': y,
        'styleIndex': _styleIndex,
      });
    }

    return stickers;
  }

  Future<void> _stopSticky() async {
    await StickyPipeService.stop();
    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _clearStickers() async {
    await StickyPipeService.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空所有贴纸')),
      );
    }
  }

  Future<void> _addMoreStickers() async {
    if (!_isRunning || _selectedBookId == null) return;

    final provider = Provider.of<WordBookProvider>(context, listen: false);
    final wordsMap = await provider.getWordsForBook(_selectedBookId!, limit: 5);

    for (var i = 0; i < wordsMap.length; i++) {
      final word = wordsMap[i];
      await StickyPipeService.addSticker(
        word: word['Word'] ?? '',
        phonetic: word['SymbolUs'] ?? '',
        translation: word['Translate'] ?? '',
        x: 100 + (DateTime.now().millisecond % 600).toDouble(),
        y: 100 + ((DateTime.now().millisecond + i * 100) % 400).toDouble(),
        styleIndex: _styleIndex,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${wordsMap.length} 个贴纸')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordBookProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDataSourceSection(provider.books),
              const SizedBox(height: 24),
              _buildLayoutSection(),
              const SizedBox(height: 24),
              _buildStyleSection(),
              const SizedBox(height: 24),
              _buildPreview(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRunning ? Colors.green.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRunning ? Colors.green : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _isRunning ? Colors.green : const Color(0xFF5B6CFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sticky_note_2, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('贴纸插件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  _isRunning ? '运行中 - 可拖拽移动贴纸' : '把词库里的单词贴在桌面上',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isRunning ? Colors.green : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          if (_isRunning) ...[
            IconButton(
              onPressed: _addMoreStickers,
              icon: const Icon(Icons.add),
              tooltip: '添加更多',
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                foregroundColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _clearStickers,
              icon: const Icon(Icons.clear_all),
              tooltip: '清空全部',
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                foregroundColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _stopSticky,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('停止'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: _startSticky,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('启动贴纸'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B6CFF),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataSourceSection(List<WordBook> books) {
    return _buildSection(
      '数据源',
      Icons.library_books,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择词书', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _selectedBookId,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('选择词书'),
              items: books.map<DropdownMenuItem<String>>((book) {
                return DropdownMenuItem<String>(
                  value: book.bookId,
                  child: Text('${book.bookName} (${book.wordCount}词)'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedBookId = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            '贴纸数量',
            _stickerCount.toDouble(),
            1,
            10,
            '个',
            (v) {
              setState(() => _stickerCount = v.toInt());
              _saveConfigSilently();
            },
            divisions: 9,
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutSection() {
    return _buildSection(
      '布局方式',
      Icons.grid_view,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              _buildLayoutChip('随机分布', 'random', Icons.shuffle),
              _buildLayoutChip('网格排列', 'grid', Icons.grid_4x4),
              _buildLayoutChip('阶梯排列', 'cascade', Icons.view_agenda),
            ],
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            '贴纸间距',
            _spacing,
            10,
            50,
            'px',
            (v) {
              setState(() => _spacing = v);
              _saveConfigSilently();
            },
            divisions: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutChip(String label, String value, IconData icon) {
    final isSelected = _layout == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _layout = value);
        _saveConfigSilently();
      },
      selectedColor: const Color(0xFF5B6CFF),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  Widget _buildStyleSection() {
    return _buildSection(
      '贴纸样式',
      Icons.palette,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 样式主题选择
          const Text('快速主题', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _styleThemes.asMap().entries.map((entry) {
              final theme = entry.value;
              final isSelected = _colorToInt(_bgColor) == theme['bg'] &&
                                 _colorToInt(_wordColor) == theme['word'] &&
                                 _colorToInt(_transColor) == theme['trans'];
              return ActionChip(
                avatar: Icon(theme['icon'] as IconData, size: 16,
                  color: isSelected ? Colors.white : Color(theme['bg'] as int)),
                label: Text(theme['name'] as String),
                backgroundColor: isSelected ? const Color(0xFF5B6CFF) : Colors.grey[100],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                ),
                onPressed: () {
                  setState(() {
                    _bgColor = Color(theme['bg'] as int);
                    _wordColor = Color(theme['word'] as int);
                    _transColor = Color(theme['trans'] as int);
                  });
                  _saveConfigSilently();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // 自定义设置
          const Text('自定义设置', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 12),
          _buildSliderRow(
            '字体大小',
            _fontSize,
            12,
            24,
            'px',
            (v) {
              setState(() => _fontSize = v);
              _saveConfigSilently();
            },
            divisions: 12,
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '透明度',
            _opacity,
            0.5,
            1.0,
            '',
            (v) {
              setState(() => _opacity = v);
              _saveConfigSilently();
            },
            divisions: 10,
          ),
          const SizedBox(height: 16),
          _buildColorPickerRow('背景颜色', _bgColor, (c) {
            setState(() => _bgColor = c);
            _saveConfigSilently();
          }, colors: _presetBgColors),
          const SizedBox(height: 12),
          _buildColorPickerRow('单词颜色', _wordColor, (c) {
            setState(() => _wordColor = c);
            _saveConfigSilently();
          }, colors: _presetTextColors),
          const SizedBox(height: 12),
          _buildColorPickerRow('翻译颜色', _transColor, (c) {
            setState(() => _transColor = c);
            _saveConfigSilently();
          }, colors: _presetTextColors),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return _buildSection(
      '效果预览',
      Icons.preview,
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStickerPreview('represent', '/reprɪˈzent/', 'v. 代表'),
            _buildStickerPreview('essential', '/ɪˈsenʃl/', 'adj. 必要的'),
            _buildStickerPreview('achieve', '/əˈtʃiːv/', 'v. 实现'),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerPreview(String word, String phonetic, String trans) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: _opacity),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _bgColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: TextStyle(
              color: _wordColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            phonetic,
            style: TextStyle(
              color: _wordColor.withValues(alpha: 0.7),
              fontSize: _fontSize - 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trans,
            style: TextStyle(
              color: _transColor,
              fontSize: _fontSize - 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    String suffix,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).toInt(),
            onChanged: onChanged,
            activeColor: const Color(0xFF5B6CFF),
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}$suffix',
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildColorPickerRow(String label, Color value, ValueChanged<Color> onChanged, {required List<Color> colors}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected = value == color;
              return GestureDetector(
                onTap: () => onChanged(color),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF5B6CFF) : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 16, color: color == Colors.white ? Colors.black : Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ============ OFFLINE TTS ============
class _OfflineTtsPage extends StatefulWidget {
  const _OfflineTtsPage();

  @override
  State<_OfflineTtsPage> createState() => _OfflineTtsPageState();
}

class _OfflineTtsPageState extends State<_OfflineTtsPage> {
  double _speechRate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;
  String? _selectedVoice;
  List<Map<String, String>> _voices = [];
  bool _isInitialized = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      final tts = TtsService.instance;
      await tts.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = tts.isInitialized;
          _speechRate = tts.speechRate;
          _volume = tts.volume;
          _pitch = tts.pitch;
          _selectedVoice = tts.currentVoice;

          // Parse voices
          _voices = [];
          for (var voice in tts.availableVoices) {
            if (voice is Map) {
              final name = voice['name']?.toString() ?? '';
              final locale = voice['locale']?.toString() ?? '';
              if (name.isNotEmpty) {
                _voices.add({'name': name, 'locale': locale});
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testSpeak() async {
    await TtsService.instance.speak('Hello, this is a test of the text to speech engine.');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!_isInitialized)
            _buildErrorState()
          else
            _buildSettings(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isInitialized ? Colors.green : const Color(0xFF5B6CFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _isInitialized ? Icons.volume_up : Icons.record_voice_over_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('离线语音引擎', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              _isInitialized ? '已启用 - ${_voices.length} 个语音可用' : '本地TTS发音引擎',
              style: TextStyle(fontSize: 13, color: _isInitialized ? Colors.green : Colors.grey[500]),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _testSpeak,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('测试发音'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B6CFF),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          Icon(Icons.error_outline, size: 80, color: Colors.red[200]),
          const SizedBox(height: 16),
          Text('TTS引擎初始化失败', style: TextStyle(color: Colors.red[400], fontSize: 16)),
          const SizedBox(height: 8),
          Text('请检查系统是否安装了语音引擎', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _initTts,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Voice Selection
        const Text('语音选择', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _selectedVoice,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text('选择语音'),
            items: _voices.map((voice) {
              return DropdownMenuItem<String>(
                value: voice['name'],
                child: Text('${voice['name']} (${voice['locale']})'),
              );
            }).toList(),
            onChanged: (value) async {
              if (value != null) {
                final voice = _voices.firstWhere(
                  (v) => v['name'] == value,
                  orElse: () => {'name': value, 'locale': 'en-US'},
                );
                await TtsService.instance.setVoice(value, voice['locale'] ?? 'en-US');
                setState(() => _selectedVoice = value);
              }
            },
          ),
        ),

        const SizedBox(height: 24),

        // Speech Rate
        Row(
          children: [
            const SizedBox(width: 100, child: Text('语速')),
            Expanded(
              child: Slider(
                value: _speechRate,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: _speechRate < 0.4 ? '慢' : (_speechRate > 0.6 ? '快' : '正常'),
                onChanged: (value) async {
                  await TtsService.instance.setSpeechRate(value);
                  setState(() => _speechRate = value);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text('${(_speechRate * 100).toInt()}%'),
            ),
          ],
        ),

        // Volume
        Row(
          children: [
            const SizedBox(width: 100, child: Text('音量')),
            Expanded(
              child: Slider(
                value: _volume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                onChanged: (value) async {
                  await TtsService.instance.setVolume(value);
                  setState(() => _volume = value);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text('${(_volume * 100).toInt()}%'),
            ),
          ],
        ),

        // Pitch
        Row(
          children: [
            const SizedBox(width: 100, child: Text('音调')),
            Expanded(
              child: Slider(
                value: _pitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: _pitch < 0.8 ? '低' : (_pitch > 1.2 ? '高' : '正常'),
                onChanged: (value) async {
                  await TtsService.instance.setPitch(value);
                  setState(() => _pitch = value);
                },
              ),
            ),
            SizedBox(
              width: 50,
              child: Text('${_pitch.toStringAsFixed(1)}x'),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '离线语音引擎使用Windows系统自带的SAPI语音合成，无需联网即可发音。可在系统设置中安装更多语音包。',
                  style: TextStyle(color: Colors.blue[700], fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

