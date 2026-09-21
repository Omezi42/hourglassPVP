# 4.0 対局画面

子がすべてコード描画の `Control` で Inspector から編集する値を持たないため、`.tscn` を作らず
`CardMatchScreen` の中で組み立てる。**画面本体(`card_match_screen.gd`)と `CardView` は1000行の上限に
張り付いており、機能は `_screen` / `_view` 参照を持つ `RefCounted` か static の描画ヘルパへ切り出す**(11章)。

## クラス一覧

| クラス | 責務 |
|---|---|
| `CardMatchScreen` | 全体を並べ `MatchState` と同期し、操作を受ける。**自分の1手は必ず `_perform()` を通す**(適用と送信を1箇所に集め、送信し忘れる経路を作らない)。`_finish_action()` が演出の状態を見て `refresh()` の時機を決めるため、**`_perform()` の呼び出し元で `refresh()` を重ねて呼ばない** |
| `CardMatchBuild` | 画面の子を生成する。`CardMatchTouch` は `_build()` より先に生成する(組み立て中に駒のシグナルへ接続されるため) |
| `CardMatchGeometry` | 座標系の問い合わせ(`hp_bar_center()` / `slot_center()` / `playable_hand_rects()` / `end_turn_button_rect()`)。`CardMatchScreen` の座標定数を読むだけ |
| `CardView` / `CardViewPaint` / `HandCardPaint` | 駒・札1枚の表示。`Mode.HAND`(枠あり・コスト左上/総量右下)と `Mode.BOARD`(枠なし・台座の上の砂時計・攻撃力左下/体力右下)。**砂術は `Mode.HAND` の中の分岐**(`is_spell` で絵の代わりに紋章・総量バッジなし・枠色変更。`Mode.SPELL` は作らない——場での見た目が存在せず、`BOARD` との組み合わせという有り得ない状態を表現できてしまう)。守護の輪は `guard_frame`(場だけ true)。状態(`health_punch`/`attack_punch`/`unselect_amount`/`counter_offset`/`spark_amount`/strikeの offset・angle・flash)は `CardView` が持ち、描画は `CardViewPaint`(台座・封蝋・バッジ・予測)と `HandCardPaint`(手札の面)が担う。いずれも第1引数に `CardView` を取る |
| `CardViewStrike` / `CardViewFlourish` | 攻撃の4段の段取り / 相打ちの反撃(`play_counter()`)とドローの合図(`play_spark()`)の Tween。`CardView` に同名の薄い委譲を残す |
| `CardUnitFx` | `CardView` の子として重ねる演出のうち盤面の状態を参照しないもの(着地 / 崩落 / 硝子の閃光 / `play_recall()`)。崩落は `CardData` を受け取り絵と矩形をその時点で控える(次の同期で `card` が null になるため) |
| `CardDragPreview` / `CardDragArrow` | ドラッグ中に指へ付いてくる絵(速度から傾き)/ 攻撃ドラッグの駒→指先の矢印(自分の場の駒のときだけ) |
| `CardMatchHandLayout` | 手札の並べ方。**位置は代入せず Tween で滑らせる**。ホバー中の両隣を避け、相手の手番で沈める |
| `BoardTable` / `PlaymatLibrary` / `PlaymatPaint` | 卓(木の額 / マット2枚 / レール)。マットは `clip_contents` の子層(`MatLayer`)として敷く(模様が卓の外へ漏れる)。**卓とショップの見本で同じ描画関数を通す**。既定は `NONE_ID`(何も敷かない) |
| `MatchBackdrop` / `ActionColumnPanel` / `RoundActionButton` / `TurnClockDial` / `FlipRightGauge` | 再構築(10.10.0節)で足した下地・行動の列の地・丸ボタン・持ち時間の時計・反転権の粒の札 |
| `PlayerInfoBar` | 片方の情報帯。板を持たず真鍮の器具(メダル / 名札 / HPの器 / マナの計器 / 山の札)を並べる。`hp_bar_rect()` 等の座標の問い合わせ、`highlight_cost()` / `spend_toward()`(ピップの光と吸い込み)、`drop_handler`(HP帯へのドロップ。`targetable` のときだけ受ける)、`show_emote()` |
| `CardMatchSelection` | いま選んでいるもの(手札 / 自分の枠 / TARGETING / FLIP_RIGHT / 未選択)と `hover_target`(`NO_HOVER` / `FACE` / 相手の枠) |
| `CardMatchTouch` | 盤面と手札を押す/ドラッグする受け口。分岐だけを持ち、適用は `MatchState`、段取りは `CardMatchSpell` / `CardMatchEffectTarget` / `CardMatchFlipRight` へ渡す |
| `CardMatchSpell` / `CardMatchEffectTarget` / `CardMatchFlipRight` | 砂術 / 設置効果の対象選択 / 反転権 の段取り。反転権のボタンは再生・観戦の「戻る」と同じ位置(両者は同時に見えない) |
| `CardMatchTargets` | 置ける枠・殴れる相手の強調、相打ちの予測(`refresh_own_preview()`)、身構え(`CardView.brace`) |
| `CardMatchDetail` | 詳細パネルの出し消し。出してよい状態か(対象選択中・マリガン中・演出中でない)、消すまでの猶予(`HIDE_DELAY`)、置き場(`CardDetailPanel.place_near()` に卓の範囲を渡す)。**`CardMatchScreen` の const を const から参照しない**(読み込みが循環して起動が固まる。11章) |
| `CardMatchMulligan` | マリガン画面。選んだ枚数を `mulligan_confirmed(indices)` で返し、適用は `MatchState` |
| `CardMatchLog` / `CardMatchTurnFeed` | ログ(記録と表示を同じクラスに持ち、実況と読み返しの文を一致させる)/ 手番バナーと相手の1手の実況(`CardMatchLog.describe()` から引く) |
| `CardMatchStrike` / `CardMatchShake` | 攻撃の演出の進行役(被ダメージ・音を当たる瞬間まで持ち越す)/ 盤面の揺れ |
| `CardMatchEffectStrike` / `EmblemStrikeFx` | 設置効果・トリガーの紋章の進行役 / 紋章が飛ぶ演出そのもの(独立したオーバーレイ) |
| `CardMatchEffects` | 攻撃以外の演出の進行役(着地 / 崩落 / 硝子の閃光 / ドローと疲労の山札 / 砂へ還す)。`MatchState` のシグナルだけを見る |
| `CardFlipBeam` | 反転の光の筋と駒の裏返り(`play_flip()`)。独立したオーバーレイ(`Control._draw()` は子より背面のため画面側で描くと卓に隠れる) |
| `CardMatchSound` | 対局中の効果音。**画面側の操作ではなく `MatchState` のシグナルだけを見て鳴らす**(自分の手・CPU・オンライン・再生のすべてが同じ経路を通る) |
| `CardMatchResult` / `CardMatchOutcome` | 結果パネル / 終局後の後始末(リプレイ保存・砂金・戦績・ミッション・記録) |
| `CardMatchReplay` / `CardMatchOnline` / `CardMatchPuzzle` / `CardMatchSolo` / `CardMatchTutorial` | 再生コントロール / オンラインの3入口 / パズル / ソロ / 誘導対局。いずれも `_screen` 参照の切り出し |
| `CardMatchEmote` / `EmotePopupPanel` / `EmoteBubble` | エモート(6.6節) |
| `CardMatchAlert` / `CardMatchDamageAssist` / `CardMatchActionHistory` | 残り15秒の焦燥演出 / 打点アシスト / 直前の手の列 |
| `CardDetailPanel` / `CardEffectPreview` / `CardEffectStage` / `CardEffectDemoKeyword` / `CardEffectDemoEnemy` / `InkFigure` | カード詳細と能力の実演(4.0.4節) |
| `CardPileViewer` | 墓地の中身(同じカードは1枚にまとめ枚数バッジ) |

