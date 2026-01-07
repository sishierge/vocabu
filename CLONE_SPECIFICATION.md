# WordMomo Clone - Complete Specification

## 1. Application Overview
- **Name**: WordMomo (v1.2.2 clone)
- **Platform**: Windows (Flutter Desktop)
- **Purpose**: Vocabulary learning with spaced repetition

---

## 2. Global UI Components

### 2.1 Main Shell Layout
```
┌─────────────────────────────────────────────────────┐
│ 🔶 WordMomo    ≡                    🛒 ❓ — □ ×   │
├──────────┬──────────────────────────────────────────┤
│ [Avatar] │                                          │
│ pronut   │          Content Area                    │
│──────────│                                          │
│ 🏠 我的主页│                                          │
│ 📚 我的词库│                                          │
│ ✓ 熟词管理 │                                          │
│ 🔍 词库中心│                                          │
│ 📊 扩展资料│                                          │
│ ⚡ 扩展功能│                                          │
│ ⚙ 软件设置│                                          │
├──────────┴──────────────────────────────────────────┤
│ v1.2.2                                              │
└─────────────────────────────────────────────────────┘
```

### 2.2 Color Palette
| Role | Hex | Usage |
|------|-----|-------|
| Primary | #3C8CE7 | Sidebar active, buttons |
| Success | #52C41A | Green badges, progress |
| Warning | #FAAD14 | Orange alerts |
| Danger | #FF4D4F | Red warnings |
| Background | #F5F7FA | Main content bg |
| Sidebar | #FFFFFF | Sidebar bg |
| Card | #FFFFFF | Card bg |

---

## 3. Page Specifications

### 3.1 我的主页 (Home)
**Statistics Header**:
- 今日学习时长 | 本周累计 | 本周平均 | 最佳记录 | 连续学习天数 | 累计学习天数

**学习时长统计**: Heatmap calendar (month view)

**最近学习**: Course cards grid (2 columns)
- Card: Icon + Title + "最近学习 X小时前" + Progress ring

### 3.2 我的词库 (Library)
**Toolbar**: + 新建词库 | 📁 分组管理 | 🔍 全局搜索

**Course Cards Grid** (3 columns):
- Title + Word count + Progress bar + Progress %
- Footer icons: 📥 | 📊 | → | ≡

### 3.3 熟词管理 (Mastered Words)
**Toolbar**: 📥 导入熟词 | 📋 复制 | 🗑 删除 | 🗑 清空 | 🔄 反向更新

**Table**: 词汇 | 添加时间
**Pagination**: < 1 > 共 X 条 | 🔍 关键字搜索

### 3.4 词库中心 (Store)
**Tabs**: 📚 词库 | 📖 课程 | 🎧 听力课程 | 📖 小说

**Category Filter**: 全部 | 小学 | 初中 | 高中 | 大学 | 四六级 | 专八 | 考研 | 计算机 | 托福 | 雅思 | 其他 | 日语

**Book Cards** (4 columns):
- Title + Tag + Word count + Mini chart

### 3.5 扩展资料 (Extended Materials)
**Tabs**: 本地资料 | 在线下载

**Material Cards** (3 columns):
- Icon + Title + Description + Menu (≡)

### 3.6 扩展功能 (Extensions)
**Sub-menu**: 弹幕插件 | 轮播插件 | 查词插件 | 贴纸插件 | 离线语音引擎

Each plugin has:
- Header: Icon + Name + "启用" / "停用" + "还原设置"
- Introduction section
- Settings tabs

### 3.7 软件设置 (Settings)
**Tabs**: 基本设置 | WebDAV | 记忆算法 | 快捷链接

---

## 4. Learning Tools Specifications

### 4.1 卡片背单词 (Flashcard)
**Toolbar**: 🔊播放 | ⭐收藏 | ✓掌握 | 📝拼写 | ⏭延后 | 📋创建贴纸

**States**:
1. Front: Word + Phonetic + [显示背面(Space)]
2. Back: + Definition + Example

**Grading**: 不认识(10min) | 模糊(1h) | 认识(2d)

### 4.2 列表背单词 (List)
**Toggle**: 遮挡译文 | 遮挡单词
**List**: Word + Phonetic (translation masked)
**Grading**: Same as flashcard

### 4.3 选题练习 (Multiple Choice)
**Display**: Word + Phonetic + 4 Options (numbered)
**Feedback**: Correct/Wrong highlight

### 4.4 单词拼写 (Spelling)
**Display**: Partial word (green typed) + Phonetic + Definition
**Input**: Keyboard typing
**Grading**: Same as flashcard

### 4.5 高级拼写 (Sentence Spelling)
**Display**: Chinese sentence + Input boxes for each word
**Hotkeys**: Ctrl+P/J, Tab, Space, Ctrl+←/→

---

## 5. Data Models (SQLite)

### WordItem
```sql
WordId TEXT PRIMARY KEY,
BookId TEXT,
Word TEXT,
Translate TEXT,
Symbol TEXT,
LearnStatus INTEGER,
LearnParam TEXT,  -- JSON: {ease, interval, repetitions, lastReview}
NextReviewTime TEXT,
ReviewCount INTEGER,
Collected INTEGER
```

### WordBook
```sql
BookId TEXT PRIMARY KEY,
BookName TEXT,
WordCount INTEGER,
CreateTime TEXT
```

### DailyLearnInfo
```sql
Date TEXT,
Duration INTEGER,
NewCount INTEGER,
ReviewCount INTEGER
```

---

## 6. Implementation Priority

### Phase 1: Shell & Navigation
- [ ] Main layout with sidebar
- [ ] Page routing

### Phase 2: Data Layer
- [ ] SQLite connection (read existing data.db)
- [ ] FSRS algorithm implementation

### Phase 3: Core Pages
- [ ] 我的主页
- [ ] 我的词库
- [ ] 词库中心

### Phase 4: Learning Tools
- [ ] 卡片背单词
- [ ] 列表背单词
- [ ] 选题练习
- [ ] 拼写练习

### Phase 5: Extensions & Settings
- [ ] 扩展功能 (5 plugins)
- [ ] 软件设置
