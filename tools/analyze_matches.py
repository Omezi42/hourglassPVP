#!/usr/bin/env python3
"""オンライン対戦の記録(match_records)を読んで集計する(GameDesign.md 22章)。

シミュレーションでしか測れていないバランスの数値を、**人が指した対局**と突き合わせる
ための道具。求めたときだけ動かし、自動投稿は行わない(1局ごとに流せばうるさく、
日次でまとめるにはサーバー側の定期実行が要るが、この作品はサーバーを持たない)。

使い方:
    python tools/analyze_matches.py                      # 通算を集計して表示
    python tools/analyze_matches.py --build 20260902-101530
    python tools/analyze_matches.py --days 7 --kind random
    python tools/analyze_matches.py --out out.md --post   # Discordへ投稿する
    python tools/analyze_matches.py --funnel --days 7     # 来た人がどの段階まで進んだか

読み取りは匿名サインインで行う(ゲーム本体と同じ経路)。棋譜(actions)は既定では
取得しない。1局あたりの大半を占めるうえ、集計には要らないため。
"""

import argparse
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "data" / "firebase_config.tres"
CARDS_DIR = ROOT / "data" / "cards"
COLLECTION = "match_records"
PAGE_SIZE = 300
# 集計に要るフィールドだけを取りに行く。actions は1局あたりの大半を占めるため既定では外す。
SUMMARY_FIELDS = [
    "build",
    "version",
    "kind",
    "finished_at",
    "winner",
    "end_reason",
    "turns",
    "hp_a",
    "hp_b",
    "deck_a",
    "deck_b",
    "player_a",
    "player_b",
]
END_REASON_LABELS = {
    "hp": "HPが0",
    "surrender": "投了",
    "timeout": "時間切れ",
    "draw": "引き分け",
}
FUNNEL_PATH = "stats/funnel"
# 段階の並び(scripts/net/funnel_service.gd のキーと同じ)。誘導対局を飛ばしてCPU戦へ行く人も
# いて順には通らないため、割合はすべて起動に対して出す。
FUNNEL_STEPS = [
    ("launch", "起動"),
    ("home", "ホーム"),
    ("tutorial_start", "誘導対局を始めた"),
    ("tutorial_clear", "誘導対局を終えた"),
    ("match_end", "CPU戦を終えた"),
    ("online_try", "オンラインの入口"),
    ("online_end", "オンライン対戦を終えた"),
    ("daily_puzzle", "今日の1問を始めた"),
    ("return", "別の日に来た"),
]
TUTORIAL_SCRIPT = ROOT / "resources" / "tutorial" / "tutorial_script.tres"
TUTORIAL_STEP_KEY = "tutorial_%02d"
TUTORIAL_TEXT_CHARS = 18
TUTORIAL_SIDES = {"a": "あなた", "b": "CPU", "info": "説明"}
# ランクマッチの最初の待機(funnel_service.gd の RANKED_* と同じ)。割合は待機を始めた人に対して出す。
RANKED_WAIT_SECONDS = [5, 15, 30, 60]
RANKED_STEPS = (
    [("ranked_wait", "待機を始めた")]
    + [("ranked_wait_%d" % s, "%d秒待った" % s) for s in RANKED_WAIT_SECONDS]
    + [
        ("ranked_cpu", "CPU戦へ切り替えた"),
        ("ranked_matched", "人と対戦が成立した"),
        ("ranked_cancel", "自分でやめた"),
    ]
)
# これに満たないカードは、勝率が偶然で大きく振れるため一覧から省く。
MIN_CARD_SAMPLES = 5


def read_config():
    text = CONFIG.read_text(encoding="utf-8")
    api_key = re.search(r'api_key\s*=\s*"([^"]+)"', text)
    project = re.search(r'project_id\s*=\s*"([^"]+)"', text)
    if not api_key or not project:
        sys.exit("%s から api_key / project_id を読めませんでした。" % CONFIG)
    return api_key.group(1), project.group(1)


def post_json(url, payload):
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def sign_in(api_key):
    """匿名サインイン。ゲーム本体と同じ経路で、読み取りに要るIDトークンだけを得る。"""
    url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % api_key
    return post_json(url, {"returnSecureToken": True})["idToken"]


def decode(value):
    """FirestoreのValueをPythonの値へ戻す(scripts/net/firestore_codec.gd と同じ対応)。"""
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return value["booleanValue"]
    if "arrayValue" in value:
        return [decode(item) for item in value["arrayValue"].get("values", [])]
    if "mapValue" in value:
        return dict((k, decode(v)) for k, v in value["mapValue"].get("fields", {}).items())
    return None