## 4.0.1 寸法と描画

- **右端148pxは行動の列**。盤面・情報帯・手札はその手前で止め、両情報帯は同じ幅(`BAR_WIDTH`)にする
- 座標定数(`TABLE_RECT` / `*_ROW_TOP` / `*_BAR_TOP` / `HAND_AREA` / `ACTION_COLUMN_X`)は `CardMatchScreen` が持ち、`CardMatchGeometry` は読むだけ
- **手札は `CardView.HAND_SIZE_PX`(118x158)を基準に、各部を比(`_hand_scale()`)で決める**(固定値だと辞書のように小さく置いたとき名前がはみ出す)
- **砂時計の絵は枠へ引き伸ばさず縦横比のまま収める**(`_fit_art()`)。キャンバスは400x513(`state_falling` だけ415x532)で、**倍率は3状態のうちいちばん高いキャンバスを基準に共通化する**(状態ごとに割ると `falling` へ切り替わった瞬間だけ縮む)。ドラッグのプレビューも同じ大きさ
- **相手の列は `CardView.scale` で0.92倍**(`FOE_ROW_SCALE`)。`pivot_offset` を中心に置き `position`/`size` は変えないため、座標の問い合わせ・ドラッグの当たり判定は従来のまま
- **選択中の枠は水色、守護の枠は真鍮色**と系統を分ける
- **「反転」ボタンは選んだ駒のすぐ下**(`_flip_button_position()`、高さ `FLIP_BUTTON_SIZE`)。上へ出すと相手の駒へ重なる
- 総手数は `MatchState.turn_count` をそのまま使う(UI側で数えるとCPU同士・再生で0になる)
- **ログは結果パネルより後に `add_child()`**(終局後も上から開けるように)。エモートのUIはさらに後なので終局後は隠す

