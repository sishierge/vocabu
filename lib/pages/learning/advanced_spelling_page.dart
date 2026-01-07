import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/word_book_provider.dart';
import '../../services/tts_service.dart';
import '../../services/learning_stats_service.dart';
import '../../services/algorithm_scheduler.dart';

/// 高级拼写 - 完全按照原版设计（含设置面板）
class AdvancedSpellingPage extends StatefulWidget {
  final String? bookId;
  final String? bookName;

  const AdvancedSpellingPage({super.key, this.bookId, this.bookName});

  @override
  State<AdvancedSpellingPage> createState() => _AdvancedSpellingPageState();
}

class _AdvancedSpellingPageState extends State<AdvancedSpellingPage> {
  List<Map<String, dynamic>> _items = [];
  int _currentIndex = 0;
  int _errorCount = 0;
  bool _isLoading = true;
  bool _isSentenceMode = false;
  
  // 当前拼写状态
  String _targetText = '';
  String _userInput = '';
  bool _showFullAnswer = false;
  
  // 设置项
  double _translationFontSize = 40;
  double _wordFontSize = 25;
  int _autoPlayCount = 1;
  bool _showSymbol = true;
  bool _showTranslation = true;
  bool _pauseOnComplete = true;
  bool _highlightErrors = true;
  int _keyboardSound = 3; // 0=关闭, 1-5=音效
  bool _errorSound = true;
  bool _correctSound = true;
  
  final FocusNode _focusNode = FocusNode();
  final AlgorithmScheduler _scheduler = AlgorithmScheduler.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final provider = WordBookProvider.instance;
    final bookId = widget.bookId ?? provider.books.firstOrNull?.bookId;
    
    if (bookId != null) {
      final sentences = await provider.getSentencesForBook(bookId, limit: 50);
      
      if (!mounted) return;
      
      if (sentences.isNotEmpty) {
        setState(() {
          _items = sentences;
          _isSentenceMode = true;
          _isLoading = false;
        });
      } else {
        final reviewWords = await provider.getWordsForReview(bookId, limit: 30);
        final newWords = await provider.getWordsForBook(bookId, status: 0, limit: 20);
        
        if (!mounted) return;
        
        setState(() {
          _items = [...reviewWords, ...newWords];
          _items.shuffle();
          _isSentenceMode = false;
          _isLoading = false;
        });
      }
      
      if (_items.isNotEmpty) {
        _initCurrentItem();
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    
    _focusNode.requestFocus();
  }

  void _initCurrentItem() {
    if (_currentIndex >= _items.length) return;
    
    final item = _items[_currentIndex];
    _targetText = _isSentenceMode 
        ? item['SentenceText'] as String? ?? ''
        : item['Word'] as String? ?? '';
    _userInput = '';
    _showFullAnswer = false;
    setState(() {});
    
    // 自动播放单词读音
    if (_targetText.isNotEmpty && _autoPlayCount > 0) {
      _autoPlayWord();
    }
  }

  /// 自动播放单词读音
  Future<void> _autoPlayWord() async {
    for (int i = 0; i < _autoPlayCount; i++) {
      if (!mounted) return;
      await TtsService.instance.speak(_targetText);
      if (i < _autoPlayCount - 1) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  Map<String, dynamic>? get _currentItem => 
      _items.isNotEmpty && _currentIndex < _items.length ? _items[_currentIndex] : null;

  String get _translation => _currentItem?['Translate'] as String? ?? '';
  String get _symbol => _currentItem?['Symbol'] as String? ?? '';

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _showCurrentWord();
      return;
    }
    
    // Ctrl+M 显示完整答案 (避免与空格输入冲突)
    if (event.logicalKey == LogicalKeyboardKey.keyM && 
        HardwareKeyboard.instance.isControlPressed && !_showFullAnswer) {
      setState(() => _showFullAnswer = true);
      return;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && 
        HardwareKeyboard.instance.isControlPressed) {
      _prevItem();
      return;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.arrowRight && 
        HardwareKeyboard.instance.isControlPressed) {
      _nextItem();
      return;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_userInput.isNotEmpty) {
        setState(() => _userInput = _userInput.substring(0, _userInput.length - 1));
      }
      return;
    }
    
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      // 只有在已显示答案时才进入下一题
      if (_showFullAnswer) {
        _nextItem();
      }
      // 回车键不显示答案，只有Space键才显示答案
      return;
    }
    
