import 'package:flutter/material.dart';
import '../../services/listening_materials_service.dart';
import '../../services/import_service.dart';
import 'dart:convert';

/// 听力素材库页面
class ListeningMaterialsStorePage extends StatefulWidget {
  final String bookId;

  const ListeningMaterialsStorePage({super.key, required this.bookId});

  @override
  State<ListeningMaterialsStorePage> createState() => _ListeningMaterialsStorePageState();
}

class _ListeningMaterialsStorePageState extends State<ListeningMaterialsStorePage> {
  String _selectedCategory = '全部';
  final Set<String> _downloadedIds = {};
  String? _downloadingId;

  final List<String> _categories = ['全部', '基础', '场景', '职场', '学术', '进阶'];

  List<MaterialSource> get _filteredSources {
    if (_selectedCategory == '全部') {
      return ListeningMaterialsService.sources;
    }
    return ListeningMaterialsService.sources
        .where((s) => s.category == _selectedCategory)
        .toList();
  }

  Future<void> _downloadMaterial(MaterialSource source) async {
    setState(() => _downloadingId = source.id);

    try {
      // 获取素材内容
      final sentences = await ListeningMaterialsService.instance.fetchMaterialContent(source.id);

      if (sentences.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取素材失败')),
          );
        }
        return;
      }

      // 转换为JSON格式
      final jsonContent = jsonEncode({'sentences': sentences});

      // 导入到数据库
      final result = await ImportService.instance.importListeningMaterials(
        widget.bookId,
        jsonContent,
      );

      if (mounted) {
        setState(() {
          _downloadedIds.add(source.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${source.name}: $result')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '听力素材库',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, color: Colors.amber, size: 20),
            label: const Text('完成', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 分类筛选
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber : Colors.grey[800],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 素材列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredSources.length,
              itemBuilder: (context, index) {
                final source = _filteredSources[index];
                return _MaterialCard(
                  source: source,
                  isDownloaded: _downloadedIds.contains(source.id),
                  isDownloading: _downloadingId == source.id,
                  onDownload: () => _downloadMaterial(source),
                  onPreview: () => _showPreview(source),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(MaterialSource source) async {
    final sentences = await ListeningMaterialsService.instance.fetchMaterialContent(source.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252542),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF252542),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    source.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${sentences.length} 个句子',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _downloadMaterial(source);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('下载'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: sentences.length,
                itemBuilder: (context, index) {
                  final sentence = sentences[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[900],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.blue, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sentence['en'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Text(
                            sentence['cn'] ?? '',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final MaterialSource source;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onPreview;

  const _MaterialCard({
    required this.source,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onDownload,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252542),
        borderRadius: BorderRadius.circular(12),
        border: isDownloaded
            ? Border.all(color: Colors.green.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPreview,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      source.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            source.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(source.difficulty),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              source.difficulty,
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ),
                          if (isDownloaded) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        source.description,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${source.sentenceCount} 个句子',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // 下载按钮
                if (isDownloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  )
                else if (isDownloaded)
                  IconButton(
                    onPressed: onDownload,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                    tooltip: '重新下载',
                  )
                else
                  IconButton(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, color: Colors.amber),
                    tooltip: '下载',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '初级':
        return Colors.green;
      case '中级':
        return Colors.orange;
      case '高级':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
