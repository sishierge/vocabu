import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../services/backup_service.dart';
import '../providers/word_book_provider.dart';

/// 数据备份恢复页面
class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  List<BackupFileInfo> _backups = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final backups = await BackupService.instance.listBackups();
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    final result = await BackupService.instance.exportData();

    setState(() => _isExporting = false);

    if (!mounted) return;

    if (result.success) {
      _loadBackups();
      _showSuccessDialog(
        title: '备份成功',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('文件已保存到：'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                result.filePath ?? '',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            if (result.summary != null) ...[
              const SizedBox(height: 16),
              _buildSummaryRow('词书', '${result.summary!.bookCount} 本'),
              _buildSummaryRow('单词', '${result.summary!.wordCount} 个'),
              _buildSummaryRow('已掌握', '${result.summary!.masteredCount} 个'),
              _buildSummaryRow('学习天数', '${result.summary!.daysLearned} 天'),
            ],
          ],
        ),
      );
    } else {
      _showErrorSnackBar('备份失败: ${result.error}');
    }
  }

  Future<void> _importFromFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON备份文件',
        extensions: ['json'],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) return;

      final filePath = file.path;

      // 验证文件
      final validation = await BackupService.instance.validateBackupFile(filePath);

      if (!validation.valid) {
        _showErrorSnackBar('无效的备份文件: ${validation.error}');
        return;
      }

      if (!mounted) return;

      // 显示确认对话框
      final confirmed = await _showConfirmDialog(validation);
      if (confirmed != true) return;

      setState(() => _isImporting = true);

      final importResult = await BackupService.instance.importData(filePath);

      setState(() => _isImporting = false);

      if (!mounted) return;

      if (importResult.success) {
        // 刷新词书数据
        await WordBookProvider.instance.loadBooks();

        _showSuccessDialog(
          title: '恢复成功',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('恢复词书', '${importResult.booksRestored} 本'),
              _buildSummaryRow('恢复单词', '${importResult.wordsRestored} 个'),
              _buildSummaryRow('恢复统计', '${importResult.statsRestored} 条'),
            ],
          ),
        );
      } else {
        _showErrorSnackBar('恢复失败: ${importResult.error}');
      }
    } catch (e) {
      _showErrorSnackBar('操作失败: $e');
    }
  }

  Future<void> _restoreFromBackup(BackupFileInfo backup) async {
    if (!backup.validation.valid) {
      _showErrorSnackBar('无效的备份文件');
      return;
    }

    final confirmed = await _showConfirmDialog(backup.validation);
    if (confirmed != true) return;

    setState(() => _isImporting = true);

    final result = await BackupService.instance.importData(backup.path);

    setState(() => _isImporting = false);

    if (!mounted) return;

    if (result.success) {
      await WordBookProvider.instance.loadBooks();

      _showSuccessDialog(
        title: '恢复成功',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('恢复词书', '${result.booksRestored} 本'),
            _buildSummaryRow('恢复单词', '${result.wordsRestored} 个'),
            _buildSummaryRow('恢复统计', '${result.statsRestored} 条'),
          ],
        ),
      );
    } else {
      _showErrorSnackBar('恢复失败: ${result.error}');
    }
  }

  Future<void> _deleteBackup(BackupFileInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除备份'),
        content: Text('确定要删除备份文件 "${backup.fileName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await BackupService.instance.deleteBackup(backup.path);
      if (success) {
        _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份已删除')),
          );
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(BackupValidation validation) {
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '恢复将更新现有单词的学习进度',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('备份信息:', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (validation.exportTime != null)
              _buildSummaryRow('备份时间', _formatDateTime(validation.exportTime!)),
            if (validation.summary != null) ...[
              _buildSummaryRow('词书', '${validation.summary!.bookCount} 本'),
              _buildSummaryRow('单词', '${validation.summary!.wordCount} 个'),
              _buildSummaryRow('已掌握', '${validation.summary!.masteredCount} 个'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({required String title, required Widget content}) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: content,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          '数据备份与恢复',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // 操作按钮区
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.cloud_upload_outlined,
                    title: '备份数据',
                    subtitle: '导出学习进度到文件',
                    color: Colors.blue,
                    isLoading: _isExporting,
                    onTap: _isExporting || _isImporting ? null : _exportData,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.folder_open_outlined,
                    title: '从文件恢复',
                    subtitle: '选择备份文件导入',
                    color: Colors.green,
                    isLoading: _isImporting,
                    onTap: _isExporting || _isImporting ? null : _importFromFile,
                  ),
                ),
              ],
            ),
          ),

          // 备份历史列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '备份历史',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_backups.isNotEmpty)
                  Text(
                    '${_backups.length} 个备份',
                    style: TextStyle(color: colorScheme.outline, fontSize: 12),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _backups.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _backups.length,
                        itemBuilder: (context, index) {
                          return _BackupCard(
                            backup: _backups[index],
                            onRestore: () => _restoreFromBackup(_backups[index]),
                            onDelete: () => _deleteBackup(_backups[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '暂无备份',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '点击"备份数据"创建第一个备份',
            style: TextStyle(color: colorScheme.outline, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// 操作卡片
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            if (isLoading)
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 备份卡片
class _BackupCard extends StatelessWidget {
  final BackupFileInfo backup;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _BackupCard({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isValid = backup.validation.valid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isValid
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isValid ? Icons.backup : Icons.error_outline,
              color: isValid ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.fileName,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      backup.sizeDisplay,
                      style: TextStyle(color: colorScheme.outline, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${backup.modified.month}/${backup.modified.day} ${backup.modified.hour}:${backup.modified.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: colorScheme.outline, fontSize: 12),
                    ),
                    if (isValid && backup.validation.summary != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${backup.validation.summary!.wordCount} 词',
                        style: TextStyle(color: colorScheme.primary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isValid)
            IconButton(
              icon: Icon(Icons.restore, color: colorScheme.primary),
              onPressed: onRestore,
              tooltip: '恢复此备份',
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[400]),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}
