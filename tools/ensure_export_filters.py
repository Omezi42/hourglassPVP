#!/usr/bin/env python3
"""Webプリセットの include_filter / exclude_filter / export_path を書き戻す。

Godotのエディタで書き出すと export_presets.cfg のフィルタが空へ戻り、
BGM(8.8MB)とシミュレーションの生データ(1.1MB)が混ざったpckができあがり、
逆に data/discord_webhook.txt が落ちて募集通知が飛ばなくなる。
実際にこれが起きたため、書き出しの直前に毎回ここで揃え直す。
"""

import re
import sys
from pathlib import Path

WANT = {
    "include_filter": '"data/discord_webhook.txt"',
    "exclude_filter": '"assets/bgm/*, tools/balance/*"',
    # 書き出し先も揃える。エディタから書き出したときに build/砂時計pvp.pck という
    # 別名のpckができ、unityroomへ間違った方を上げかけたため。
    "export_path": '"build/web/index.html"',
}


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "export_presets.cfg")
    text = path.read_text(encoding="utf-8")
    fixed = []
    for key, value in WANT.items():
        pattern = re.compile(rf"^{key}=.*$", re.MULTILINE)
        current = pattern.search(text)
        if current is None:
            sys.exit(f"{path} に {key} がありません。")
        if current.group(0) != f"{key}={value}":
            text = pattern.sub(f"{key}={value}", text, count=1)
            fixed.append(key)
    if fixed:
        path.write_text(text, encoding="utf-8")
        print("export_presets.cfg を直しました: " + " / ".join(fixed))


if __name__ == "__main__":
    main()
