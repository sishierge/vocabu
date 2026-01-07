import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/word_book_provider.dart';
import '../../services/danmu_pipe_service.dart';
import '../../services/extension_settings_service.dart';
import '../../services/translation_service.dart';

class DanmuPluginPage extends StatefulWidget {
  const DanmuPluginPage({super.key});

  @override
  State<DanmuPluginPage> createState() => _DanmuPluginPageState();
}

class _DanmuPluginPageState extends State<DanmuPluginPage> {
  bool _isRunning = false;
  bool _isPaused = false;

  // === 弹幕区域设置 ===
  late double _areaTop;
  late double _areaHeight;

  // === 弹幕样式设置 ===
  late double _speed;
  late double _fontSize;
  late int _spawnInterval;
  late bool _showTranslation;
  late Color _wordColor;
  late Color _transColor;
  late Color _bgColor;
  late double _opacity;

  // === 例句设置 ===
  late String _examplePosition;
  late double _exampleOffsetY;

  // === 数据源设置 ===
  String? _selectedBookId;

  // 预设颜色
  final List<Color> _presetColors = [
    const Color(0xFFFFFFFF),
    const Color(0xFFFFD700),
    const Color(0xFF00FF00),
    const Color(0xFF00BFFF),
    const Color(0xFFFF69B4),
    const Color(0xFFFF6347),
    const Color(0xFF9370DB),
    const Color(0xFF00CED1),
  ];

