"""functions/data/cards.json からカードidを1行1件で標準出力へ書き出す。

export_discord_effect_gifs.sh から呼ぶ。コマンドライン引数へパスを埋め込むと、
リポジトリのパスに含まれる日本語文字("砂時計pvp")がシェル→Pythonの受け渡しで
文字化けしたため(実際に FileNotFoundError で踏んだ)、相対パスの直読みにしている。
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS_JSON = os.path.join(ROOT, "functions", "data", "cards.json")

with open(CARDS_JSON, encoding="utf-8") as f:
    data = json.load(f)

for card in data["cards"]:
    print(card["id"])
