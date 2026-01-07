Vocabu 是一款Windows桌面端智能英语学习软件，具备词书管理、多种学习模式、听力练习、以及5个扩展插件功能。

---

## 整体进度

| 模块 | 进度 | 状态 |
|------|------|------|
| 核心框架 | 100% | ✅ 已完成 |
| 词书管理 | 100% | ✅ 已完成 |
| 学习模式 | 100% | ✅ 已完成 |
| 听力练习 | 100% | ✅ 已完成 |
| 扩展插件 | 100% | ✅ 已完成 |
| UI美化 | 100% | ✅ 已完成 |
| 安装包 | 100% | ✅ 已完成 |

---

## 一、2026-01-07 更新日志（v1.8.0）

### 🔧 弹幕插件优化

#### 例句获取改进 ✅
- **问题**: 弹幕点击后显示单词本身而非例句
- **原因**: 例句获取超时过短、数量限制过少
- **解决方案**:
  - 使用有道API并行获取（与首页查词相同）
  - 处理数量从15个增加到30个
  - 单词超时3秒/总计超时8秒
  - 添加详细调试日志

**修改文件**:
- `lib/pages/extensions/danmu_plugin_page.dart`
  - `_fetchExamplesParallel()` 优化
  - 添加调试输出
- `lib/services/danmu_pipe_service.dart`
  - 添加CONFIG/WORDS命令日志

### 🐛 Bug修复

#### 语法练习在线题库 ✅
- **问题**: 在线语法练习选项无效（Trivia API不提供语法题目）
- **解决方案**: 移除在线题库选项，仅使用本地题目
- **修改文件**: `lib/pages/learning/grammar_page.dart`

#### DanmuOverlay错误处理 ✅
- **问题**: WPF应用在解析数据时可能崩溃
- **解决方案**: 添加try-catch错误处理
- **修改文件**: `windows/danmu_overlay/MainWindow.xaml.cs`

### 📦 安装包功能

#### 便携版打包脚本 ✅
- **新增文件**: `build_installer.ps1`
- **功能**:
  - 复制Release版本主程序
  - 复制WPF插件到plugins目录
  - 打包为ZIP压缩包
- **输出**: `installer_output/Vocabu_1.0.0.zip` (21MB)

---

## 二、核心功能模块 ✅

### 1.1 数据库系统
- [x] SQLite数据库集成 (`database_helper.dart`)
- [x] 词书数据模型 (`word_book.dart`)
- [x] 单词数据模型 (`word_item.dart`)
- [x] 词书仓库 (`book_repository.dart`)
- [x] 单词仓库 (`word_repository.dart`)
- [x] 统计仓库 (`stats_repository.dart`)

### 1.2 状态管理
- [x] Provider状态管理
- [x] WordBookProvider - 词书和单词数据
- [x] ThemeProvider - 主题切换

### 1.3 服务层
- [x] 本地配置服务 (`local_config_service.dart`)
- [x] 词书导入服务 (`import_service.dart`)
- [x] FSRS记忆算法服务 (`fsrs_service.dart`)
- [x] SM-2记忆算法服务 (`sm2_service.dart`)
- [x] TTS语音服务 (`tts_service.dart`)
- [x] 翻译服务 (`translation_service.dart`)
- [x] 扩展设置服务 (`extension_settings_service.dart`)
- [x] 英语书籍服务 (`english_book_service.dart`)
- [x] 每日金句服务 (`daily_quote_service.dart`)
- [x] 听力素材服务 (`listening_materials_service.dart`) - **新增**
- [x] 在线素材服务 (`online_materials_service.dart`) - **v1.6.0新增**
- [x] 设置服务 (`settings_service.dart`) - 自启动、持久化配置

---

## 二、页面模块 ✅

### 2.1 主页面
- [x] 首页 (`main.dart`) - 词书列表、搜索框、每日金句
- [x] 词书详情页 (`book_detail_page.dart`) - 单元学习、词汇浏览
- [x] 设置页 (`settings_page.dart`) - 主题、自启动、算法选择
- [x] 商店页 (`store_page.dart`)
- [x] 扩展功能页 (`extensions_page.dart`)
- [x] 英语书籍页 (`english_books_page.dart`) - 原著阅读、点词翻译

### 2.2 学习模式
- [x] 闪卡模式 (`flashcard_page.dart`)
- [x] 列表模式 (`list_page.dart`)
- [x] 拼写模式 (`spelling_page.dart`)
- [x] 高级拼写 (`advanced_spelling_page.dart`) - TTS自动播放、Ctrl+M显示答案
- [x] 测验模式 (`quiz_page.dart`)

