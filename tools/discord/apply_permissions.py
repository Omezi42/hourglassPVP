#!/usr/bin/env python3
"""チャンネルの権限を、決めた形へ揃える。

    python tools/discord/apply_permissions.py            … 差分を表示するだけ
    python tools/discord/apply_permissions.py --apply    … 実際に適用する

手で1チャンネルずつ設定すると、どこを触ったか分からなくなり、直したつもりの
漏れにも気づけない。ここに表として持たせておけば、いつでも同じ状態へ戻せる。

方針は単純で、**読ませるだけのチャンネルは @everyone の書き込みを外す**。
それ以外のチャンネルには何も設定しない(既定のままにする)。触る対象を減らすほど
事故が減るため、必要なところだけを明示的に扱う。

Webhookでの投稿はチャンネル権限の影響を受けないため、#お知らせ や #通知 の
書き込みを外しても、すなえるの投稿は今までどおり通る。
"""

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://discord.com/api/v10"
USER_AGENT = "DiscordBot (https://github.com/Omezi42/hourglassPVP, 1.0)"
CONFIG = Path.home() / ".hourglass_discord.json"

VIEW_CHANNEL = 1 << 10
SEND_MESSAGES = 1 << 11
CREATE_PUBLIC_THREADS = 1 << 35
CREATE_PRIVATE_THREADS = 1 << 36
MANAGE_ROLES = 1 << 28

# 読ませるだけのチャンネル(@everyone の書き込みとスレッド作成を外す)。
# リアクションは残す。お知らせに反応できるほうが場が動くため。
READ_ONLY = ["welcome", "はじめに", "お知らせ", "通知"]
DENY = SEND_MESSAGES | CREATE_PUBLIC_THREADS | CREATE_PRIVATE_THREADS

# 権限を書き換えるために、Bot自身が持っている必要があるもの
# (Discordは「自分が持っていない権限」を上書き設定に書き込ませない)
REQUIRED = {
    "ロールの管理": MANAGE_ROLES,
    "メッセージを送信": SEND_MESSAGES,
    "公開スレッドの作成": CREATE_PUBLIC_THREADS,
    "プライベートスレッドの作成": CREATE_PRIVATE_THREADS,
}


def api(token: str, path: str, method: str = "GET", payload: dict | None = None):
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


def bot_permissions(token: str, guild_id: str, bot_id: str) -> int:
    guild = api(token, f"/guilds/{guild_id}")
    member = api(token, f"/guilds/{guild_id}/members/{bot_id}")
    roles = {r["id"]: int(r["permissions"]) for r in guild["roles"]}
    total = roles.get(guild_id, 0)  # @everyone
    for role_id in member.get("roles", []):
        total |= roles.get(role_id, 0)
    return total


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="チャンネルの権限を揃える")
    parser.add_argument("--apply", action="store_true", help="実際に適用する")
    args = parser.parse_args()

    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    token, guild_id = config["bot_token"], config["guild_id"]
    me = api(token, "/users/@me")

    if args.apply:
        have = bot_permissions(token, guild_id, me["id"])
        missing = [name for name, bit in REQUIRED.items() if not have & bit]
        if missing:
            print("Botに次の権限が足りないため適用できません:")
            for name in missing:
                print(f"  ・{name}")
            print("\nサーバー設定 → ロール → すなえる で一時的にONにし、")
            print("適用が終わったらすべてOFFに戻してください。")
            print("(Discordは、自分が持っていない権限を上書き設定に書き込ませないため)")
            sys.exit(1)

    channels = {c["name"]: c for c in api(token, f"/guilds/{guild_id}/channels")
                if c.get("type") == 0}

    print(f"{'チャンネル':<12} {'いま':<12} {'あるべき姿':<12} 変更")
    print("-" * 52)
    changes = 0
    for name, channel in sorted(channels.items(), key=lambda kv: kv[1].get("position", 0)):
        overwrite = next((o for o in channel.get("permission_overwrites", [])
                          if o["id"] == guild_id), None)
        now_deny = int(overwrite["deny"]) if overwrite else 0
        want_deny = DENY if name in READ_ONLY else 0

        now = "書き込み不可" if now_deny & SEND_MESSAGES else "書き込み可"
        want = "書き込み不可" if want_deny & SEND_MESSAGES else "書き込み可"
        same = (now_deny & DENY) == want_deny
        print(f"#{name:<11} {now:<12} {want:<12} {'—' if same else '★ 変更'}")
        if same or name not in READ_ONLY:
            continue
        changes += 1
        if args.apply:
            api(token, f"/channels/{channel['id']}/permissions/{guild_id}", "PUT",
                {"type": 0, "allow": str(VIEW_CHANNEL), "deny": str(DENY)})

    print("-" * 52)
    if changes == 0:
        print("すでに揃っています。")
    elif args.apply:
        print(f"{changes}件を適用しました。Botの一時的な権限はOFFに戻してください。")
    else:
        print(f"{changes}件が変更対象です。適用するには --apply を付けてください。")


if __name__ == "__main__":
    main()