def fetch_records(project, token, with_actions):
    """コレクションを丸ごと読む。**クエリで絞らない**のは、複合インデックスを要求せずに
    済ませるため(絞り込みは手元で行う。ゲーム本体のクエリ方針と同じ)。"""
    base = (
        "https://firestore.googleapis.com/v1/projects/%s"
        "/databases/(default)/documents/%s" % (project, COLLECTION)
    )
    mask = ""
    if not with_actions:
        mask = "".join("&mask.fieldPaths=%s" % field for field in SUMMARY_FIELDS)
    records = []
    page_token = ""
    while True:
        url = "%s?pageSize=%d%s" % (base, PAGE_SIZE, mask)
        if page_token:
            url += "&pageToken=%s" % page_token
        request = urllib.request.Request(url, headers={"Authorization": "Bearer %s" % token})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8")[:400]
            sys.exit("読み取りに失敗しました(%d): %s" % (error.code, detail))
        for document in body.get("documents", []):
            record = dict((k, decode(v)) for k, v in document.get("fields", {}).items())
            record["id"] = document["name"].rsplit("/", 1)[-1]
            records.append(record)
        page_token = body.get("nextPageToken", "")
        if not page_token:
            return records


def fetch_funnel(project, token):
    url = (
        "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s"
        % (project, FUNNEL_PATH)
    )
    request = urllib.request.Request(url, headers={"Authorization": "Bearer %s" % token})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return {}
        sys.exit("読み取りに失敗しました(%d): %s" % (error.code, error.read().decode("utf-8")[:400]))
    return dict((k, decode(v)) for k, v in body.get("fields", {}).items())


def sum_days(days, within_days):
    """日のキーは "d20260925" の形。期間内の日を足し合わせて (合計, 日数) を返す。"""
    if within_days:
        start = time.strftime("d%Y%m%d", time.localtime(time.time() - within_days * 86400))
        days = dict((day, counts) for day, counts in days.items() if day > start)
    totals = Counter()
    for counts in days.values():
        totals.update(counts)
    return totals, len(days)


def ratio_table(totals, steps, base_key, base_label):
    lines = ["| 段階 | 人数 | %sに対して |" % base_label, "|---|---|---|"]
    base = totals.get(base_key, 0)
    for key, label in steps:
        count = totals.get(key, 0)
        ratio = "%.0f%%" % (100.0 * count / base) if base else "—"
        lines.append("| %s | %d | %s |" % (label, count, ratio))
    return lines


def tutorial_steps():
    """台本の手順を (キー, 見出し) で返す。見出しは番号・誰の手か・種類・指示の冒頭。"""
    text = TUTORIAL_SCRIPT.read_text(encoding="utf-8")
    body = text[text.index("steps = ") :]
    steps = []
    for index, chunk in enumerate(re.split(r"\}, \{", body)):
        side = re.search(r'"side": "(\w+)"', chunk)
        kind = re.search(r'"kind": "(\w+)"', chunk)
        words = re.search(r'"(?:text|wait_text)": "([^"\\]*)', chunk)
        label = "%02d %s %s %s" % (
            index,
            TUTORIAL_SIDES.get(side.group(1) if side else "", "?"),
            kind.group(1) if kind else "",
            words.group(1)[:TUTORIAL_TEXT_CHARS] if words else "",
        )
        steps.append((TUTORIAL_STEP_KEY % index, label))
    return steps


def funnel_report(fields, within_days):
    """段階ごとの人数(起動に対する割合)・誘導対局の手順・ランクマッチの待機・配信先ごと。"""
    totals, day_count = sum_days(fields.get("days", {}), within_days)
    span = "直近%d日" % within_days if within_days else "通算"
    lines = ["## 来た人がどの段階まで進んだか(%s・%d日分)" % (span, day_count), ""]
    lines += ratio_table(totals, FUNNEL_STEPS, "launch", "起動")
    lines += ["", "## 誘導対局の手順ごと(台本を書き換えた日をまたいで比べない)", ""]
    lines += ratio_table(totals, tutorial_steps(), "tutorial_start", "始めた人")
    lines += ["", "## ランクマッチの最初の待機", ""]
    lines += ratio_table(totals, RANKED_STEPS, "ranked_wait", "待機を始めた人")
    sites = dict(
        (site, sum_days(days, within_days)[0])
        for site, days in sorted(fields.get("portals", {}).items())
    )
    if sites:
        lines += ["", "## 配信先ごと", ""]
        lines.append("| 段階 | " + " | ".join(sites) + " |")
        lines.append("|---|" + "---|" * len(sites))
        for key, label in FUNNEL_STEPS:
            counts = " | ".join(str(site_totals.get(key, 0)) for site_totals in sites.values())
            lines.append("| %s | %s |" % (label, counts))
    return "\n".join(lines)


