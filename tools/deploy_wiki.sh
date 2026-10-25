#!/usr/bin/env bash
# 攻略サイトを組み立てて Cloudflare Pages へ上げる(Architecture.md 10.21節)。
# 認証は `npx wrangler login` 済みの資格情報を使う。初回だけ
# `npx wrangler pages project create sunadokei-arena-wiki --production-branch main` が要る。
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="sunadokei-arena-wiki"
python "$ROOT/tools/build_wiki.py"
# リポジトリ直下の functions/ を Pages Functions と誤認させないため、build/wiki の中から実行する
cd "$ROOT/build/wiki"
npx wrangler pages deploy . --project-name "$PROJECT" --branch main --commit-dirty=true
