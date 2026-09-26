---
name: post-shorts
description: |
  書き出したショート(カード紹介・とどめ問題)を、Claude in Chrome で YouTube Studio と X の
  予約投稿へ入れる手順。「ショートを予約して」「今週の投稿を入れて」「YouTubeとXに上げて」
  といった指示があった場合に使用する。週1回、明日から7日ぶんをまとめて入れる。
---

# post-shorts Skill

## 目的

投稿の手作業(動画の添付・本文の貼り付け・日時の設定)をユーザーから引き取る。
APIを使わないのは、X API が従量課金で予約の機能を持たず、YouTube API は審査を通すまで
アップロードが非公開に固定されるため。ユーザーの許可済みなので、1本ごとに確認を取らない。

## 前提

- 素材は `tools/shorts/schedule.py` が作る(`docs/arch/10_20_promo_capture.md`)。動画が無い日は先に撮る
- **Chrome のウィンドウを前面に出しておいてもらう。**タブが裏にある(`document.visibilityState` が `hidden`)と、
  X は添付した動画を読み込まず、予約設定のボタンが押せないまま止まる。最初に確かめ、`hidden` ならユーザーへ頼む
- 動画は1本10MB未満(`file_upload` の上限)。超えたら書き出しの設定を見直す

## 手順

### 1. 残りを出す

```
python tools/shorts/reserve.py list x --days 7
python tools/shorts/reserve.py list youtube --days 7
```

日時・動画のパス・本文(YouTube はタイトル/説明/タグ)が JSON で出る。明日以降で、まだ印の無いものだけ。

**入れる前に、各サイトの予約一覧と突き合わせる。**ユーザーが手で入れたものや、割り振りを変える前の予約が残っていることがある。
- X: `https://x.com/compose/post/unsent/scheduled`(ページの `div` から「〜に送信されます」の行を拾うと一覧になる)
- YouTube: `https://studio.youtube.com/channel/<id>/videos/short`(`ytcp-video-row` の文字に「公開予約 日付」が出る)

すでに入っているものは `reserve.py done` で印だけ付ける。今の割り振りと食い違う予約(日時・番号が違う)は
**消さずにユーザーへ一覧で伝え、消してもらう**(予約の削除は取り消せないため Claude は行わない)。

### 2. X へ入れる(1本ずつ)

1. `https://x.com/compose/post` を開く
2. 画面を撮りながら進める(撮らないと描画が進まず、`find` が要素を見つけられないことがある)
3. 予約のアイコン(ツールバーのカレンダー)を座標で押す。ref でのクリックは効かないことがある
4. 予約設定の `select`(`SELECTOR_1`=月・`2`=日・`3`=年・`4`=時(24時間制)・`5`=分)を JS で入れる。
   React が拾うよう、`HTMLSelectElement.prototype` の value セッターで入れて `change` を投げる。
   ダイアログの「〜に送信されます」の行で日時を確かめ、「確認する」を押す
5. 本文の欄を押して `type` で本文を打つ(改行はそのまま入る)
6. `find` で投稿ダイアログ内の file input を探し、`file_upload` で動画を付ける
7. 添付の枠に動画のサムネイルが出て、URLのリンクカードが消えたら「予約設定」を押す。
   **リンクカードが出たままなら動画は付いていない**(付け直す)
8. 「ポストの送信日時: …」のトーストを確かめ、`python tools/shorts/reserve.py done <日付> <種類> x`

### 3. YouTube へ入れる(1本ずつ)

Studio の「作成 → 動画をアップロード」で file input へ `file_upload` し、タイトル・説明をそのまま入れ、
「子ども向けではありません」、公開設定で「スケジュールを設定」に日時を入れて予約する。
入れたら `python tools/shorts/reserve.py done <日付> <種類> youtube`。

### 4. 片付け

- 予約一覧をもう一度読み、二重に入っていないか・日時がずれていないかを確かめる
- `tools/shorts/schedule.json` の印をコミットして push する
- 作ったタブを閉じる
