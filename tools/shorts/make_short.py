#!/usr/bin/env python3
"""SNS用の縦長ショート(X・YouTube Shorts)を1本、台本から動画まで通しで作る。

    python tools/shorts/make_short.py card <カードid>
    python tools/shorts/make_short.py card all   # 台本のある全カード。書き出し済みは飛ばす(途中から再開できる)
    python tools/shorts/make_short.py puzzle <番号>  # とどめ問題。番号は問題集 puzzles.json の1始まり
    python tools/shorts/make_short.py puzzle all     # 問題集の全問。書き出し済みは飛ばす
    python tools/shorts/make_short.py forge <問数>   # 難しい問題を並列で探して問題集へ足す(数十分かかる)

1. 台本(ナレーション + 見出し)を tools/shorts/card_lines.json / puzzle_lines.json から組む
2. VOICEVOXエンジンで読み上げる(tools/pv_voice.py)。エンジンが応答しなければ VOICEVOX_ENGINE の run.exe を
   起動して待つ(手で起動するならそのファイルを実行する。黒い窓が開いている間が起動中)
3. Godotで撮る(非ヘッドレス。1080x1920のPNG連番 + 音声用のAVI)
4. ffmpegで結合して tools/shorts/out/<種類>_<id>.mp4 へ出す

撮影中はGodotのウィンドウが開く。閉じない。同時に2本走らせない(Pitfalls.md「非ヘッドレスの静止画・動画キャプチャ」)。
"""

import json
import math
import os
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(r"C:\Users\omezi\Documents\Godot_v4.6.2-stable_win64_console.exe")
VOICEVOX_ENGINE = Path.home() / "Documents/voicevox-engine/run.exe"
ENGINE_URL = "http://127.0.0.1:50021/version"
ENGINE_BOOT_SECONDS = 120
FFMPEG = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft/WinGet/Links/ffmpeg.exe"
OUT_DIR = ROOT / "tools/shorts/out"
WORK_DIR = OUT_DIR / "work"
FPS = 30
SCENES = {
    "card": "res://tools/shorts/record_card_short.tscn",
    "puzzle": "res://tools/shorts/record_puzzle_short.tscn",
}
SPEAKER = {"speaker": "ずんだもん", "style": "ノーマル", "speed_scale": 1.3}


def load_json(name: str) -> dict:
    return json.loads((ROOT / "tools/shorts" / name).read_text(encoding="utf-8"))


def card_narration(card_id: str) -> dict:
    table = load_json("card_lines.json")
    entry = table["cards"].get(card_id)
    if entry is None:
        sys.exit(f"card_lines.json に台本がありません: {card_id}")
    return {**SPEAKER, "card": card_id, "heads": entry["heads"], "lines": entry["lines"] + [table["cta"]]}


# 台本は問題によらず同じ。問題そのもの(局面と正解手順)を台本に同梱して撮影側へ渡す。
def puzzle_narration(number: str) -> dict:
    book = load_json(PUZZLE_BOOK)
    if not number.isdigit() or not 1 <= int(number) <= len(book):
        sys.exit(f"問題集の番号は 1〜{len(book)} で指定してください: {number}")
    entry = load_json("puzzle_lines.json")
    cta = load_json("card_lines.json")["cta"]
    return {**SPEAKER, "puzzle": book[int(number) - 1], "heads": entry["heads"], "lines": entry["lines"] + [cta]}


def targets(kind: str) -> list:
    if kind == "card":
        return list(load_json("card_lines.json")["cards"])
    return [str(n) for n in range(1, len(load_json(PUZZLE_BOOK)) + 1)]


