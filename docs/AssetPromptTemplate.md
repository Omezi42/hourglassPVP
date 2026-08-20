# 砂時計アセット生成プロンプトテンプレート

このファイルは、新しい砂時計を追加する際にClaude Codeが参照する、画像生成プロンプトの雛形。
画像生成そのものはAPI経由で自動化せず、ユーザーが無料のnanobanana(Gemini/AI Studio等)へ
手動でコピペして生成し、透過処理まで手作業で行う運用とする。

---

## 共通テンプレート

```
A single sprite sheet image showing the same hourglass game token 
in three states side by side in one row, 
each state in its own equal-width square cell, no dividing lines, no cell borders, 
consistent character design and proportions across all three, 

left cell: sand fully settled in the top chamber, bottom chamber empty
middle cell: sand actively pouring through the middle neck, motion streaks visible
right cell: all sand settled in the bottom chamber, top chamber empty, dim glow

CRITICAL SIZE CONSTRAINT: the hourglass's core glass bulb shape (the two chambers 
connected by the narrow neck, from the top rim of the upper chamber to the bottom rim 
of the lower chamber) must occupy exactly the vertical center 70% of each square cell's 
height. This core bulb size must be IDENTICAL across all hourglass designs in this game, 
regardless of motif. Decorative elements (crossed swords, wings, a crown, gems, stone 
brick trim, a circular frame, etc.) are allowed to extend beyond this core zone toward 
the cell edges, but they must never shrink the core bulb itself smaller than this fixed 
70% proportion — treat the bulb's size as fixed first, and let decorations wrap around 
it second, not the other way around.

{{MOTIF}}, 
minimalist flat-vector illustration, clean bold outlines, soft cel-shading, 
color palette: warm amber sand with {{ACCENT_COLOR}} accents, 

the glass chamber of the hourglass is semi-transparent: through the glass, 
render a soft uniform neutral gray shadow/tint (a muted flat gray, not the background color), 
suggesting glass thickness and depth, subtle and consistent across all three cells. 

IMPORTANT: the area OUTSIDE the hourglass illustration (the entire background) 
must be a single flat solid color: pure magenta (#FF00FF), completely uniform, 
no gradient, no texture, no pattern, no shadow. 
This magenta will be removed later via chroma key. 
Do not use magenta or pink anywhere inside the hourglass design itself, 
including the glass tint — the glass tint must be gray, clearly distinct from the magenta background.

no text, no watermark, 
mobile game asset style, 
three equal square cells arranged horizontally in one wide canvas
```

---

## 変数の埋め方

- `{{MOTIF}}`: その駒のモチーフを英語1〜2文で記述する
  (例: `hourglass frame forged from a crossed sword hilt motif, sharp metallic edges`)
- `{{ACCENT_COLOR}}`: 琥珀色の砂と衝突しない、モチーフに合ったアクセントカラーを英語で指定する
  (例: `steel-gray`, `royal gold`, `bright cyan`)

新しい駒を追加する際、Claude Codeはこの2つの変数をGameDesign.mdの記述に基づいて埋め、
完成したプロンプト文をユーザーに提示する。画像生成そのものは実行しない。

---

## 運用フロー