## 4.0.2 操作

- **詳細のホバー**: `CardDetailPanel` を `interactive = false` で使う(語のボタンと実演を持たないため、外れたら消える形が成立する)。幅340px(`compact_width`)。ホバーの受け口は `_on_view_hovered()` / `_on_view_left()` という関数にし、その時点の `_detail` を読む(`_detail` は `_build()` の途中で作るため、生成時に束ねると空の参照を掴む)
- **攻撃の予測**は `MatchState.combat_preview()`(盤面を変えずに計算。判定の順序は `_resolve_unit_combat()` と同じ:硝子→毒砂)が返し、`CardView.preview_health` へ出す。攻撃側は狙える相手が複数だと定まらないため**最も自分が削られる組**を出し、指している相手(`hover_target`)がある間だけその1組に置き換える。切り替えは相手の駒の `hovered`/`mouse_exited` と情報帯の `mouse_entered`/`mouse_exited` から。Godotはドラッグ中も enter/exit を出すため経路を分けない
- **ドラッグ**: `CardView._get_drag_data()` / `_drop_data()`、枠側は `drop_handler`(Callable)。手札は放されたら押して選ぶ経路と同じ `_play_selected()` へ合流(設置効果の対象選択もそのまま働く)。攻撃は `draggable` な自分の駒の `drag_started` で押したのと同じ選択状態を作り、相手の駒(`on_foe_slot_drop`)か HP帯(`on_face_drop`)で `_attack()` へ合流
- **タッチのゆらぎ吸収(`PressTracker`)**: 8px の許容マージン(`SLOP_MARGIN`)。`InputEventScreenTouch` も受ける
- **設置効果の対象選択**は `CardMatchSelection.TARGETING`。枠まで決めた時点で止め、相手の駒を押すと `play_card()` の `target` へ渡す。相手の場が空ならそのまま出す。案内は行動の列へ出す(盤面へ重ねると対象の駒を隠す)
- **対局の入口**: `Main._request_battle()` が導線を `Callable` として控え、デッキ選択画面(`CardDeckListScreen` の PICK)で選ばれたら `CardDeckSave.set_selected_index()` を書いてから呼ぶ。保存デッキが無いときだけ選択画面を挟まない。CPU戦は `start_cpu_match()` → `Timer`(`CPU_THINK_SECONDS`)→ `CardCpuStrategy.choose_action()` を1手ずつ

## 4.0.3 演出の仕組み

**ロジックは演出を待たない。**`MatchState` は即座に解決し、演出は結果を後から見せる(演出の完了へ依存させると再生・観戦・CPUの連続着手が尺に縛られる)。

