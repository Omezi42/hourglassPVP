---
name: build-and-announce
description: |
  砂時計アリーナをWeb(unityroom)向けにビルドし、その内容を更新のお知らせとして
  Discordの #お知らせ へ投稿するまでの手順。「ビルドして」「書き出して」
  「unityroom用に出して」といった指示があった場合に使用する。
  ビルドはpckができた時点では終わりではなく、お知らせの投稿までが1回ぶんの作業。
---

# build-and-announce Skill

## 目的

**ビルドと更新のお知らせを必ず対にする**(ユーザーの指示)。
毎日更新する運用のため、何が変わったのかが伝わらないとプレイヤーが更新に気づけない。
カードを1枚足したときの「砂時計紹介」(`add-hourglass` Skill)と対になる工程で、
こちらは**ビルド1回ぶんの変更をまとめて知らせる**。

投稿してよいか毎回確認を取る必要はない。

---

## 手順

### 1. ビルドする

```
bash tools/export_web.sh
```

- ビルドIDが `project.godot` へ刻まれる(`application/config/build_id`)。
  **この変更はそのままコミットする**(GameDesign.md 11章・Architecture.md 6.4節)
- 末尾に `tests passed` が出ること、`build/web/index.pck` のサイズが
  直前のビルドから跳ねていないことを確認する
- **フィルタの確認は自動化してある。**`export_presets.cfg` はエディタで書き出すたびに
  `include_filter` / `exclude_filter` が空へ戻る(実際に2度起きた)。空のまま書き出すと
  BGMとシミュレーションの生データが混ざってpckが3倍に膨らみ、逆に
  `data/discord_webhook.txt` が落ちて募集通知が飛ばなくなる。
  `tools/export_web.sh` が書き出し前に `tools/ensure_export_filters.py` で揃え直し、
  書き出し後に `tools/verify_web_pck.gd` でpckの中身を検査する。
  **`pck check passed` が出ないビルドは上げない**
- **エディタのメニューから書き出さない。**必ずこのスクリプトを通す
  (エディタから出すとビルドIDが刻まれず、検査も走らない)

### 2. お知らせの下書きを起こす

```
python tools/discord/new_update_draft.py
```

`tools/discord/drafts/update-{バージョン}.md` に、決まった書式の雛形と、
前回の告知以降のコミット一覧(材料)が書き出される。

### 3. 文面を仕上げる

- 書式は **あたらしいもの / なおしたもの / かわったもの** の3節。
  **中身が無い節は丸ごと消す**。最後にリンクの1行を残す
- **文面はマスコット「すなえる」の口調**(一人称「ぼく」・語尾「〜だよ」「〜してみてね」)。
  砂時計紹介・公開告知と同じ声に揃える
- **コミットの件名をそのまま流さない**。内部都合(ツール追加・仕様書の反映・
  リファクタ)が大量に混ざるうえ、コミットの粒度は読み手の関心と一致しない。
  **プレイヤーが画面で気づく変化の単位へまとめ直す**
- 材料のコメント(`<!-- ここから下は材料 -->`)は消してから投稿する
- **プレイヤーに関係する変更が1件も無い回は、お知らせを出さない**という判断も正しい

### 4. バナーを作る

```
python tools/discord/build_update_banner.py {バージョン} --subtitle "..."
```

- 添え書きは**20文字程度まで**。長いと右端で切れる(実際に切れた)
- 出力先は `tools/discord/out/`。**`assets/` の下へ出さない**
  (Godotがインポートして、告知用の画像がゲームのpckへ入ってしまう)
- 出力は `tools/discord/out/update_banner.png`。**生成したら必ず目で確かめる**

### 5. 投稿する

```
python tools/discord/discord_post.py tools/discord/drafts/update-{バージョン}.md \
    --attach tools/discord/out/update_banner.png --dry-run
python tools/discord/discord_post.py tools/discord/drafts/update-{バージョン}.md \
    --attach tools/discord/out/update_banner.png
```

既定の宛先が #お知らせ。**必ず `--dry-run` で1度確認してから投稿する。**

### 6. 記録する

```
bash tools/discord/since_last_announce.sh --mark
```

- 返ってきた message_id を `tools/discord/posted.json` の
  `announce_webhook_url` へ `update-{バージョン}.md` として記録する
  (あとで文面を直して差し替えられるようにするため)
- ビルドID・下書き・posted.json をまとめてcommit / pushする

---

## 注意事項

- **unityroomへ上げるのは `build/web/index.pck` だけ**。index.htmlの隣へ置く
  追加ファイルは配信されない(BGMをCDNから取りに行くのはこのため)
- アップロード自体はユーザーの手作業。こちらはpckを用意してお知らせを出すところまで
- お知らせにバージョン番号を書く場合は `project.godot` の `config/version`
  (日付方式)を使う。マッチングに使うビルドIDとは別物
