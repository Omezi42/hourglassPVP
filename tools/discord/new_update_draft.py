#!/usr/bin/env python3
"""ビルドごとの更新のお知らせの下書きを起こす。

    python tools/discord/new_update_draft.py

前回の告知以降のコミットを集め、決まった書式の雛形と、材料としての
コミット一覧を書き出す。**文面そのものは人(またはClaude)が仕上げる。**
コミットには「ツール追加」「仕様書の反映」のような内部都合が大量に混ざり、
そのまま流すと読まれないお知らせになるため。

書式(確定):
    **あたらしいもの** / **なおしたもの** / **かわったもの** の3節。
    中身が無い節は丸ごと消す。最後にリンクの1行を置く。
"""

import argparse
import datetime
import re
import subprocess
from pathlib import Path

DRAFTS = Path("tools/discord/drafts")
STATE = Path.home() / ".hourglass_announce_state"

# プレイヤーに関係しない可能性が高いコミット。落とさず「除外候補」として印を付ける
NOISE = re.compile(
    r"^(ツール|検証|テスト|リファクタ)[:：]|仕様書|TODO|Architecture|GameDesign|"
    r"gdlint|gdformat|\.uid|切り出し|行数の上限|コメント"
)

TEMPLATE = """**あたらしいもの**
- 

**なおしたもの**
- 

**かわったもの**
- 

-# 遊ぶ → https://unityroom.com/games/sunadokei_arena
"""


def commits() -> list[str]:
    rev = "HEAD~30..HEAD"
    if STATE.exists():
        marker = STATE.read_text(encoding="utf-8").strip()
        if subprocess.run(["git", "cat-file", "-e", marker + "^{commit}"],
                          capture_output=True).returncode == 0:
            rev = f"{marker}..HEAD"
    out = subprocess.run(
        ["git", "log", "--no-merges", "--reverse", "--pretty=format:%s", rev],
        capture_output=True, text=True, encoding="utf-8",
    )
    return [line for line in out.stdout.splitlines() if line.strip()]


def main() -> None:
    parser = argparse.ArgumentParser(description="更新のお知らせの下書きを起こす")
    parser.add_argument("--version", default="", help="既定は今日の日付(2026.08.30)")
    args = parser.parse_args()

    today = datetime.date.today()
    version = args.version or today.strftime("%Y.%m.%d")

    path = DRAFTS / f"update-{version}.md"
    suffix = 2
    while path.exists():
        version = f"{today.strftime('%Y.%m.%d')}-{suffix}"
        path = DRAFTS / f"update-{version}.md"
        suffix += 1

    log = commits()
    keep = [c for c in log if not NOISE.search(c)]
    drop = [c for c in log if NOISE.search(c)]

    body = [TEMPLATE, "", "<!-- ここから下は材料。仕上げたら消すこと ------------------", ""]
    body.append(f"バージョン: {version}   コミット {len(log)}件")
    body.append("")
    body.append("## プレイヤーに関係しそう")
    body += [f"- {c}" for c in keep] or ["(なし)"]
    body.append("")
    body.append("## 内部都合(除外候補)")
    body += [f"- {c}" for c in drop] or ["(なし)"]
    body.append("")
    body.append("-->")

    DRAFTS.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(body), encoding="utf-8")

    print(f"下書き: {path}")
    print(f"  材料 {len(log)}件 → 関係しそう {len(keep)}件 / 除外候補 {len(drop)}件")
    if not keep:
        print("\n  ※ プレイヤーに関係する変更が見つかりません。")
        print("     この回はお知らせを出さない、という判断も正しいです。")
    print(f"\n仕上げたら:\n"
          f"  python tools/discord/build_update_banner.py {version} --subtitle \"...\"\n"
          f"  python tools/discord/discord_post.py {path} "
          f"--attach assets/mascot/update_banner.png\n"
          f"  tools/discord/since_last_announce.sh --mark")


if __name__ == "__main__":
    main()