- **砂の演出は2種類のシグナルで受ける**: 被ダメージ `unit_damaged` → `play_shatter()`(砕けて散る・赤)、ターン終了 `unit_ticked` → `play_drop()`(下へ流れる・琥珀)。相乗りさせない
- **攻撃**は `CardView.play_strike()`(1本の `Tween`、駒は上端を支点に振れる `_strike_pivot`。`pivot_offset` は回転と拡縮の両方に効くため描画側で変換)。防御側は当たった瞬間に `play_shatter()` + 小さな揺れ + **攻撃力が1以上なら `play_counter()`**(台座正面の紋章を攻撃側へ突き出す。向きは `CardViewStrike` の `side_x` と同じ符号)。`CardMatchStrike.capture()` が**適用前に**防御側のユニットと攻撃力を控える(適用後は消えている可能性がある)
- **揺れ(`CardMatchShake`)**: `bind()` した卓と場の駒だけ。基準位置を控えて `base + offset` を書く(毎フレーム足すと累積する)ため、毎ターン並べ替わる手札は対象にできない。強さは攻撃力から、上書きは大きいほう
- **反転**は `CardFlipBeam.play_flip(self, target_side, slot, actor_side)`。通常の反転は持ち主=手を出した側だが、反転権(`flip_right_used(actor_side, target_side, slot)`)では別々の値になりうるため第4引数で向きを渡す。届いたら `view.play_flip()` + 銘板の `play_spark()`
- **光の筋(`CardFlipBeam`)は `_beams` の配列**で同時に何本でも出せる。進捗は Dictionary の要素に置く(ラムダは外側のローカル変数を値でキャプチャする。11章)。**残っているのは通常の反転とドローの山札→手札だけ**
- **`CardMatchEffects` は `MatchState` のシグナル(`unit_played` / `unit_destroyed` / `unit_shielded` / `cards_drawn` / `fatigue_damage` / `effect_drawn` / `unit_returned`)だけを見る**。攻撃の演出中のぶんは `_defer()` で当たる瞬間まで持ち越し、`CardMatchStrike._on_impact()` が `effects.flush()` / `sound.flush()` / `effect_strike.flush()` を呼ぶ
- 破壊は「絵を縦に3つへ割って左右へ落とす」。硝子の割れは `MatchState` が受ける前の `glass_intact` を控えて消えたときだけ `unit_shielded` を出す(与ダメージ0では判別できない)

**紋章の演出(`effect_struck` / `effect_struck_many`)**