### 2.3 听力练习 **新增**
- [x] 单句听力 (`listening_page.dart`)
  - [x] 15个素材包，500+句子
  - [x] 素材快速切换
  - [x] 听写模式
  - [x] 循环播放设置
- [x] 文章听力 (`article_listening_page.dart`) **新增**
  - [x] 全文显示
  - [x] 句子高亮跟随
  - [x] 连续播放模式
  - [x] 语速调节（8档）
  - [x] 翻译显示开关

### 2.4 听力素材库 **大幅扩充**
| 分类 | 素材包 | 句子数 |
|------|--------|--------|
| 基础 | 日常对话、生活常用语、发音教程 | ~150 |
| 场景 | 旅行英语、影视台词、地道英语 | ~140 |
| 职场 | 商务英语、科技英语、面试英语、BBC职场 | ~200 |
| 进阶 | 习语、新闻、BBC 6分钟、BBC新闻 | ~180 |
| 学术 | 学术英语 | ~60 |

### 2.5 单词管理
- [x] 已掌握单词页 (`mastered_words_page.dart`)
- [x] 错词本页 (`error_words_page.dart`)
- [x] 收藏单词页 (`collected_words_page.dart`)

### 2.6 组件
- [x] 热力图日历 (`heatmap_calendar.dart`)
- [x] 词书详情组件 (`book_detail_widgets.dart`)

---

## 三、扩展插件模块 ✅

### 3.1 弹幕插件 ✅ 100%
- [x] WPF透明全屏窗口
- [x] 弹幕动画效果
- [x] TCP Socket通信 (端口9527)
- [x] 词书选择、速度/字体/颜色设置
- [x] 效果预览、启动/暂停/停止控制

### 3.2 轮播插件 ✅ 100%
- [x] 桌面角落显示
- [x] 定时自动切换
- [x] 多种卡片样式

### 3.3 贴纸插件 ✅ 100%
- [x] 可拖拽移动
- [x] 右键删除
- [x] 布局方式（随机/网格/阶梯）

### 3.4 查词插件 ✅ 100%
- [x] 首页搜索框集成
- [x] 多API翻译支持
- [x] 一键添加到词库

### 3.5 离线TTS ✅ 100%
- [x] Windows SAPI引擎
- [x] 语音/语速/音量调节

---

## 四、2026-01-06 更新日志（v1.7.0）

### ✨ 用户体验增强 - 方向A

#### A1: 数据备份/恢复 ✅
- **备份服务** (`lib/services/backup_service.dart`)
  - 导出学习进度为 JSON 文件
  - 自动验证备份文件格式
  - 支持增量恢复（更新现有单词进度）
  - 备份文件列表管理

- **备份管理页面** (`lib/pages/backup_restore_page.dart`)
  - 一键备份当前数据
  - 从文件选择器导入备份
  - 显示备份历史列表
  - 备份文件详情（大小、时间、词数）
  - 支持删除旧备份

- **设置页入口** (`lib/pages/settings_page.dart`)
  - 在「数据管理」区域添加备份恢复入口

#### A2: 学习报告导出 ✅
- **报告服务** (`lib/services/learning_report_service.dart`)
  - 周报数据生成（7天学习时长、新词数、掌握数）
  - 月报数据生成（每周汇总、总学习天数）
  - Widget 截图保存为 PNG

- **报告页面** (`lib/pages/learning_report_page.dart`)
  - 周报/月报 Tab 切换
  - fl_chart 柱状图展示
  - 每日详情列表
  - 导出为 PNG 图片

- **设置页入口** (`lib/pages/settings_page.dart`)
  - 在「数据管理」区域添加学习报告入口

#### A3: 键盘快捷键 ✅
- **闪卡模式** (`lib/pages/learning/flashcard_page.dart`)
  - `空格键` - 翻转卡片显示答案
  - `数字键 1` - 不认识
  - `数字键 2` - 模糊
  - `数字键 3` - 认识
  - `数字键 4` - 太简单
  - 快捷键提示文字

- **选择练习** (`lib/pages/learning/quiz_page.dart`)
  - `数字键 1` - 选项 A
  - `数字键 2` - 选项 B
  - `数字键 3` - 选项 C
  - `数字键 4` - 选项 D
  - 快捷键提示文字

