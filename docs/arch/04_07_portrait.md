# 4.7 縦画面(GameDesign.md 9章「縦画面」)

## 向きの判定と切り替え

| クラス | 責務 |
|---|---|
| `ScreenOrientation`(`scripts/ui/screen_orientation.gd`、static のみ) | `ENABLED`(true。縦の配置を止めるときだけ false)・基準解像度(横 1280x720 / 縦 720x1280)・いまの向き `is_portrait()`。判定はウィンドウの縦横比だけで、配信先を見ない |
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
- `button_scale`(縦=1.4)は反転権・粒・コイン・メニューのボタン、`text_scale`(縦=1.5)は反転ボタン・対象選択の案内・実況の文字・
  エモートの選択肢・墓地の一覧に掛ける。`CardMatchBuild.center_on()` は縮尺を通して中心を合わせる。誘導対局の帯は縦で画面幅いっぱい・1.4倍
- 手札は縦で選んだ札を `hand_select_lift` だけ上へ出し、`z_index` で最前面へ(`CardMatchHandLayout`)
- `CardMatchMenu`: 縦のときだけ出す「メニュー」ボタン(紋章 `MENU`)と、ログ・エモート・投了・スキップの横長のボタンを縦に並べたパネル。横では出さない。
  項目は押したら行動の列のボタンと同じ関数を呼ぶだけで、出す・押せる・エモートの残り秒は開くたびに元のボタン(`_log_button` など)から写す。
  スキップは `CardMatchTutorial.request_skip()` を通し、縦では `TutorialSkip` を隠す。エモートの選択肢はメニューの項目の脇へ開く(`anchor_popup()`)
- マリガン(`apply_layout()`)は見出し〜確定ボタンの一群を縦の中央へ置き、札を `PORTRAIT_COLUMNS`(2)列・`PORTRAIT_CARD_SCALE`(2.0)倍で折り返す。
  一群の高さは `content_height()` が初期手札の最大枚数から出す(先手・後手で一群が動かないように)。誘導対局の帯はマリガンの確定ボタンの下端から位置を決める
- 結果パネル(`CardMatchResult.apply_layout()`)は縦で `PORTRAIT_PANEL_SIZE`(幅 `PortraitModal.WIDTH`)に組み、`PortraitModal.SCALE` 倍にする。入場の拡大はこの倍率へ戻す
- ログ(`CardMatchLog.apply_layout()`)は縦で680x1180・文字を24px(見出し30px)にする。詳細パネルは横と同じ詰めた表示のまま
- 再生の操作(`CardMatchReplay.apply_layout()`)は縦で `CardMatchLayout.replay_center` を中心に3列2段・1.4倍。
  遅れて作るため、作った直後にも `apply_layout()` を呼ぶ
- 遠征の札: `CardMatchArrange.place_history()` が直前の手の列を置き、縦の遠征では `set_layout(layout, 1)` で末尾の1件を空け、
  `SoloMatchPlaque.apply_layout()` がその場所へ同じ縮尺で置く(`_compact` で2行に詰め、説明は札の下へ出す)。遠征の対局の開始・終了でも呼ぶ
- 誘導対局が光らせる駒・手札の輪郭は `CardMatchGeometry.view_rect()`(縮尺を通した見た目の矩形)で取る
- メニューのボタンは直前の手の列の直後へ並べ替え、マリガン・結果パネル・ログの暗幕より背面に置く(パネルと幕は最前面)
- 縦では吊りランプと行動の列の板を出さない(情報帯と直前の手に重なり、列を置く幅も無いため)
- 横と縦の見た目は `tools/capture_match_layout`(非ヘッドレス)で撮る

## タイトル・ホーム・デッキ一覧

