import sqlite3
import os

db_path = r'C:\Users\nut19\AppData\Roaming\com.enki.wordmomo\WordMomo\accounts\83081784-deb2-4857-9e7a-e5a91d527e3e\data.db'

try:
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute("SELECT Word, LearnParam, NextReviewTime FROM WordItem WHERE LearnParam IS NOT NULL AND LearnParam != '' LIMIT 1")
    row = c.fetchone()
    print(f"Row: {row}")
except Exception as e:
    print(f"Error: {e}")
finally:
    if 'conn' in locals(): conn.close()
