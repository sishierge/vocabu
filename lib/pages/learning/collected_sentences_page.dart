import 'package:flutter/material.dart';
import '../../services/sentence_collection_service.dart';
import '../../services/unified_audio_service.dart';

/// 收藏句子列表页面
class CollectedSentencesPage extends StatefulWidget {
  final bool showDifficultOnly; // 是否只显示难句

  const CollectedSentencesPage({
    super.key,
    this.showDifficultOnly = false,
  });

  @override
  State<CollectedSentencesPage> createState() => _CollectedSentencesPageState();
}

class _CollectedSentencesPageState extends State<CollectedSentencesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _playingIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showDifficultOnly ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    UnifiedAudioService.instance.stop();
    super.dispose();
  }

  List<CollectedSentence> get _collectedList =>
      SentenceCollectionService.instance.collected;

  List<CollectedSentence> get _difficultList =>
      SentenceCollectionService.instance.difficult;

  Future<void> _playSentence(String text, int index) async {
    setState(() => _playingIndex = index);
    await UnifiedAudioService.instance.play(text: text);
    if (mounted) {
      setState(() => _playingIndex = -1);
    }
  }

  Future<void> _uncollectSentence(String english, bool isDifficult) async {
    if (isDifficult) {
      await SentenceCollectionService.instance.unmarkDifficult(english);
    } else {
      await SentenceCollectionService.instance.uncollectSentence(english);
    }
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDifficult ? '已移除难句标记' : '已取消收藏'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _startPractice(List<CollectedSentence> sentences, String title) {
    if (sentences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可练习的句子')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SentencePracticePage(
          sentences: sentences,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '句子收藏',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, size: 18),
                  const SizedBox(width: 6),
                  Text('收藏 (${_collectedList.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag, size: 18),
                  const SizedBox(width: 6),
                  Text('难句 (${_difficultList.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSentenceList(_collectedList, false),
          _buildSentenceList(_difficultList, true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final isCollectedTab = _tabController.index == 0;
          _startPractice(
            isCollectedTab ? _collectedList : _difficultList,
            isCollectedTab ? '收藏句子练习' : '难句专项练习',
          );
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始练习'),
      ),
    );
  }

  Widget _buildSentenceList(List<CollectedSentence> sentences, bool isDifficult) {
    final colorScheme = Theme.of(context).colorScheme;

    if (sentences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDifficult ? Icons.flag_outlined : Icons.favorite_border,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isDifficult ? '暂无标记的难句' : '暂无收藏的句子',
              style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              isDifficult ? '在听力练习中标记难句' : '在听力练习中收藏句子',
              style: TextStyle(fontSize: 13, color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sentences.length,
      itemBuilder: (context, index) {
        final sentence = sentences[index];
        final isPlaying = _playingIndex == index + (isDifficult ? 1000 : 0);

        return _SentenceCard(
          sentence: sentence,
          isPlaying: isPlaying,
          isDifficult: isDifficult,
          onPlay: () => _playSentence(
            sentence.english,
            index + (isDifficult ? 1000 : 0),
          ),
          onRemove: () => _uncollectSentence(sentence.english, isDifficult),
        );
      },
    );
  }
}

class _SentenceCard extends StatelessWidget {
  final CollectedSentence sentence;
  final bool isPlaying;
  final bool isDifficult;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _SentenceCard({
    required this.sentence,
    required this.isPlaying,
    required this.isDifficult,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 英文句子
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    sentence.english,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 播放按钮
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.stop_circle : Icons.play_circle,
                    color: colorScheme.primary,
                  ),
                  onPressed: onPlay,
                  tooltip: isPlaying ? '停止' : '播放',
                ),
                // 移除按钮
                IconButton(
                  icon: Icon(
                    isDifficult ? Icons.flag : Icons.favorite,
                    color: isDifficult ? Colors.orange : Colors.red,
                  ),
                  onPressed: onRemove,
                  tooltip: isDifficult ? '取消难句标记' : '取消收藏',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 中文翻译
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                sentence.chinese,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSecondaryContainer,
                  height: 1.4,
                ),
              ),
            ),
            // 来源信息
            if (sentence.materialName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.source, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    sentence.materialName!,
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(sentence.collectedAt),
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

/// 句子练习页面
class _SentencePracticePage extends StatefulWidget {
  final List<CollectedSentence> sentences;
  final String title;

  const _SentencePracticePage({
    required this.sentences,
    required this.title,
  });

  @override
  State<_SentencePracticePage> createState() => _SentencePracticePageState();
}

class _SentencePracticePageState extends State<_SentencePracticePage> {
  int _currentIndex = 0;
  bool _showEnglish = false;
  bool _showChinese = false;
  bool _isPlaying = false;

  CollectedSentence get _currentSentence => widget.sentences[_currentIndex];

  @override
  void initState() {
    super.initState();
    _playSentence();
  }

  @override
  void dispose() {
    UnifiedAudioService.instance.stop();
    super.dispose();
  }

  Future<void> _playSentence() async {
    setState(() => _isPlaying = true);
    await UnifiedAudioService.instance.play(
      text: _currentSentence.english,
      audioUrl: _currentSentence.audioUrl,
    );
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  void _nextSentence() {
    if (_currentIndex < widget.sentences.length - 1) {
      setState(() {
        _currentIndex++;
        _showEnglish = false;
        _showChinese = false;
      });
      _playSentence();
    }
  }

  void _prevSentence() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showEnglish = false;
        _showChinese = false;
      });
      _playSentence();
    }
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
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1} / ${widget.sentences.length}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 进度条
          LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.sentences.length,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 播放按钮
                  GestureDetector(
                    onTap: _playSentence,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isPlaying
                              ? [Colors.red[400]!, Colors.red[600]!]
                              : [colorScheme.primary, colorScheme.primaryContainer],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.stop : Icons.play_arrow,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 句子卡片
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        // 英文
                        GestureDetector(
                          onTap: () => setState(() => _showEnglish = !_showEnglish),
                          child: AnimatedCrossFade(
                            firstChild: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.visibility, color: colorScheme.outline),
                                  const SizedBox(width: 8),
                                  Text(
                                    '点击显示英文',
                                    style: TextStyle(color: colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            secondChild: Text(
                              _currentSentence.english,
                              style: TextStyle(
                                fontSize: 18,
                                color: colorScheme.onSurface,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            crossFadeState: _showEnglish
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 中文
                        GestureDetector(
                          onTap: () => setState(() => _showChinese = !_showChinese),
                          child: AnimatedCrossFade(
                            firstChild: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.translate, color: colorScheme.outline),
                                  const SizedBox(width: 8),
                                  Text(
                                    '点击显示翻译',
                                    style: TextStyle(color: colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            secondChild: Text(
                              _currentSentence.chinese,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            crossFadeState: _showChinese
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部控制栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _prevSentence : null,
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: _currentIndex > 0
                        ? colorScheme.onSurface
                        : colorScheme.outline,
                    size: 32,
                  ),
                ),
                IconButton(
                  onPressed: _playSentence,
                  icon: Icon(Icons.replay, color: colorScheme.primary, size: 28),
                ),
                IconButton(
                  onPressed: _currentIndex < widget.sentences.length - 1
                      ? _nextSentence
                      : null,
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: _currentIndex < widget.sentences.length - 1
                        ? colorScheme.onSurface
                        : colorScheme.outline,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
