#!/usr/bin/env python3
"""Webhookの表示名とアイコンをマスコット「すなえる」にする。

絵を作り直したとき(tools/build_mascot.py)に、もう一度これを回せば反映される。
投稿は行わない。認証情報は ~/.hourglass_discord.json から読む。
"""

import base64
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

MASCOT_NAME = "すなえる"
# DiscordのAPIはUser-Agentを検査する。urllibの既定値(Python-urllib/x.y)はCloudflareに
# 403 (error code: 1010) で弾かれるため、必ずこの形式で名乗る。
USER_AGENT = "DiscordBot (https://github.com/Omezi42/hourglassPVP, 1.0)"
AVATAR = Path("assets/mascot/mascot_avatar.png")
CONFIG = Path.home() / ".hourglass_discord.json"
TARGETS = [("queue_notify_webhook_url", "#通知"), ("announce_webhook_url", "#お知らせ")]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    avatar = "data:image/png;base64," + base64.b64encode(AVATAR.read_bytes()).decode("ascii")
    payload = json.dumps({"name": MASCOT_NAME, "avatar": avatar}).encode("utf-8")

    for key, label in TARGETS:
        url = config.get(key, "")
        if not url:
            print(f"{label:10} 未設定のため飛ばしました")
            continue
        request = urllib.request.Request(
            url, data=payload, headers={"Content-Type": "application/json", "User-Agent": USER_AGENT}, method="PATCH"
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                result = json.loads(response.read().decode("utf-8"))
            print(f"{label:10} 反映しました → 表示名 {result.get('name')} / アイコンあり")
        except urllib.error.HTTPError as error:
            print(f"{label:10} 失敗({error.code}): {error.read().decode('utf-8', 'replace')}")


if __name__ == "__main__":
    main()
