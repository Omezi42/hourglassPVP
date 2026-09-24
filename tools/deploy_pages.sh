#!/usr/bin/env bash
# itch.io・PLiCy の起動部が読む pck を Cloudflare Pages へ上げる(Architecture.md 4.6節)。
# build/pages は tools/make_portal.py が作る。認証は `npx wrangler login` 済みの資格情報を使う。
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="sunadokei-arena"
# リポジトリ直下の functions/(Cloud Functions)を Pages Functions と誤認させないため、build/pages の中から実行する
cd "$ROOT/build/pages"
npx wrangler pages deploy . --project-name "$PROJECT" --branch main --commit-dirty=true
