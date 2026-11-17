---
name: add-hourglass
description: |
  新しい砂時計(カード)を1枚、ゲームに追加する際の一連の手順をまとめたSkill。
  「新しい砂時計『○○』を追加して」といった指示があった場合に使用する。
  仕様の追記、カードResourceの生成、イラストの描画、値付けの実測までを一貫して行う。
  イラストはカードごとにシェーダーを1本書いて焼く。画像生成は使わない。
---

# add-hourglass Skill

## 目的

カードを追加していく運用を、定型作業の自動化によって支える。
仕様の追記・Resource生成・イラストの描画・値付けの実測をClaude Codeが引き受ける。

---

## 手順

### 1. 仕様の確認・追記

- `docs/Hourglasses.md` の現行カード一覧と、`docs/design/06_keywords.md`(GameDesign.md 6章: キーワードと値段表)を確認する
- 新しいカードの **コスト / 総量 / キーワードまたは効果** が、既存カードと重複・類似しすぎて
  いないか確認する
- **総量の当たりは値段表から付ける。**バニラの基準総量は `1.9 + 1.33 × コスト` で、
  そこからキーワードの値段を引いた値が出発点になる
- 未確定な部分があれば、コードを書く前に
  「GameDesign.mdを以下のように修正することを提案します」という形で追記案を提示し、
  ユーザーの承認を待つ

### 2. カードResourceの作成

- `data/cards/{id}.tres`(`CardData`)を新規作成し、以下を埋める
  - `id` / `display_name` / `cost` / `total_sand`
  - `pool_index`(追加順の通し番号)。**いま一番大きい番号+1を入れる**。
    砂時計一覧の「追加順」の並び(GameDesign.md 9章 = `docs/design/09_ui.md`)がこれを読む。
    確認は `grep -h pool_index data/cards/*.tres | sort -t= -k2 -n | tail -1`
  - `keywords`(`CardEnums.Keyword`。0個でよい)
  - `effects`(`CardEffectData` = トリガー × ターゲット × エフェクト。0個でよい)
  - `rules_text`(キーワードだけのカードは空でよい)
- 既存の `CardEnums.EffectType` で表現できない効果の場合は、新しいエフェクト種別と
  `CardEffectResolver` のハンドラの追加が必要になる旨をユーザーに伝え、実装前に承認を得る
  (仕様変更フローに従う)

### 3. イラストの描画

**砂時計の絵はカードごとにシェーダーを1本書き、PNGへ焼く**(GameDesign.md 9章 / Architecture.md 10.19節 =
`docs/arch/10_19_hourglass_shader_art.md`、4.1節 = `docs/arch/04_01_hourglass_art.md`)。
ガラス玉と砂は全種共通の部品で、カードが描くのは**柱・板・天板の上の飾り**だけ。

- `resources/shaders/hourglasses/{id}.gdshader` を置く。既存のシェーダーを見本にし、
  `hourglass_lib.gdshaderinc` と `frame_parts.gdshaderinc` を読んで `art_back()` / `art_frame()` を書き、
  最後に `art_main.gdshaderinc` を読む。**`clock` は使わない**(焼くときは0で評価される)
- 飾りのモチーフはカード名と世界観から引く(能力の分類にしない)。柱の素材と形・板の模様・天板の上の飾りで個性を出す
- `data/hourglass_sands.tres` へ `"{id}": {"sand": [r, g, b]}` を1行足す。砂の質感を変えるなら `"texture"`
  (grain / liquid / crystal / glow / stardust)も足す。**隣の色のカードと見分けが付く色にする**
- `.tres` に絵への参照も `art_id` も書かない(借りると2枚が同じ姿になる)
- 焼く: `Godot --path . --script res://tools/bake_hourglass_art.gd -- {id}`(**ウィンドウありで回す**。headlessは描かない)。
  続けて `Godot --headless --path . --import` で取り込む
- 天板の上の飾りはキャンバスの上端(y≒1.37)を越えると切れる。焼いた絵を拡大して、
  **既存の絵と並べて見劣りしない**(飾りが小さすぎない・切れていない・暗すぎない)ことを確かめる。
  場の駒・手札・図鑑の大きさで並べたスクリーンショットを人に渡し、採否の判定を待つ

### 3b. 紋章の割り当て

**棚・リスト・直前の手のような小さな表示では絵の飾りまで読めないため、そこで見分けるのは紋章である**
(GameDesign.md 9章)。砂術は絵を持たないため、紋章がそのまま札の顔になる。

- 紋章は**そのカードのモチーフ**(サンド=砂時計 / アイ=目 / ポイズン=髑髏)。
  能力の分類ではない
