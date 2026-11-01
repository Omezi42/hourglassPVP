#!/usr/bin/env python3
"""デッキ紹介の入口(#デッキを紹介する)を作り、ボタンの投稿を置く(GameDesign.md 26章)。

    python tools/discord/setup_deck_intro.py

チャンネルが無ければ #デッキ紹介 と同じカテゴリーの、そのすぐ上に作る。入口の投稿は
既に置いてあれば書き換える。作ったチャンネルと投稿のidは ~/.hourglass_discord.json へ残す。
書き込みを外すのは apply_permissions.py の役目(READ_ONLY に入れてある)。
"""

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://discord.com/api/v10"
USER_AGENT = "DiscordBot (https://github.com/Omezi42/hourglassPVP, 1.0)"
CONFIG = Path.home() / ".hourglass_discord.json"

ENTRY_CHANNEL = "デッキを紹介する"
INTRO_CHANNEL = "デッキ紹介"
GUILD_TEXT = 0
ACTION_ROW = 1
BUTTON = 2
BUTTON_PRIMARY = 1
BUTTON_SECONDARY = 2

# custom_id は functions/discord_deck_intro.js と揃える。
ENTRY_MESSAGE = {
    "content": "ボタンを押すと、ゲーム内の自分のデッキを <#{intro}> へ紹介できます。",
    "components": [
        {
            "type": ACTION_ROW,
            "components": [
                {
                    "type": BUTTON,
                    "style": BUTTON_PRIMARY,
                    "custom_id": "deck_intro:start",
                    "label": "デッキを紹介する",
                },
                {
                    "type": BUTTON,
                    "style": BUTTON_SECONDARY,
                    "custom_id": "deck_intro:link",
                    "label": "アカウント連携",
                },
            ],
        }
    ],
}


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


def ensure_entry_channel(token: str, config: dict) -> str:
    channels = config.setdefault("channels", {})
    if channels.get(ENTRY_CHANNEL):
        return channels[ENTRY_CHANNEL]
    intro = api(token, f"/channels/{channels[INTRO_CHANNEL]}")
    created = api(
        token,
        f"/guilds/{config['guild_id']}/channels",
        "POST",
        {"name": ENTRY_CHANNEL, "type": GUILD_TEXT, "parent_id": intro.get("parent_id")},
    )
    # 作った直後は末尾に入るため、#デッキ紹介 のすぐ上へ並べ直す。
    siblings = [
        c
        for c in api(token, f"/guilds/{config['guild_id']}/channels")
        if c.get("parent_id") == intro.get("parent_id") and c["id"] != created["id"]
    ]
    siblings.sort(key=lambda c: c["position"])
    order = []
    for channel in siblings:
        if channel["id"] == intro["id"]:
            order.append(created["id"])
        order.append(channel["id"])
    api(
        token,
        f"/guilds/{config['guild_id']}/channels",
        "PATCH",
        [{"id": cid, "position": i} for i, cid in enumerate(order)],
    )
    channels[ENTRY_CHANNEL] = created["id"]
    print(f"#{ENTRY_CHANNEL} を作りました。")
    return created["id"]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    token = config["bot_token"]
    channel_id = ensure_entry_channel(token, config)
    message = dict(ENTRY_MESSAGE)
    message["content"] = message["content"].format(intro=config["channels"][INTRO_CHANNEL])
    message_id = config.get("deck_intro_entry_message_id", "")
    if message_id:
        api(token, f"/channels/{channel_id}/messages/{message_id}", "PATCH", message)
        print("入口の投稿を書き換えました。")
    else:
        posted = api(token, f"/channels/{channel_id}/messages", "POST", message)
        config["deck_intro_entry_message_id"] = posted["id"]
        print("入口の投稿を置きました。")
    CONFIG.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
