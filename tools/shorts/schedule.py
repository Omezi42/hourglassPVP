#!/usr/bin/env python3
"""書き出したショートを投稿日へ割り振り、投稿文を添えて日付つきのフォルダへ並べる。
ゲームの「今日の1問」(data/daily_puzzles/<日付>.tres)も同じ割り振りから書き出す。

    python tools/shorts/schedule.py <日数> [--start YYYY-MM-DD]

- 毎日、カード紹介(19:00)ととどめ問題(12:00)を1本ずつ。とどめ問題はゲームの今日の1問と同じ問題
- 割り振りの記録は tools/shorts/schedule.json(コミットする)。次に回すと記録の最終日の翌日から<日数>ぶん続け、
  一度出したカード・問題は二度と選ばない。記録の範囲内で明日以降に欠けている種類があれば先に埋める。
  --start は記録が空のときの初日(既定は明日)。<日数> が 0 なら埋め直しと書き出しだけを行う
- とどめ問題が尽きた日はその日の問題を出さず、足りない旨を出す(先に make_short.py forge で増やす)
- 出力は tools/shorts/out/posts/<日付>_<種類>_<id>/ に動画と post.txt(Xの本文・YouTubeのタイトル/説明/タグ)。
  全体の一覧は tools/shorts/out/posts/一覧.md。動画が未書き出しの日はフォルダを作らず、一覧に「動画なし」と出す
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
DAILY_DIR = ROOT / "data/daily_puzzles"
KINDS = ["puzzle", "card"]
# 同じ日に2本を並べないよう時刻を分ける。とどめ問題はゲームの今日の1問(0:00切り替え)と
# 同じ問題を遊べる時間が長くなるよう昼にする。
POST_TIME = {"puzzle": "12:00", "card": "19:00"}
# カードの並びは固定の乱数で混ぜる(追加順のままだと同じコスト帯・同じ種類が続くため)。
CARD_ORDER_SEED = 42

GAME_URL = "https://unityroom.com/games/sunadokei_arena"
FOOTER = f"砂時計で戦うカードバトル「砂時計アリーナ」\nブラウザで無料で遊べます▶ {GAME_URL}"
HASHTAGS = "#砂時計アリーナ #ブラウザゲーム #インディーゲーム"
YOUTUBE_TAGS = "砂時計アリーナ,カードゲーム,ブラウザゲーム,インディーゲーム,ずんだもん,Shorts"
CREDIT = "VOICEVOX:ずんだもん"
DAILY_NOTE = "ゲームの「今日の1問」でも同じ問題が解けます"
X_LIMIT = 280
X_URL_WEIGHT = 23

DAILY_TRES = """[gd_resource type="Resource" script_class="PuzzleStageData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/puzzle_stage_data.gd" id="script_puzzle"]

