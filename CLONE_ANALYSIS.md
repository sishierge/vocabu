# WordMomo Clone - Implementation Analysis

## Current Status (2025-12-31)

### 1. Database & Core Infrastructure ✅
- **Database Connection**: Real. Connects to `data.db`.
- **Provider**: `WordBookProvider` works for basic book counts and word lists.
- **MISSING**: No `StudyLog` or `DailyLearnInfo` integration in Provider, so Home Page stats are impossible currently.

### 2. UI Reality Check (The "Mock" List) ⚠️
- **Home Page**: **FAKE**. Uses hardcoded "0 minutes", "45 minutes". Heatmap is random static data.
- **Mastered Words**: **FAKE**. Uses hardcoded standard list `['represent', 'shortage'...]`.
- **Store Page**: **FAKE**. Uses static list logic. Does not read JSONs.
- **Extensions**: **FAKE**. Static UI.
- **TTS**: **MISSING**. Buttons exist but do nothing.

### 3. Learning Tools ✅
- **Flashcard Page**: **REAL**. Fetches real words. FSRS logic works. Updates DB.
- **List/Quiz/Spelling**: **REAL**. Work with real data.

## Implementation Plan (Prioritized)
1.  **Home Page Stats**: Connect `DailyLearnInfo` -> Provider -> UI.
2.  **Mastered Words**: Connect `getWordsByStatus(2)` -> UI.
3.  **TTS**: Add `flutter_tts` and wire up buttons.
4.  **Store/Import**: Scan local JSONs for Store page.