- `CardEffectResolver._apply()` は、対象が単体(`ENEMY_UNIT` / `ALLY_UNIT` / 相手プレイヤー)なら `effect_struck`、相手全体の打撃(`ALL_ENEMY_UNITS` × `DAMAGE_UNIT`/`DROP_SAND`)と味方全体の恵与(`ALL_ALLY_UNITS` × `ADD_TOTAL`/`ADD_ATTACK`/`DROP_SAND`/`GRANT_KEYWORD`)なら `effect_struck_many`(`targets: Array`)を、**状態を変更する直前に同期的に**発行する。`EmblemStrikeFx` は `play()`(単体)と `play_many()`(複数)を持ち、進捗は全飛翔で共有する
- **型(`style: EffectVisualStyle`)は `_apply()` の分岐が決める**: `DAMAGE_UNIT` / `DESTROY_UNIT` / 相手への `DAMAGE_PLAYER` / `DAMAGE_PLAYER_PER_ENEMY_UNIT` = `STRIKE`、`ADD_TOTAL` / `ADD_ATTACK` / `GRANT_KEYWORD` / 自分への `HEAL_PLAYER` = `DESCEND`、`SILENCE` = `DRAIN`、`SWAP_STATS` = `SPIN`(届いたら対象の `play_flip()`)、`RETURN_TO_HAND` = `RECALL`、`INVERT_PLAYER_HP` = `SPIN` を自分のHPバーへ、出どころが `SPELL`/`DEATH` の `DRAW` = `PULSE`(飛ばずにその場で光の輪)、`SUMMON` = 置く先の空き枠へ `DESCEND`。型ごとの尺・弧・色・輪は `EmblemStrikeFx` が持つ。**盤面を揺らすのは `STRIKE` だけ**(被ダメージが無ければ既定値4)
- **出どころ(`origin: EffectOrigin`)**は `resolve()` の入口で1度だけ決める: `_slot_of()` が枠を返せば `UNIT`(駒の中心から即座に)、`hint` に `death_slot` があれば `DEATH`(台座の銘板の位置に `LINGER` の間残ってから飛ぶ)、それ以外は `SPELL`(自分の情報帯の中心で `RISE` の間浮き上がってから飛ぶ)。対象の解決に使う `from` は演出の出どころとは分けて持つ(`DEATH` で砕けた枠に差し替えると `ALLY_UNIT` の除外や `SELF` が空の枠を指す)
- **受け口は `CardMatchEffectStrike.on_effect_struck*()`**。ここで `_armed = true` にしてから Tween を組む(yieldしないので、直後の状態変更が出す `unit_damaged` の時点で armed 済み)。`CardMatchStrike.on_unit_damaged()` / `on_unit_ticked()` は**先に `effect_strike.busy()` を見て** `hold_damage()` / `hold_tick()` へ渡す(`unit_damaged` の受け口は `_strike` の1箇所のまま、どちらの進行役が持っているかで振り分ける)。`unit_destroyed` / `unit_shielded` は `_defer()` が `strike_busy()`(両方の busy)を見て自動的に持ち越す
- **余砂は崩落を先に見せてから銘板が飛ぶ**。`_destroy_unit()` は `_fire(ON_DEATH)` → `unit_destroyed` の順のため、`CardMatchEffects._on_unit_destroyed()` は `effect_strike.is_death_origin()` なら持ち越さず即座に `play_break()`。**攻撃の演出中に死んだ場合は飛ぶこと自体を着弾まで持ち越す**(`_pending` に積み、`_on_impact()` の `effect_strike.flush()` で出す。この間も `busy()` は真)
- `RECALL` は `MatchState.unit_returned` を `_defer()` で受け、着弾の瞬間に `view.play_recall(card, hand_center(side))`
- **`effect_drawn(source_side, source_slot, count)`** は駒が盤面上にあるときだけ発行し、`play_spark()`(紋章の周りの光の輪)を呼ぶ。armed/持ち越しは持たない(タイミングのズレが実害にならない)
- `EmblemStrikeFx.impact` で演出をまとめて出し、`finished` で `_screen.on_strike_finished()`(`refresh()` を含む)。`_finish_action()` は `_strike.play()` に加えて `_effect_strike.busy()` も見る

## 4.0.4 カード詳細と能力の実演

- `CardDetailPanel` はキーワードを名前と説明の両方で出し、`SUMMON` を持つカードには出るトークンの名前・総量・効果を1行添える。`interactive`(既定 true)のときだけ語のボタンと `CardEffectPreview` を持つ(4.3節)
- **実演はカードごとではなく語彙ごとに台本(`Script` enum)を持つ**。`show_card()` が「named/plain キーワード → `ON_FLIP` → `effects` の `EffectType`」の順に並びを組み、能力の無いカードには基本の砂の動き。`show_demo()` は語を直接指定(辞書用)
- **台本は「何が起きるか」だけを書き、「いつ」は `_stage()` が entry の `trigger` から前へ付ける**(`stage["trigger_note"]`)。トリガーを持たない実演は `stage["note"]` へ完成した文。怠ると余砂のカードが「場に出したとき、…」と嘘を言う
- 台本は「時刻 → 盤面の状態」の純粋な関数で、駒は `CardView` を流用せず `InkFigure`(紙のインクの図版。`UiPaint` と同じ static で第1引数に `CanvasItem`)で簡略に描く。**部品の組み合わせだけで図版を組める状態を保つ**。下の部屋の砂は台形(三角だと浮いて見える)。基本の砂は1粒ずつ落とし、省略は「…」
- `CardEffectDemoKeyword` は扱わない語に空の Dictionary を返させる(既定の盤面を返すと台本が無いことに気づけない)

## 4.0.5 デッキ編集・デッキ一覧

