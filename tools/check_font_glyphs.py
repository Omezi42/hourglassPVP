"""同梱フォントが字形を持たない文字が、UIへ出す文字列に混ざっていないか調べる。

**エディタ実行では別のフォントで代替されて気づけず、書き出した版でだけ豆腐(□)になる**
(docs/Architecture.md 11章)。記号を足すたびに手で cmap を確認するのは続かないため、
まとめて機械的に見る。

    python tools/check_font_glyphs.py

見つからなければ何も出さずに 0 を返す。
"""

import pathlib
import re
import sys

from fontTools.ttLib import TTFont

FONT = pathlib.Path("assets/fonts/ZenKakuGothicNew-Bold.ttf")
TARGETS = (list(pathlib.Path("scripts").rglob("*.gd")) + list(pathlib.Path("data").rglob("*.tres")))
LITERAL = re.compile(r'"([^"' + "\\\\" + r']*)"')


def main() -> int:
    covered = set(TTFont(FONT).getBestCmap())
    missing: dict[int, list[str]] = {}
    for path in TARGETS:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            # コメント行は画面へ出ないため見ない。
            if line.lstrip().startswith("#"):
                continue
            for literal in LITERAL.findall(line):
                for char in literal:
                    point = ord(char)
                    if point < 32 or point in covered:
                        continue
                    missing.setdefault(point, []).append(f"{path}:{number}")
    for point, places in sorted(missing.items()):
        print(f"U+{point:04X} ({len(places)}) {', '.join(places[:5])}")
    if missing:
        print(f"\n{len(missing)} 種の文字に字形がありません。")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