1. ユーザーが新しい駒のモチーフ・効果をGameDesign.mdに追記(または追記案をClaude Codeが提示し承認)
2. Claude Codeが上記テンプレートを埋めたプロンプトを提示
3. ユーザーが無料のnanobanana(Web版)へ手動でコピペし、画像を生成・ダウンロード
4. ユーザーが背景のマゼンタ(#FF00FF)を手動で透過処理する
5. 透過済みPNGを `assets/hourglasses/incoming/{駒名のローマ字}.png` に配置
6. Claude Codeが取り込み、Resourceファイルを生成する(詳細は add-hourglass Skill を参照)

---

## 複数駒まとめ生成用テンプレート(サイズ統一の一括生成)

砂時計本体のサイズを駒同士で揃えたい場合、1駒ずつ個別に生成するより、**複数駒を1枚のシートに
まとめて生成する方が有効**。AIが同一画面内で複数デザインを見比べながら描くため、本体サイズが
ブレにくくなる(ボタンシート生成で実証済みの手法と同じ考え方)。既存駒の一括再生成や、まとめて
複数の新規駒を追加する際に使う。

縦一列に全駒を並べると、キャンバスが縦に間延びして1駒あたりの解像度が下がるため、
**{{GRID_COLS}}列×{{GRID_ROWS}}行のグリッド**(1駒=3状態の横並びブロックを1マスとして、
それをグリッド状に配置)にまとめる。正方形に近いキャンバス比率になり、1駒あたりの描画面積を
確保しやすい。

### 共通テンプレート

```
A single sprite sheet image, showing {{HOURGLASS_COUNT}} different hourglass game token 
designs, arranged in a {{GRID_COLS}}-column by {{GRID_ROWS}}-row grid of blocks (reading 
order: left to right, then top to bottom).

Each block represents one hourglass design, and is itself divided into 3 equal square 
cells side by side, no dividing lines, no cell borders, representing that hourglass's 
three states:
- left cell: sand fully settled in the top chamber, bottom chamber empty
- middle cell: sand actively pouring through the middle neck, motion streaks visible
- right cell: all sand settled in the bottom chamber, top chamber empty, dim glow

Leave a clear empty gap between adjacent blocks (both horizontally and vertically) so 
each block is visually separate and easy to cut apart later.

CRITICAL SIZE CONSTRAINT: across ALL {{HOURGLASS_COUNT}} blocks, the hourglass's core 
glass bulb shape (the two chambers connected by the narrow neck, from the top rim of the 
upper chamber to the bottom rim of the lower chamber) must be drawn at the exact same 
size and vertical position within its cell — occupying the vertical center 70% of each 
cell's height, identically in every single block regardless of that block's decoration. 
Since all {{HOURGLASS_COUNT}} designs are visible together on this one sheet, use block 1 
(the plain undecorated wooden frame) as the reference scale for the bulb, and match every 
other block's bulb to that exact same size. Decorative elements (swords, wings, a crown, 
gems, stone brick, a circular frame, ripple rings, an eye motif, etc.) may extend beyond 
the core zone toward the cell edges, but must never shrink the bulb itself. For any 
decoration that forms a ring, disc, or panel AROUND the hourglass (a shield, a circular 
frame, a medallion, etc.), keep that surrounding shape closely fitted to the hourglass — 
sized to just snugly frame it — rather than a large background element that dominates the 
cell; the hourglass must always read as the main subject, with decoration as a close-
fitting accent, not an oversized backdrop.

The {{HOURGLASS_COUNT}} blocks, in reading order, are: {{HOURGLASS_LIST}}

minimalist flat-vector illustration, clean bold outlines, soft cel-shading, warm amber 
sand color consistent across all blocks, each block's glass chamber is semi-transparent 
with a soft uniform neutral gray shadow/tint suggesting glass thickness, consistent 
across all blocks and cells.

IMPORTANT: the area OUTSIDE the hourglass illustrations (the entire background) must be a 
single flat solid color: pure magenta (#FF00FF), completely uniform, no gradient, no 
texture, no pattern, no shadow. This magenta will be removed later via chroma key. Do not 
use magenta or pink anywhere inside any hourglass design, including glass tints.

no text, no watermark, mobile game asset style, each block's 3 cells perfectly aligned in 
a horizontal strip, blocks evenly arranged in the grid with equal spacing, consistent 
cell size across the entire sheet.
```

### 変数の埋め方

- `{{HOURGLASS_COUNT}}`: そのシートに含める駒の個数
- `{{GRID_COLS}}` / `{{GRID_ROWS}}`: 駒ブロックの配置列数・行数(正方形に近くなる組み合わせを選ぶ。
  例: 10個なら2列×5行)
- `{{HOURGLASS_LIST}}`: 番号付きリストで「1. ○○: モチーフ説明, アクセントカラー」のように、
  読み順(左から右、上から下)で各ブロックを記述する

### 取り込み後の運用(想定)

1. `assets/hourglasses/incoming/all.png` に生成画像を配置
2. Claude Codeがブロック(駒)×状態(3列)で等分割する。分割はマス目の罫線ではなく、
   ブロック間・セル間の透明(alpha)な隙間を検出して境界を求める方式を使う(均等割りだと駒ごとの
   描画サイズのブレでズレるため。ボタンシート取り込み時に確立した手法を再利用する)
3. 分割した各画像を `assets/hourglasses/incoming/{駒名}.png` として保存し直し、
   通常の取り込みフロー(3等分・Resource反映)に合流させる

### 運用上の注意

- 2次元グリッド配置(複数列×複数行)は、列を跨いだ位置関係の指示をAIが崩しやすく、
  実際に試したところ品質が安定しなかった
- 1列に5個を縦に並べる(グリッド化しない)構成も試したが、こちらも安定しなかった
  (1個ずつの単体生成に比べればマシ、程度)
- 現状、**1個ずつ単体で生成するのが最も安定する**。まとめ生成は今後の生成AIの向上や
  プロンプトの工夫で再挑戦できる可能性があるが、現時点ではデフォルトの運用として
  推奨しない

---

## 既知の注意点

- 生成される画像はスプライトシート1枚(横3コマ、上向き/落下中/落ちきりの順)を想定
- 背景は必ずマゼンタ(#FF00FF)のベタ塗りを指定する。グラデーションやチェッカー柄の透過表現は
  実際には透過されておらず、RGBのベタ塗りとして焼き込まれてしまうため使用しない
- ガラス部分の透け感は、マゼンタと明確に区別できる「グレーの陰影」で表現させる
- 3コマの境界がずれることがあるため、取り込み時に等分割が可能か目視確認する
- 剣・翼・宝石・石枠のような大きな装飾を持つ駒は、装飾込みの外形(バウンディングボックス)を基準に
  正規化すると、砂時計本体(上下のガラス玉)が装飾のない駒より小さく見えてしまう。これを防ぐため、
  共通テンプレートに「本体はキャンバス高さの70%を必ず占める」という制約を明記している。既存駒を
  再生成する際は、この制約を含む最新のテンプレートで生成し直すこと

---

## UI背景テンプレート

画面背景(`assets/背景画像.png`相当)のバリエーションを増やす際に使うテンプレート。
砂時計本体とは異なり、背景そのものは**透過不要な不透明イラスト**として使うため、
砂時計テンプレートのマゼンタ全面塗りは使わない。

ボタン類は本テンプレートでは生成せず、下記「ボタンシート生成用テンプレート」で
背景とは別に一括生成する(白ベタ切り出し方式は位置合わせの手間が大きく廃止した)。

### 共通テンプレート

```
A single wide illustrated background scene for a mobile game screen, 1920x1080 canvas, 
full-bleed edge-to-edge — {{SCENE_DESCRIPTION}}. Moody atmospheric painting, soft depth, 
warm amber sand-glow accents consistent with an hourglass-themed game, dark navy/charcoal 
color grade, safe open space in the center so UI elements can sit on top later without 
fighting busy detail. This image is fully opaque — no transparency, just a normal 
painted background.

minimalist game-ready illustration style, mobile game UI asset, no text, no watermark, 
clean silhouettes, high readability once small UI elements are placed on top later.
```

### 変数の埋め方

- `{{SCENE_DESCRIPTION}}`: その画面の雰囲気を英語1〜2文で記述する

### 取り込み後の運用(想定)

1. `assets/backgrounds/incoming/{画面名}.png` に生成画像を配置
2. `assets/backgrounds/processed/{画面名}/background.png` として保存する(透過不要)
3. Claude Codeが取り込み、該当画面のシーンへ反映する

---

## ボタンシート生成用テンプレート

プロジェクト内のボタンは種類が有限(現状30個弱)なので、1個ずつ単体生成せず、
**画面グループ単位でまとめて1枚のシートとして生成**する。1枚のシートには
そのグループに属する複数ボタンを縦に並べ、各ボタンごとに
**normal/hover/pressedの3状態を横並びで同時生成**する(状態ごとの生成・差し替えの
手間をなくすため)。テキストは画像に焼き込まず、Godot側でLabel/Buttonのテキスト
プロパティとして重ねる(プロジェクト共通フォントで統一するため)。

透過方式は砂時計と同じ**マゼンタ(#FF00FF)ベタ塗り+クロマキー**を採用する
(白ベタ切り出しより実績があり安定しているため)。

### 共通テンプレート

```
A single tall sprite sheet image, showing {{BUTTON_COUNT}} different UI button frame 
designs for a mobile game, stacked vertically, one row per button design. 

Each row is divided into 3 equal square cells side by side, no dividing lines, no cell 
borders, representing that button's three interaction states, with consistent frame 
shape and proportions across all 3 cells in the same row:
- left cell: normal state (resting, flat)
- middle cell: hover state (slightly brighter glow / raised highlight, same silhouette)
- right cell: pressed state (slightly darker, subtly recessed / pushed-in look, same silhouette)

Each row's button frame is a decorative empty rounded-rectangle panel only — no text, 
no icon, no label inside it.

The {{BUTTON_COUNT}} rows, top to bottom, are: {{BUTTON_LIST}}

{{STYLE_DESCRIPTION}}, minimalist flat-vector illustration, clean bold outlines, 
soft cel-shading, warm amber/gold accents consistent with an hourglass-themed game, 
consistent material and color palette across all rows so they read as one UI family 
(each row's frame shape may vary slightly to reflect its own listed motif).

IMPORTANT: the area OUTSIDE the button frames (the entire background) must be a single 
flat solid color: pure magenta (#FF00FF), completely uniform, no gradient, no texture, 
no pattern, no shadow. This magenta will be removed later via chroma key. Do not use 
magenta or pink anywhere inside the button frame designs themselves.

no text, no watermark, no icons, mobile game UI asset style, each row's 3 cells 
perfectly aligned in a horizontal strip, rows evenly stacked vertically with equal 
spacing, consistent cell size across the entire sheet.
```

### 変数の埋め方

- `{{BUTTON_COUNT}}`: そのシートに含めるボタンの個数(行数)
- `{{BUTTON_LIST}}`: 番号付きリストで「1. ○○ボタン: モチーフ説明」のように各行を記述する
- `{{STYLE_DESCRIPTION}}`: そのグループ全体の素材感(例: `aged brass and dark wood UI panel`)

### 取り込み後の運用(想定)

1. `assets/buttons/incoming/{グループ名}.png` に生成画像を配置
2. Claude Codeが行(ボタン)×列(状態)で等分割し、
   `assets/buttons/processed/{グループ名}/{ボタンid}_normal.png` / `_hover.png` / `_pressed.png`
   として保存する
3. 各ボタンのGodotシーンで、StyleBoxTextureとしてtheme_override_styles/normal・hover・pressed
   に割り当てる(テキストは既存どおりButton.textのまま)

### 運用上の注意

- 1枚に詰め込む行数が多すぎると生成品質(枠の一貫性・整列)が落ちやすいため、
  まず現状の全ボタンを1枚で試し、崩れが大きい場合は画面グループ単位
  (`resources/theme/buttons/`の既存分類 home/deck/battle/match 等)で分割して
  再生成する
