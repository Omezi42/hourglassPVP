#!/usr/bin/env python3
"""Web / WebCheck プリセットの include_filter / exclude_filter / export_path を書き戻す。

Godotのエディタで書き出すと export_presets.cfg のフィルタが空へ戻り、
BGM(8.8MB)とシミュレーションの生データ(1.1MB)が混ざったpckができあがり、
逆に data/discord_webhook.txt や data/unityroom_hmac_key.txt、data/endless_puzzles.json が落ちて
募集通知・ランキング送信・エンドレスが働かなくなる。実際にこれが起きたため、
書き出しの直前に毎回ここで揃え直す。
"""

import re
import sys
from pathlib import Path

# 本番(Web)は tools/ を丸ごと外す。検査用(WebCheck)はテストを動かすため tools/ を残す(Architecture.md 4.1.6節)。
COMMON_INCLUDE = '"data/discord_webhook.txt, data/unityroom_hmac_key.txt, data/endless_puzzles.json"'
WANT = {
    "Web": {
        "include_filter": COMMON_INCLUDE,
        "exclude_filter": '"assets/bgm/*, tools/*"',
        # 書き出し先も揃える。エディタから書き出したときに build/砂時計pvp.pck という
        # 別名のpckができ、unityroomへ間違った方を上げかけたため。
        "export_path": '"build/web/index.html"',
    },
    "WebCheck": {
        "include_filter": COMMON_INCLUDE,
        "exclude_filter": '"assets/bgm/*, tools/balance/*"',
        "export_path": '"build/web_check/index.html"',
    },
}
SECTION = re.compile(r"^\[preset\.\d+\]$", re.MULTILINE)


def fix_section(section: str, name: str, fixed: list) -> str:
    for key, value in WANT[name].items():
        pattern = re.compile(rf"^{key}=.*$", re.MULTILINE)
        current = pattern.search(section)
        if current is None:
            sys.exit(f"プリセット {name} に {key} がありません。")
        if current.group(0) != f"{key}={value}":
            section = pattern.sub(lambda _m: f"{key}={value}", section, count=1)
            fixed.append(f"{name}.{key}")
    return section


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "export_presets.cfg")
    text = path.read_text(encoding="utf-8")
    starts = [m.start() for m in SECTION.finditer(text)] + [len(text)]
    out = [text[: starts[0]]]
    fixed: list = []
    seen = set()
    for begin, end in zip(starts, starts[1:]):
        section = text[begin:end]
        name_match = re.search(r'^name="(.*)"$', section, re.MULTILINE)
        name = name_match.group(1) if name_match else ""
        if name in WANT:
            seen.add(name)
            section = fix_section(section, name, fixed)
        out.append(section)
    missing = set(WANT) - seen
    if missing:
        sys.exit(f"{path} にプリセット {', '.join(sorted(missing))} がありません。")
    if fixed:
        with path.open("w", encoding="utf-8", newline="\n") as f:
            f.write("".join(out))
        print("export_presets.cfg を直しました: " + " / ".join(fixed))


if __name__ == "__main__":
    main()