  final List<Color> _presetBgColors = [
    const Color(0xFF5B6CFF),
    const Color(0xFF2E7D32),
    const Color(0xFFE91E63),
    const Color(0xFF00BCD4),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF333333),
    Colors.transparent,
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
    final running = await DanmuPipeService.checkProcessRunning();
    if (mounted) {
      setState(() => _isRunning = running);
    }
  }

  void _loadConfig() {
    final config = ExtensionSettingsService.instance.getDanmuConfig();
    _areaTop = (config['areaTop'] as num?)?.toDouble() ?? 5.0;
    _areaHeight = (config['areaHeight'] as num?)?.toDouble() ?? 60.0;
    // 确保速度在有效范围内 (0.1-1.5)
    final loadedSpeed = (config['speed'] as num?)?.toDouble() ?? 0.6;
    _speed = loadedSpeed.clamp(0.1, 1.5);
    _fontSize = (config['fontSize'] as num?)?.toDouble() ?? 20.0;
    _spawnInterval = (config['spawnInterval'] as num?)?.toInt() ?? 5;
    _showTranslation = config['showTranslation'] as bool? ?? true;
    _wordColor = Color((config['wordColor'] as num?)?.toInt() ?? 0xFFFFFFFF);
    _transColor = Color((config['transColor'] as num?)?.toInt() ?? 0xFFFFD700);
    _bgColor = Color((config['bgColor'] as num?)?.toInt() ?? 0xFF5B6CFF);
    _opacity = (config['opacity'] as num?)?.toDouble() ?? 0.85;
    _examplePosition = config['examplePosition'] as String? ?? 'bottom-center';
    _exampleOffsetY = (config['exampleOffsetY'] as num?)?.toDouble() ?? 80.0;
  }


  @override
  void dispose() {
    // 不再在 dispose 时自动停止弹幕，让用户手动控制
    // 这样切换到其他插件页面时弹幕仍可继续运行
    super.dispose();
  }

  Future<void> _startDanmu() async {
    if (!mounted) return;

    final provider = Provider.of<WordBookProvider>(context, listen: false);

    if (_selectedBookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择词书')),
      );
      return;
    }

    // 显示加载中提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在准备弹幕数据...')),
    );

    // 获取选中词书的单词
    final wordsMap = await provider.getWordsForBook(_selectedBookId!, limit: 200);

    if (wordsMap.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选中的词书没有单词')),
        );
      }
      return;
    }

    // 快速并行获取例句（使用有道API）
    debugPrint('弹幕: 获取到${wordsMap.length}个单词');
    final wordsWithExamples = await _fetchExamplesParallel(wordsMap);

    // 统计有例句的单词数量
    int withExamples = 0;
    for (final w in wordsWithExamples) {
      final example = w['SentenceEn'] as String? ?? w['Example'] as String? ?? '';
      if (example.isNotEmpty) withExamples++;
    }
    debugPrint('弹幕: 共${wordsWithExamples.length}个单词，其中$withExamples个有例句');

    // 发送完整配置到WPF overlay
    final result = await DanmuPipeService.launchDanmuOverlay(
      words: wordsWithExamples,
      config: {
        // 区域设置
        'areaTop': _areaTop,
        'areaHeight': _areaHeight,
        // 样式设置
        'speed': _speed,
        'fontSize': _fontSize,
        'interval': _spawnInterval,
        'showTranslation': _showTranslation,
        'wordColor': _colorToHex(_wordColor),
        'transColor': _colorToHex(_transColor),
        'bgColor': _colorToHex(_bgColor),
        'opacity': _opacity,
        // 例句设置
        'examplePosition': _examplePosition,
        'exampleOffsetY': _exampleOffsetY,
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (result.success) {
        setState(() {
          _isRunning = true;
          _isPaused = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('弹幕已启动！点击弹幕可显示例句')),
        );
      } else {
        // 显示详细的错误信息
        _showLaunchErrorDialog(result);
      }
    }
  }

  /// 并行快速获取例句（使用有道API，和首页查词一样）
  Future<List<Map<String, dynamic>>> _fetchExamplesParallel(List<Map<String, dynamic>> words) async {
    final result = List<Map<String, dynamic>>.from(words);

    // 找出没有例句的单词（最多处理30个）
    final wordsNeedingExamples = <int>[];
    for (int i = 0; i < words.length && wordsNeedingExamples.length < 30; i++) {
      final existingExample = words[i]['SentenceEn'] as String? ??
                              words[i]['Example'] as String? ?? '';
      if (existingExample.isEmpty) {
        wordsNeedingExamples.add(i);
      }
    }

    if (wordsNeedingExamples.isEmpty) {
      debugPrint('弹幕: 所有单词已有例句');
      return result;
    }

    debugPrint('弹幕: 需要获取${wordsNeedingExamples.length}个单词的例句...');

    // 并行获取例句，每个词3秒超时，总超时8秒
    int fetchedCount = 0;
    try {
      final futures = wordsNeedingExamples.map((index) async {
        final wordText = words[index]['Word'] as String? ?? '';
        if (wordText.isEmpty) return null;

        try {
          final definition = await TranslationService.instance.lookupWord(wordText)
              .timeout(const Duration(seconds: 3));
          if (definition != null && definition.examples.isNotEmpty) {
            return MapEntry(index, {
              'example': definition.examples.first,
              'exampleTrans': definition.exampleTranslations.isNotEmpty
                  ? definition.exampleTranslations.first
                  : '',
            });
          }
        } catch (e) {
          debugPrint('弹幕: 获取"$wordText"例句失败: $e');
        }
        return null;
      });

      final results = await Future.wait(futures)
          .timeout(const Duration(seconds: 8), onTimeout: () => []);

      // 更新有例句的单词
      for (final entry in results) {
        if (entry != null) {
          final updatedWord = Map<String, dynamic>.from(result[entry.key]);
          updatedWord['SentenceEn'] = entry.value['example'];
          updatedWord['SentenceCn'] = entry.value['exampleTrans'];
          result[entry.key] = updatedWord;
          fetchedCount++;
        }
      }
    } catch (e) {
      debugPrint('弹幕: 批量获取例句超时: $e');
    }

    debugPrint('弹幕: 成功获取${fetchedCount}个例句');
    return result;
  }

  /// 显示启动失败的详细错误对话框
  void _showLaunchErrorDialog(DanmuLaunchResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400]),
            const SizedBox(width: 8),
            Text(result.errorMessage ?? '弹幕启动失败'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.errorDetails != null) ...[
                Text(
                  '详细信息：',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.errorDetails!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                '解决方案：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. 确保已编译 DanmuOverlay 项目'),
              const Text('2. 检查 DanmuOverlay.exe 是否在正确路径'),
              const Text('3. 检查防火墙是否阻止了程序运行'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopDanmu() async {
    await DanmuPipeService.stop();
    if (mounted) {
      setState(() {
        _isRunning = false;
        _isPaused = false;
      });
    }
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await DanmuPipeService.resume();
    } else {
      await DanmuPipeService.pause();
    }
    if (mounted) {
      setState(() => _isPaused = !_isPaused);
    }
  }

  void _updateConfig() {
    // 自动保存设置到持久化存储
    _saveConfigSilently();

    // 如果弹幕正在运行，实时更新
    if (!_isRunning) return;
    DanmuPipeService.updateConfig(
      areaTop: _areaTop,
      areaHeight: _areaHeight,
      speed: _speed,
      fontSize: _fontSize,
      interval: _spawnInterval,
      showTranslation: _showTranslation,
      wordColor: _colorToHex(_wordColor),
      transColor: _colorToHex(_transColor),
      bgColor: _colorToHex(_bgColor),
      opacity: _opacity,
      examplePosition: _examplePosition,
      exampleOffsetY: _exampleOffsetY,
    );
  }

  /// 静默保存配置（不显示提示）
  Future<void> _saveConfigSilently() async {
    await ExtensionSettingsService.instance.saveDanmuConfig({
      'areaTop': _areaTop,
      'areaHeight': _areaHeight,
      'speed': _speed,
      'fontSize': _fontSize,
      'spawnInterval': _spawnInterval,
      'showTranslation': _showTranslation,
      'wordColor': _colorToInt(_wordColor),
      'transColor': _colorToInt(_transColor),
      'bgColor': _colorToInt(_bgColor),
      'opacity': _opacity,
      'examplePosition': _examplePosition,
      'exampleOffsetY': _exampleOffsetY,
    });
  }

  /// Convert Color to int (ARGB format)
  int _colorToInt(Color color) {
    return (color.a * 255).round() << 24 |
           (color.r * 255).round() << 16 |
           (color.g * 255).round() << 8 |
           (color.b * 255).round();
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
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
              _buildAreaSection(),
              const SizedBox(height: 24),
              _buildStyleSection(),
              const SizedBox(height: 24),
              _buildExampleSection(),
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
            child: const Icon(Icons.subtitles, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('弹幕插件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  _isRunning
                      ? (_isPaused ? '已暂停' : '运行中')
                      : '把词库里的单词通过桌面弹幕展示',
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
              onPressed: _togglePause,
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              tooltip: _isPaused ? '继续' : '暂停',
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                foregroundColor: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _stopDanmu,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('停止'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: _startDanmu,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('启动弹幕'),
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
              items: books.map((book) {
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
        ],
      ),
    );
  }

  Widget _buildAreaSection() {
    return _buildSection(
      '弹幕区域',
      Icons.crop,
      Column(
        children: [
          _buildSliderRow(
            '距顶部',
            _areaTop,
            0,
            80,
            '%',
            (v) {
              setState(() => _areaTop = v);
              _updateConfig();
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '区域高度',
            _areaHeight,
            20,
            100,
            '%',
            (v) {
              setState(() => _areaHeight = v);
              _updateConfig();
            },
          ),
          const SizedBox(height: 12),
          // 区域预览
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: _areaTop,
                  left: 0,
                  right: 0,
                  height: _areaHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B6CFF).withValues(alpha: 0.3),
                      border: Border.all(color: const Color(0xFF5B6CFF), width: 2),
                    ),
                    child: const Center(
                      child: Text('弹幕区域', style: TextStyle(color: Color(0xFF5B6CFF), fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSection() {
    return _buildSection(
      '弹幕样式',
      Icons.palette,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderRow(
            '弹幕速度',
            _speed,
            0.1,
            1.5,
            'x',
            (v) {
              setState(() => _speed = v);
              _updateConfig();
            },
            divisions: 14,
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '字体大小',
            _fontSize,
            12,
            32,
            'px',
            (v) {
              setState(() => _fontSize = v);
              _updateConfig();
            },
            divisions: 20,
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '生成间隔',
            _spawnInterval.toDouble(),
            1,
            10,
            '秒',
            (v) {
              setState(() => _spawnInterval = v.toInt());
              _updateConfig();
            },
            divisions: 9,
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '透明度',
            _opacity,
            0.3,
            1.0,
            '',
            (v) {
              setState(() => _opacity = v);
              _updateConfig();
            },
            divisions: 7,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('显示翻译'),
              const Spacer(),
              Switch(
                value: _showTranslation,
                onChanged: (v) {
                  setState(() => _showTranslation = v);
                  _updateConfig();
                },
                activeColor: const Color(0xFF5B6CFF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildColorPickerRow('单词颜色', _wordColor, (c) {
            setState(() => _wordColor = c);
            _updateConfig();
          }),
          const SizedBox(height: 12),
          _buildColorPickerRow('翻译颜色', _transColor, (c) {
            setState(() => _transColor = c);
            _updateConfig();
          }),
          const SizedBox(height: 12),
          _buildColorPickerRow('背景颜色', _bgColor, (c) {
            setState(() => _bgColor = c);
            _updateConfig();
          }, colors: _presetBgColors),
        ],
      ),
    );
  }

  Widget _buildExampleSection() {
    return _buildSection(
      '例句显示',
      Icons.format_quote,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('点击弹幕时显示例句的位置', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildPositionChip('底部居中', 'bottom-center'),
              _buildPositionChip('底部靠左', 'bottom-left'),
              _buildPositionChip('底部靠右', 'bottom-right'),
              _buildPositionChip('顶部居中', 'top-center'),
            ],
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '距离边缘',
            _exampleOffsetY,
            20,
            200,
            'px',
            (v) {
              setState(() => _exampleOffsetY = v);
              _updateConfig();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPositionChip(String label, String value) {
    final isSelected = _examplePosition == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _examplePosition = value);
        _updateConfig();
      },
      selectedColor: const Color(0xFF5B6CFF).withValues(alpha: 0.2),
    );
  }

  Widget _buildPreview() {
    return _buildSection(
      '效果预览',
      Icons.preview,
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // 弹幕预览 - 分段布局（单词在上，翻译在下）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _bgColor.withValues(alpha: _opacity),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _bgColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'represent',
                    style: TextStyle(
                      color: _wordColor,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_showTranslation) ...[
                    const SizedBox(height: 4),
                    Text(
                      'v. 代表',
                      style: TextStyle(
                        color: _transColor,
                        fontSize: _fontSize - 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 例句预览
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '点击弹幕后显示:',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'He represents the company at international conferences.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '他代表公司参加国际会议。',
                    style: TextStyle(color: _transColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildColorPickerRow(String label, Color value, ValueChanged<Color> onChanged, {List<Color>? colors}) {
    final colorList = colors ?? _presetColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colorList.map((color) {
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
                    boxShadow: color == Colors.transparent
                        ? null
                        : [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                  child: color == Colors.transparent
                      ? const Icon(Icons.block, size: 16, color: Colors.grey)
                      : (isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
