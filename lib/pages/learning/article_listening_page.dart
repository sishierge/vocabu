import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/tts_service.dart';
import '../../services/listening_materials_service.dart';

/// 文章听力页面 - 支持完整文章播放和句子高亮
class ArticleListeningPage extends StatefulWidget {
  final String? initialMaterialId;
  
  const ArticleListeningPage({super.key, this.initialMaterialId});

  @override
  State<ArticleListeningPage> createState() => _ArticleListeningPageState();
}

class _ArticleListeningPageState extends State<ArticleListeningPage> {
  List<Map<String, String>> _sentences = [];
  int _currentSentenceIndex = -1;
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isContinuousMode = true; // 连续播放模式
  bool _showTranslation = true;
  String _currentMaterialName = '';
  String _currentMaterialId = '';
  
  // 语速控制
  double _speechRate = 0.5;
  
  // 滚动控制
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sentenceKeys = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialMaterialId != null) {
      _loadMaterial(widget.initialMaterialId!);
    } else {
      // 默认加载第一个素材
      if (ListeningMaterialsService.sources.isNotEmpty) {
        _loadMaterial(ListeningMaterialsService.sources.first.id);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _loadMaterial(String materialId) async {
    setState(() => _isLoading = true);
    
    try {
      final source = ListeningMaterialsService.sources.firstWhere(
        (s) => s.id == materialId,
        orElse: () => ListeningMaterialsService.sources.first,
      );
      
      final sentences = await ListeningMaterialsService.instance.fetchMaterialContent(materialId);
      
      setState(() {
        _sentences = sentences;
        _currentMaterialName = source.name;
        _currentMaterialId = materialId;
        _currentSentenceIndex = -1;
        _isLoading = false;
        _sentenceKeys.clear();
        for (int i = 0; i < sentences.length; i++) {
          _sentenceKeys.add(GlobalKey());
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading material: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  void _showMaterialPicker() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.article, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '选择文章素材',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant, height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: ListeningMaterialsService.sources.length,
                itemBuilder: (context, index) {
                  final source = ListeningMaterialsService.sources[index];
                  final isSelected = _currentMaterialId == source.id;
                  return ListTile(
                    leading: Text(source.icon, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      source.name,
                      style: TextStyle(
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${source.sentenceCount} 句 · ${source.difficulty}',
                      style: TextStyle(color: colorScheme.outline, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _loadMaterial(source.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playSentence(int index) async {
    if (index < 0 || index >= _sentences.length) return;
    
    setState(() {
      _currentSentenceIndex = index;
      _isPlaying = true;
    });
    
    // 滚动到当前句子
    _scrollToSentence(index);
    
    await TtsService.instance.setSpeechRate(_speechRate);
    await TtsService.instance.speak(_sentences[index]['en'] ?? '');
    
    if (!mounted) return;
    
    setState(() => _isPlaying = false);
    
    // 连续播放模式下自动播放下一句
    if (_isContinuousMode && index < _sentences.length - 1) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _isContinuousMode) {
        _playSentence(index + 1);
      }
    }
  }

  void _scrollToSentence(int index) {
    if (index < 0 || index >= _sentenceKeys.length) return;
    
    final key = _sentenceKeys[index];
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _stopPlaying() {
    TtsService.instance.stop();
    setState(() {
      _isPlaying = false;
      _isContinuousMode = false;
    });
  }

  void _playAll() {
    setState(() => _isContinuousMode = true);
    _playSentence(0);
  }

  void _playFromCurrent() {
    setState(() => _isContinuousMode = true);
    _playSentence(_currentSentenceIndex >= 0 ? _currentSentenceIndex : 0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () {
            _stopPlaying();
            Navigator.pop(context);
          },
        ),
        title: GestureDetector(
          onTap: _showMaterialPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentMaterialName.isEmpty ? '文章听力' : _currentMaterialName,
                style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: colorScheme.primary),
            ],
          ),
        ),
        actions: [
          // 显示翻译开关
          IconButton(
            icon: Icon(
              _showTranslation ? Icons.translate : Icons.translate_outlined,
              color: _showTranslation ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => _showTranslation = !_showTranslation),
            tooltip: '显示翻译',
          ),
          // 设置
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Column(
              children: [
                // 文章内容区域
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _sentences.length,
                    itemBuilder: (context, index) {
                      final sentence = _sentences[index];
                      final isCurrentSentence = index == _currentSentenceIndex;

                      return GestureDetector(
                        key: _sentenceKeys[index],
                        onTap: () {
                          setState(() => _isContinuousMode = false);
                          _playSentence(index);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrentSentence
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isCurrentSentence
                                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.5), width: 1)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 句子序号和英文
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isCurrentSentence
                                          ? colorScheme.primary
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isCurrentSentence
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      sentence['en'] ?? '',
                                      style: TextStyle(
                                        color: isCurrentSentence
                                            ? colorScheme.onSurface
                                            : colorScheme.onSurfaceVariant,
                                        fontSize: 16,
                                        height: 1.5,
                                        fontWeight: isCurrentSentence
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentSentence && _isPlaying)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.volume_up,
                                        color: colorScheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                              // 中文翻译
                              if (_showTranslation && (sentence['cn'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 36, top: 8),
                                  child: Text(
                                    sentence['cn'] ?? '',
                                    style: TextStyle(
                                      color: colorScheme.outline,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 底部播放控制栏
                _buildControlBar(),
              ],
            ),
    );
  }

  Widget _buildControlBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 进度显示
            Text(
              '${_currentSentenceIndex + 1}/${_sentences.length}',
              style: TextStyle(color: colorScheme.outline, fontSize: 13),
            ),
            const SizedBox(width: 16),

            // 语速显示
            GestureDetector(
              onTap: _showSettingsDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_speechRate * 2).toStringAsFixed(1)}x',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ),
            ),

            const Spacer(),

            // 上一句
            IconButton(
              icon: Icon(Icons.skip_previous, color: colorScheme.onSurfaceVariant),
              onPressed: _currentSentenceIndex > 0
                  ? () {
                      setState(() => _isContinuousMode = false);
                      _playSentence(_currentSentenceIndex - 1);
                    }
                  : null,
            ),

            // 播放/暂停
            GestureDetector(
              onTap: _isPlaying ? _stopPlaying : _playFromCurrent,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPlaying
                        ? [Colors.red[400]!, Colors.red[600]!]
                        : [colorScheme.primary, colorScheme.primaryContainer],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),

            // 下一句
            IconButton(
              icon: Icon(Icons.skip_next, color: colorScheme.onSurfaceVariant),
              onPressed: _currentSentenceIndex < _sentences.length - 1
                  ? () {
                      setState(() => _isContinuousMode = false);
                      _playSentence(_currentSentenceIndex + 1);
                    }
                  : null,
            ),

            const Spacer(),

            // 连续播放模式
            IconButton(
              icon: Icon(
                _isContinuousMode ? Icons.repeat_one_on : Icons.playlist_play,
                color: _isContinuousMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                if (_isContinuousMode) {
                  setState(() => _isContinuousMode = false);
                } else {
                  _playAll();
                }
              },
              tooltip: '连续播放',
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '播放设置',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // 语速设置
              Row(
                children: [
                  Text('语速', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Text(
                    '${(_speechRate * 2).toStringAsFixed(1)}x',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ],
              ),
              Slider(
                value: _speechRate,
                min: 0.2,
                max: 1.0,
                divisions: 8,
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.surfaceContainerHighest,
                onChanged: (v) {
                  setState(() => _speechRate = v);
                  setModalState(() {});
                },
              ),

              const SizedBox(height: 16),

              // 显示翻译
              SwitchListTile(
                title: Text('显示翻译', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                value: _showTranslation,
                activeColor: colorScheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() => _showTranslation = v);
                  setModalState(() {});
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
