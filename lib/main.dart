import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'pages/store_page.dart';
import 'pages/settings_page.dart';
import 'pages/book_detail_page.dart';
import 'pages/extensions_page.dart';
import 'pages/error_words_page.dart';
import 'pages/extensions/desktop_danmu_window.dart';
import 'pages/extensions/query_word_dialog.dart';
import 'pages/collected_words_page.dart';
import 'pages/learning/listening_page.dart';
import 'pages/learning/reading_page.dart';
import 'pages/learning/speaking_practice_page.dart';
import 'pages/learning/grammar_page.dart';
import 'widgets/heatmap_calendar.dart';
import 'providers/word_book_provider.dart';
import 'providers/theme_provider.dart';
import 'services/tts_service.dart';
import 'services/translation_service.dart';
import 'services/daily_quote_service.dart';
import 'services/settings_service.dart';
import 'services/extension_settings_service.dart';
import 'services/learning_stats_service.dart';
import 'services/review_reminder_service.dart';
import 'services/system_tray_service.dart';
import 'services/local_config_service.dart';
import 'widgets/learning_stats_widgets.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 性能监控 - 启动时间测量
  final stopwatch = Stopwatch()..start();
  
  // Check if this is a sub-window
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argsMap = jsonDecode(args[2]) as Map<String, dynamic>;
    final windowType = argsMap['windowType'] as String?;
    
    if (windowType == 'danmu') {
      argsMap['windowId'] = windowId.toString();
      runApp(DesktopDanmuWindow(args: argsMap));
      return;
    }
  }
  
  // Main app initialization - 并行初始化独立服务以加快启动速度
  await Future.wait([
    SettingsService.instance.initialize(),
    ExtensionSettingsService.instance.initialize(),
    LocalConfigService.instance.initialize(),
    WordBookProvider.instance.initialize(),
    LearningStatsService.instance.initialize(),
    // TtsService 延迟加载 - 只在首次使用时初始化
  ]);
  debugPrint('⏱️ Services initialized in ${stopwatch.elapsedMilliseconds}ms');

  // 启动复习提醒服务
  ReviewReminderService.instance.startReminder();

  debugPrint('⏱️ App ready in ${stopwatch.elapsedMilliseconds}ms');
  stopwatch.stop();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: WordBookProvider.instance),
        ChangeNotifierProvider.value(value: ThemeProvider.instance),
      ],
      child: const VocabuApp(),
    ),
  );
}

