#!/usr/bin/env python3
"""公開向けの日本語文章(お知らせの下書き等)をGemini APIで添削する。

    python tools/discord/proofread.py tools/discord/drafts/update-2026.09.21.md

APIキーは ~/.hourglass_gemini.json の "api_key" から読む(リポジトリの外に置く)。
ブラウザでGeminiを開く運用をやめ、こちらで済ませる。
"""
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

CONFIG_PATH = Path.home() / ".hourglass_gemini.json"
# 混雑(503)のときは後ろの候補へ順に落とす
MODELS = ["gemini-flash-latest", "gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.6-flash", "gemini-3.5-flash", "gemini-2.5-flash"]
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

PROMPT = """あなたは日本語の校正者です。次の文章はブラウザゲーム「砂時計アリーナ」の
更新のお知らせで、マスコット「すなえる」(一人称「ぼく」、語尾「〜だよ」「〜してみてね」)の
口調で書かれています。この口調と、見出し・箇条書き・リンクなどのMarkdownの構造は変えずに、
誤字脱字・不自然な言い回し・意味の取りにくい箇所だけを直してください。

出力は次の2つだけにしてください。
1. 「## 指摘」の見出しの下に、直した箇所とその理由を箇条書きで(無ければ「なし」)
2. 「## 修正後」の見出しの下に、修正後の全文をそのまま

---
"""


def load_key() -> str:
    try:
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))["api_key"]
    except (OSError, KeyError, ValueError) as exc:
        sys.exit(f"APIキーを読めません: {CONFIG_PATH} ({exc})")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    text = Path(sys.argv[1]).read_text(encoding="utf-8")
    body = json.dumps(
        {"contents": [{"parts": [{"text": PROMPT + text}]}]}
    ).encode("utf-8")
    key = load_key()
    data = None
    for model in MODELS:
        req = urllib.request.Request(
            ENDPOINT.format(model=model),
            data=body,
            headers={"Content-Type": "application/json", "x-goog-api-key": key},
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as res:
                data = json.loads(res.read().decode("utf-8"))
            break
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:300]
            if exc.code in (404, 429, 503):
                print(f"[{model}] {exc.code} のため次の候補へ", file=sys.stderr)
                continue
            sys.exit(f"Gemini APIが失敗しました: {exc.code} {detail}")
        except urllib.error.URLError as exc:
            sys.exit(f"Gemini APIへ接続できません: {exc}")
    if data is None:
        sys.exit("Gemini API: どのモデルも応答しませんでした")
    parts = data["candidates"][0]["content"]["parts"]
    sys.stdout.reconfigure(encoding="utf-8")
    print("".join(p.get("text", "") for p in parts))


if __name__ == "__main__":
    main()