    if (event.character != null && RegExp(r"[a-zA-Z\s\-']").hasMatch(event.character!)) {
      setState(() => _userInput += event.character!);
      
      // 拼写完成检查
      if (_userInput.length == _targetText.length) {
        final isAllCorrect = _userInput.toLowerCase() == _targetText.toLowerCase();
        
        // 更新学习状态（不针对句子模式）
        if (!_isSentenceMode) {
          _updateWordLearningStatus(isAllCorrect);
        }
        
        if (isAllCorrect) {
          // 拼写完全正确，根据设置决定是否自动下一题
          if (_pauseOnComplete) {
            // 停顿确认模式：显示答案，等待用户按键
            setState(() => _showFullAnswer = true);
          } else {
            // 自动下一题 - 先显示结果再跳转
            setState(() => _showFullAnswer = true);
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) _nextItem();
            });
          }
        } else {
          // 有错误，增加错误计数并显示正确答案
          _errorCount++;
          setState(() => _showFullAnswer = true);
        }
      }
    }
  }

  /// 更新单词学习状态
  Future<void> _updateWordLearningStatus(bool isCorrect) async {
    final item = _items[_currentIndex];
    final wordId = item['WordId'] as String?;
    if (wordId == null) return;

    final learnParam = item['LearnParam'] as String?;
    final rating = isCorrect ? 3 : 1;
    final result = _scheduler.schedule(learnParam, rating);

    final newStatus = isCorrect && result.reps >= 3 ? 2 : 1;

    await WordBookProvider.instance.updateWordStatus(
      wordId,
      newStatus,
      result.learnParam,
      result.nextReview.millisecondsSinceEpoch.toString(),
    );

    // 记录学习统计
    final currentStatus = item['LearnStatus'] as int? ?? 0;
    if (currentStatus == 0) {
      LearningStatsService.instance.recordNewWord();
    } else {
      LearningStatsService.instance.recordReview();
    }
  }

  void _showCurrentWord() {
    final words = _targetText.split(RegExp(r'\s+'));
    int charCount = 0;
    for (final word in words) {
      charCount += word.length + 1;
      if (charCount > _userInput.length) {
        setState(() {
          final targetPos = charCount - 1;
          if (targetPos > _userInput.length) {
            _userInput = _targetText.substring(0, targetPos);
          }
        });
        break;
      }
    }
  }

  void _nextItem() {
    if (_currentIndex < _items.length - 1) {
      setState(() => _currentIndex++);
      _initCurrentItem();
    } else {
      _showSessionComplete();
    }
    _focusNode.requestFocus();
  }

  void _prevItem() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _initCurrentItem();
    }
    _focusNode.requestFocus();
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('练习完成！'),
        content: Text('错误次数: $_errorCount'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _errorCount = 0;
              });
              _loadData();
            },
            child: const Text('再来一轮'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Container(
              width: 520,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Text('更多设置', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close, size: 20, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('基本设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  // 译文字体大小
                  _SettingRow(
                    label: '译文字体大小',
                    child: _OptionButtons(
                      options: const ['20', '30', '40', '50', '60'],
                      selected: _translationFontSize.toInt().toString(),
                      onChanged: (v) {
                        setDialogState(() => _translationFontSize = double.parse(v));
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 词汇字体大小
                  _SettingRow(
                    label: '词汇字体大小',
                    child: _OptionButtons(
                      options: const ['20', '25', '30', '40', '50', '60'],
                      selected: _wordFontSize.toInt().toString(),
                      onChanged: (v) {
                        setDialogState(() => _wordFontSize = double.parse(v));
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 自动播放次数
                  _SettingRow(
                    label: '自动播放次数',
                    child: _OptionButtons(
                      options: const ['1次', '2次', '3次', '4次', '5次'],
                      selected: '$_autoPlayCount次',
                      onChanged: (v) {
                        setDialogState(() => _autoPlayCount = int.parse(v.replaceAll('次', '')));
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 显示音标
                  _SettingRow(
                    label: '显示音标',
                    child: _ToggleButtons(
                      value: _showSymbol,
                      onChanged: (v) {
                        setDialogState(() => _showSymbol = v);
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 显示译文
                  _SettingRow(
                    label: '显示译文',
                    child: _ToggleButtons(
                      value: _showTranslation,
                      onChanged: (v) {
                        setDialogState(() => _showTranslation = v);
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 拼写完成停顿确认
                  _SettingRow(
                    label: '拼写完成停顿确认',
                    child: _ToggleButtons(
                      value: _pauseOnComplete,
                      onChanged: (v) {
                        setDialogState(() => _pauseOnComplete = v);
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 拼错字符高亮显示
                  _SettingRow(
                    label: '拼错字符高亮显示',
                    child: _ToggleButtons(
                      value: _highlightErrors,
                      onChanged: (v) {
                        setDialogState(() => _highlightErrors = v);
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 键盘音效
                  _SettingRow(
                    label: '键盘音效',
                    child: _OptionButtons(
                      options: const ['关闭', '音效1', '音效2', '音效3', '音效4', '音效5'],
                      selected: _keyboardSound == 0 ? '关闭' : '音效$_keyboardSound',
                      onChanged: (v) {
                        setDialogState(() => _keyboardSound = v == '关闭' ? 0 : int.parse(v.replaceAll('音效', '')));
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 错误音效
                  _SettingRow(
                    label: '错误音效',
                    child: _ToggleButtons(
                      value: _errorSound,
                      onChanged: (v) {
                        setDialogState(() => _errorSound = v);
                        setState(() {});
                      },
                    ),
                  ),
                  
                  // 正确音效
                  _SettingRow(
                    label: '正确音效',
                    child: _ToggleButtons(
                      value: _correctSound,
                      onChanged: (v) {
                        setDialogState(() => _correctSound = v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetWords = _targetText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final inputWords = _userInput.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 顶部栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '返回',
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('高级拼写', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        if (!_isLoading && _items.isNotEmpty)
                          Text('${_currentIndex + 1}/${_items.length}', 
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.star_border, size: 20), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.check_box_outline_blank, size: 20), onPressed: () {}),
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 20, color: Color(0xFF3C8CE7)),
                      onPressed: () => TtsService.instance.speak(_targetText),
                    ),
                    IconButton(icon: const Icon(Icons.repeat, size: 20), onPressed: () {}),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                      child: const Text('1.0x', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          Icon(Icons.close, size: 14, color: _errorCount > 0 ? Colors.red : Colors.grey),
                          Text(' $_errorCount', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, size: 20),
                      onPressed: _showSettingsDialog,
                    ),
                  ],
                ),
              ),
            ),
            
            // 主内容区
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('暂无数据'))
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 中文翻译
                              if (_showTranslation)
                                Text(
                                  _translation,
                                  style: TextStyle(fontSize: _translationFontSize, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              const SizedBox(height: 16),
                              
                              // 音标
                              if (_showSymbol && _symbol.isNotEmpty)
                                Text('/$_symbol/', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                              
                              const SizedBox(height: 48),
                              
                              // 输入显示区
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: _buildInputDisplay(),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              if (targetWords.length > 1)
                                Text('${inputWords.length}/${targetWords.length}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                            ],
                          ),
                        ),
            ),
            
            // 底部快捷键
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _KeyHint(keys: 'Ctrl + P', label: '播放句子'),
                  _KeyHint(keys: 'Ctrl + J', label: '播放单词'),
                  _KeyHint(keys: 'Tab', label: '显示单词'),
                  _KeyHint(keys: 'Ctrl+M', label: '显示答案'),
                  _KeyHint(keys: 'Ctrl + ←', label: '上一个'),
                  _KeyHint(keys: 'Ctrl + →', label: '下一个'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputDisplay() {
    if (_showFullAnswer) {
      return Column(
        children: [
          Text(
            _targetText,
            style: TextStyle(fontSize: _wordFontSize, fontWeight: FontWeight.bold, color: const Color(0xFF3C8CE7)),
            textAlign: TextAlign.center,
          ),
          if (_userInput.isNotEmpty && _userInput.toLowerCase() != _targetText.toLowerCase())
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('你的输入: $_userInput', style: TextStyle(fontSize: 14, color: Colors.red[400])),
            ),
        ],
      );
    }
    
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 0,
      runSpacing: 8,
      children: List.generate(_targetText.length, (i) {
        final isTyped = i < _userInput.length;
        final char = isTyped ? _userInput[i] : '';
        final isSpace = _targetText[i] == ' ';
        final isCorrect = isTyped && _userInput[i].toLowerCase() == _targetText[i].toLowerCase();
        
        if (isSpace) return const SizedBox(width: 16);
        
        // 实时颜色反馈：正确蓝色，错误红色
        Color textColor = Colors.grey[400]!;
        if (isTyped) {
          textColor = isCorrect ? const Color(0xFF3C8CE7) : Colors.red;
        }
        
        return Container(
          width: _wordFontSize * 0.9,
          height: _wordFontSize * 1.4,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isTyped ? textColor : Colors.grey[400]!, width: 2)),
          ),
          child: Center(
            child: Text(char, style: TextStyle(fontSize: _wordFontSize * 0.8, fontWeight: FontWeight.bold, color: textColor)),
          ),
        );
      }),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final String keys;
  final String label;
  const _KeyHint({required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(keys, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

/// 设置行 - 标签 + 选项
class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _SettingRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 选项按钮组 - 多选一
class _OptionButtons extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Function(String) onChanged;
  const _OptionButtons({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF5B6CFF) : Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 开关按钮 - 开启/关闭
class _ToggleButtons extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;
  const _ToggleButtons({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: value ? const Color(0xFF5B6CFF) : Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('开启', style: TextStyle(fontSize: 12, color: value ? Colors.white : Colors.grey[600])),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => onChanged(false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: !value ? const Color(0xFF5B6CFF) : Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('关闭', style: TextStyle(fontSize: 12, color: !value ? Colors.white : Colors.grey[600])),
          ),
        ),
      ],
    );
  }
}