- **2カラム**(`GRID_RECT` / `SIDE_RECT`)。高さは `ScreenHeader.CONTENT_TOP` / `CONTENT_HEIGHT` から取り、画面ごとに数えない
- 絞り込みと検索は `CardDeckFilter` / `CardDeckFilterModal` が `matches(card)` として合成し、画面は `changed` を受けて並べ直す
- **`CardDeckShelf` は1つの `Control` が30枠を `_draw()` で描き、当たり判定を矩形の表として持つ**(30個のノードだと1枚動かすたびに生成と破棄が走る)。枠の数は `MatchState.DECK_SIZE` から実行時に読む(横 `COLUMNS`=6)。空き枠も枠として描き当たり判定にも積む。バッジ半径は `clampf(art_w * 0.20, 8, 13)`。**共有のデッキ表(`CardDeckSheet`)も同じ棚**(`columns=10` / `readonly=true`)
- 詳細は `interactive = false` で幅400px、`CardDetailPanel.place_near()` で置く(`MOUSE_FILTER_IGNORE` でホバーを奪わない)
- 一覧のカードは `CardView.badge` で「2/2」。保存は30枚ちょうどのときだけ。編集画面は必ず一覧から `open(index)`(-1は新規)。デッキ名の入力欄は編成中の欄の上端
- **ボタンの既定の文字色はテーマ側でオフホワイト**(`main_theme.tres`。指定を書き忘れた画面だけ黒い文字になる状態を無くすため。`font_hover_color` だけ暗いまま)
- デッキ一覧・対局前の選択は `CardDeckListScreen` 1つが `Mode`(MANAGE / PICK)で兼ねる(4.5節)

## 4.0.6 シーン構成

```
Main
├── TitleScreen              # 起動して最初に出る
├── HomeScreen               # 下部5タブ
├── ReplayListScreen
├── AccountScreen
│   (対局画面を除く各画面は先頭の子として共通の ScreenHeader を持つ)
├── CardMatchScreen          # 対局・観戦・再生(コードで組み立てる)
├── CardDeckListScreen / CardDeckEditorScreen / CardListScreen
├── RuleScreen / KeywordDictScreen / ScreenGuideScreen
├── CardSoloMapScreen / CardRoomScreen / CardRandomMatchScreen / CardRankedMatchScreen
└── CardShopScreen / CardStatsScreen / CardLabScreen / CardRankScreen …
```

v1.0(位相制)の画面・クラス・`data/hourglasses/*.tres` は削除済み。`ReplayListScreen` は `seed` を持つ棋譜だけを一覧に出す。

- `TitleScreen`(`.tscn`):背景・ロゴ・開始の導線だけを持ち `start_requested` を出す。ロゴは `assets/title/logo.png` があればそれ、無ければ `TitleLogo`(コード描画)を `ResourceLoader.exists()` で分岐(`preload` だと無い時点でコンパイルが通らない)。背景も同様
- `SandTransition`:タイトル→ホーム専用。`Main` が1個生成して最前面へ置き `cover()` / `reveal()` を await。砂面は折れ線 + 頂点カラーのグラデーション(段ごとの単色だと縞に見える)。**アンカーは `anchor_right` / `anchor_bottom` へ直接代入**(11章)。砂の間は `mouse_filter = STOP`
- `Main._show_only()`:クロスフェード(`modulate:a` の Tween、実行中の Tween は kill してから作り直す、遷移中は透明な `ColorRect` で入力を塞ぐ)。タイトル→ホームだけ `_on_title_start_requested()` が「ロゴの演出 → `cover()` → `_show_only()` → `reveal()`」。`.tscn` を持たない画面は `_ready()` で生成して `_screens` へ
- BGMの切り替えも `_show_only()` から1箇所で(`_track_for()`。9章)

## 4.0.7 ホーム画面