# 問題探し(puzzle_forge.gd)は1問に数十秒〜数分かかるため、CPUのコア数に合わせて並列で回し、
# 見つかった問題を問題集の末尾へ足す(既存の番号は動かさない)。
def forge(count: int) -> None:
    workers = max(1, (os.cpu_count() or 2) - 2)
    per_worker = math.ceil(count / workers)
    base_seed = int(time.time())
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    outs = [WORK_DIR / f"forge_{i}.json" for i in range(workers)]
    procs = []
    for i, out in enumerate(outs):
        out.unlink(missing_ok=True)
        command = [
            GODOT, "--headless", "--path", ".", "--script", "res://tools/shorts/puzzle_forge.gd", "--",
            f"--count={per_worker}", f"--seed={base_seed + i}", f"--out={out}",
        ]
        procs.append(subprocess.Popen([str(p) for p in command], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    print(f"{workers}並列で {per_worker}問ずつ探しています…", flush=True)
    for proc in procs:
        proc.wait()
    book_path = ROOT / "tools/shorts" / PUZZLE_BOOK
    book = load_json(PUZZLE_BOOK) if book_path.exists() else []
    known = {signature(entry["stage"]) for entry in book}
    added = 0
    for out in outs:
        if not out.exists():
            continue
        for entry in json.loads(out.read_text(encoding="utf-8")):
            if signature(entry["stage"]) in known:
                continue
            known.add(signature(entry["stage"]))
            book.append(entry)
            added += 1
        out.unlink()
    book_path.write_text(json.dumps(book, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
    print(f"問題集へ {added}問を足しました(計 {len(book)}問)")


def signature(stage: dict) -> str:
    return json.dumps([stage["mana"], stage["hand_ids"], stage["own_units"], stage["foe_units"]])


NARRATIONS = {"card": card_narration, "puzzle": puzzle_narration}
PUZZLE_BOOK = "puzzles.json"


def run(command: list) -> None:
    print("$", " ".join(str(part) for part in command), flush=True)
    subprocess.run([str(part) for part in command], cwd=ROOT, check=True)


def main() -> None:
    if len(sys.argv) < 3 or sys.argv[1] not in [*SCENES, "forge"]:
        sys.exit(__doc__)
    kind, target = sys.argv[1], sys.argv[2]
    if kind == "forge":
        forge(int(target))
        return
    if target != "all":
        make(kind, target)
        return
    failed = []
    for name in targets(kind):
        if (OUT_DIR / f"{kind}_{name}.mp4").exists():
            continue
        try:
            make(kind, name)
        except subprocess.CalledProcessError:
            failed.append(name)
    print("失敗:", " ".join(failed) if failed else "なし")


def engine_ready() -> bool:
    try:
        with urllib.request.urlopen(ENGINE_URL, timeout=2):
            return True
    except OSError:
        return False


# 読み上げの前にエンジンが応答するかを見て、止まっていれば起動する(撮影が終わっても動かしたまま残る)。
def ensure_engine() -> None:
    if engine_ready():
        return
    if not VOICEVOX_ENGINE.exists():
        sys.exit(f"VOICEVOXエンジンが見つかりません: {VOICEVOX_ENGINE}")
    print("VOICEVOXエンジンを起動しています…", flush=True)
    subprocess.Popen([str(VOICEVOX_ENGINE), "--host", "127.0.0.1", "--port", "50021"],
                     creationflags=getattr(subprocess, "CREATE_NEW_CONSOLE", 0))
    deadline = time.time() + ENGINE_BOOT_SECONDS
    while time.time() < deadline:
        if engine_ready():
            return
        time.sleep(2)
    sys.exit("VOICEVOXエンジンが起動しませんでした")


def make(kind: str, target: str) -> None:
    ensure_engine()
    work = WORK_DIR / f"{kind}_{target}"
    shutil.rmtree(work, ignore_errors=True)
    frames = work / "f"
    frames.mkdir(parents=True)
    narration_path = work / "narration.json"
    narration_path.write_text(json.dumps(NARRATIONS[kind](target), ensure_ascii=False), encoding="utf-8")

    run([sys.executable, "tools/pv_voice.py", work / "voice", narration_path])
    audio = work / "audio.avi"
    run([
        GODOT, "--path", ".", "--write-movie", audio, "--fixed-fps", FPS, SCENES[kind], "--",
        f"--narration={narration_path}", f"--voice={work / 'voice'}", f"--frames={frames}",
    ])
    start = int((frames / "start.txt").read_text().strip())
    out = OUT_DIR / f"{kind}_{target}.mp4"
    run([
        FFMPEG, "-y", "-loglevel", "error",
        "-framerate", FPS, "-start_number", start, "-i", frames / "%05d.png",
        "-ss", f"{start / FPS:.4f}", "-i", audio,
        "-map", "0:v", "-map", "1:a", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
        "-c:a", "aac", "-b:a", "192k", "-shortest", out,
    ])
    shutil.rmtree(work, ignore_errors=True)
    print(f"書き出し: {out}")


if __name__ == "__main__":
    main()