- `TitleScreen.apply_orientation()`: ロゴ・開始の文言・「アカウント」を置き直す。横の値は `_ready()` で `.tscn` から控える
- `HomeScreen.apply_orientation()`: 名札(`AccountNameplateButton.set_portrait()`)・ミッションの札・日曜の知らせを組み直し、`BattleTab` / `DeckTab` / `LearnMenu` の `apply_orientation()` を呼ぶ
- 列の位置は `HomeLayout` の `portrait_*`(上から バトル → ソロモード → 右の列の3つを横1列)。`BattleTab` は縦で `RankedEntryInfo.tall` を外して横長の組み方に戻す
- `HomeTile.set_portrait_text()`: 見出し・副題(24px・2行まで)・余白・紋章の上限・印の倍率を縦横で切り替える。副題の折り返しは `_subtitle_rows()` が区切りを優先して行う。`DeckTab` は縦で紋章のぶんの空き(`emblem_reserve`)を0にする(3分の1の幅に見出しが入らないため)
- `HomeModePicker` は縦で札を画面の幅いっぱいにして上から積む。横の文字の大きさは札のメタに控えて戻す
- 「つぎはここ」の印は `NextStepMark.tag_scale` 1.5
- `ScreenHeader.apply_orientation()`: 縦で文字と「戻る」を大きくし、`ActionSlot` を `Row` から外してヘッダーの下の行へ置く。
  内容の上端は `portrait_content_top()`(主アクションの行の有無で変わる)。各画面が自分の `apply_orientation()` から呼ぶ
- `CardDeckListScreen`: 縦は1列、管理のボタンは名前の下の行。主アクションの行の有無で一覧の上端が変わるため、縦では `_refresh()` のたびに `_layout()` する

## デッキ編集

- `CardDeckEditorScreen.apply_orientation()`: 縦では在庫棚(`_grid_box`)と組立台(`_side_box`)を同じ木箱の矩形へ置き、`_select_tab()` で片方だけ出す。
  下地(`WorkshopBackdrop.portrait` / `show_shelf`)も1つの木箱を描く
- `WorkshopStockItem.zoom`: `CELL_SIZE` の座標のまま `draw_set_transform()` で拡大して描く(縦=1.6、3列)。
  `CardDeckShelf.text_scale`: 名前・名前の帯・印の上限だけを拡大する(縦=1.7。枠と絵は `size` から決まる)
- 詳細は縦では画面の中央に1.6倍で出す

## 砂時計図鑑・辞書・ルール・画面の見かた・一覧

- `CardListScreen.apply_orientation()`: `AlmanacBook.portrait` で1ページの本(`PORTRAIT_BOOK` / `PORTRAIT_PAGE`)を描き、`_select_tab()` で一覧と解説の片方だけを出す。
  `AlmanacEntry.zoom`(縦=1.6)は `WorkshopStockItem` と同じく `CELL_SIZE` の座標のまま拡大して描く。
  `AlmanacPage.set_page(size, scale)` はページを細く組み直して `scale` を掛ける(めくりの `scale:x` はこの倍率へ戻す。データ欄の間隔は紙の幅から決め、文は幅で折り返して実演をその下へ続けて置く)
- `KeywordPopup` は開くたびと向きの変化で `_fit()` し、`PortraitModal` の幅で組んで拡大する。`KeywordEntryView.set_layout()` が実演の幅と文字の大きさを持ち替える
- `KeywordDictScreen` は縦で語のボタンを `VBox` から `GridContainer`(2列)へ移す。`RuleScreen` / `ScreenGuideScreen` は縦横の矩形を `apply_orientation()` で置き直し、盤面は `RuleStage._fit()` が枠に合わせる
- 一覧の画面(`CardPuzzlePickerScreen`)は縦で1列。内容の矩形は `ScreenHeader.portrait_content_rect()`。パズルの札は向きの変化で作り直す
- `EmptyState` は縦で中身を `PORTRAIT_ZOOM`(1.5)倍で描く
- 画面を縦横で撮るのは `tools/capture_screen_layout`(非ヘッドレス。`class_name` か `.tscn` を並べる)

## その他の画面

