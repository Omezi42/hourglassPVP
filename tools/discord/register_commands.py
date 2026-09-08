#!/usr/bin/env python3
"""砂時計アリーナのDiscordスラッシュコマンドを登録する(GameDesign.md 26章)。

    python tools/discord/register_commands.py

コマンドを足す・引数を変えるたびにこれを実行し直す(1度登録すれば恒久的に有効な
ため、ビルドのたびに自動実行はしない)。ギルドコマンドとして登録するため、
グローバルコマンド(反映に最大1時間)と違って即座に使えるようになる。
"""

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://discord.com/api/v10"
USER_AGENT = "DiscordBot (https://github.com/Omezi42/hourglassPVP, 1.0)"
CONFIG = Path.home() / ".hourglass_discord.json"

STRING = 3

COMMANDS = [
    {
        "name": "card",
        "description": "砂時計アリーナのカード情報を調べる",
        "options": [
            {"type": STRING, "name": "name", "description": "カード名(部分一致)", "required": True}
        ],
    },
    {
        "name": "deck",
        "description": "デッキコードからデッキの中身を画像で表示する",
        "options": [
            {"type": STRING, "name": "code", "description": "8桁のデッキコード", "required": True}
        ],
    },
    {
        "name": "link",
        "description": "ゲーム内アカウントとDiscordアカウントを連携する",
        "options": [
            {
                "type": STRING,
                "name": "code",
                "description": "ゲーム内アカウント画面で発行した8桁の連携コード",
                "required": True,
            }
        ],
    },
    {
        "name": "profile",
        "description": "連携したゲーム内アカウントのプロフィールを表示する",
    },
]


def api(token: str, path: str, method: str = "GET", payload=None):
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"Authorization": f"Bot {token}", "User-Agent": USER_AGENT}
    if data:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        sys.exit(f"失敗しました({error.code}) {path}\n{detail}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    token, guild_id = config["bot_token"], config["guild_id"]
    application_id = api(token, "/oauth2/applications/@me")["id"]

    result = api(
        token, f"/applications/{application_id}/guilds/{guild_id}/commands", "PUT", COMMANDS
    )
    print(f"{len(result)}件のコマンドを登録しました。")
    for command in result:
        print(f"  /{command['name']}")


if __name__ == "__main__":
    main()