**新增/修改文件**:
- `lib/services/backup_service.dart` - **新增** 备份恢复服务
- `lib/services/learning_report_service.dart` - **新增** 学习报告服务
- `lib/pages/backup_restore_page.dart` - **新增** 备份管理页面
- `lib/pages/learning_report_page.dart` - **新增** 学习报告页面
- `lib/pages/settings_page.dart` - 添加数据管理入口
- `lib/pages/learning/flashcard_page.dart` - 添加键盘快捷键
- `lib/pages/learning/quiz_page.dart` - 添加键盘快捷键

---

## 五、2026-01-06 更新日志（v1.6.0）

### ✨ 在线听力素材（带真实音频）

新增在线素材分类，包含 5 个新素材包，**支持真实音频播放**：

| 素材名称 | 描述 | 句子数 | 音频 |
|----------|------|--------|------|
| 🇺🇸 VOA 慢速英语 | Voice of America 新闻 | 25 | ✅ |
| 🇬🇧 BBC Learning English | BBC学习英语节目 | 20 | ✅ |
| 📅 每日英语短句 | 励志英语短句 | 20 | ✅ |
| 🎤 TED 演讲精选 | TED 经典语录 | 20 | ✅ |
| 📰 新闻英语听力 | 精选新闻片段 | 20 | ✅ |

**新增/修改文件**:
- `lib/services/audio_player_service.dart` - **新增** 音频播放服务
- `lib/services/online_materials_service.dart` - 添加音频URL支持
- `lib/pages/learning/listening_page.dart` - 集成真实音频播放
- `pubspec.yaml` - 添加 audioplayers 依赖

**技术特性**:
- 使用 Google Translate TTS 生成高质量发音
- 支持 0.5x - 2.0x 变速播放
- 带本地缓存支持，首次加载后离线可用
- 在线素材自动标记为"(在线音频)"

### 🔧 LocalConfigService 集成

- `main.dart` 添加 LocalConfigService 初始化
- `tts_service.dart` 从配置读取 ttsSpeed 和 ttsVolume

### 📊 启动性能监控

Debug 模式下输出服务初始化耗时：
- `⏱️ Services initialized in Xms`
- `⏱️ App ready in Xms`

---

## 六、2026-01-05 更新日志（v1.5.0）

### 🔧 插件系统重大修复

#### WPF Overlay 点击穿透问题 ✅
- **问题**: `WS_EX_TRANSPARENT` 标志使整个窗口穿透鼠标，导致弹幕/贴纸无法点击
- **解决方案**: 实现 `WndProc` + `WM_NCHITTEST` 选择性点击穿透
  - 透明区域返回 `HTTRANSPARENT` → 穿透点击
  - UI 元素返回 `HTCLIENT` → 可以交互
- **修改文件**:
  - `windows/danmu_overlay/MainWindow.xaml.cs` - 弹幕可点击显示例句
  - `windows/sticky_overlay/MainWindow.xaml.cs` - 贴纸可拖动

#### 插件状态检测修复 ✅
- **问题**: `isRunning` 只检查 socket 连接，但 overlay 启动后会断开连接
- **解决方案**: 使用 `tasklist` 检查实际进程状态
  ```dart
  static Future<bool> checkProcessRunning() async {
    final result = await Process.run('tasklist', 
      ['/FI', 'IMAGENAME eq StickyOverlay.exe', '/NH']);
    return result.stdout.contains('StickyOverlay.exe');
  }
  ```
- **修改文件**: 
  - `lib/services/sticky_pipe_service.dart`
  - `lib/services/danmu_pipe_service.dart`
  - `lib/services/carousel_pipe_service.dart`
  - `lib/pages/extensions_page.dart` - 使用异步进程检测

#### 插件停止功能修复 ✅
- **问题**: `stop()` 方法发送 STOP 命令后立即断开，命令可能未到达
- **解决方案**: 
  1. 发送 STOP 命令 → 等待 500ms
  2. 断开连接
  3. 备用方案：`taskkill /F /IM xxx.exe`

### 📖 翻译功能优化

#### 翻译竞争条件修复 ✅
- **问题**: 快速选择多个单词时，旧请求结果覆盖新请求
- **解决方案**: 添加请求版本号追踪
- **修改文件**: `lib/pages/english_books_page.dart`

#### 翻译 API 单词验证 ✅
- **问题**: 有道/iCiba API 返回模糊匹配结果（如查 "handsome" 返回 "handle"）
- **解决方案**: 验证返回单词是否与查询词完全匹配
- **修改文件**: `lib/services/translation_service.dart`

### 📊 其他修复

