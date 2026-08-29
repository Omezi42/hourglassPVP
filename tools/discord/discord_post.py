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
# DiscordのAPIはUser-Agentを検査する。urllibの既定値(Python-urllib/x.y)はCloudflareに
# 403 (error code: 1010) で弾かれるため、必ずこの形式で名乗る。
USER_AGENT = "DiscordBot (https://github.com/Omezi42/hourglassPVP, 1.0)"
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


def _multipart(payload: dict, files: list[Path]) -> tuple[bytes, str]:
    """画像やGIFを添えるときの本文(multipart/form-data)を組み立てる。"""
    crlf = "\r\n"
    boundary = "----hourglass" + os.urandom(8).hex()
    parts: list[bytes] = []

    head = (
        f"--{boundary}{crlf}"
        f'Content-Disposition: form-data; name="payload_json"{crlf}'
        f"Content-Type: application/json{crlf}{crlf}"
    )
    parts.append(head.encode() + json.dumps(payload).encode("utf-8") + crlf.encode())

    for index, path in enumerate(files):
        head = (
            f"--{boundary}{crlf}"
            f'Content-Disposition: form-data; name="files[{index}]"; '
            f'filename="{path.name}"{crlf}'
            f"Content-Type: application/octet-stream{crlf}{crlf}"
        )
        parts.append(head.encode() + path.read_bytes() + crlf.encode())

    parts.append(f"--{boundary}--{crlf}".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def _send(url: str, data: bytes, content_type: str, method: str = "POST") -> dict:
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": content_type, "User-Agent": USER_AGENT},
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        sys.exit(f"失敗しました({error.code}): {detail}")
    except urllib.error.URLError as error:
        sys.exit(f"接続できませんでした: {error.reason}")


def post(url: str, content: str, username: str, mention_role: str,
         files: list[Path] | None = None) -> dict:
    allowed = {"parse": []}
    if mention_role:
        allowed = {"parse": [], "roles": [mention_role]}
    payload: dict = {"content": content, "allowed_mentions": allowed}
    if username:
        payload["username"] = username

    if files:
        data, content_type = _multipart(payload, files)
    else:
        data, content_type = json.dumps(payload).encode("utf-8"), "application/json"
    return _send(f"{url}?wait=true", data, content_type)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    # Windowsのstdinは既定がcp932。明示しないとUTF-8で渡した本文が化ける
    sys.stdin.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Discordへ1件投稿する")
    parser.add_argument("body", nargs="?", help="本文のファイル。'-' で標準入力から読む")
    parser.add_argument("--attach", action="append", default=[], help="添える画像/GIF(複数可)")
    parser.add_argument("--delete", metavar="MESSAGE_ID", help="投稿済みメッセージを消す")
    parser.add_argument("--edit", metavar="MESSAGE_ID", help="投稿済みメッセージを差し替える")
    parser.add_argument("--dry-run", action="store_true", help="投稿せず内容だけ表示する")
    parser.add_argument("--username", default="", help="表示名を上書きする")
    parser.add_argument("--mention-role", default="", help="鳴らすロールID(既定は無音)")
    parser.add_argument(
        "--config", default=os.environ.get("HOURGLASS_DISCORD_CONFIG", str(DEFAULT_CONFIG))
    )
    parser.add_argument("--key", default="announce_webhook_url", help="設定内のキー名")
    args = parser.parse_args()

    if args.delete:
        url = load_webhook_url(Path(args.config), args.key)
        _send(f"{url}/messages/{args.delete}", b"", "application/json", method="DELETE")
        print(f"削除しました message_id={args.delete}")
        return

    if not args.body:
        sys.exit("本文のファイルを指定してください。")

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
    files = [Path(a) for a in args.attach]
    for f in files:
        if not f.exists():
            sys.exit(f"添付が見つかりません: {f}")

    if args.edit:
        if len(chunks) > 1:
            sys.exit("差し替えは1メッセージに収まる本文のみ対応しています。")
        payload = json.dumps({"content": chunks[0], "allowed_mentions": {"parse": []}})
        _send(f"{url}/messages/{args.edit}", payload.encode("utf-8"), "application/json",
              method="PATCH")
        print(f"差し替えました message_id={args.edit}")
        return

    for index, chunk in enumerate(chunks, start=1):
        # 添付は最後のメッセージにだけ付ける(分割時に画像が本文の途中へ挟まらないように)
        attach = files if index == len(chunks) else None
        result = post(url, chunk, args.username, args.mention_role, attach)
        print(f"投稿しました {index}/{len(chunks)} message_id={result.get('id', '?')}")


if __name__ == "__main__":
    main()