- `PortraitTabs`(static): 縦で2つの面を切り替えるボタン。ヘッダーの主アクションの行に置く(ランク・ショップ)
- `RankOwnPanel.zoom`・`RankBoardRow.set_portrait()`: 段位は中身ごと拡大、ランキングの行は2段に積んで拡大して描く
- `CardStatsScreen`: 縦では2つの欄を1本のスクロールへ移して積む
- `CardShopScreen`: 一覧と詳細のパネルを拡大して置く(`_place_scaled`)。`ShopKindTab.portrait` で文字を大きくする。
  `ShopItemTile.text_scale` は、はじめの7日の札(`WelcomeDaysPanel`)が使う
- `AccountScreen`: 2つのパネルを `PortraitModal.SCALE` 倍で上下に置く(上は中身の高さ)。`AccountLooksTabs.set_portrait()` で列数を変える
- `CardRoomArrange`(static): ルームマッチ画面の縦横の置き場所(1000行の上限のための切り出し)
- `LabProposalCard.set_portrait()`: 拡大の層を押し込みの層(`_face`)の親に分けて置く。`LabThemeBand.set_portrait()` は締切・票の段をお題の下へ移す
- `SoloRouteView.vertical` と `relayout()`(段を下から上へ)、`SoloDepartureView.stacked`(作戦の札を上下に)。状態・行き先の詳細は1.25倍で道の下へ
- 遠征の重ね画面(`SoloBundleOverlay` / `SoloBoonOverlay` / `SoloWorkshopOverlay` / `SoloRunSummary`)は `set_portrait()` を持ち、
  `CardSoloMapScreen.apply_orientation()` が大きさと一緒に渡す。束・恩恵・工房は暗幕以外を `_body` にまとめ、縦では `size / PORTRAIT_ZOOM` で組んで
  `PORTRAIT_ZOOM` 倍にする。工房の格子は縦では高さにも収まる縮尺を選ぶ(スクロールしないため)。
  記録は道(`SoloRouteView.vertical`)を描き直す大きさが要るため拡大せず、文字・ボタンを縦の大きさにして山札の一覧だけを1.4倍にする。
  道は大きさが変わっても自分では置き直さないため、記録の `_layout()` が `relayout()` を呼ぶ
- `CardMatchFastForward`: 向きが変わったとき、有限の Tween を終わりまで進めてから並べ直す(終わりの無い Tween には触らない)。タイマーで待つ演出は打ち切らない

## モーダル

- `PortraitModal`(static のみ): 縦ではパネルを論理幅 `WIDTH`(480)で組み、`fit()` で `SCALE`(1.4)倍に中心から拡大する。
  **コンテナの子は渡さない**(コンテナが `scale` を1へ戻す)。`CenterContainer` で中央へ置くモーダルはその箱ごと渡す
- モーダルは画面ではないため `Main` から呼ばれない。開くたびに組み直し、開いている間の向きの変化は `PortraitModal.watch()` が受ける(状態は保つ)
- 対象: `ConfirmModal`・`SettingsPanel`・`CardCpuDifficultyPicker`・`DailyMissionPanel`・`WelcomeDaysPanel`・`CardSeasonCeremonyPanel`・`ShopSetPreview`・
  `AccountCredentialDialog`(上端を基準に拡大)・`LabProposalDetail`・`LabSubmitPanel`。拡大しても目安に足りない文字だけ縦の大きさを持つ
- `PortraitModal.fit_width()`: 中身の幅をそろえて持つモーダル用。横で最小幅が同じ子孫を、縦では論理幅へ合わせる

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
- **指スクロール**: `TouchScroll.enable(scroll)` を一覧の `ScrollContainer` ごとに1回呼ぶ。`SceneTree.node_added` で中身の
  `Control` 全部の `gui_input` へ見張りを掛け(シグナルは各Control自身の処理より先に呼ばれる)、`InputEventScreenDrag` で動かす。
  遊びを超えたら `NOTIFICATION_SCROLL_BEGIN` を配って押し込みを解き(BaseButton・`ClickArea`)、離す入力を `accept_event()` で
  握りつぶす(`PressTracker` の確定を防ぐ)。ドラッグで運べる札は `TouchScroll.is_touching()` 中の縦の動きでは運ばない
