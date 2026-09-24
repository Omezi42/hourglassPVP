#!/usr/bin/env python3
"""SNS用の縦長ショート(X・YouTube Shorts)を1本、台本から動画まで通しで作る。

    python tools/shorts/make_short.py card <カードid>
    python tools/shorts/make_short.py card all   # 台本のある全カード。書き出し済みは飛ばす(途中から再開できる)

1. 台本(ナレーション + 見出し)を tools/shorts/card_lines.json から組む
2. VOICEVOXエンジンで読み上げる(tools/pv_voice.py。エンジンを先に起動しておく)
3. Godotで撮る(非ヘッドレス。1080x1920のPNG連番 + 音声用のAVI)
4. ffmpegで結合して tools/shorts/out/<種類>_<id>.mp4 へ出す

撮影中はGodotのウィンドウが開く。閉じない。同時に2本走らせない(Pitfalls.md「非ヘッドレスの静止画・動画キャプチャ」)。
"""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = Path(r"C:\Users\omezi\Documents\Godot_v4.6.2-stable_win64_console.exe")
FFMPEG = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft/WinGet/Links/ffmpeg.exe"
OUT_DIR = ROOT / "tools/shorts/out"
WORK_DIR = OUT_DIR / "work"
FPS = 30
SCENES = {"card": "res://tools/shorts/record_card_short.tscn"}
SPEAKER = {"speaker": "ずんだもん", "style": "ノーマル", "speed_scale": 1.3}


def card_narration(card_id: str) -> dict:
    table = json.loads((ROOT / "tools/shorts/card_lines.json").read_text(encoding="utf-8"))
    entry = table["cards"].get(card_id)
    if entry is None:
        sys.exit(f"card_lines.json に台本がありません: {card_id}")
    return {**SPEAKER, "card": card_id, "heads": entry["heads"], "lines": entry["lines"] + [table["cta"]]}


def run(command: list) -> None:
    print("$", " ".join(str(part) for part in command), flush=True)
    subprocess.run([str(part) for part in command], cwd=ROOT, check=True)


def main() -> None:
    if len(sys.argv) < 3 or sys.argv[1] not in SCENES:
        sys.exit(__doc__)
    kind, target = sys.argv[1], sys.argv[2]
    if target != "all":
        make(kind, target)
        return
    table = json.loads((ROOT / "tools/shorts/card_lines.json").read_text(encoding="utf-8"))
    failed = []
    for card_id in table["cards"]:
        if (OUT_DIR / f"{kind}_{card_id}.mp4").exists():
            continue
        try:
            make(kind, card_id)
        except subprocess.CalledProcessError:
            failed.append(card_id)
    print("失敗:", " ".join(failed) if failed else "なし")


def make(kind: str, target: str) -> None:
    work = WORK_DIR / f"{kind}_{target}"
    shutil.rmtree(work, ignore_errors=True)
    frames = work / "f"
    frames.mkdir(parents=True)
    narration_path = work / "narration.json"
    narration_path.write_text(json.dumps(card_narration(target), ensure_ascii=False), encoding="utf-8")

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
