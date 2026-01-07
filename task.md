- [x] Implement Models: `Word`, `Book`, `StudyLog` <!-- id: 5 -->
- [ ] Implement `LocalConfigService` to read `localConfig.json` <!-- id: 6 -->
- [x] Implement FSRS Algorithm Class <!-- id: 7 -->

## Phase 3: UI Implementation (The Face)
- [x] **Sidebar & Shell** (Menu: Home, Library, Words, Store, Materials, Features, Settings) <!-- id: 8 -->
- [x] **Home Page ("我的主页")**
    - [x] Statistics Header (Implement `StudyLog` service & Connect) <!-- id: 9 -->
    - [x] Heatmap Calendar Widget (Connect to `DailyLearnInfo`) <!-- id: 10 -->
    - [x] Recent Study Course Cards (Persist last opened book) <!-- id: 11 -->
- [x] **Library Page ("我的词库")**
    - [x] Course Grid with Progress Bars (Connected to DB) <!-- id: 12 -->
    - [x] Toolbar (New, Group, Search) <!-- id: 13 -->
- [x] **Store Page ("词库中心")** created as **Import Center**
    - [x] Renamed to "Data Import" <!-- id: 14 -->
    - [x] Implemented JSON Import Logic <!-- id: 15 -->
    - [x] Added "Quick Start" Demo Book <!-- id: 30 -->
- [x] **Mastered Words ("熟词管理")** (Connect to DB `LearnStatus=2`) <!-- id: 23 -->
- [/] **Extended Materials ("扩展资料")** (UI implemented, Data mocked) <!-- id: 16 -->

## Phase 4: Core Logic (The Soul)
- [x] **Flashcard Review Gameplay**
    - [x] Front/Back Card flipping <!-- id: 17 -->
    - [x] Grading Buttons (Custom Tiles) <!-- id: 18 -->
    - [x] Progress Update logic <!-- id: 19 -->
- [/] **Learning Modes**
    - [x] Quiz Mode <!-- id: 24 -->
    - [x] Spelling Mode (Refreshed UI) <!-- id: 25 -->
    - [x] Audio/TTS Support (`flutter_tts`) <!-- id: 27 -->
- [x] **Import/Export**
    - [x] Decoupled from Original App Data (Uses local `wordmomo.db`) <!-- id: 31 -->
    - [x] Implemented `ImportService` <!-- id: 32 -->
    - [x] **1:1 Original Schema Mirror** (Restored `CourseSentence` etc.) <!-- id: 33 -->
    - [x] **Data Migration Tool** (Clone `data.db` from original) <!-- id: 34 -->

## Phase 5: Polish & Verify
- [x] **Visual Overhaul (Design 2.0)**
    - [x] Redesign "Advanced Spelling" (Card style, better feedback) <!-- id: 28 -->
    - [x] Redesign "Flashcard" (Elevation, Typography, Buttons) <!-- id: 29 -->
- [/] Match Colors and Fonts (Ongoing) <!-- id: 21 -->
- [x] Verify Data Persistence (Logic verified via tests) <!-- id: 22 -->
