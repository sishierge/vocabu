import 'package:flutter/material.dart';
import '../providers/word_book_provider.dart';
import '../services/tts_service.dart';

class CollectedWordsPage extends StatefulWidget {
  const CollectedWordsPage({super.key});

  @override
  State<CollectedWordsPage> createState() => _CollectedWordsPageState();
}

class _CollectedWordsPageState extends State<CollectedWordsPage> {
  List<Map<String, dynamic>> _collectedWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollectedWords();
  }

  Future<void> _loadCollectedWords() async {
    setState(() => _isLoading = true);

    final words = await WordBookProvider.instance.getCollectedWords();

    if (mounted) {
      setState(() {
        _collectedWords = words;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleCollect(String wordId, int index) async {
    await WordBookProvider.instance.collectWord(wordId, false);
    if (mounted) {
      setState(() {
        _collectedWords.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已取消收藏'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            const Text('收藏单词', style: TextStyle(color: Colors.black, fontSize: 16)),
            const Spacer(),
            Text(
              '${_collectedWords.length} 词',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _collectedWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        '暂无收藏单词',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '在学习时点击星标收藏单词',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _collectedWords.length,
                  itemBuilder: (context, index) {
                    final word = _collectedWords[index];
                    final wordId = word['WordId'] as String? ?? '';
                    return _WordCard(
                      word: word,
                      onUncollect: wordId.isNotEmpty
                          ? () => _toggleCollect(wordId, index)
                          : null,
                    );
                  },
                ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final Map<String, dynamic> word;
  final VoidCallback? onUncollect;

  const _WordCard({required this.word, this.onUncollect});

  @override
  Widget build(BuildContext context) {
    final wordText = word['Word'] as String? ?? '';
    final symbol = word['Symbol'] as String? ?? '';
    final translate = word['Translate'] as String? ?? '';
    final example = word['Example'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wordText,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                      ),
                      if (symbol.isNotEmpty)
                        Text(
                          symbol,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF3C8CE7)),
                  onPressed: () => TtsService.instance.speak(wordText),
                  tooltip: '播放发音',
                ),
                IconButton(
                  icon: const Icon(Icons.star, color: Colors.amber),
                  onPressed: onUncollect,
                  tooltip: '取消收藏',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                translate,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            if (example.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  example,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
