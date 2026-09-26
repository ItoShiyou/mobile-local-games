"""Checks store listing text against each store's length limits.

    python3 tool/check_listing.py
"""
import os
import re
import sys

LIMITS = {
    'アプリ名': 30, 'App name': 30,
    'サブタイトル': 30, 'Subtitle': 30,
    'プロモーションテキスト': 170, 'Promotional text': 170,
    'キーワード': 100, 'Keywords': 100,
    '簡単な説明': 80, 'Short description': 80,
}

path = os.path.join(os.path.dirname(__file__), '..', 'store', 'listing.md')
text = open(path, encoding='utf-8').read()
ok = True

# "- **Label**（上限N）：value" or a value on the following indented line
for m in re.finditer(r'- \*\*(.+?)\*\*[^\n]*?[：:]\s*\n?\s*(.+)', text):
    label, value = m.group(1), m.group(2).strip()
    limit = LIMITS.get(label)
    if limit is None:
        continue
    n = len(value)
    flag = 'OK ' if n <= limit else 'NG '
    ok &= n <= limit
    print(f'{flag}{label}: {n}/{limit}  {value[:40]}')

# descriptions: the text between "### 説明文" / "### Description" and the next "##"
for m in re.finditer(r'### (説明文|Description)[^\n]*\n(.*?)(?=\n## )', text, re.S):
    n = len(m.group(2).strip())
    flag = 'OK ' if n <= 4000 else 'NG '
    ok &= n <= 4000
    print(f'{flag}{m.group(1)}: {n}/4000')

sys.exit(0 if ok else 1)
