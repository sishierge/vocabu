import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class MasteredWordsPage extends StatefulWidget {
  const MasteredWordsPage({super.key});

  @override
  State<MasteredWordsPage> createState() => _MasteredWordsPageState();
}

class _MasteredWordsPageState extends State<MasteredWordsPage> {
  int _currentPage = 1;
  final int _pageSize = 20;
  List<Map<String, dynamic>> _words = [];
  int _totalCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final db = await DatabaseHelper.database;
      
      // Get Total Count
      final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM WordItem WHERE LearnStatus = 2');
      _totalCount = countResult.first['cnt'] as int? ?? 0;
      
      // Get Page Data
      final offset = (_currentPage - 1) * _pageSize;
      _words = await db.query(
        'WordItem',
        where: 'LearnStatus = 2',
        limit: _pageSize,
        offset: offset,
        orderBy: 'MasterTime DESC' // Recently mastered first
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading mastered words: $e');
      }
    }

    setState(() => _isLoading = false);
  }
  
  void _changePage(int newPage) {
    if (newPage < 1) return;
    final maxPage = (_totalCount / _pageSize).ceil();
    if (maxPage > 0 && newPage > maxPage) return;
    
    setState(() => _currentPage = newPage);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final maxPage = (_totalCount / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 8),
              Text('熟词管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          // Toolbar
          Row(
            children: [
              TextButton.icon(icon: const Icon(Icons.upload_outlined, size: 18), label: const Text('导入'), onPressed: null),
              TextButton.icon(icon: const Icon(Icons.copy_outlined, size: 18), label: const Text('复制'), onPressed: null),
              TextButton.icon(icon: const Icon(Icons.delete_outline, size: 18), label: const Text('删除'), onPressed: null),
              TextButton.icon(icon: const Icon(Icons.clear_all, size: 18), label: const Text('清空'), onPressed: null),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 18), 
                label: const Text('刷新'), 
                onPressed: _loadData
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[100]),
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('序号', style: TextStyle(fontSize: 12))),
                SizedBox(width: 150, child: Text('单词', style: TextStyle(fontSize: 12))),
                Expanded(child: Text('翻译', style: TextStyle(fontSize: 12))),
                SizedBox(width: 120, child: Text('音标', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
          // Table rows
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _words.isEmpty
                    ? Center(child: Text('暂无熟词', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        itemCount: _words.length,
                        itemBuilder: (context, index) {
                          final word = _words[index];
                          final globalIndex = (_currentPage - 1) * _pageSize + index + 1;
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
                            child: Row(
                              children: [
                                SizedBox(width: 50, child: Text('$globalIndex', style: TextStyle(color: Colors.grey[600]))),
                                SizedBox(width: 150, child: Text(word['Word'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                Expanded(child: Text(word['Translate'] as String? ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                SizedBox(width: 120, child: Text(word['Symbol'] as String? ?? '', style: TextStyle(color: Colors.grey[500]))),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Pagination
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left), 
                  onPressed: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF3C8CE7), borderRadius: BorderRadius.circular(12)),
                  child: Text('$_currentPage', style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                 Text('/ $maxPage 页', style: TextStyle(color: Colors.grey[600])),
                IconButton(
                  icon: const Icon(Icons.chevron_right), 
                  onPressed: _currentPage < maxPage ? () => _changePage(_currentPage + 1) : null
                ),
                const Spacer(),
                Text('共 $_totalCount 条', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
