#!/usr/bin/env python3
"""縦長PVのナレーション(tools/pv_narration.json)をVOICEVOXエンジンで読み上げ、WAVにする。

    python tools/pv_voice.py <出力ディレクトリ>

VOICEVOXエンジン(既定 http://127.0.0.1:50021)を先に起動しておく。
出力は 00.wav, 01.wav ... で、record_pv_vertical.tscn へ --voice=<出力ディレクトリ> で渡す。
[ ] は字幕の強調、| は字幕の改行の記号なので読み上げ前に外す。
"""
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ENGINE = "http://127.0.0.1:50021"
NARRATION = Path(__file__).with_name("pv_narration.json")


def call(method: str, path: str, params: dict, body: bytes | None = None) -> bytes:
    url = f"{ENGINE}{path}?{urllib.parse.urlencode(params)}"
    headers = {"Content-Type": "application/json"} if body is not None else {}
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=120) as res:
        return res.read()


def speaker_id(name: str, style: str) -> int:
    for speaker in json.loads(call("GET", "/speakers", {})):
        if speaker["name"] != name:
            continue
        for entry in speaker["styles"]:
            if entry["name"] == style:
                return entry["id"]
    sys.exit(f"話者が見つかりません: {name}({style})")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    narration = json.loads(NARRATION.read_text(encoding="utf-8"))
    speaker = speaker_id(narration["speaker"], narration["style"])
    for index, line in enumerate(narration["lines"]):
        text = line.replace("[", "").replace("]", "").replace("|", "")
        query = json.loads(call("POST", "/audio_query", {"text": text, "speaker": speaker}))
        query["speedScale"] = narration["speed_scale"]
        query["prePhonemeLength"] = 0.0
        query["postPhonemeLength"] = 0.05
        wav = call("POST", "/synthesis", {"speaker": speaker}, json.dumps(query).encode("utf-8"))
        (out_dir / f"{index:02d}.wav").write_bytes(wav)
        print(f"{index:02d}.wav  {text}")


if __name__ == "__main__":
    main()