- **タブは行いで分ける**(GameDesign.md 9章): たたかう=`BattleTab`(`.tscn`)/ そろえる=`DeckTab`(`.tscn`)/ きろく=`RecordTab` / おぼえる=`RulesTab` / つくる=`LabTab`。**`.tscn` を持つ2つはクラス名を変えない**(`home_screen.tscn` が instance しているため。画面に出る名前との食い違いは許容)。`SoloTab` は削除済み
- `BattleTab` の `.tscn` の縦並び(`Margin/VBox`)は使わず、`StatusLabel` だけを引き取る(`_take_over_status_label()`)。`.tscn` は書き換えない
- **入口はどのタブも `HomeTile`**(`Button` 継承。見出し・副題・紋章の透かし・砂時計を自前で描く。`text` へは入れない)。`.tscn` は書き換えず `_ready()` で同じ場所へ差し替える(`_to_tile()`)。**紋章の透かしは `CodedButtonStyle.inner_rect()` の中へ収め、比率で決めたうえで上限で止める**(額縁へ載り上がる / 大きな札で文字より主張する)。`primary`(塗りつぶした真鍮)と `badge`(未受取の数。下部タブへも同じ静的な描画関数で打つ)を引数で持つ
- 枠は `HomeFrame`(`content_panel.tres` のパネル + 真鍮のプレートの見出し)。**枠の右へ並べる行(ミッションの進捗)は `HomeFrame` が描く**(`Control._draw()` は子より背面なので、タブ側で描くと枠に隠れる)。`BattleTab._layout()` は復帰の帯(`ResumeBand`。縁を琥珀にして急ぐ用件だと分かるようにする)の有無どちらでも領域の中央へ置き直す
- `HomeScrim`(`Background` の直後):上=アカウント帯 / 中=タブ / 下=下部タブ を別々の濃さで落とす。**上下は中より濃く、対称に。3つの濃さは揃えて動かす**(片方だけ変えると重心が寄る)。アカウント帯の下端に中央が濃く左右で消える真鍮の細線
- 下部タブは幅を共通にし高さだけ変える(幅まで変えると `HBoxContainer` で他が押し出される)。非選択を下端へ沈め、選択中だけ帯の中央へ
- アカウント帯は `.tscn` の幅460pxを `_ready()` で右端まで伸ばし、残高を右へ寄せる(`ACCOUNT_BAR_RIGHT_INSET`)。ホームの残高だけ `CurrencyChip.scale_factor` で大きく、`height_override` で名札と揃える。`CurrencyChip` は単位を小さく数値を大きく別々に描き、紋章と文字のあいだに縦の細線
- 副題は画面の外で変わるため、タブを開くたびに `refresh()` で読み直す
- ホーム画面のタブは上端112pxをアカウント帯のために空け、残り(560px)の中央へ内容を置く
- **初回起動の判定は `UiState`**(`user://ui_state.json`)。`RulesTab` とそのタブボタンは `HomeScreen._ready()` がコードで生成(既存のボタンを `duplicate()`)

## 4.0.8 共通部品とUIクローム

- `ScreenHeader`(`scenes/screen_header.tscn`):外周余白24px・ヘッダー高88px・コンテンツ開始y=136をここで決める。タイトルの後ろに中央が濃く左右へ消える暗幕、下端に真鍮の細線
- `PressTracker`:押下→離した位置が要素内かで確定/取消(`CardView` / `ReplayListCard` / `ClickArea` が共用)
- `EmptyState`:空の一覧・待機の見せ方(印・見出し・1行)を1箇所へ
- `CodedButton`:ボタン生成の集約(画面ごとに `theme_override` を並べない)
- `resources/theme/content_panel.tres`:一覧・詳細・モーダルの汎用パネル
- **UIクロームはコード描画、3層に分ける**: `UiPalette`(色の単一情報源)/ `UiPaint`(static。**第1引数は `ci: RID`** で `RenderingServer.canvas_item_add_*` 系。`StyleBox._draw()` からは `CanvasItem.draw_*` を呼べないため)/ 各 `StyleBox` 派生と `Control._draw()` 側
  - 質感の要件: **金属の反射カーブは最低5ストップ**(上端のハイライト・中央で落とし・**下端に照り返し**)/ **グレインを alpha 0.05〜0.10 で重ねる**(`static var` で1度生成してtile)/ **枠は上が明るい凸、中央パネルは上が暗い凹**で向きを逆に
  - **意味を持たない小物の装飾(四隅のネジ・渦巻き)は付けない**。機能を示す形と紋章は積極的に付ける
  - **グループの個性は「外形」と「紋章」だけ。材質は全グループ共通**