- **复习单词数量**: 添加 `LearnStatus >= 1` 条件，只统计已学习单词
- **DLL 部署问题**: 修复 .NET overlay DLL 未正确复制的问题

---

## 七、历史更新日志

### v1.4.0 (2026-01-04)

#### 🐛 全面Bug修复 - 12个逻辑错误

#### 🔴 Critical修复 (3个)

1. **FlashcardPage缺少unitName参数** (编译错误)
   - 文件: `lib/pages/learning/flashcard_page.dart`
   - 问题: book_detail_page调用时传入unitName，但FlashcardPage未定义该参数
   - 修复: 添加 `final String? unitName` 字段和构造参数
   - 影响: 单元学习功能无法正常导航

2. **settings_page时间解析崩溃风险**
   - 文件: `lib/pages/settings_page.dart` (L372-395)
   - 问题: 免打扰时间设置直接使用 `int.parse()` 解析，格式错误时崩溃
   - 修复: 添加 try-catch + 默认值 TimeOfDay(22, 0) 和 TimeOfDay(7, 0)
   - 影响: 预防用户数据错误导致应用崩溃

3. **WordRepository依赖验证**
   - 文件: `lib/repositories/word_repository.dart`
   - 结果: ✅ 已验证存在，包含完整 `getErrorWords()` 方法
   - 说明: 原标记为潜在bug，实际不存在问题

#### 🟠 Medium修复 (5个)

4. **book_detail_page收藏卡片硬编码**
   - 文件: `lib/pages/book_detail_page.dart` (L468)
   - 问题: 收藏数量显示硬编码为 '0'
   - 修复: 改为读取 `book.collectedCount` 动态显示
   - 同步修改: `lib/providers/word_book_provider.dart` 添加 `collectedCount` 字段

5. **mastered_words_page工具栏按钮未实现**
   - 文件: `lib/pages/mastered_words_page.dart` (L87-90)
   - 问题: 导入/复制/删除/清空按钮 `onPressed: () {}` 空函数
   - 修复: 改为 `onPressed: null` 禁用按钮，明确表示未实现
   - 影响: 避免用户点击无反应的困惑

6. **collected_words_page冗余mounted检查**
   - 文件: `lib/pages/collected_words_page.dart` (L35-48)
   - 问题: 两个连续的 `if (mounted)` 块，第二个冗余
   - 修复: 合并为一个 if 块，同时执行 setState 和 SnackBar
   - 影响: 代码简洁性和可维护性

7. **extensions_page插件状态不同步** 🎯
   - 文件: `lib/pages/extensions_page.dart` (L17-38)
   - 问题: 插件启用状态硬编码为 `false`，不从服务读取
   - 修复: 
     - 在 `initState()` 中从 `ExtensionSettingsService` 读取状态
     - 添加 `_loadPluginStates()` 方法动态加载
   - 同步修改: `lib/services/extension_settings_service.dart`
     - 添加 `isDanmuEnabled`, `isCarouselEnabled`, `isStickyEnabled` getter
     - 添加对应的 setter 方法保存状态
   - 影响: 插件开关状态现在可以正确持久化

8. **book_detail_page虚拟单元掌握数硬编码** 🎯
   - 文件: `lib/pages/book_detail_page.dart` (L210-238)
   - 问题: 虚拟单元的 `mastered` 字段始终为 0
   - 修复: 在生成虚拟单元时查询数据库获取实际掌握数
     ```dart
     final words = await WordBookProvider.instance.getWordsForBookByRange(
       bookId, offset: startIndex, limit: wordsInUnit,
     );
     masteredCount = words.where((w) => (w['LearnStatus'] as int? ?? 0) == 2).length;
     ```
   - 影响: 单元学习进度现在准确显示

#### 🟡 Low修复 (4个)

9. **mastered_words_page空if语句**
   - 文件: `lib/pages/mastered_words_page.dart` (L65-68)
   - 问题: 空的 if 语句块 (3行注释代码)
   - 修复: 移除无用代码
   - 影响: 代码清洁度

10. **settings_page主题切换刷新**
    - 说明: Flutter自动响应主题变更，无需额外处理
    - 状态: ✅ 无需修改

11. **database_helper阈值常量化**
    - 文件: `lib/services/database_helper.dart`
    - 说明: 文件在之前版本已重构，不存在硬编码阈值
    - 状态: ✅ 已优化

12. **extensions_page插件选择持久化**
    - 文件: `lib/services/extension_settings_service.dart`
    - 修复: 已在修复#7中实现，添加了完整的状态持久化
    - 影响: 插件启用状态在应用重启后保留

