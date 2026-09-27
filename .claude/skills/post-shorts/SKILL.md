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
- **作業するタブが画面に見えている必要がある。**`document.visibilityState` が `hidden` だと、X は添付した動画を読み込まず、
  URLのリンクカードが出たまま「予約設定」が押せない。`hidden` になるのは次の2つ
  - タブがウィンドウの中で選ばれていない → `tabs_create_mcp` で新しいタブを作るとそのタブが前に出る
  - Chrome のウィンドウ全体が他のウィンドウ(Claude のアプリなど)に完全に覆われている → Windows の遮蔽判定で隠れた扱いになる。
    ユーザーに Chrome を並べて表示したままにしてもらう
  最初に確かめ、`hidden` ならユーザーへ頼む
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

### 2. X へ入れる(1本ずつ・2回の browser_batch)

要素は `data-testid` で JS から触る(座標や ref のクリックは効かないことがある)。1本目で JS が要素を見つけられないときは画面を撮ってから触る。

1. `https://x.com/compose/post` を開き、`[role=dialog] [data-testid=tweetTextarea_0]` を JS で `focus()` して `type` で本文を打つ(改行はそのまま入る)。
   `find` で投稿ダイアログ内の file input の ref を取る
2. `file_upload` で動画を付ける → `[data-testid=scheduleOption]` を JS で押す → 予約設定の `select`
   (`SELECTOR_1`=月・`2`=日・`3`=年・`4`=時(24時間制)・`5`=分)を `HTMLSelectElement.prototype` の value セッターで入れて
   `change` を投げ、「確認する」を押す
3. **10秒待ってから**確かめて押す。動画のアップロード中に押すと何も起きない。次の3つが揃ったときだけ `[data-testid=tweetButton]`(「予約設定」)を押す
   - `[data-testid=attachments]` がある
   - `[data-testid="card.wrapper"]`(URLのリンクカード)が無い。リンクカードが出たままなら動画は付いていない
   - `[data-testid=scheduledTweetIndicator]` の文が狙った日時になっている
4. 画面が `/home` へ移り、`[data-testid=toast]` に「ポストの送信日時: …」が出たら `reserve.py done <日付> <種類> x`

### 3. YouTube へ入れる(1本ずつ・2回の browser_batch)

1. `https://studio.youtube.com/channel/<id>/videos/upload?d=ud` を開き、`find` でアップロードダイアログの file input の ref を取る
2. `file_upload` → 6秒待つ → 続けて次を行う
   - タイトル・説明: `ytcp-uploads-dialog #textbox` の1つ目・2つ目へ、`execCommand('selectAll')` → `execCommand('insertText')` で入れる
     (`type` だと説明のハッシュタグの候補を Enter が拾う)
   - `tp-yt-paper-radio-button[name=VIDEO_MADE_FOR_KIDS_NOT_MFK]` を押す
   - `#toggle-button`(すべて表示)を押し、`input[aria-label=タグ]` へ focus して、タグを末尾カンマつきで `type`。チップが6個になったかを数える
   - `#step-badge-3`(公開設定)→ `#second-container-expand-button`(スケジュールを設定)
   - `#datepicker-trigger` を押し、見えている日付の input を選択して `2026/10/01` の形で打って Enter
   - `#time-of-day-container input` を選択して `12:00` の形で打って Enter
   - 日付・時刻・チップの数が合っているときだけ `#done-button` を押す
3. 「動画は 〜 に公開に設定されます」のダイアログが出たら `reserve.py done <日付> <種類> youtube`

タイトル・説明・タグは `reserve.py list youtube` の値をそのまま使う。

### 4. 片付け

- 予約一覧をもう一度読み、二重に入っていないか・日時がずれていないかを確かめる
- `tools/shorts/schedule.json` の印をコミットして push する
- 作ったタブを閉じる