- `CodedButtonStyle`(`extends StyleBox`):`State`(NORMAL/HOVER/PRESSED/DISABLED。`Variant` は組み込み型と衝突する)/ `Shape`(ROUNDED_RECT/CIRCLE/PILL/CHEVRON_LEFT)/ `Emblem` / `EmblemPlacement`(CENTER/UPPER/RIGHT_INSET/TOP_BADGE)。**枠・輪郭・面取りの太さは要素の大きさに合わせて細くする**(`_frame_thickness()` は「高さ56pxで12px / 34pxで5px」を通る直線。単純な短辺比例では小さい側が細くならない)。紋章とテキストの余白は `_get_content_margin()` が `shape` と `emblem_placement` から決める。`.tres` の1行目は `[gd_resource type="StyleBox" script_class="CodedButtonStyle" format=3]`

| グループ | Shape | Emblem | 使う場所 |
|---|---|---|---|
| `back_nav` | CHEVRON_LEFT | NONE | 共通ヘッダーの戻る |
| `nav_tab` | PILL | HOURGLASS(TOP_BADGE) | ホームの下部タブ |
| `wide_text` | ROUNDED_RECT | NONE | 既定の横長ボタン |
| `icon_square` | ROUNDED_RECT | NONE | 小さな正方形 |
| `primary_action` | ROUNDED_RECT | NONE | 塗りつぶした真鍮の面(`filled`) |
| `icon_menu` | ROUNDED_RECT | MENU(CENTER) | ホームのハンバーガー |
| `icon_discord` | ROUNDED_RECT | DISCORD(CENTER) | 設定メニューのDiscord導線 |

  - **`.tres` を増やすときは、それを読む `CodedButton` のグループ定数を必ず同時に足す**(読まれない `.tres` は使っているか判定できなくなる)
  - `UiPaint.Emblem` に未使用の紋章(`SWAP_ARROWS` / `BENCH` / `CHECK` / `ADVANCE` / `AWAKEN` / `HEAL` / `STRIKE`)が残るが、**enumの並びは `.tres` が整数で保存する保存データ**のため消さない(11章)
  - `EmblemPlacement.CENTER` の紋章は単位座標 ±0.55 程度に留める(±0.85 まで描くと額縁へ載り上がる)
  - 既存の `.tscn` が参照する `resources/theme/buttons/img_{グループ}_{state}.tres` はパスを維持したまま中身だけコードStyleBoxへ差し替えてある
- **見出しの書体は `UiFonts.display_font(fallback)`**(Zen Old Mincho のサブセット、約100KB)。タイトルロゴ・共通ヘッダー・`HomeFrame`・`primary` の `HomeTile` にだけ当てる。**返すフォントへ `fallbacks` を設定する**ため、サブセットに無い文字は静かに本文用へ戻る(豆腐にならない)。サブセットの更新手順は `assets/fonts/LICENSE_ZenOldMincho.txt` 末尾
- **背景イラストを持たない画面は `ScreenBackdrop`**(多段グラデーション + グレイン + 左右の落ち込み)。`Room`(無地 / 書庫 / 記録室 / 控えの間 / 帳場)を1行入れるだけ。部品は `RoomPaint`(static、第1引数 `CanvasItem`)。`WorkshopBackdrop` も同じ部品から組む。場所ごとの違いは壁の色味と造作だけ
- **UIに出す記号は共通フォントが字形を持つものだけ**。使える: `● ○ ◆ ■ ▲ ▼ → ← ↑ ↓ ★ ※ ×(U+00D7) −(U+2212) ＋`。使えない: `▸ ▶ ▷ ► ◀ ✓ ✔ ✕ ▪ ⌛`。エディタ実行では代替されて気づけないため、**`python tools/check_font_glyphs.py` を記号を足したら回す**
- **共通テーマはボタン3px・ラベル2pxの暗い縁取りを掛けている**。明るい面(紙)へ置く `Control` には `outline_size` を0にする(テーマ側の既定は変えない)
- **画像アセットを使う場合は原寸のアスペクト比を保った倍率だけで大きさを決め、`StyleBoxTexture` の `texture_margin_*`(9-slice)は使わない**(角だけ元ピクセルのまま残り縁が太くなる)。コード描画のStyleBoxにはこの制約は無い
