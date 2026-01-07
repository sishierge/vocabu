import sqlite3

conn = sqlite3.connect(r'C:\Users\nut19\OneDrive\Documents\WordMomo_Clone\wordmomo.db')
cursor = conn.cursor()

# 检查 CourseSentence 中有哪些 BookId
print('=== CourseSentence 中的 BookId ===')
cursor.execute('SELECT DISTINCT BookId FROM CourseSentence')
sentence_book_ids = [row[0] for row in cursor.fetchall()]
print(f'共 {len(sentence_book_ids)} 个词书有句子数据:')
for bid in sentence_book_ids[:10]:
    print(f'  {bid}')

# 检查 WordBook 表中的词书
print('\n=== WordBook 中的词书 ===')
cursor.execute('SELECT BookId, BookName FROM WordBook LIMIT 10')
for row in cursor.fetchall():
    has_sentences = row[0] in sentence_book_ids
    print(f'  {row[1]}: {row[0][:20]}... [句子: {"✓" if has_sentences else "✗"}]')

# 检查匹配情况
print('\n=== 匹配分析 ===')
cursor.execute('SELECT COUNT(*) FROM WordBook')
total_books = cursor.fetchone()[0]
matched = 0
for bid in sentence_book_ids:
    cursor.execute('SELECT COUNT(*) FROM WordBook WHERE BookId = ?', (bid,))
    if cursor.fetchone()[0] > 0:
        matched += 1

print(f'WordBook 总数: {total_books}')
print(f'CourseSentence 有数据的词书数: {len(sentence_book_ids)}')
print(f'匹配的词书数: {matched}')

# 显示有句子的词书名称
print('\n=== 有句子数据的词书 ===')
for bid in sentence_book_ids:
    cursor.execute('SELECT BookName FROM WordBook WHERE BookId = ?', (bid,))
    row = cursor.fetchone()
    if row:
        cursor.execute('SELECT COUNT(*) FROM CourseSentence WHERE BookId = ?', (bid,))
        count = cursor.fetchone()[0]
        print(f'  {row[0]}: {count} 条句子')

conn.close()