[resource]
script = ExtResource("script_puzzle")
id = {id}
title = {title}
hint = {hint}
order = 0
foe_hp = {foe_hp}
own_hp = {own_hp}
mana = {mana}
hand_ids = Array[String]({hand_ids})
own_units = Array[String]({own_units})
foe_units = Array[String]({foe_units})
"""


def load(path: Path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def dump(value) -> str:
    return json.dumps(value, ensure_ascii=False)


def card_post(card: dict) -> tuple[str, str]:
    stats = f"コスト{card['cost']}の砂術" if card["is_spell"] else f"コスト{card['cost']} / 総量{card['total_sand']}"
    body = f"【カード紹介】{card['display_name']}\n{stats}\n{card['describe']}\n\n{FOOTER}\n{HASHTAGS}"
    return body, f"【カード紹介】{card['display_name']}｜砂時計アリーナ #Shorts"


def puzzle_post(number: int, stage: dict) -> tuple[str, str]:
    body = (
        f"【とどめ問題 #{number}】\n相手の体力はあと{stage['foe_hp']}。\nこのターンで勝ちきれる？\n"
        f"答えは動画の後半で！\n{DAILY_NOTE}\n\n{FOOTER}\n{HASHTAGS}"
    )
    return body, f"【とどめ問題 #{number}】このターンで勝ちきれる？｜砂時計アリーナ #Shorts"


# Xは全角を2、URLを一律23と数える。
def x_weight(text: str) -> int:
    text = text.replace(GAME_URL, "")
    return X_URL_WEIGHT + sum(1 if ord(ch) < 0x1100 else 2 for ch in text)


def queues(ledger: list) -> dict:
    cards = {c["id"]: c for c in load(CARDS, {})["cards"]}
    lines = load(SHORTS / "card_lines.json", {})["cards"]
    used = {(e["kind"], e["id"]) for e in ledger}
    card_queue = [cid for cid in lines if cid in cards and ("card", cid) not in used]
    random.Random(CARD_ORDER_SEED).shuffle(card_queue)
    book = load(SHORTS / "puzzles.json", [])
    puzzle_queue = [str(n) for n in range(1, len(book) + 1) if ("puzzle", str(n)) not in used]
    return {"card": card_queue, "puzzle": puzzle_queue}


# 明日から記録の最終日まで欠けている種類を埋め、続けて<日数>ぶん延ばす。
def assign(ledger: list, first_new: datetime.date, days: int) -> None:
    pool = queues(ledger)
    tomorrow = datetime.date.today() + datetime.timedelta(days=1)
    have = {(e["date"], e["kind"]) for e in ledger}
    last = first_new + datetime.timedelta(days=days - 1)
    day = min(tomorrow, first_new)
    short = []
    while day <= last:
        for kind in KINDS:
            date = day.isoformat()
            if day < tomorrow or (date, kind) in have:
                continue
            if not pool[kind]:
                short.append(f"{date} {kind}")
                continue
            ledger.append({"date": date, "kind": kind, "id": pool[kind].pop(0), "label": ""})
        day += datetime.timedelta(days=1)
    if short:
        print("割り振れるショートが足りません(とどめ問題は make_short.py forge <問数> で増やす): " + ", ".join(short))
    ledger.sort(key=lambda e: (e["date"], KINDS.index(e["kind"])))


def relabel(ledger: list) -> None:
    cards = {c["id"]: c for c in load(CARDS, {})["cards"]}
    number = 0
    for entry in ledger:
        if entry["kind"] == "puzzle":
            number += 1
            entry["label"] = f"とどめ問題 #{number}"
        else:
            entry["label"] = cards[entry["id"]]["display_name"]


# ゲームの今日の1問。記録にある日のぶんだけを置き、記録から外れたものは消す。
def write_daily(ledger: list, book: list) -> None:
    DAILY_DIR.mkdir(parents=True, exist_ok=True)
    wanted = set()
    for entry in ledger:
        if entry["kind"] != "puzzle":
            continue
        day = datetime.date.fromisoformat(entry["date"])
        stage = book[int(entry["id"]) - 1]["stage"]
        path = DAILY_DIR / f"{entry['date']}.tres"
        wanted.add(path.name)
        text = DAILY_TRES.format(
            id=dump(f"daily_{entry['date']}"),
            title=dump(f"{day.month}月{day.day}日の問題"),
            hint=dump(stage["hint"]),
            foe_hp=stage["foe_hp"],
            own_hp=stage["own_hp"],
            mana=stage["mana"],
            hand_ids=dump(stage["hand_ids"]),
            own_units=dump(stage["own_units"]),
            foe_units=dump(stage["foe_units"]),
        )
        path.write_text(text, encoding="utf-8", newline="\n")
    for path in DAILY_DIR.glob("*.tres"):
        if path.name not in wanted:
            path.unlink()


def write_posts(ledger: list, book: list) -> list:
    cards = {c["id"]: c for c in load(CARDS, {})["cards"]}
    today = datetime.date.today().isoformat()
    missing = []
    for entry in ledger:
        if entry["date"] < today:
            continue
        kind = entry["kind"]
        if kind == "card":
            body, title = card_post(cards[entry["id"]])
        else:
            body, title = puzzle_post(int(entry["label"].split("#")[1]), book[int(entry["id"]) - 1]["stage"])
        if x_weight(body) > X_LIMIT:
            sys.exit(f"Xの本文が長すぎます({x_weight(body)}/{X_LIMIT}): {entry['date']} {entry['label']}")
        video = OUT_DIR / f"{kind}_{entry['id']}.mp4"
        folder = POSTS_DIR / f"{entry['date']}_{kind}_{entry['id']}"
        if not video.exists():
            missing.append(video.name)
            continue
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob("*.mp4"):
            old.unlink()
        shutil.copyfile(video, folder / f"{entry['date']}_{entry['label']}.mp4")
        post = (
            f"■ 投稿日時: {entry['date']} {POST_TIME[kind]}\n\n■ X の本文\n{body}\n\n■ YouTube のタイトル\n{title}\n\n"
            f"■ YouTube の説明\n{body}\n\n{CREDIT}\n\n■ YouTube のタグ\n{YOUTUBE_TAGS}\n"
        )
        (folder / "post.txt").write_text(post, encoding="utf-8", newline="\n")
    return missing


def write_index(ledger: list) -> None:
    POSTS_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for e in ledger:
        video = OUT_DIR / f"{e['kind']}_{e['id']}.mp4"
        folder = f"`{e['date']}_{e['kind']}_{e['id']}/`" if video.exists() else "動画なし"
        rows.append(f"| {e['date']} {POST_TIME[e['kind']]} | {e['label']} | {folder} |")
    (POSTS_DIR / "一覧.md").write_text(
        "# 投稿予定\n\n| 日時 | 内容 | フォルダ |\n|---|---|---|\n" + "\n".join(rows) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> None:
    args = sys.argv[1:]
    if not args or not args[0].isdigit():
        sys.exit(__doc__)
    days = int(args[0])
    ledger = load(LEDGER, [])
    if ledger:
        first_new = datetime.date.fromisoformat(ledger[-1]["date"]) + datetime.timedelta(days=1)
    elif "--start" in args:
        first_new = datetime.date.fromisoformat(args[args.index("--start") + 1])
    else:
        first_new = datetime.date.today() + datetime.timedelta(days=1)

    assign(ledger, first_new, days)
    relabel(ledger)
    book = load(SHORTS / "puzzles.json", [])
    write_daily(ledger, book)
    missing = write_posts(ledger, book)
    LEDGER.write_text(json.dumps(ledger, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
    write_index(ledger)
    for e in ledger:
        if e["date"] >= datetime.date.today().isoformat():
            print(f"{e['date']} {POST_TIME[e['kind']]}  {e['label']}")
    if missing:
        print("未書き出しの動画(make_short.py で撮ってから回し直す): " + " ".join(sorted(set(missing))))


if __name__ == "__main__":
    main()