- 素材は**商用可・クレジット表記不要**のアイコンサイトから取る。既存21枚はすべて
  [icooon-mono](https://icooon-mono.com/)。検索は `https://icooon-mono.com/?s={語}`、
  SVGは `https://icooon-mono.com/i/icon_{id}/icon_{id}1.svg` で取れる
- `assets/hourglasses/emblems/sources/{id}.svg` へ置き、
  `Godot --headless --path . --script tools/build_emblem_icons.gd` を回す
- `.tres` へ `emblem` の参照を足す。**`[ext_resource]` は既存のext_resourceの直後へ書く**
  (`[sub_resource]` より後ろへ置くとそのファイルが読み込めなくなる)
- 出所・元アイコン名を `assets/CREDITS.md` の表へ1行足す

### 3c. カードの演出(省略しない)

**新しいカードは演出とセットで追加する**(GameDesign.md 9章「カードの演出」)。
カードの個性は、絵に加えて演出でも出す。

- 見せ方を1〜2行で決め、9章の「カードの演出」の表へ1行足す(仕様の追記として承認を取る)
- 効果を持つカードは `scripts/ui/signature/moves/{id}_effect.gd`、効果を持たないカードは
  `{id}_entrance.gd` を置き(どちらも `SignatureMove` を継ぐ)、`SignatureLibrary` の表へ1行足す。
  既存の `moves/` を見本にする
- **型の色と、盤面を揺らすかどうかは守る**(打撃なら揺らす / 払拭ならくすんだ色)。変えるのは効果が届くまでだけ
- 尺は1.2秒以内。専用の効果音は登場と、コスト6以上のカードの効果にだけ付ける(`tools/build_sfx.py` に `sig_{id}` を足し、打点の秒を演出の定数と揃える)
- 使い回せる絵の部品は `SignaturePaint` へ足す
- 対局画面で `--write-movie` で撮り、`ffmpeg` で音付きの動画にして見せ、判断を待つ

### 4. 値付けの実測

- `tools/balance/run_v5_card_check.gd` で、そのカードを2枚含むデッキの勝率を測る
  ```
  Godot --headless --path . --script tools/balance/run_v5_card_check.gd -- \
      focus={id} games=800 seed=42
  ```
- 50%から大きく外れていたら総量を±1して測り直す。**800戦の測定誤差は±3.5pt程度**なので、
  50%±5pt に収まれば十分とみなし、それ以上は誤差を追いかけるだけになる
- **混成デッキの平均勝率(`run_v5_simulation.gd` のカード別勝率)で1枚の強さを判断しない。**
  20種のプールから20枚を引くと1デッキに13種前後が入り、1枚の差が現れない
- 総量が下限(2)に達しても勝率が下がらない効果は、**コストを上げても釣り合わない**。
  効果そのものを弱める提案を出す(ハンマー・スイープで実際にそうなった)

### 5. 検証

- gdformat / gdlint を実行する
- `tools/tests/run_tests.gd` を実行し、`CardLibrary` が新しいカードを読めることを確認する
  (枚数を数えているテストがあるため、期待値の更新が要る場合がある)
- 一覧画面とデッキ編集画面をレンダリングし、表示が崩れていないか目で確かめる

### 6. お知らせの投稿(省略しない)

**カードを1枚足したら、必ず #お知らせ へ紹介を投稿する**(ユーザーの指示)。
実装だけして黙って終わらせない。手順は次のとおりで、**2通に分ける**。

1. カード画像を作る
   ```
   python tools/discord/build_card_image.py --id {id} --label 砂時計紹介
   ```
2. 能力の実演動画と `/card` 用の詳細画像を焼き、**コミットする**
   ```
   bash tools/discord/build_effect_video.sh {id}
   "C:\Users\omezi\Documents\Godot_v4.6.2-stable_win64_console.exe" --path . --script tools/export_discord_card_art.gd
   ```
   出力先の `functions/data/effect_videos/` `card_art/` は `/card` と正午のカードスポットライトが
   jsDelivr経由で読む場所。コミットし忘れるとそのカードの実演・画像がDiscordで出ない
3. 下書きを `tools/discord/drafts/cards/{id}-1.md` `-2.md` へ書く。
   **文面はすなえるの口調**(一人称「ぼく」・語尾「〜だよ」)で、1通目は
   `## ⌛ 砂時計紹介 ── {名前}` の見出しとコスト・総量・持っている語、
   2通目はその語が実際に何をするかを短く。既存の
   `tools/discord/drafts/cards/` を見本にする
4. `--dry-run` で確認してから投稿する
   ```
   python tools/discord/discord_post.py tools/discord/drafts/cards/{id}-1.md --attach tools/discord/out/card_reveal.png
   python tools/discord/discord_post.py tools/discord/drafts/cards/{id}-2.md --attach functions/data/effect_videos/{id}.mp4
   ```
5. 返ってきた message_id を `tools/discord/posted.json` の
   `announce_webhook_url` へ記録する(あとで文面を直して差し替えられるようにするため)

**カードセットをまとめて足したときは、1枚ずつの2通ではなくセット全体を1通にまとめる**
(`tools/discord/drafts/cards/pack-58-1.md` が見本)。Web版へ書き出すまでプレイヤーは触れないので、
「追加したよ」ではなく「次のアップデートで追加される予定だよ」と予告の形で書く。
追加からだいぶ経って未告知に気づいた場合は、告知するか尋ね、断られたら出さない。

**動画を作ったら、能力が盤面に映っているか人に見せる**
(`functions/data/effect_videos/{id}.mp4` を `SendUserFile` で渡す)。実演の台本は
キーワードとトリガーから自動で組む(`CardEffectPlan`)ため、新しい組み合わせで効果が
出ない局面になっていないかはここで気づく。良し悪しの判定は人が行う。

### 7. 仕様書への反映と完了報告

- `docs/Hourglasses.md` のカード表へ、実測した勝率とともに1行足す
- 報告する内容
  - 追加したカード(コスト/総量/効果)と、値付けの根拠となった実測値
  - イラストの飾りのモチーフ
  - 次に追加候補となりそうな方向性(あれば)

---

## 注意事項

- 1回のSkill実行で追加するカードは1枚までとする(実装単位を小さく保つ方針による)
- 仕様書(GameDesign.md / Hourglasses.md)とデータが常に一致している状態を保つ
- **同名カードはデッキに2枚まで**という制限があるため、デッキ編集・シミュレータの
  どちらもこの前提で動く。新しいカードもこの制限の対象になる
- 効果のバランス(強すぎる・弱すぎる)についての懸念があれば、実装前にユーザーへ伝える
