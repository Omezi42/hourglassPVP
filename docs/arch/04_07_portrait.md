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

- **座標は `CardMatchLayout`(`RefCounted`)が横と縦の2つの値の組で持つ。**`CardMatchLayout.choose()` で今の組を選び、
  `current()`(= `CardMatchScreen.layout`)が返す。対局画面への参照を持つ進行役は `screen.layout`、持たない描画部品
  (`MatchBackdrop` / `SwingingLamp` / `ActionColumnPanel` / 固有演出)は `CardMatchLayout.current()` を関数の中から読む
  (const から読むと読み込みが循環する。Pitfalls.md)
- **`CardMatchArrange.apply()` が部品を置く唯一の場所。**組み立て(`CardMatchBuild`)は作って配線するだけで位置を持たず、
  `_ready()` の最後と `apply_orientation()` から呼ぶ。卓・帯・駒・ボタン・直前の手・メニューを置き直し、揺れの基準位置を取り直して `refresh()` する
- 駒の縮尺は `CardView.base_scale`(縦=0.88、相手の列はさらに0.92)。中心を軸に掛け、身構えの縮みはこの上に掛ける
- `PlayerInfoBar.stacked`: true で左の群と右の群を左端へ揃えて2段に描く(縦。帯ごと `scale` 1.5)。1つのノードのまま描き分け、帯を複製しない。
  `mana_row_first` で右の群(マナの段)を上の段にする。いまは両者とも下の段(相手は名札・HPが上、自分はマナが手札の側)
- `CardView.stat_scale`: 場の攻撃力・体力のバッジの倍率(縦=1.4)。`STAT_RADIUS` に掛けるだけで、跳ねる演出(`*_punch`)はその上に重なる
- `CardView.label_scale`: 駒の下の名前・キーワードの文字の倍率(縦=1.65)。大きくしたぶん行を駒の下へはみ出させる(上へ寄せるとバッジに重なる)
- 手札の札も `base_scale`(縦=1.35)を下端の中央から掛ける。`CardMatchHandLayout` は見た目の幅で並べる位置を逆算し、ホバー・タッチの拡大はこの上に掛ける
- `CardMatchDetail.apply_layout()`: パネルごと `scale`(縦=1.6)。置き場の計算は拡大後の大きさで行う
- `CardMatchActionHistory.set_layout()`: 縦では3件を横1列に並べ、1.3倍で置く(積むのは常に4件)
- 縦の反転権とコインはレールの左端(右端のターン終了と対)、対象選択の案内はレールの中央
- `CardMatchMenu`: 縦のときだけ出す「メニュー」ボタンと、ログ・エモート・投了を縦に並べたパネル。横では出さない
  (ボタンの実体は横の行動の列のものをパネルへ付け替えて使い、押したときの処理を二重に持たない)
- マリガン(`apply_layout()`)は見出し〜確定ボタンの一群を縦の中央へ置き、最大4枚の札を1.35倍のまま横1列に詰めて並べる。
  結果パネルは横と同じ大きさのまま画面の中央へ置く。誘導対局の帯はマリガンの確定ボタンの下端から位置を決める
- ログ(`CardMatchLog.apply_layout()`)は縦で680x1180・文字を24px(見出し30px)にする。詳細パネルは横と同じ詰めた表示のまま
- 墓地の一覧(`CardPileViewer.apply_layout()`)は縦で4列、パネルを720幅いっぱいまで `CenterContainer` ごと拡大する。
  実況(`CardMatchTurnFeed.apply_layout()`)は縦で文字と札を1.5倍。再生の操作(`CardMatchReplay.apply_layout()`)は
  縦で `CardMatchLayout.replay_center` を中心に3列2段・1.4倍。再生の操作は作った直後にも `apply_layout()` を呼ぶ(遅れて作るため)
- 誘導対局が光らせる駒・手札の輪郭は `CardMatchGeometry.view_rect()`(縮尺を通した見た目の矩形)で取る
- メニューのボタンは直前の手の列の直後へ並べ替え、マリガン・結果パネル・ログの暗幕より背面に置く(パネルと幕は最前面)
- 縦では吊りランプと行動の列の板を出さない(情報帯と直前の手に重なり、列を置く幅も無いため)
- 横と縦の見た目は `tools/capture_match_layout`(非ヘッドレス)で撮る

## タッチ操作

- **長押しの詳細**: `CardMatchPointer` が駒・手札の `gui_input` を見張り、押下から `LONG_PRESS_SECONDS` 指が動かなければ
  `CardMatchDetail.show_fixed()` で卓の中央へ出し、離したら消す。長押しが成立した押下は駒の `PressTracker` を打ち切り、離しても選択にしない
- タッチかどうかは `TouchInput.active`(static)。対局画面の `_input()` が入力ごとに `TouchInput.note()` へ渡し、
  `InputEventScreenTouch` かエミュレートされたマウス(`device == DEVICE_ID_EMULATION`)なら true。向きとは独立に持つ
- タッチのときは、タッチから作られたホバーで詳細・手札の避け・手札の拡大を出さない(指を離しても消えないため)。
  代わりに押している間だけ手札の札を1.5倍に浮かせる(`CardView.lift_for_touch()`)
- ログのカード名: タッチのときはホバーではなく `meta_clicked` で詳細を出す。行の押下で「名前以外を押した」を
  遅延で仮置きし、同じ押下で `meta_clicked` が来たら取り消す(押下と `meta_clicked` の順序に依らず、同じ名前の2度押しで消える)
- 反転の予測は「反転」ボタンを出した時点、ターン終了の予測は `button_down` で出し `button_up` で消す(タッチのときだけ)
