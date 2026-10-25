# 10.14 Discordスラッシュコマンド(GameDesign.md 26章)

| クラス/ファイル | 責務 |
|---|---|
| `tools/export_card_data_json.gd` | ヘッドレスで `CardLibrary` を読み、`functions/data/cards.json` へ書き出す |
| `DiscordCardArt`(`scripts/ui/discord_card_art.gd`) | `/card` 用の詳細画像の描画。図鑑の右のページ(`AlmanacPage`)を元にするが、個人の戦績・裏返し操作・キーワードのボタンは持たない静的な1枚絵 |
| `tools/export_discord_card_art.gd` | `DiscordCardArt` を全カードぶん順に表示し、レンダリングされたフレームをキャプチャして `functions/data/card_art/{id}.png` へ書き出す |
| `tools/record_effect_gif.gd` / `.tscn`(既存) | カード1枚ぶんの実演(`CardEffectPreview`)を、詳細パネルと同じ地の上で1周分だけPNG連番として書き出す。**新規に作らず、既にある紹介動画用の撮影ツールをそのまま使う** |
| `tools/discord/build_effect_gif.sh` | 上記で録った連番を `magick` でGIFへエンコードし `functions/data/effect_gifs/{id}.gif` へ書き出す。引数にidを並べればそのカードだけ、無ければ全カード。**Discordの紹介投稿に添えるGIFも同じファイルを使い、出力先を1か所にする** |
| `functions/discord_commands.js`(Node.js) | `/card` `/deck` `/link` `/profile` と `/link` のフォーム送信のハンドラ。`discordInteractions` から呼ばれる |
| `functions/.env` | `AUTH_WEB_API_KEY`(`data/firebase_config.tres` の `api_key` と同じ値)。`/link` がID/パスワードを確かめるのに使う。クライアントに埋め込んでいる公開の値なのでコミットしてよい。`FIREBASE_` で始まる名前は予約されていてデプロイが止まる |
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
- **`functions/data/card_art` と `effect_gifs` は `firebase.json` の `functions.ignore` でデプロイから外す**(関数は読まず
  jsDelivrが配るため。同梱すると約70MBが関数ごとのソース保管・ビルドイメージへ載り課金の元になる)。全関数は
  `setGlobalOptions({maxInstances: 2})` で同時インスタンス数を絞る(公開URLへの大量リクエスト対策)
- **`/deck` は3秒の応答期限を超えうるため deferred response**(type 5・`flags: 64`)を即座に返し、生成後に
  `PATCH /webhooks/{application_id}/{token}/messages/@original` で追送する。**`res.json()` の直後に `return` せず、
  追送(`sendDeckFollowup()`)の完了を `await` してからハンドラを終える**(応答送信後にCPUがスロットルされることがある)
- **Firestore**: `discord_links/{discord_user_id}`(`{uid}`。`/link` が上書き)/ `discord_link_attempts/{discord_user_id}`
  (`{window_start, failures}`。失敗回数の窓)/ `bot_spotlight_history/{card_id}`(`{last_shown}`。カードごとに1件で、
  抽選のたびに全件読んで30日以内を除く。範囲クエリは組まない)。`discord_links` `discord_link_attempts` はFunctionsだけが書く
- **`/link` はモーダル(応答type 9)を返し、送信(`MODAL_SUBMIT`、`custom_id: "link_modal"`)で確かめる。**
  IDを `FirebaseAuth._to_email()` と同じ `<小文字のid>@hourglass-arena.local` へ直し、`accounts:signInWithPassword` の
  `localId` をuidとして使う(`returnSecureToken: false`。トークンは要らない)。パスワードはログへ出さない
- 失敗(`INVALID_LOGIN_CREDENTIALS` 等)は `discord_link_attempts` へ数え、1時間に5回で打ち切る。成功したら消す
- `/profile` は `players/{uid}` と `match_records`(`player_a`/`player_b` の等価フィルタ)から直接読む。**19章の戦績(CPU戦込み)は
  ローカル保存のため出せない**
- **応答はすべて `flags: 64`(ephemeral)**。カードスポットライト(`announceCardSpotlight`)だけは通常のメッセージ
- `discordInteractions` は `APPLICATION_COMMAND` を `data.name` で4コマンドへ、`MODAL_SUBMIT` を `data.custom_id` で分岐する。署名検証(`verifyKey()`)は全コマンド共通
