import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import '../providers/word_book_provider.dart';
import '../services/import_service.dart';
import '../services/word_book_download_service.dart';
import 'book_detail_page.dart';
import 'english_books_page.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int _selectedCategory = 0;

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.library_books_outlined, 'name': '全部词书'},
    {'icon': Icons.assignment_turned_in_outlined, 'name': '正在学习'},
    {'icon': Icons.download_done_outlined, 'name': '已下载'},
    {'icon': Icons.menu_book_outlined, 'name': '英语书籍'},
  ];

  /// 显示导入选项对话框
  void _showImportDialog(BuildContext context, WordBookProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入词书'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 本地导入
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_open, color: Color(0xFF3C8CE7)),
              ),
              title: const Text('从本地导入'),
              subtitle: const Text('支持 JSON 格式词书文件'),
              onTap: () {
                Navigator.pop(ctx);
                _importFromLocal(provider);
              },
            ),
            const Divider(),
            // 在线下载
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud_download, color: Colors.green),
              ),
              title: const Text('在线词书中心'),
              subtitle: const Text('浏览并下载热门词书'),
              onTap: () {
                Navigator.pop(ctx);
                _showOnlineBooks(context, provider);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 从本地文件导入
  Future<void> _importFromLocal(WordBookProvider provider) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'JSON files',
        extensions: ['json'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) return;

      final String content = await file.readAsString();
      final result = await ImportService.instance.importBookFromJson(content);

      // 刷新词书列表
      await provider.loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: result.startsWith('Success') ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 显示在线词书列表
  void _showOnlineBooks(BuildContext context, WordBookProvider provider) {
    // 预设的在线词书列表 - 分类展示
    final onlineBooks = [
      // 大学英语
      {'name': 'CET-4 四级核心词汇', 'count': 3000, 'desc': '大学英语四级考试核心词汇', 'category': '大学英语'},
      {'name': 'CET-4 四级高频词汇', 'count': 1500, 'desc': '四级高频考点词汇精选', 'category': '大学英语'},
      {'name': 'CET-6 六级核心词汇', 'count': 2500, 'desc': '大学英语六级考试核心词汇', 'category': '大学英语'},
      {'name': 'CET-6 六级高频词汇', 'count': 1800, 'desc': '六级高频考点词汇精选', 'category': '大学英语'},
      
      // 出国考试
      {'name': 'TOEFL 托福词汇', 'count': 4000, 'desc': '托福考试必备词汇', 'category': '出国考试'},
      {'name': 'IELTS 雅思词汇', 'count': 3500, 'desc': '雅思考试必备词汇', 'category': '出国考试'},
      {'name': 'GRE 红宝书', 'count': 5000, 'desc': 'GRE考试核心词汇', 'category': '出国考试'},
      {'name': 'GMAT 核心词汇', 'count': 3000, 'desc': 'GMAT考试高频词汇', 'category': '出国考试'},
      {'name': 'SAT 词汇', 'count': 3500, 'desc': 'SAT考试必备词汇', 'category': '出国考试'},
      
      // 国内考试
      {'name': '考研英语核心词汇', 'count': 4500, 'desc': '研究生入学考试英语词汇', 'category': '国内考试'},
      {'name': '考研英语高频词汇', 'count': 2000, 'desc': '考研真题高频词汇精选', 'category': '国内考试'},
      {'name': '专四词汇', 'count': 4000, 'desc': '英语专业四级考试词汇', 'category': '国内考试'},
      {'name': '专八词汇', 'count': 5500, 'desc': '英语专业八级考试词汇', 'category': '国内考试'},
      
      // 高中英语
      {'name': '高中英语 3500 词', 'count': 3500, 'desc': '高考英语必备词汇', 'category': '高中英语'},
      {'name': '高考核心 800 词', 'count': 800, 'desc': '高考高频核心词汇', 'category': '高中英语'},
      {'name': '高考阅读高频词', 'count': 1200, 'desc': '高考阅读理解常见词汇', 'category': '高中英语'},
      
      // 初中英语  
      {'name': '中考英语 1600 词', 'count': 1600, 'desc': '中考必备词汇', 'category': '初中英语'},
      {'name': '初中核心词汇', 'count': 1000, 'desc': '初中阶段核心词汇', 'category': '初中英语'},
      
      // 商务英语
      {'name': 'BEC 商务英语词汇', 'count': 2500, 'desc': '剑桥商务英语考试词汇', 'category': '商务英语'},
      {'name': '职场常用英语', 'count': 1500, 'desc': '办公室日常英语词汇', 'category': '商务英语'},
      
      // 日常英语
      {'name': '生活常用 3000 词', 'count': 3000, 'desc': '日常生活高频词汇', 'category': '日常英语'},
      {'name': '旅游英语词汇', 'count': 800, 'desc': '出国旅游必备词汇', 'category': '日常英语'},
      {'name': '新概念英语1-4册', 'count': 4500, 'desc': '新概念全册词汇汇总', 'category': '日常英语'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Text('在线词书中心'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          height: 400,
          child: ListView.builder(
            itemCount: onlineBooks.length,
            itemBuilder: (context, index) {
              final book = onlineBooks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.book, color: Color(0xFF3C8CE7)),
                  ),
                  title: Text(book['name'] as String),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book['desc'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text('${book['count']} 词', style: const TextStyle(fontSize: 11, color: Color(0xFF3C8CE7))),
                    ],
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _downloadOnlineBook(book['name'] as String, provider);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3C8CE7),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('下载'),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 下载在线词书
  Future<void> _downloadOnlineBook(String bookName, WordBookProvider provider) async {
    // 显示下载中提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('正在下载 "$bookName"...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      // 获取词书内容
      final bookData = await WordBookDownloadService.instance.fetchWordBook(bookName);

      if (bookData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('获取词书失败，请稍后重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 导入词书
      final result = await ImportService.instance.importBookFromJson(
        '{"bookName": "${bookData['bookName']}", "words": ${_encodeWords(bookData['words'] as List)}}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: result.startsWith('Success') ? Colors.green : Colors.red,
          ),
        );

        // 刷新词书列表
        if (result.startsWith('Success')) {
          await provider.loadBooks();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _encodeWords(List words) {
    final buffer = StringBuffer('[');
    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if (i > 0) buffer.write(',');
      buffer.write('{"word":"${_escapeJson(w['word'] ?? '')}",'
          '"trans":"${_escapeJson(w['trans'] ?? '')}",'
          '"symbol":"${_escapeJson(w['symbol'] ?? '')}",'
          '"example":"${_escapeJson(w['example'] ?? '')}"}');
    }
    buffer.write(']');
    return buffer.toString();
  }

  String _escapeJson(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n');
  }

  /// 确认删除词书
  Future<void> _confirmDeleteBook(BuildContext context, WordBook book, WordBookProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除词书'),
        content: Text('确定要删除 "${book.bookName}" 吗？\n\n这将同时删除该词书中的所有单词，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteWordBook(book.bookId);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(success ? '已删除 "${book.bookName}"' : '删除失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Sidebar (Desktop Style)
        Container(
          width: 200,
          padding: const EdgeInsets.all(16),
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_library_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('词库管理', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(_categories.length, (index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      cat['icon'],
                      size: 18,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant
                    ),
                    title: Text(
                      cat['name'],
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                    trailing: isSelected
                      ? Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(color: colorScheme.onPrimary, shape: BoxShape.circle)
                        )
                      : null,
                    onTap: () => setState(() => _selectedCategory = index),
                  ),
                );
              }),
            ],
          ),
        ),

        // Vertical Divider
        VerticalDivider(width: 1, thickness: 1, color: colorScheme.outlineVariant),

        // Main Content Area
        Expanded(
          child: Container(
            color: colorScheme.surfaceContainerLowest,
            child: _selectedCategory == 3
                ? const EnglishBooksPage()
                : Consumer<WordBookProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter logic
                List<WordBook> displayBooks = provider.books;
                if (_selectedCategory == 1) {
                  displayBooks = provider.books.where((b) => b.masteredCount > 0 || b.learningCount > 0).toList();
                } else if (_selectedCategory == 2) {
                   displayBooks = provider.books;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Content Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _categories[_selectedCategory]['name'],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${displayBooks.length}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                          const Spacer(),
                          // 导入按钮
                          ElevatedButton.icon(
                            onPressed: () => _showImportDialog(context, provider),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('导入词书'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3C8CE7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            color: Colors.grey[500],
                            tooltip: '刷新',
                            onPressed: () => provider.loadBooks(),
                          ),
                          const SizedBox(width: 8),
                           IconButton(
                            icon: const Icon(Icons.sort, size: 20),
                            color: Colors.grey[500],
                            tooltip: '排序',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Book Grid
                    Expanded(
                      child: displayBooks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outlineVariant),
                              const SizedBox(height: 16),
                              Text('这里什么都没有', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220, // Max width for card
                            childAspectRatio: 0.75, // Taller for book cover aspect
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          itemCount: displayBooks.length,
                          itemBuilder: (context, index) {
                            final book = displayBooks[index];
                            return _DesktopBookCard(
                              book: book,
                              onDelete: () => _confirmDeleteBook(context, book, provider),
                            );
                          },
                        ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopBookCard extends StatelessWidget {
  final WordBook book;
  final VoidCallback? onDelete;

  const _DesktopBookCard({required this.book, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final progress = book.wordCount > 0 ? book.masteredCount / book.wordCount : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookDetailPage(bookName: book.bookName),
            ),
          );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Stack(
                  children: [
                     Center(
                       child: Icon(Icons.book, size: 48, color: colorScheme.primary.withValues(alpha: 0.5)),
                     ),
                     Positioned(
                       top: 8,
                       right: 8,
                       child: PopupMenuButton<String>(
                         icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onPrimaryContainer),
                         onSelected: (value) {
                           if (value == 'delete' && onDelete != null) {
                             onDelete!();
                           }
                         },
                         itemBuilder: (context) => [
                           PopupMenuItem(
                             value: 'delete',
                             child: Row(
                               children: [
                                 Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                                 const SizedBox(width: 8),
                                 Text('删除词书', style: TextStyle(color: Colors.red[400])),
                               ],
                             ),
                           ),
                         ],
                       ),
                     )
                  ],
                ),
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.bookName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          '${book.wordCount} 词',
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                        const Spacer(),
                        if (progress > 0)
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
