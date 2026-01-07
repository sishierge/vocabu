import 'package:flutter/material.dart';
import '../repositories/word_repository.dart';
import '../services/tts_service.dart';

/// Error Words Page - 错题本
class ErrorWordsPage extends StatefulWidget {
  const ErrorWordsPage({super.key});

  @override
  State<ErrorWordsPage> createState() => _ErrorWordsPageState();
}

class _ErrorWordsPageState extends State<ErrorWordsPage> {
  final WordRepository _wordRepo = WordRepository();
  List<Map<String, dynamic>> _errorWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadErrorWords();
  }

  Future<void> _loadErrorWords() async {
    setState(() => _isLoading = true);
    try {
      final words = await _wordRepo.getErrorWords(limit: 200);
      setState(() {
        _errorWords = words;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _speakWord(String word) {
    TtsService.instance.speak(word);
  }

  /// 从错题本中删除单词
  Future<void> _removeFromErrorBook(String wordId, String word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出错题本'),
        content: Text('确定要将 "$word" 从错题本中移除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定移除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _wordRepo.clearErrorCount(wordId);
      _loadErrorWords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$word" 已从错题本移除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('错题本', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadErrorWords,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorWords.isEmpty
              ? _buildEmptyState()
              : _buildWordList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text('太棒了！', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[600])),
          const SizedBox(height: 8),
          Text('暂无错题记录', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return Column(
      children: [
        // Stats Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_errorWords.length} 个错词',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '多练习这些单词吧',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Word List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _errorWords.length,
            itemBuilder: (context, index) {
              final word = _errorWords[index];
              return _buildWordCard(word);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard(Map<String, dynamic> word) {
    final wordId = word['WordId'] as String? ?? '';
    final wordText = word['Word'] as String? ?? '';
    final translate = word['Translate'] as String? ?? '';
    final symbol = word['Symbol'] as String? ?? '';
    final errorCount = word['ErrorCount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$errorCount',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              wordText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (symbol.isNotEmpty)
              Text(symbol, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
        subtitle: Text(
          translate,
          style: TextStyle(color: Colors.grey[600]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.blue),
              onPressed: () => _speakWord(wordText),
              tooltip: '发音',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () => _removeFromErrorBook(wordId, wordText),
              tooltip: '移出错题本',
            ),
          ],
        ),
      ),
    );
  }
}
