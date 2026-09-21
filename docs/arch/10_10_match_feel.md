# 10.10 対局中演出・QOL(GameDesign.md 9章)

対局の緊張感・操作性・状況把握を支援する演出・UI群。既存のコード描画(UiPalette/真鍮・琥珀スタイル)に完全準拠する。

| クラス | 責務 |
|---|---|
| `CardMatchAlert`(`scripts/ui/card_match_alert.gd`) | タイムリミット演出(焦燥演出)。残り15秒以下で脈動・警告表示 |
| `CardMatchDamageAssist`(`scripts/ui/card_match_damage_assist.gd`) | 盤面総攻撃力(直接攻撃打点)の算出とアシスト表示 |
| `CardMatchActionHistory`(`scripts/ui/card_match_action_history.gd`) | 直近のアクション履歴ミニプレビュー |
| `BoardTable`(`scripts/ui/board_table.gd`) | 卓上装飾のインタラクティブトイ(クリック時の歯車・砂埃アニメーション) |

- **タイムリミット演出**: `CardMatchClock` の残り時間を監視し、残り15秒を切ると警告パルス(アンバー〜赤)と微細な揺れを付与する。
- **打点アシスト**: 自陣の攻撃可能ユニットの攻撃力合計、および相手の守護を考慮した直接打点を算出して控えめに表示。

---

## 10.10.0 対局画面の見た目(GameDesign.md 9章「対局画面の見た目」)

**見た目は独立した層として持つ。**`MatchState`・各進行役(`CardMatchStrike` 等)・`CardMatchTouch` は
見た目を知らず、座標定数と `_draw()` を持つクラスだけが担う。

| クラス | 責務 |
|---|---|
| `MatchBackdrop`(`scripts/ui/match_backdrop.gd`) | 対局画面専用の下地。石の広間(`RoomPaint` の部品を薄く)/ 吊りランプ / 卓の中心の光だまり(放射グラデーションの `GradientTexture2D` を1枚。同心の楕円を重ねると段が見える)/ 卓・情報帯・手札・行動の列への落ち影 / 四辺のビネット。`ScreenBackdrop.PLAIN` の代わりに `_build()` の先頭で足す |
| `ActionColumnPanel`(`scripts/ui/action_column_panel.gd`) | 右端の行動の列の地。卓の脇に立てた**真鍮枠の操作盤**(濃紺の板 + 真鍮の額 + 上下の紋章入り飾り板 + ターン終了の周りの彫り込みの輪 + 群の区切り線)。ボタンより先に `add_child()` して背面へ置く |
| `RoundActionButton`(`scripts/ui/round_action_button.gd`, `extends Button`) | 行動の列の丸ボタン。**`CodedButton` / `CodedButtonStyle` は使わない**——文字の幅で矩形が伸びる仕組みのため、丸のつもりが楕円のピルになる。`text` は空にして `label` を自前で描き、`_get_minimum_size()` を直径で固定する。`filled`(ターン終了の金真鍮の面)/ `badge`(反転権の残り回数・エモートの残り秒)を持つ。ホバー・押下・`disabled` は `Button` のものをそのまま使い、`queue_redraw()` だけつなぐ |
| `TurnClockDial`(`scripts/ui/turn_clock_dial.gd`) | 行動の列の持ち時間の時計(GameDesign.md 9章)。いま手番の側の残り時間を1つだけ出し、時計を持たない対局は「∞」。書き込むのは `CardMatchClock.refresh_bars()` / `clear()` だけで、`CardMatchScreen._clock_dial` を直に触る(画面側の公開メソッドを増やさないため)。位置は `TurnClockDial.COLUMN_CENTER_Y` を `CardMatchBuild.make_clock_dial()` が読む |
| `FlipRightGauge`(`scripts/ui/flip_right_gauge.gd`) | 反転権ボタンの下の真鍮の札。自分と相手の残り回数を総回数ぶんの粒で並べる(GameDesign.md 9章)。`CardMatchFlipRight` が持ち、`refresh()` のたびに `state.flip_right_remaining` と `first_side` から総回数を引いて渡す。再生・観戦でも出す(見る側にも両者の残りが分かる) |

- **卓の奥行きは `BoardTable` が額と面を台形で描く**ことで出す(`PERSPECTIVE_INSET`:奥の辺を
  左右それぞれ何px狭めるか)。**額は最前面の層(`_rail_layer`)にリング状のポリゴンとして描き、
  マットの矩形の角を覆う**。マットの縁飾りが額の斜辺と平行になるよう、`PlaymatPaint.draw_mat()` は
  `top_inset` / `bottom_inset` を受け取って台形として描く(相手側 = 全量と半量、自分側 = 半量と0)。
  ショップ・アカウントの見本は引数を省略して矩形のまま
- **相手の列の駒は `CardView.scale` で 0.92 倍にする**(`CardMatchScreen.FOE_ROW_SCALE`)。
  `pivot_offset` を駒の中心に置き、`position` / `size` は変えない。これにより
  `CardFlipBeam.unit_center()` / `CardMatchGeometry.slot_center()` / ドラッグの当たり判定は
  等倍の座標のまま使える(Godot は `scale` を持つ `Control` の入力を正しく変換する)。
  攻撃の演出(`CardViewStrike`)は描画側の変換で駒を動かしており、`scale` と干渉しない
- **台座は `CardViewPaint.pedestal_base()` が「上面の楕円 + 側面の帯」の器として描く**。
  側面は上面の楕円の下半分を `PEDESTAL_HEIGHT` ぶん下へ押し出した帯で、暗い真鍮の縦グラデーション。
  輪(`pedestal_ring()`)は上面の縁に掛ける。接地の影は器の足元へ移す
