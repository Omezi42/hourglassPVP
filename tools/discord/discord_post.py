#!/usr/bin/env python3
"""Discordのチャンネルへ1件投稿する。

認証情報(Webhook URL)はこのリポジトリに置かない。リポジトリは公開のままで
なければBGMが配信できず(Architecture.md 4.1.6節)、かつ確認を挟まずcommitする
運用のため、木の中に置くと事故で公開される。既定では次の場所から読む。

    ~/.hourglass_discord.json

使い方:
    python tools/discord/discord_post.py 本文.md --dry-run
    python tools/discord/discord_post.py 本文.md

既定ではメンションを一切飛ばさない(allowed_mentions.parse = [])。ロールを
鳴らしたい場合だけ --mention-role <ロールID> を明示する。本文へ利用者の入力
(表示名・バグ報告の引用など)が混ざったときに @everyone が誤爆しないよう、
オプトインでしか鳴らない側を既定にしている。
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

# Discordの1メッセージあたりの上限。超える分は複数メッセージへ分ける。
MESSAGE_LIMIT = 2000
DEFAULT_CONFIG = Path.home() / ".hourglass_discord.json"


def load_webhook_url(config_path: Path, key: str) -> str:
    if not config_path.exists():
        sys.exit(
            f"設定ファイルが見つかりません: {config_path}\n"
            "リポジトリの外に置く必要がある(公開リポジトリのため)。"
        )
    config = json.loads(config_path.read_text(encoding="utf-8"))
    url = config.get(key, "")
    if not url:
        sys.exit(f"{config_path} に {key} がありません。")
    return url


def split_message(body: str) -> list[str]:
    """上限を超える本文を、なるべく段落の切れ目で分ける。"""
    if len(body) <= MESSAGE_LIMIT:
        return [body]

    chunks: list[str] = []
    current = ""
    for block in body.split("\n\n"):
        candidate = block if not current else f"{current}\n\n{block}"
        if len(candidate) <= MESSAGE_LIMIT:
            current = candidate
            continue
        if current:
            chunks.append(current)
        # 段落単体で上限を超える場合は行単位、それでも超える場合は文字数で切る。
        current = ""
        for line in block.split("\n"):
            line_candidate = line if not current else f"{current}\n{line}"
            if len(line_candidate) <= MESSAGE_LIMIT:
                current = line_candidate
                continue
            if current:
                chunks.append(current)
            while len(line) > MESSAGE_LIMIT:
                chunks.append(line[:MESSAGE_LIMIT])
                line = line[MESSAGE_LIMIT:]
            current = line
    if current:
        chunks.append(current)
    return chunks


def post(url: str, content: str, username: str, mention_role: str) -> dict:
    allowed = {"parse": []}
    if mention_role:
        allowed = {"parse": [], "roles": [mention_role]}
    payload: dict = {"content": content, "allowed_mentions": allowed}
    if username:
        payload["username"] = username

    request = urllib.request.Request(
        f"{url}?wait=true",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        sys.exit(f"投稿に失敗しました({error.code}): {detail}")
    except urllib.error.URLError as error:
        sys.exit(f"接続できませんでした: {error.reason}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Discordへ1件投稿する")
    parser.add_argument("body", help="本文のファイル。'-' で標準入力から読む")
    parser.add_argument("--dry-run", action="store_true", help="投稿せず内容だけ表示する")
    parser.add_argument("--username", default="", help="表示名を上書きする")
    parser.add_argument("--mention-role", default="", help="鳴らすロールID(既定は無音)")
    parser.add_argument(
        "--config", default=os.environ.get("HOURGLASS_DISCORD_CONFIG", str(DEFAULT_CONFIG))
    )
    parser.add_argument("--key", default="announce_webhook_url", help="設定内のキー名")
    args = parser.parse_args()

    if args.body == "-":
        body = sys.stdin.read()
    else:
        body = Path(args.body).read_text(encoding="utf-8")
    body = body.strip()
    if not body:
        sys.exit("本文が空です。")

    chunks = split_message(body)

    if args.dry_run:
        print(f"[dry-run] {len(chunks)} 件のメッセージとして投稿します")
        for index, chunk in enumerate(chunks, start=1):
            print(f"\n--- {index}/{len(chunks)} ({len(chunk)}文字) ---")
            print(chunk)
        return

    url = load_webhook_url(Path(args.config), args.key)
    for index, chunk in enumerate(chunks, start=1):
        result = post(url, chunk, args.username, args.mention_role)
        print(f"投稿しました {index}/{len(chunks)} message_id={result.get('id', '?')}")


if __name__ == "__main__":
    main()