class VocabuApp extends StatelessWidget {
  const VocabuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Vocabu',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MainScaffold(),
        );
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // 全局热键
  final HotKey _queryHotKey = HotKey(
    key: PhysicalKeyboardKey.keyE,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  final List<Widget> _pages = [
    const HomePage(),
    const StorePage(),
    const ExtensionsPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _registerHotKeys();
    // 延迟初始化系统托盘（非阻塞，不影响首屏渲染）
    _initSystemTray();
  }

  Future<void> _initSystemTray() async {
    await SystemTrayService.instance.initialize();
  }

  @override
  void dispose() {
    _unregisterHotKeys();
    super.dispose();
  }

  Future<void> _registerHotKeys() async {
    // Alt+E: 唤出查词对话框
    await hotKeyManager.register(
      _queryHotKey,
      keyDownHandler: (hotKey) {
        _showQueryDialog();
      },
    );
  }

  Future<void> _unregisterHotKeys() async {
    await hotKeyManager.unregister(_queryHotKey);
  }

  void _showQueryDialog() {
    QueryWordDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('首页'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books),
                label: Text('词库'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.extension_outlined),
                selectedIcon: Icon(Icons.extension),
                label: Text('扩展'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

// -- DESKTOP SIDEBAR LAYOUT --

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  WordDefinition? _searchResult;
  bool _isSearching = false;
  bool _showResults = false;

  // 每日金句状态
  DailyQuote? _dailyQuote;
  bool _isLoadingQuote = true;

  // 当前选中的词书索引
  int _currentBookIndex = 0;

  // 学习统计
  LearningStatsSummary? _learningStats;

  @override
  void initState() {
    super.initState();
    _loadDailyQuote();
    _loadLearningStats();
    // 监听复习提醒变化
    ReviewReminderService.instance.addListener(_onReminderChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    ReviewReminderService.instance.removeListener(_onReminderChanged);
    super.dispose();
  }

  void _onReminderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLearningStats() async {
    if (mounted) {
      setState(() {
        _learningStats = LearningStatsService.instance.getSummary();
      });
    }
  }

  Future<void> _loadDailyQuote() async {
    try {
      final quote = await DailyQuoteService.instance.getTodayQuote();
      if (mounted) {
        setState(() {
          _dailyQuote = quote;
          _isLoadingQuote = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }

  void _showBookSwitcher(List<WordBook> books) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择学习词书'),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final isSelected = index == _currentBookIndex;
              return ListTile(
                leading: Icon(
                  Icons.book,
                  color: isSelected ? const Color(0xFF3C8CE7) : Colors.grey,
                ),
                title: Text(
                  book.bookName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF3C8CE7) : null,
                  ),
                ),
                subtitle: Text('${book.wordCount} 词 · 已掌握 ${book.masteredCount}'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Color(0xFF3C8CE7))
                    : null,
                onTap: () {
                  setState(() => _currentBookIndex = index);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
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

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResult = null;
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    final result = await TranslationService.instance.lookupWord(query);

    if (mounted) {
      setState(() {
        _searchResult = result;
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResult = null;
      _showResults = false;
    });
  }

  Future<void> _addToWordBook() async {
    if (_searchResult == null) return;

    final provider = Provider.of<WordBookProvider>(context, listen: false);
    final books = provider.books;

    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可用的词书，请先创建词书')),
      );
      return;
    }

    final selectedBook = await showDialog<WordBook>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择词书'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: const Icon(Icons.book),
                title: Text(book.bookName),
                subtitle: Text('${book.wordCount} 词'),
                onTap: () => Navigator.pop(ctx, book),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedBook != null && mounted) {
      final success = await provider.addWordToBook(
        bookId: selectedBook.bookId,
        word: _searchResult!.word,
        translation: _searchResult!.definitions.isNotEmpty
            ? _searchResult!.definitions.join('; ')
            : _searchResult!.translation,
        phonetic: _searchResult!.phoneticUs,
        example: _searchResult!.examples.isNotEmpty ? _searchResult!.examples.first : '',
        exampleTranslation: _searchResult!.exampleTranslations.isNotEmpty
            ? _searchResult!.exampleTranslations.first
            : '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '已添加 "${_searchResult!.word}" 到 ${selectedBook.bookName}'
                : '添加失败，单词可能已存在'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordBookProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final books = provider.books;
        // 确保索引有效
        if (_currentBookIndex >= books.length && books.isNotEmpty) {
          _currentBookIndex = 0;
        }
        final currentBook = books.isNotEmpty ? books[_currentBookIndex] : null;
        final stats = provider.homePageStats;

        return Material(
          color: colorScheme.surface,
          child: Row(
            children: [
              // Left Sidebar
              Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.home_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('学习概览', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Scrollable content area
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stats Summary
                            _SidebarStatItem(
                              icon: Icons.school_outlined,
                              label: '今日新学',
                              value: '${_learningStats?.todayNew ?? 0}/${_learningStats?.dailyGoalNew ?? 20}',
                            ),
                            const SizedBox(height: 12),
                            _SidebarStatItem(
                              icon: Icons.refresh_outlined,
                              label: '今日复习',
                              value: '${_learningStats?.todayReview ?? 0}/${_learningStats?.dailyGoalReview ?? 50}',
                            ),
                            const SizedBox(height: 12),
                            _SidebarStatItem(
                              icon: Icons.local_fire_department_outlined,
                              label: '连续打卡',
                              value: '${_learningStats?.currentStreak ?? 0} 天',
                            ),

                            const SizedBox(height: 32),

                            // Review Reminder
                            if (ReviewReminderService.instance.pendingReviewCount > 0)
                              _ReviewReminderCard(
                                count: ReviewReminderService.instance.pendingReviewCount,
                                hasNew: ReviewReminderService.instance.hasNewReminder,
                                onTap: () {
                                  ReviewReminderService.instance.clearReminder();
                                  // 跳转到词库页面
                                  final scaffold = context.findAncestorStateOfType<_MainScaffoldState>();
                                  scaffold?.setState(() => scaffold._selectedIndex = 1);
                                },
                              ),

                            if (ReviewReminderService.instance.pendingReviewCount > 0)
                              const SizedBox(height: 16),

                            // Quick Actions
                            Text('快捷操作', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            _SidebarActionItem(
                              icon: Icons.edit_note_rounded,
                              label: '易错词',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ErrorWordsPage())),
                            ),
                            _SidebarActionItem(
                              icon: Icons.headphones_rounded,
                              label: '听力练习',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListeningPage())),
                            ),
                            _SidebarActionItem(
                              icon: Icons.menu_book_rounded,
                              label: '英语阅读',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingPage())),
                            ),
                            _SidebarActionItem(
                              icon: Icons.record_voice_over_rounded,
                              label: '口语练习',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeakingPracticePage())),
                            ),
                            _SidebarActionItem(
                              icon: Icons.psychology_rounded,
                              label: '语法练习',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarPage())),
                            ),
                            _SidebarActionItem(
                              icon: Icons.star_rounded,
                              label: '收藏单词',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CollectedWordsPage())),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Theme Toggle (fixed at bottom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ThemeProvider.instance.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ThemeProvider.instance.isDarkMode ? '深色模式' : '浅色模式',
                              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                            ),
                          ),
                          Switch(
                            value: ThemeProvider.instance.isDarkMode,
                            onChanged: (_) => ThemeProvider.instance.toggleTheme(),
                            activeColor: colorScheme.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: Container(
                  color: colorScheme.surfaceContainerLowest,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Header with Daily Quote
                        Text(
                          '欢迎回来',
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        // 每日金句
                        if (_isLoadingQuote)
                          Text(
                            '加载每日金句...',
                            style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
                          )
                        else ...
                        [
                          Text(
                            _dailyQuote?.english ?? 'Every day is a new beginning.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dailyQuote?.chinese ?? '每一天都是新的开始。',
                            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Search Box
                        _buildSearchBox(),

                        // Search Results
                        if (_showResults) _buildSearchResults(),

                        const SizedBox(height: 24),

                        // Current Book Card with Switcher
                        if (currentBook != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '当前学习',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                  ),
                                  const SizedBox(width: 8),
                                  if (books.length > 1)
                                    TextButton.icon(
                                      onPressed: () => _showBookSwitcher(books),
                                      icon: const Icon(Icons.swap_horiz, size: 18),
                                      label: const Text('切换词书'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _DesktopBookCard(book: currentBook),
                            ],
                          )
                        else
                          _EmptyBookCard(),

                        const SizedBox(height: 32),

                        // 今日学习进度
                        if (_learningStats != null)
                          DailyProgressCard(
                            stats: _learningStats!,
                            onTap: () {
                              // 可以跳转到详细统计页面
                            },
                          ),

                        const SizedBox(height: 24),

                        // 学习趋势图表
                        LearningTrendChart(
                          dailyHistory: LearningStatsService.instance.getDailyHistory(),
                          daysToShow: 7,
                        ),

                        const SizedBox(height: 24),

                        // Heatmap Section
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '学习记录',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '过去一年',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              HeatmapCalendar(data: stats['heatmap'] ?? {}),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBox() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '输入单词查询翻译...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
              onSubmitted: (_) => _doSearch(),
              onChanged: (value) {
                if (value.isEmpty) {
                  _clearSearch();
                }
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant, size: 20),
              onPressed: _clearSearch,
            ),
          Container(
            margin: const EdgeInsets.all(6),
            child: ElevatedButton(
              onPressed: _doSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('查询', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : _searchResult != null
              ? _buildWordResultCard()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 40, color: colorScheme.outlineVariant),
                        const SizedBox(height: 8),
                        Text('未找到结果', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWordResultCard() {
    final r = _searchResult!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word header
          Row(
            children: [
              Text(
                r.word,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => TtsService.instance.speak(r.word),
                icon: const Icon(Icons.volume_up, color: Color(0xFF3C8CE7)),
                tooltip: '发音',
                iconSize: 22,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addToWordBook,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('加入词库'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                ),
              ),
              IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close),
                iconSize: 20,
                color: Colors.grey[400],
              ),
            ],
          ),

          // Phonetics
          if (r.phoneticUs.isNotEmpty || r.phoneticUk.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (r.phoneticUk.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('英 /${r.phoneticUk}/', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ),
                if (r.phoneticUs.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('美 /${r.phoneticUs}/', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Definitions in a row layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chinese definitions
              if (r.definitions.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9800),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('中文释义', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...r.definitions.take(3).map((def) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(def, style: const TextStyle(fontSize: 14, height: 1.4)),
                        )),
                      ],
                    ),
                  ),
                ),

              if (r.definitions.isNotEmpty && r.definitionsEn.isNotEmpty)
                const SizedBox(width: 12),

              // English definitions
              if (r.definitionsEn.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3C8CE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('英文释义', style: TextStyle(color: Colors.white, fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...r.definitionsEn.take(2).map((def) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(def, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF1565C0))),
                        )),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Example sentences
          if (r.examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('例句', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    r.examples.length > 2 ? 2 : r.examples.length,
                    (index) {
                      final example = r.examples[index];
                      final trans = index < r.exampleTranslations.length
                          ? r.exampleTranslations[index]
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => TtsService.instance.speak(example),
                              child: Icon(Icons.play_circle_outline, size: 18, color: Colors.green[600]),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(example, style: const TextStyle(fontSize: 13, height: 1.4)),
                                  if (trans.isNotEmpty)
                                    Text(trans, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SidebarStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _DesktopBookCard extends StatelessWidget {
  final WordBook book;

  const _DesktopBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = book.wordCount > 0 ? book.masteredCount / book.wordCount : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book Cover
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.book, color: colorScheme.onPrimary, size: 36),
            ),
          ),
          const SizedBox(width: 24),

          // Book Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.bookName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  '${book.wordCount} 词 · ${book.masteredCount} 已掌握',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                // Progress
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Action Button
                FilledButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailPage(bookName: book.bookName),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    '开始学习',
                    style: GoogleFonts.notoSansSc(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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

class _EmptyBookCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.library_books_outlined, size: 48, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('暂无课程', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ReviewReminderCard extends StatelessWidget {
  final int count;
  final bool hasNew;
  final VoidCallback onTap;

  const _ReviewReminderCard({
    required this.count,
    required this.hasNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasNew
              ? const Color(0xFFFF9800).withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasNew
                ? const Color(0xFFFF9800).withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasNew
                    ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                    : colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasNew ? Icons.notifications_active : Icons.notifications_outlined,
                size: 18,
                color: hasNew ? const Color(0xFFFF9800) : colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasNew ? '复习提醒' : '待复习',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: hasNew
                          ? const Color(0xFFFF9800)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count 个单词',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
