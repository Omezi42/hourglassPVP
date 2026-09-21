# 10.14 Discordスラッシュコマンド(GameDesign.md 26章)

| クラス/ファイル | 責務 |
|---|---|
| `tools/export_card_data_json.gd` | ヘッドレスで `CardLibrary` を読み、`functions/data/cards.json` へ書き出す |
| `DiscordCardArt`(`scripts/ui/discord_card_art.gd`) | `/card` 用の詳細画像の描画。図鑑の右のページ(`AlmanacPage`)を元にするが、個人の戦績・裏返し操作・キーワードのボタンは持たない静的な1枚絵 |
| `tools/export_discord_card_art.gd` | `DiscordCardArt` を全カードぶん順に表示し、レンダリングされたフレームをキャプチャして `functions/data/card_art/{id}.png` へ書き出す |
| `tools/record_effect_gif.gd` / `.tscn`(既存) | カード1枚ぶんの実演(`CardEffectPreview`)を、詳細パネルと同じ地の上で1周分だけPNG連番として書き出す。**新規に作らず、既にある紹介動画用の撮影ツールをそのまま使う** |
| `tools/export_discord_effect_gifs.sh` | 上記を全カードぶんループで呼び出す |
| `tools/encode_discord_gifs.sh` | PNG連番をGIFへエンコードする。`record_effect_gif.gd` の冒頭コメントに既にある `magick`(ImageMagick)のコマンド列をそのまま使い、**全カードぶんループで回すラッパーにする**(Pillowでの再実装はしない) |
| `DiscordLinkService`(`scripts/net/discord_link_service.gd`, static) | アカウント画面の「Discord連携コード」発行。`DeckCodeService` と同じ「8桁の数字を発行してFirestoreへ預ける」方式 |
| `functions/discord_commands.js`(Node.js) | `/card` `/deck` `/link` `/profile` のハンドラ。`discordInteractions` から呼ばれる |
| `functions/deck_sheet_canvas.js`(Node.js) | `/deck` 用の簡易デッキ表画像を `@napi-rs/canvas` で描画する。ゲーム内の `CardDeckSheet` とは別実装であり、見た目の一致は求めない |
| `functions/fonts/ZenKakuGothicNew-Bold.ttf` | `assets/fonts/` からコピーした同梱フォント。`firebase.json` の `functions.source` が `functions` ディレクトリだけを見るため、`functions/` の外にあるファイルはデプロイされない |
| `functions/.gdignore` | `functions/data/card_art/*.png` をGodotのインポート対象から外す。**置き忘れると `.png.import` が大量に生成される**(実際に70個生成された)。4.1.6節の「実行時に読まないディレクトリには`.gdignore`を置く」の実例 |
| `announceCardSpotlight` | Cloud Scheduler(毎日正午12:00 JST)。カードスポットライトの自動投稿 |
| `tools/discord/register_commands.py` | 4つのスラッシュコマンドをDiscordへ登録する(既存の `tools/discord/apply_permissions.py` と同じ、`~/.hourglass_discord.json` からBotトークンを読む流儀)。コマンドの追加・変更のたびに実行し直す。ギルドコマンドとして登録するため反映は即時 |


**運用**

- `functions/data/cards.json` は `tools/export_web.sh` がビルドのたびに更新する。**画像・実演GIFはビルドに組み込まない**——
  実際にレンダリングしたピクセルを読むため `--headless` では動かず、通常起動が要る(11章)。カードを追加・変更したとき
  (`add-hourglass` Skill の手順)に手動で実行し直す。画像・GIF・JSONはいずれもリポジトリへコミットする(秘匿情報ではない)
- **実演GIFはカードごとに1本**(`effect_gifs/{id}.gif`)。`record_effect_gif.gd` がそのカードの能力すべてを通しで1周ぶん録る
- **`/deck` の画像だけはFunctions側(Node.js、`@napi-rs/canvas`)で都度描く**(組み合わせが無数で事前生成できない。
  `node-canvas` はCairo依存でCloud Functionsのビルドが不安定なため採らない)。ゲーム内の `CardDeckSheet` と見た目を合わせない
- **`/card` の画像・GIFはjsDelivr経由でリポジトリから直接読む**(`https://cdn.jsdelivr.net/gh/Omezi42/hourglassPVP@main/functions/data/...`)。
  Embedへ埋めるだけでBotはアップロードしない。pushから数分〜数時間は古い版が返ることがある。`/deck` は生成したバイト列を
  `multipart/form-data` の `files[0]` として添付する
- **`/deck` は3秒の応答期限を超えうるため deferred response**(type 5・`flags: 64`)を即座に返し、生成後に
  `PATCH /webhooks/{application_id}/{token}/messages/@original` で追送する。**`res.json()` の直後に `return` せず、
  追送(`sendDeckFollowup()`)の完了を `await` してからハンドラを終える**(応答送信後にCPUがスロットルされることがある)
- **Firestore**: `discord_links/{discord_user_id}`(`{uid}`。`/link` が上書き)/ `discord_link_codes/{コード}`(`{uid}`。8桁の引換券、
  読んでも消さない)/ `bot_spotlight_history/{card_id}`(`{last_shown}`。カードごとに1件で、抽選のたびに全件読んで30日以内を除く。
  範囲クエリは組まない)。`firestore.rules` では `discord_link_codes` の発行だけをクライアントに許可し、`discord_links` はFunctionsだけが書く
- `/link` のコード発行はGodot側 `DiscordLinkService.publish_code()`(`DeckCodeService.publish()` と同じ実装、衝突したら引き直す)
- `/profile` は `players/{uid}` と `match_records`(`player_a`/`player_b` の等価フィルタ)から直接読む。**19章の戦績(CPU戦込み)は
  ローカル保存のため出せない**
- **応答はすべて `flags: 64`(ephemeral)**。カードスポットライト(`announceCardSpotlight`)だけは通常のメッセージ
- `discordInteractions` は `data.name` で4コマンドへ分岐する。署名検証(`verifyKey()`)は全コマンド共通