- **情報帯(`PlayerInfoBar`)は板を持たず、器具を並べる**(GameDesign.md 9章「情報帯」)。
  肖像のメダルとバッジの真鍮の輪は `_brass_ring()`(外周と内周を1つのポリゴンにして縦グラデーション)、
  濃紺の板は `_plate()`、丸いバッジは `_badge()` が描く。持ち時間は情報帯には持たず、
  行動の列の `TurnClockDial` が出す。要素の並び・シグナルの受け口は変えない
- 座標定数(`TABLE_RECT` / `*_ROW_TOP` / `*_BAR_TOP` / `HAND_AREA` / `ACTION_COLUMN_X`)は
  `CardMatchScreen` が持つまま値を更新する。**`CardMatchGeometry` はこれらを読むだけ**なので、
  値を変えれば座標系の問い合わせは追従する

## 10.10.1 対局画面の手触り(GameDesign.md 9章「操作への反応」)

**新しい画面要素を足さず、既存の要素へ反応を足す。**実装済み。どこが持つかだけを残す。

| 反応 | 持つ場所 |
|---|---|
| 手札の並び(隣が避ける / ドローで場所を空ける / 相手手番で沈む) | `CardMatchHandLayout`(位置は代入せず Tween。沈める量は `SUMMONED_SINK` と同じ語彙) |
| ドラッグ中の傾き | `CardDragPreview`(移動の速度から傾きを決める。`CardView._get_drag_data()` はこれを作って返すだけ) |
| 放した位置から台座へ滑る | `CardMatchTouch.on_slot_drop()` が放した座標を控え、`unit_played` を受ける既存の経路で滑らせてから `play_land()` |
| ピップの光と吸い込み | `PlayerInfoBar.highlight_cost(n)` / `spend_toward(n, target)`。呼ぶのは `_on_view_hovered()` / `_on_view_left()` と `CardMatchEffects`(`unit_played` / `spell_cast`) |
| バッジの跳ね | `CardView` が `unit` の前回値を控えて差分で `stat_punch` を1.0にし Tween で戻す。描画は `1 + stat_punch * 0.3` の拡縮 |
| 身構え | `CardMatchTargets` が光っている相手の駒へカーソルが乗ったら `CardView.brace = true` |
| 取り消しの「戻る」 | `CardMatchSelection.clear()` を受けた画面側が `CardView.play_unselect()`(0.1秒で縮めて消す) |
| 攻撃ドラッグの矢印 | `CardDragArrow` |
| ホバー音 | `SoundBank.Sfx.HOVER`(`button.wav` を `SFX_PITCH` で高く、`SFX_GAIN` で小さく)。`wire_buttons()` が `mouse_entered` にもつなぎ、対局中の駒・手札は `CardView` が直接鳴らす(カーソルの出来事であり盤面の状態ではないため `CardMatchSound` を経由しない) |

## 10.10.2 メニュー画面群の手触り(GameDesign.md 9章「操作への反応」)

同じ方針。実装済み。

| 反応 | 持つ場所 |
|---|---|
| 画面遷移の横移動 | `ScreenTransitionFx`(`Main._show_only()` の中)。`_show_only()` は進む/戻るを知らないため、`back_pressed` 経由の遷移だけを `going_back = true` で逆方向にし、それ以外は「進む」で揃える |
| Esc / 右クリックで戻る | `Main._unhandled_input()`。現在の画面が `back_pressed` を持てば発行。対局画面は自前で使うため対象外 |
| ボタンの押し込みを深く | `CodedButtonStyle` の `State.PRESSED`(ハイライトの明度をもう一段落とし影を1px増やす。全ボタン共通の定数1つ) |
| ヘッダータイトルの着地 | `ScreenHeader` が `title_label.position.y` を -2 → 0 |
| 絵が矩形から矩形へ飛ぶ(一覧⇄棚 / 品⇄砂金チップ / ミッション受取) | `CardFlightFx.play(texture_or_control, from_rect, to_rect, duration)` の1メソッド。画面ごとに専用クラスを作らない。**演出の完了を待たずに配列操作は即座に行い、見た目だけが追いかける** |
| ホームのタブの横滑り | `_select_tab()` のフェードへ、タブの並び順で符号を決めた横移動を足す |
| `HomeTile` のホバー浮き / 副題の光り | `HomeTile` 自身(`mouse_entered`/`mouse_exited`)/ `refresh()` の呼び出し側が前回の文字列と比較して `flash_subtitle()` |
| 砂金チップの着地 | `DailyMissionPanel` / `CardMatchResult` が `CardFlightFx` で飛ばしてから `CurrencyChip.bump()` |
| デッキ編集の「2/2」の跳ね / 30枚の光り / 絞り込みモーダルの膨らみ | `WorkshopStockItem.count_punch` / `CardDeckShelf.glow_amount`(`rebuild()` で30に達した回だけ)/ `CardDeckFilterModal` の開始スケールをボタン矩形に合わせる |
| 図鑑のページめくり / ホバー傾き / 並び替えのスライド | `AlmanacPage.turn_to(card)` / `_gui_input()` 近くの tilt Tween / 左ページの一覧も「位置は Tween で滑らせる」方式 |
| ショップ・アカウント | 購入は `CardFlightFx` で品→チップ → 残高更新 / 名札見本の `bump()` / 買えない品は `enabled=false` の間 `MOUSE_FILTER_IGNORE` |
| 一覧の段差フェードイン / 削除の縮小 | `list_reveal_fx.gd` の `stagger(items, step=0.03, max_staggered=8)`(9件目以降は同時)/ 画面側が `scale` を0へ縮めてから配列から取り除く |
