#!/usr/bin/env python3
"""#お知らせ の下書きから、ゲーム内のお知らせ(data/announcements/*.tres)を作り直す。

GameDesign.md 33章 / Architecture.md 10.22節。お知らせはそのビルドのpckに同梱するため、
**ビルドの前に**回す(build-and-announce Skill)。直近の回だけを残し、古い回の .tres は消す。

使い方:
    python tools/discord/sync_announcements.py
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DRAFTS = ROOT / "tools" / "discord" / "drafts"
OUT = ROOT / "data" / "announcements"
# ゲームの一覧に出す回数(AnnouncementLibrary.MAX_LISTED と揃える)。
KEEP = 20
DRAFT_NAME = re.compile(r"^update-(\d{4}\.\d{2}\.\d{2}(?:-\d+)?)\.md$")
# 材料のコメント(new_update_draft.py が付ける)。投稿前に消す決まりだが、残っていても載せない。
MATERIAL = re.compile(r"<!--.*?-->", re.DOTALL)

TEMPLATE = """[gd_resource type="Resource" script_class="AnnouncementData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/announcement_data.gd" id="script_announcement"]

[resource]
script = ExtResource("script_announcement")
version = "{version}"
body = "{body}"
"""


def version_key(version: str) -> tuple:
    day, _, count = version.partition("-")
    return (day, int(count or 1))


def escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')


def main() -> None:
    drafts = {}
    for path in DRAFTS.glob("update-*.md"):
        match = DRAFT_NAME.match(path.name)
        if match:
            drafts[match.group(1)] = path
    keep = sorted(drafts, key=version_key, reverse=True)[:KEEP]

    OUT.mkdir(parents=True, exist_ok=True)
    wanted = set()
    for version in keep:
        body = MATERIAL.sub("", drafts[version].read_text(encoding="utf-8")).strip()
        target = OUT / f"{version}.tres"
        wanted.add(target.name)
        text = TEMPLATE.format(version=version, body=escape(body))
        if not target.exists() or target.read_text(encoding="utf-8") != text:
            target.write_text(text, encoding="utf-8", newline="\n")
            print(f"wrote {target.relative_to(ROOT)}")
    for old in OUT.glob("*.tres"):
        if old.name not in wanted:
            old.unlink()
            print(f"removed {old.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
