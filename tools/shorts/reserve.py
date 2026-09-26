#!/usr/bin/env python3
"""YouTube と X の予約投稿へ入れる作業の、残りの一覧と済みの記録。手順は post-shorts Skill。

    python tools/shorts/reserve.py list <youtube|x> [--days N]   まだ予約していない投稿を日付順に出す(既定7日ぶん)
    python tools/shorts/reserve.py done <日付> <card|puzzle> <youtube|x>   予約を入れた印を schedule.json へ付ける

- 対象は明日以降で、動画を書き出して投稿フォルダがあるものだけ(当日ぶんは予約の締め切りに間に合わないため出さない)
- 印は schedule.json の各項目の "reserved" に残す(コミットする)。schedule.py は知らない鍵をそのまま残す
"""

import datetime
import json
import sys

from schedule import LEDGER, POST_TIME, POSTS_DIR, load

PLATFORMS = ["youtube", "x"]
DEFAULT_DAYS = 7


def section(text: str, name: str) -> str:
    head = f"■ {name}\n"
    start = text.index(head) + len(head)
    end = text.find("\n\n■ ", start)
    return text[start:end if end != -1 else len(text)].strip("\n")


def pending(ledger: list, platform: str, days: int) -> list:
    first = datetime.date.today() + datetime.timedelta(days=1)
    last = first + datetime.timedelta(days=days - 1)
    rows = []
    for entry in ledger:
        day = datetime.date.fromisoformat(entry["date"])
        if not first <= day <= last or platform in entry.get("reserved", []):
            continue
        folder = POSTS_DIR / f"{entry['date']}_{entry['kind']}_{entry['id']}"
        videos = list(folder.glob("*.mp4"))
        if not videos:
            continue
        post = (folder / "post.txt").read_text(encoding="utf-8")
        row = {"date": entry["date"], "time": POST_TIME[entry["kind"]], "kind": entry["kind"], "label": entry["label"]}
        if platform == "youtube":
            row |= {
                "video": str(videos[0]),
                "title": section(post, "YouTube のタイトル"),
                "description": section(post, "YouTube の説明"),
                "tags": section(post, "YouTube のタグ"),
            }
        else:
            row |= {"video": str(videos[0]), "text": section(post, "X の本文")}
        rows.append(row)
    return rows


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    ledger = load(LEDGER, [])
    if len(args) >= 2 and args[0] == "list" and args[1] in PLATFORMS:
        days = int(args[args.index("--days") + 1]) if "--days" in args else DEFAULT_DAYS
        print(json.dumps(pending(ledger, args[1], days), ensure_ascii=False, indent=1))
    elif len(args) == 4 and args[0] == "done" and args[3] in PLATFORMS:
        _, date, kind, platform = args
        matches = [e for e in ledger if e["date"] == date and e["kind"] == kind]
        if not matches:
            sys.exit(f"記録にありません: {date} {kind}")
        reserved = matches[0].setdefault("reserved", [])
        if platform not in reserved:
            reserved.append(platform)
        LEDGER.write_text(json.dumps(ledger, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
        print(f"予約済み: {date} {kind} {matches[0]['label']} → {', '.join(reserved)}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
