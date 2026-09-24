# 4.6 unityroom以外の配信先(GameDesign.md 10章「配信先」)

itch.io と PLiCy には**起動部だけ**を置き、pck は Cloudflare Pages(`https://sunadokei-arena.pages.dev/`)から読む。
ビルドのたびに各サイトへ上げ直さずに済ませ、全配信先のビルドIDを揃える(6.4節の照合で相手が分かれないため)。

## 置き場所を Cloudflare Pages にしている理由

- 無料プランに超過課金が無く、転送量の上限も無い。pck(約4MB)は毎回の起動で転送される
- git に pck を積まない(本体リポジトリ・jsDelivr に置くとビルドのたびに履歴が4MB増える)
- `_headers` で `Access-Control-Allow-Origin: *` を返せる。起動部は itch.io / PLiCy のオリジンから別オリジンの pck を fetch する

## 書き出しの流れ(`tools/export_web.sh`)

| 出力 | 中身 | 行き先 |
|---|---|---|
| `build/web/index.pck` | ゲーム本体 | unityroom(従来どおり) |
| `build/pages/` | `index-{build_id}.pck`・`latest.json`・`_headers` | `npx wrangler pages deploy`(毎ビルド) |
| `build/portal.zip` | `tools/make_portal.py` が作る起動部(pck を含まない) | itch.io / PLiCy(Godot 更新時だけ手で上げる) |

- `latest.json` は `{"build": ..., "pck": "index-{build_id}.pck", "size": ..., "engine": "4.6.2"}`。起動部はこれを `cache: "no-store"` で読み、
  `GODOT_CONFIG.mainPack` に pck の絶対URLを渡して起動する
- **pck のファイル名に build_id を入れる**。中身が変わったら名前も変わるため、pck 自体は長くキャッシュさせてよく(`_headers` で immutable)、
  同じ版の2回目以降の起動はブラウザのキャッシュから読む
- 起動部の `engine` が `latest.json` と食い違ったら起動しない(wasm と pck の Godot の版が違うと読めない)。案内文を出して止める
- Pages は1回のデプロイでサイト全体を置き換えるため、古い pck は残らない。起動中の人は読み終わっているので困らない

## 配信先の判定

起動部は `window.hourglassPortal = true` を立ててからエンジンを起動する。unityroom のドメイン名に依存せずに
「自前の起動部で動いているか」を判定するためで、`PortalInfo.is_portal()`(`scripts/net/portal_info.gd`)だけがこれを読む。
`UnityroomRankingClient.can_send()` は `is_portal()` のとき送らない。
