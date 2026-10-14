# 4.7 縦画面(GameDesign.md 9章「縦画面」)

## 向きの判定と切り替え

| クラス | 責務 |
|---|---|
| `ScreenOrientation`(`scripts/ui/screen_orientation.gd`、static のみ) | `ENABLED`(全画面がそろうまで false)・基準解像度(横 1280x720 / 縦 720x1280)・いまの向き `is_portrait()`。判定はウィンドウの縦横比だけで、配信先を見ない |
| `Main` | `get_tree().root.size_changed` を受けて向きを判定し、変わったときだけ `root.content_scale_size` を差し替えて、全画面の `apply_orientation(portrait)` を呼ぶ |

- **向きを持つ画面は `apply_orientation(portrait: bool)` を1つだけ持つ。**中で座標を組み直すだけにし、状態(選択・スクロール位置・入力中の文字)は消さない。
  表示していない画面にも呼ぶ(`_show_only()` のたびに呼ぶと、切り替えの一瞬だけ古い配置が映るため)
- `content_scale_mode` は `canvas_items`・`aspect` は `keep` のまま。縦でも合わない端末は黒帯になる
- `ENABLED` が false の間、`is_portrait()` は常に false を返す。縦の配置の確認はテストとモックから `ScreenOrientation.force_portrait_for_test()` で行う

## 対局画面

- **座標の定数は `CardMatchLayout`(`RefCounted`)へ移し、横と縦の2つの値の組を持たせる。**`CardMatchScreen.layout` が今の組を返し、
  これまで `CardMatchScreen.TABLE_RECT` 等を読んでいたクラス(`MatchBackdrop` / `SwingingLamp` / `ActionColumnPanel` / `CardMatchHandLayout` /
  `CardMatchGeometry` / `CardMatchDetail` / `CardFlipBeam` / `CardMatchEffects` / `CardMatchFlipRight` / 固有演出)は `screen.layout` を関数の中から読む
  (const から読むと読み込みが循環する。Pitfalls.md)
- `CardMatchScreen.apply_orientation()` は、駒・帯・手札・ボタンの `position` / `size` を `layout` から置き直して `refresh()` を呼ぶ。
  再生中の演出は `CardMatchEffects` の打ち切りを通して結果だけを残す
- `PlayerInfoBar.stacked`: true で左の群と右の群を2段に描く(縦)。1つのノードのまま描き分け、帯を複製しない。
  `mana_row_first` で自分の側だけマナの段を下へ置く
- `CardView.stat_scale`: 場の攻撃力・体力のバッジの倍率(縦=1.4)。`STAT_RADIUS` に掛けるだけで、跳ねる演出(`*_punch`)はその上に重なる
- `CardMatchActionHistory.horizontal`: true で4件を横1列に並べる
- `CardMatchMenu`: 縦のときだけ出す「メニュー」ボタンと、ログ・エモート・投了を縦に並べたパネル。横では作らない
  (ボタンの実体は横の行動の列のものをパネルへ付け替えて使い、押したときの処理を二重に持たない)

## タッチ操作

- **長押しの詳細**: `CardMatchPointer` が `PressTracker` の押下から `LONG_PRESS_SECONDS` 動かずに経ったら `CardMatchDetail` に固定位置で出させ、
  離したら消す。長押しが成立した押下では、離しても押した扱い(選択)にしない
- タッチかどうかは直前の入力が `InputEventScreenTouch` か(またはエミュレートされたマウス)で判定し、向きとは独立に持つ
- 反転の予測は「反転」ボタンを出した時点、ターン終了の予測は `button_down` で出し `button_up` / 取り消しで消す(タッチのときだけ)
