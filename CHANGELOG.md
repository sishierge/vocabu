# 更新日志 / Changelog

所有重要变更都会记录在此文件中。

---

## [v1.8.0] - 2026-01-07

### 🔧 弹幕插件优化
- **例句获取改进** - 使用有道API并行获取例句（与首页查词相同）
- **处理数量提升** - 从15个增加到30个单词
- **超时优化** - 单词3秒超时/总计8秒超时
- **调试日志** - 添加详细的获取进度日志
  - `弹幕: 获取到N个单词`
  - `弹幕: 需要获取N个单词的例句...`
  - `弹幕: 成功获取N个例句`

### 🐛 Bug修复
- **语法练习页面** - 移除无效的在线题库选项（Trivia API不提供语法题目）
- **DanmuOverlay** - 添加CONFIG和WORDS命令的错误处理

### 📦 安装包
- 新增便携版打包脚本 `build_installer.ps1`
- 生成 `installer_output/Vocabu_1.0.0.zip` (21MB)

### 📝 修改文件
- `lib/pages/extensions/danmu_plugin_page.dart` - 优化例句获取逻辑
- `lib/pages/learning/grammar_page.dart` - 移除在线题库选项
- `lib/services/danmu_pipe_service.dart` - 添加调试日志
- `windows/danmu_overlay/MainWindow.xaml.cs` - 添加错误处理
- `build_installer.ps1` - **新增** 便携版打包脚本

---

## [v1.7.0] - 2026-01-06

### ✨ 新功能

#### 数据备份与恢复
- 导出学习进度为 JSON 文件
- 从备份文件恢复数据（支持增量更新）
- 备份文件自动验证
- 备份历史列表管理
- 在设置页「数据管理」区域添加入口

#### 学习报告
- 周报：7天学习时长、新词数、掌握数统计
- 月报：每周汇总、总学习天数统计
- fl_chart 柱状图可视化
- 支持导出为 PNG 图片

#### 键盘快捷键
- **闪卡模式**：
  - `空格键` - 翻转卡片
  - `1/2/3/4` - 评分（不认识/模糊/认识/太简单）
- **选择练习**：
  - `1/2/3/4` - 选择选项 A/B/C/D
- 页面显示快捷键提示

### 📝 新增/修改文件
- `lib/services/backup_service.dart` - **新增**
- `lib/services/learning_report_service.dart` - **新增**
- `lib/pages/backup_restore_page.dart` - **新增**
- `lib/pages/learning_report_page.dart` - **新增**
- `lib/pages/settings_page.dart` - 添加数据管理入口
- `lib/pages/learning/flashcard_page.dart` - 添加键盘快捷键
- `lib/pages/learning/quiz_page.dart` - 添加键盘快捷键

---

## [v1.6.0] - 2026-01-06

### ✨ 新功能
- **在线听力素材（带真实音频）** - 新增 5 个在线素材包
  - 🇺🇸 VOA 慢速英语 (25 句)
  - 🇬🇧 BBC Learning English (20 句)
  - 📅 每日英语短句 (20 句)
  - 🎤 TED 演讲精选 (20 句)
  - 📰 新闻英语听力 (20 句)
- **真实音频播放** - 使用 Google Translate TTS 生成高质量发音
- 支持 0.5x - 2.0x 变速播放
- 素材带缓存支持，首次加载后离线可用

### 🔧 改进
- **LocalConfigService 集成** - TTS 速度/音量从配置读取
- **启动性能监控** - Debug 模式输出服务初始化耗时
- 在线素材自动标记为"(在线音频)"

### 📝 新增/修改文件
- `lib/services/audio_player_service.dart` - **新增** 音频播放服务
- `lib/services/online_materials_service.dart` - 添加音频URL支持
- `lib/pages/learning/listening_page.dart` - 集成真实音频播放
- `pubspec.yaml` - 添加 audioplayers 依赖

---

## [v1.5.0] - 2026-01-05

### 🔧 插件系统修复
- **WPF Overlay 点击穿透** - 实现选择性点击穿透（透明区域穿透，UI可交互）
- **插件状态检测** - 使用 `tasklist` 检查实际进程状态
- **插件停止功能** - 发送 STOP 命令后等待确认，备用 `taskkill`

### 📖 翻译优化
- **竞争条件修复** - 添加请求版本号追踪
- **API 单词验证** - 验证返回单词是否与查询词完全匹配

---

## [v1.4.0] - 2026-01-04

### 🐛 Bug修复 (12个)

#### Critical (3)
- 修复 `FlashcardPage` 缺少 `unitName` 参数导致编译错误
- 修复 `settings_page` 免打扰时间解析崩溃风险（添加 try-catch + 默认值）
- 验证 `WordRepository` 依赖完整性 ✅

#### Medium (5)
- 修复虚拟单元掌握数始终为 0（新增数据库查询）
- 修复插件启用状态不同步（从 `ExtensionSettingsService` 读取）
- 修复收藏卡片数量硬编码为 0（动态读取 `collectedCount`）
- 优化熟词管理工具栏按钮（禁用未实现功能）
- 合并收藏页冗余 `mounted` 检查

#### Low (4)
- 移除 `mastered_words_page` 空 if 语句
- 确认主题切换自动刷新
- 确认 `database_helper` 阈值已优化
- 实现插件状态持久化

### 📝 修改的文件
- `lib/pages/learning/flashcard_page.dart`
- `lib/pages/settings_page.dart`
- `lib/pages/book_detail_page.dart`
- `lib/pages/extensions_page.dart`
- `lib/pages/mastered_words_page.dart`
- `lib/pages/collected_words_page.dart`
- `lib/providers/word_book_provider.dart`
- `lib/services/extension_settings_service.dart`

---

## [v1.3.0] - 2026-01-03

### 🐛 Bug修复
- 修复字体显示问题（移除 GoogleFonts 依赖）
- 修复插件无法连接（添加 .NET 运行时配置文件）
- 修复单元单词重复（动态计算 startIndex）
- 修复复习功能失效（类型匹配问题）

### ✨ 新功能
- 弹幕轨道系统防重叠

---

## [v1.2.0] - 2026-01-03

### ✨ 新功能
- 文章听力模式
- BBC Learning English 系列（5个新素材包）
- 听力素材快速切换
- 英语书籍阅读设置持久化
- 高级拼写自动播放
- 项目重命名: `wordmomo_clone` → `loving_word` → `vocabu`

### 🔧 改进
- 高级拼写快捷键: Space → Ctrl+M
- 词汇显示限制: 10,000 → 100,000

---

## [v1.1.0] - 2026-01-03

### ✨ 新功能
- 新增文章听力功能
- 新增 BBC 素材包

---

## [v1.0.0] - 2026-01-02

### 🐛 Bug修复
- 修复插件路径查找问题
- 优化弹幕启动速度

---

## [v0.9.0] - 2026-01-01

### 🔧 改进
- 贴纸插件改为纯沉浸式设计

---

## [v0.8.0] - 2026-01-01

### 🐛 Bug修复
- 修复插件字段名映射问题

---

## [v0.7.0] - 2026-01-01

### 🔧 改进
- WPF插件改为自包含编译

---

## [v0.6.0] - 2025-12-31

### ✨ 新功能
- 完成贴纸插件基础功能

---

## [v0.5.0] - 2025-12-31

### ✨ 新功能
- 完成轮播插件

---

## [v0.4.0] - 2025-12-30

### ✨ 新功能
- 完成弹幕插件

---

**格式说明**:
- 🐛 Bug修复
- ✨ 新功能
- 🔧 改进
- 📝 文档
- ♻️ 重构
