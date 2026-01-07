import sqlite3
import os

# 连接两个数据库
wordmomo_db = r'C:\Users\nut19\OneDrive\Documents\WordMomo_Clone\wordmomo.db'
reslib_db = r'C:\Users\nut19\AppData\Roaming\com.enki.wordmomo\WordMomo\reslib\english-basic-data\reslib.db'

print('=== 开始填充翻译数据 ===')

# 连接 reslib 并读取所有翻译
print('读取 reslib 翻译数据...')
reslib_conn = sqlite3.connect(reslib_db)
reslib_cursor = reslib_conn.cursor()
reslib_cursor.execute('SELECT word, symbol, translate FROM ReslibItem')
reslib_data = {row[0].lower(): (row[1], row[2]) for row in reslib_cursor.fetchall() if row[0]}
reslib_conn.close()
print(f'读取到 {len(reslib_data)} 条翻译数据')

# 连接 wordmomo 并更新翻译
print('更新 WordItem 表...')
wm_conn = sqlite3.connect(wordmomo_db)
wm_cursor = wm_conn.cursor()

# 获取所有需要更新的单词
wm_cursor.execute("SELECT WordId, Word FROM WordItem WHERE Translate IS NULL OR Translate = ''")
words_to_update = wm_cursor.fetchall()
print(f'需要更新 {len(words_to_update)} 个单词')

# 批量更新
updated = 0
not_found = 0
for word_id, word in words_to_update:
    word_lower = word.lower() if word else ''
    if word_lower in reslib_data:
        symbol, translate = reslib_data[word_lower]
        wm_cursor.execute(
            'UPDATE WordItem SET Symbol = ?, Translate = ? WHERE WordId = ?',
            (symbol or '', translate or '', word_id)
        )
        updated += 1
    else:
        not_found += 1

wm_conn.commit()
wm_conn.close()

print(f'\n=== 完成 ===')
print(f'成功更新: {updated} 个单词')
print(f'未找到翻译: {not_found} 个单词')
