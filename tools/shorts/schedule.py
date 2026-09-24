#!/usr/bin/env python3
"""書き出したショートを投稿日へ割り振り、投稿文を添えて日付つきのフォルダへ並べる。

    python tools/shorts/schedule.py <日数> [--start YYYY-MM-DD]

- 割り振りの記録は tools/shorts/schedule.json(コミットする)。次に回すと記録の最終日の翌日から続け、
  一度出したカード・問題は二度と選ばない。--start は記録が空のときの初日(既定は明日)
- 並びは「カード・カード・とどめ問題」の繰り返し。問題が尽きたらカードで埋め、足りない旨を出す
- 出力は tools/shorts/out/posts/<日付>_<種類>_<id>/ に動画と post.txt(Xの本文・YouTubeのタイトル/説明/タグ)。
  全体の一覧は tools/shorts/out/posts/一覧.md
- 動画が未書き出しの日があれば何も書かずに止まる(先に make_short.py で撮る)
"""

import datetime
import json
import random
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHORTS = ROOT / "tools/shorts"
OUT_DIR = SHORTS / "out"
POSTS_DIR = OUT_DIR / "posts"
LEDGER = SHORTS / "schedule.json"
CARDS = ROOT / "functions/data/cards.json"
CYCLE = ["card", "card", "puzzle"]
# カードの並びは固定の乱数で混ぜる(追加順のままだと同じコスト帯・同じ種類が続くため)。
CARD_ORDER_SEED = 42
POST_TIME = "19:00"

GAME_URL = "https://unityroom.com/games/sunadokei_arena"
FOOTER = f"砂時計で戦うカードバトル「砂時計アリーナ」\nブラウザで無料で遊べます▶ {GAME_URL}"
HASHTAGS = "#砂時計アリーナ #ブラウザゲーム #インディーゲーム"
YOUTUBE_TAGS = "砂時計アリーナ,カードゲーム,ブラウザゲーム,インディーゲーム,ずんだもん,Shorts"
CREDIT = "VOICEVOX:ずんだもん"
X_LIMIT = 280
X_URL_WEIGHT = 23


def load(path: Path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def card_post(card: dict) -> tuple[str, str]:
    stats = f"コスト{card['cost']}の砂術" if card["is_spell"] else f"コスト{card['cost']} / 総量{card['total_sand']}"
    body = f"【カード紹介】{card['display_name']}\n{stats}\n{card['describe']}\n\n{FOOTER}\n{HASHTAGS}"
    return body, f"【カード紹介】{card['display_name']}｜砂時計アリーナ #Shorts"


def puzzle_post(number: int, stage: dict) -> tuple[str, str]:
    body = (
        f"【とどめ問題 #{number}】\n相手の体力はあと{stage['foe_hp']}。\nこのターンで勝ちきれる？\n"
        f"答えは動画の後半で！\n\n{FOOTER}\n{HASHTAGS}"
    )
    return body, f"【とどめ問題 #{number}】このターンで勝ちきれる？｜砂時計アリーナ #Shorts"


# Xは全角を2、URLを一律23と数える。
def x_weight(text: str) -> int:
    text = text.replace(GAME_URL, "")
    return X_URL_WEIGHT + sum(1 if ord(ch) < 0x1100 else 2 for ch in text)


def next_items(ledger: list, days: int) -> list:
    cards = {c["id"]: c for c in load(CARDS, {})["cards"]}
    lines = load(SHORTS / "card_lines.json", {})["cards"]
    used_cards = {e["id"] for e in ledger if e["kind"] == "card"}
    card_queue = [cid for cid in lines if cid in cards and cid not in used_cards]
    random.Random(CARD_ORDER_SEED).shuffle(card_queue)
    book = load(SHORTS / "puzzles.json", [])
    used_puzzles = {e["id"] for e in ledger if e["kind"] == "puzzle"}
    puzzle_queue = [str(n) for n in range(1, len(book) + 1) if str(n) not in used_puzzles]
    items = []
    for index in range(len(ledger), len(ledger) + days):
        kind = CYCLE[index % len(CYCLE)]
        if kind == "puzzle" and not puzzle_queue:
            print("とどめ問題が尽きたのでカードで埋めます(make_short.py forge <問数> で問題集を増やす)")
            kind = "card"
        queue = card_queue if kind == "card" else puzzle_queue
        if not queue:
            sys.exit("割り振れるショートが残っていません")
        items.append({"kind": kind, "id": queue.pop(0)})
    return items


def main() -> None:
    args = sys.argv[1:]
    if not args or not args[0].isdigit():
        sys.exit(__doc__)
    days = int(args[0])
    ledger = load(LEDGER, [])
    if ledger:
        first = datetime.date.fromisoformat(ledger[-1]["date"]) + datetime.timedelta(days=1)
    elif "--start" in args:
        first = datetime.date.fromisoformat(args[args.index("--start") + 1])
    else:
        first = datetime.date.today() + datetime.timedelta(days=1)

    items = next_items(ledger, days)
    missing = [f"{i['kind']}_{i['id']}.mp4" for i in items if not (OUT_DIR / f"{i['kind']}_{i['id']}.mp4").exists()]
    if missing:
        sys.exit("未書き出しの動画があります。先に make_short.py で撮ってください: " + " ".join(missing))

    cards = {c["id"]: c for c in load(CARDS, {})["cards"]}
    book = load(SHORTS / "puzzles.json", [])
    puzzle_count = sum(1 for e in ledger if e["kind"] == "puzzle")
    for offset, item in enumerate(items):
        date = (first + datetime.timedelta(days=offset)).isoformat()
        if item["kind"] == "card":
            card = cards[item["id"]]
            body, title = card_post(card)
            label = card["display_name"]
        else:
            puzzle_count += 1
            body, title = puzzle_post(puzzle_count, book[int(item["id"]) - 1]["stage"])
            label = f"とどめ問題 #{puzzle_count}"
        if x_weight(body) > X_LIMIT:
            sys.exit(f"Xの本文が長すぎます({x_weight(body)}/{X_LIMIT}): {date} {label}")
        folder = POSTS_DIR / f"{date}_{item['kind']}_{item['id']}"
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(OUT_DIR / f"{item['kind']}_{item['id']}.mp4", folder / f"{date}_{label}.mp4")
        post = (
            f"■ 投稿日時: {date} {POST_TIME}\n\n■ X の本文\n{body}\n\n■ YouTube のタイトル\n{title}\n\n"
            f"■ YouTube の説明\n{body}\n\n{CREDIT}\n\n■ YouTube のタグ\n{YOUTUBE_TAGS}\n"
        )
        (folder / "post.txt").write_text(post, encoding="utf-8", newline="\n")
        ledger.append({"date": date, "kind": item["kind"], "id": item["id"], "label": label})
        print(f"{date}  {label}")

    LEDGER.write_text(json.dumps(ledger, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
    rows = "\n".join(f"| {e['date']} {POST_TIME} | {e['label']} | `{e['date']}_{e['kind']}_{e['id']}/` |" for e in ledger)
    (POSTS_DIR / "一覧.md").write_text(
        f"# 投稿予定\n\n| 日時 | 内容 | フォルダ |\n|---|---|---|\n{rows}\n", encoding="utf-8", newline="\n"
    )


if __name__ == "__main__":
    main()