def card_names():
    names = {}
    for path in sorted(CARDS_DIR.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        card_id = re.search(r'^id\s*=\s*"([^"]+)"', text, re.M)
        display = re.search(r'^display_name\s*=\s*"([^"]+)"', text, re.M)
        if card_id:
            names[card_id.group(1)] = display.group(1) if display else card_id.group(1)
    return names


def select(records, args):
    picked = records
    if args.build:
        picked = [r for r in picked if r.get("build") == args.build]
    if args.kind:
        picked = [r for r in picked if r.get("kind") == args.kind]
    if args.days:
        since = time.time() - args.days * 86400
        picked = [r for r in picked if float(r.get("finished_at", 0)) >= since]
    if args.exclude_repeats:
        picked = drop_repeats(picked)
    return picked


def drop_repeats(records):
    """同じ2人の対局は最初の1局だけを数える。連戦は同じ構築が繰り返し出るため、
    そのままだと少数のプレイヤーの好みが全体の数字を動かす。"""
    seen = set()
    picked = []
    for record in records:
        pair = frozenset({record.get("player_a", ""), record.get("player_b", "")})
        if pair in seen:
            continue
        seen.add(pair)
        picked.append(record)
    return picked


def overview_lines(records):
    total = len(records)
    first_wins = sum(1 for r in records if r.get("winner") == "a")
    turns = sum(int(r.get("turns", 0)) for r in records)
    reasons = Counter(r.get("end_reason", "hp") for r in records)
    kinds = Counter(r.get("kind", "random") for r in records)
    builds = Counter(r.get("build", "?") for r in records)
    reason_text = " / ".join(
        "%s %d戦(%.1f%%)" % (END_REASON_LABELS.get(k, k), v, 100.0 * v / total)
        for k, v in reasons.most_common()
    )
    return [
        "## オンライン対戦の集計",
        "",
        "- 対局数: **%d**" % total,
        "- 先手勝率: **%.1f%%**(目標 45〜55%%)" % (100.0 * first_wins / total),
        "- 決着手数: **%.1f手**(目標 20〜30手)" % (float(turns) / total),
        "- 種別: " + " / ".join("%s %d戦" % (k, v) for k, v in kinds.most_common()),
        "- 決着の要因: " + reason_text,
        "- ビルド: " + " / ".join("%s %d戦" % (k, v) for k, v in builds.most_common(5)),
        "",
    ]


def card_rows(records):
    played = Counter()
    won = Counter()
    for record in records:
        for side, key in (("a", "deck_a"), ("b", "deck_b")):
            for card_id in set(record.get(key) or []):
                played[card_id] += 1
                if record.get("winner") == side:
                    won[card_id] += 1
    rows = [
        (card_id, played[card_id], 100.0 * won[card_id] / played[card_id])
        for card_id in played
        if played[card_id] >= MIN_CARD_SAMPLES
    ]
    rows.sort(key=lambda row: row[2], reverse=True)
    return rows


def summarize(records, names, top):
    if not records:
        return "該当する対局がありません。"
    lines = overview_lines(records)
    rows = card_rows(records)
    if not rows:
        return "\n".join(lines)
    lines += [
        "## カード別(そのカードを入れて戦った勝率)",
        "",
        "**カードの強さそのものではない**(強さの測り方は GameDesign.md 7章の方式による)。",
        "%d戦に満たないカードは省いている。" % MIN_CARD_SAMPLES,
        "",
        "| カード | 採用 | 勝率 |",
        "|---|---|---|",
    ]
    head = rows[:top]
    for card_id, count, rate in head:
        lines.append("| %s | %d | %.1f%% |" % (names.get(card_id, card_id), count, rate))
    if len(rows) > top:
        lines.append("| … | | |")
        for card_id, count, rate in rows[-top:]:
            lines.append("| %s | %d | %.1f%% |" % (names.get(card_id, card_id), count, rate))
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default="", help="このビルドIDの対局だけを集計する")
    parser.add_argument("--kind", choices=["random", "room"], default="", help="対局の種別で絞る")
    parser.add_argument("--days", type=int, default=0, help="直近この日数だけを集計する")
    parser.add_argument("--top", type=int, default=15, help="カード別に出す件数")
    parser.add_argument(
        "--exclude-repeats", action="store_true", help="同じ2人の対局は最初の1局だけ数える"
    )
    parser.add_argument(
        "--funnel", action="store_true", help="対局ではなく、来た人の段階ごとの人数を出す"
    )
    parser.add_argument("--with-actions", action="store_true", help="棋譜も取得する(重い)")
    parser.add_argument("--out", default="", help="集計をこのファイルへ書き出す")
    parser.add_argument("--post", action="store_true", help="Discordへ投稿する(--out が要る)")
    args = parser.parse_args()

    api_key, project = read_config()
    token = sign_in(api_key)
    if args.funnel:
        report = funnel_report(fetch_funnel(project, token), args.days)
    else:
        records = fetch_records(project, token, args.with_actions)
        report = summarize(select(records, args), card_names(), args.top)
    print(report)

    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
    if args.post:
        if not args.out:
            sys.exit("--post には --out が要ります(投稿する本文のファイルを指定してください)。")
        subprocess.run(
            [sys.executable, str(ROOT / "tools" / "discord" / "discord_post.py"), args.out],
            check=True,
        )


if __name__ == "__main__":
    main()