### 📊 修复统计

- 🔴 Critical: 3/3 (100%)
- 🟠 Medium: 5/5 (100%)
- 🟡 Low: 4/4 (100%)
- **总计: 12/12 (100%)**

### ✅ 验证结果

所有修改文件通过 `flutter analyze`:
- ✅ `lib/pages/book_detail_page.dart`
- ✅ `lib/pages/extensions_page.dart`
- ✅ `lib/services/extension_settings_service.dart`
- ✅ `lib/pages/mastered_words_page.dart`
- ✅ `lib/pages/collected_words_page.dart`

---

### v1.3.0 (2026-01-03)

#### 重大Bug修复

1. **字体显示问题** - 移除GoogleFonts依赖，改用系统字体Microsoft YaHei
   - 文件: `lib/providers/theme_provider.dart`
   - 原因: GoogleFonts需要网络下载字体，离线时显示异常

2. **插件无法连接** - 修复Overlay插件启动后无法建立TCP连接
   - 文件: `lib/services/*_pipe_service.dart`
   - 原因: 缺少.NET运行时配置文件(deps.json, runtimeconfig.json)
   - 修复: 添加workingDirectory参数、复制完整依赖文件

3. **单元单词重复** - 修复所有单元显示相同单词的问题
   - 文件: `lib/providers/word_book_provider.dart`
   - 原因: `getUnitsForBook`返回的单元缺少startIndex字段
   - 修复: 动态计算每个单元的startIndex（基于累计词数）

4. **复习功能失效** - 修复复习单词查询类型不匹配
   - 文件: `lib/providers/word_book_provider.dart`, `lib/repositories/word_repository.dart`, `lib/repositories/book_repository.dart`
   - 原因: NextReviewTime存储为int，查询时错误使用toString()
   - 修复: 移除.toString()，直接传递int类型

### 功能优化

1. **弹幕轨道系统** - 防止弹幕重叠
   - 文件: `windows/danmu_overlay/MainWindow.xaml.cs`
   - 将弹幕区域划分为多个水平轨道
   - 每个轨道高度70像素，间隙10像素
   - 新弹幕自动寻找可用轨道

### 技术改进

1. **数据库查询兼容性** - 处理旧数据库缺少列的情况
   - `getUnitsForBook`添加UnitOrder列不存在时的fallback

---

## 五、历史更新日志

### v1.2.0 (2026-01-03)
1. **文章听力模式** - 类似《每日英语听力》的文章阅读+听力练习
2. **BBC Learning English系列** - 5个新素材包
   - BBC 6分钟英语
   - BBC 职场英语
   - BBC 新闻英语
   - BBC 地道英语
   - BBC 发音教程
3. **听力素材快速切换** - 无需下载，直接加载播放
4. **英语书籍阅读设置持久化** - 字体/行高/主题自动保存
5. **高级拼写自动播放** - 新单词自动TTS播放
6. **高级拼写快捷键冲突** - Space改为Ctrl+M显示答案
7. **词汇显示限制** - 从10000增加到100000
8. **项目重命名** - `wordmomo_clone` → `loving_word` → `vocabu`

---
| v1.5.0 | 2026-01-05 | 插件系统修复：点击穿透、状态检测、停止功能 |
| v1.4.0 | 2026-01-04 | Bug全面修复，翻译优化 |
| v0.7.0 | 2026-01-01 | WPF插件改为自包含编译 |
| v0.6.0 | 2025-12-31 | 完成贴纸插件基础功能 |
| v0.5.0 | 2025-12-31 | 完成轮播插件 |
| v0.4.0 | 2025-12-30 | 完成弹幕插件 |

---

## 八、待优化项

### 功能优化
- [x] 听力素材在线获取（BBC/VOA真实音频）✅ v1.6.0 已实现
- [x] 弹幕双击标记已掌握 ✅ 已实现
- [x] 数据备份恢复 ✅ v1.7.0 已实现
- [x] 学习报告导出 ✅ v1.7.0 已实现
- [x] 键盘快捷键（空格翻卡、数字键选答案）✅ v1.7.0 已实现
- [ ] 全局热键支持（Alt+E唤出查词等）

### 性能优化
- [ ] WPF插件体积优化（当前单个~150KB，依赖.NET运行时）
- [ ] 启动速度优化

### UI优化
- [ ] 更多贴纸样式
- [x] 弹幕轨道系统防重叠 ✅ 已实现

---

*文档更新时间: 2026-01-07*
