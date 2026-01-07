import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/custom_materials_service.dart';

/// 自定义素材管理页面
class CustomMaterialsPage extends StatefulWidget {
  const CustomMaterialsPage({super.key});

  @override
  State<CustomMaterialsPage> createState() => _CustomMaterialsPageState();
}

class _CustomMaterialsPageState extends State<CustomMaterialsPage> {
  bool _isLoading = true;
  List<CustomMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    await CustomMaterialsService.instance.initialize();
    if (mounted) {
      setState(() {
        _materials = CustomMaterialsService.instance.materials;
        _isLoading = false;
      });
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
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '我的素材',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colorScheme.primary),
            onPressed: _showCreateDialog,
            tooltip: '创建素材',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _materials.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadMaterials,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) => _buildMaterialCard(_materials[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无自定义素材',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 创建您自己的素材',
            style: TextStyle(color: colorScheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.add),
            label: const Text('创建素材'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(CustomMaterial material) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showMaterialDetail(material),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          material.name,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${material.sentenceCount} 句 · ${material.difficulty}',
                          style: TextStyle(color: colorScheme.outline, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                    onSelected: (value) => _handleMenuAction(value, material),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(value: 'export', child: Text('导出')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: Colors.red[700])),
                      ),
                    ],
                  ),
                ],
              ),
              if (material.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  material.description,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '更新于 ${_formatDate(material.updatedAt)}',
                    style: TextStyle(color: colorScheme.outline, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
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

  void _handleMenuAction(String action, CustomMaterial material) {
    switch (action) {
      case 'edit':
        _showEditDialog(material);
        break;
      case 'export':
        _exportMaterial(material);
        break;
      case 'delete':
        _confirmDelete(material);
        break;
    }
  }

  void _showCreateDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    '创建自定义素材',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '素材名称',
                  hintText: '例如：我的听力练习',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '输入格式：每行一句英文，下一行中文翻译\n例如：\nHello, how are you?\n你好，你好吗？',
                  style: TextStyle(color: colorScheme.outline, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: TextField(
                  controller: contentController,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: '输入句子内容...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final content = contentController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入素材名称')),
                        );
                        return;
                      }

                      if (content.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入句子内容')),
                        );
                        return;
                      }

                      final sentences = _parseContent(content);
                      if (sentences.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('未找到有效的句子')),
                        );
                        return;
                      }

                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      await CustomMaterialsService.instance.addMaterial(
                        name: name,
                        sentences: sentences,
                      );

                      if (mounted) {
                        navigator.pop();
                        _loadMaterials();
                        messenger.showSnackBar(
                          SnackBar(content: Text('已创建素材：$name，共 ${sentences.length} 句')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('创建'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MaterialSentence> _parseContent(String content) {
    final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final sentences = <MaterialSentence>[];

    for (int i = 0; i < lines.length; i += 2) {
      final en = lines[i];
      final cn = i + 1 < lines.length ? lines[i + 1] : '';

      // 检查第一行是否为英文
      if (RegExp(r'[a-zA-Z]').hasMatch(en)) {
        sentences.add(MaterialSentence(english: en, chinese: cn));
      }
    }

    return sentences;
  }

  void _showMaterialDetail(CustomMaterial material) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _MaterialDetailPage(
          material: material,
          onChanged: _loadMaterials,
        ),
      ),
    );
  }

  void _showEditDialog(CustomMaterial material) {
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController(text: material.name);
    final descController = TextEditingController(text: material.description);
    String difficulty = material.difficulty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '编辑素材',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '素材名称',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '描述（可选）',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('难度', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['初级', '中级', '高级', '自定义'].map((d) {
                    final isSelected = difficulty == d;
                    return ChoiceChip(
                      label: Text(d),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() => difficulty = d);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('名称不能为空')),
                          );
                          return;
                        }

                        final navigator = Navigator.of(context);

                        await CustomMaterialsService.instance.updateMaterialName(material.id, name);
                        await CustomMaterialsService.instance.updateMaterialDescription(
                          material.id,
                          descController.text.trim(),
                        );
                        await CustomMaterialsService.instance.updateMaterialDifficulty(
                          material.id,
                          difficulty,
                        );

                        if (mounted) {
                          navigator.pop();
                          _loadMaterials();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _exportMaterial(CustomMaterial material) {
    final json = CustomMaterialsService.instance.exportMaterial(material.id);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('素材已复制到剪贴板')),
    );
  }

  void _confirmDelete(CustomMaterial material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除素材"${material.name}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(this.context);

              await CustomMaterialsService.instance.deleteMaterial(material.id);
              if (mounted) {
                navigator.pop();
                _loadMaterials();
                messenger.showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 素材详情页面
class _MaterialDetailPage extends StatefulWidget {
  final CustomMaterial material;
  final VoidCallback onChanged;

  const _MaterialDetailPage({
    required this.material,
    required this.onChanged,
  });

  @override
  State<_MaterialDetailPage> createState() => _MaterialDetailPageState();
}

class _MaterialDetailPageState extends State<_MaterialDetailPage> {
  late CustomMaterial _material;

  @override
  void initState() {
    super.initState();
    _material = widget.material;
  }

  void _refresh() {
    final updated = CustomMaterialsService.instance.getMaterial(_material.id);
    if (updated != null) {
      setState(() => _material = updated);
      widget.onChanged();
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
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _material.name,
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colorScheme.primary),
            onPressed: _showAddSentenceDialog,
            tooltip: '添加句子',
          ),
        ],
      ),
      body: _material.sentences.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _material.sentences.length,
              itemBuilder: (context, index) => _buildSentenceCard(index),
            ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.text_snippet_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无句子',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSentenceDialog,
            icon: const Icon(Icons.add),
            label: const Text('添加句子'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceCard(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final sentence = _material.sentences[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showEditSentenceDialog(index, sentence),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence.english,
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
                    ),
                    if (sentence.chinese.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sentence.chinese,
                        style: TextStyle(color: colorScheme.outline, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                onPressed: () => _confirmDeleteSentence(index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSentenceDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final enController = TextEditingController();
    final cnController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '添加句子',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: enController,
                decoration: InputDecoration(
                  labelText: '英文',
                  hintText: '输入英文句子',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cnController,
                decoration: InputDecoration(
                  labelText: '中文翻译',
                  hintText: '输入中文翻译',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final en = enController.text.trim();
                      if (en.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('英文不能为空')),
                        );
                        return;
                      }

                      final navigator = Navigator.of(context);

                      await CustomMaterialsService.instance.addSentence(
                        _material.id,
                        MaterialSentence(
                          english: en,
                          chinese: cnController.text.trim(),
                        ),
                      );

                      if (mounted) {
                        navigator.pop();
                        _refresh();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('添加'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSentenceDialog(int index, MaterialSentence sentence) {
    final colorScheme = Theme.of(context).colorScheme;
    final enController = TextEditingController(text: sentence.english);
    final cnController = TextEditingController(text: sentence.chinese);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '编辑句子',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: enController,
                decoration: InputDecoration(
                  labelText: '英文',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cnController,
                decoration: InputDecoration(
                  labelText: '中文翻译',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final en = enController.text.trim();
                      if (en.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('英文不能为空')),
                        );
                        return;
                      }

                      final navigator = Navigator.of(context);

                      await CustomMaterialsService.instance.updateSentence(
                        _material.id,
                        index,
                        MaterialSentence(
                          english: en,
                          chinese: cnController.text.trim(),
                        ),
                      );

                      if (mounted) {
                        navigator.pop();
                        _refresh();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSentence(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除句子'),
        content: const Text('确定要删除这个句子吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);

              await CustomMaterialsService.instance.deleteSentence(_material.id, index);
              if (mounted) {
                navigator.pop();
                _refresh();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
