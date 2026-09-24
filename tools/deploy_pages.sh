#!/usr/bin/env bash
# itch.io・PLiCy の起動部が読む pck を Cloudflare Pages へ上げる(Architecture.md 4.6節)。
# build/pages は tools/make_portal.py が作る。認証は `npx wrangler login` 済みの資格情報を使う。
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="sunadokei-arena"
npx wrangler pages deploy "$ROOT/build/pages" --project-name "$PROJECT" --branch main --commit-dirty=true
