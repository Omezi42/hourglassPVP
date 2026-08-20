# 砂時計PvP 実装設計書(Architecture v1.0)

本書は `docs/GameDesign.md` の仕様を Godot 4.x / GDScript 2.0 でどう実装するかの方針をまとめる。
仕様(ルール・数値・UI)は GameDesign.md が唯一の情報源であり、本書はその実装設計のみを扱う。

---

## 1. 設計方針

- 砂時計は `Resource` としてデータ駆動で管理し、コード変更なしで新規追加できる形にする
- 効果は「トリガー×ターゲット×エフェクト」の組み合わせで表現し、エフェクト種別ごとにハンドラを1箇所に集約する
- 既存のエフェクト種別の組み合わせだけで新しい砂時計を作れる状態を維持する(「新効果そのものの追加」と「既存効果の組み合わせによる新駒追加」を分けて運用する)
- UI層・対局ロジック層・データ層を分離する。ロジック層はUIに依存しない

---

## 2. データ構造(Resource設計)

### 2.1 `HourglassData`(Resource, `.tres`)

砂時計の静的定義データ。Inspectorから編集可能。1砂時計 = 1 `.tres` ファイル。

| フィールド | 型 | 内容 |
|---|---|---|
| `id` | String | 一意識別子("sand", "sword" 等) |
| `display_name` | String | 表示名 |
| `fall_damage` | int | 落下ダメージ |
| `icon_upright` | Texture2D | 上向き時のイラスト |
| `icon_falling` | Texture2D | 落下中のイラスト |
| `icon_fallen` | Texture2D | 落ちきり時のイラスト |
| `effects` | Array[EffectData] | 追加効果のリスト(0件でも可、バニラ駒に対応) |

### 2.2 `EffectData`(Resource)

効果1件分のデータ。GameDesign.md 7章の語彙(トリガー/ターゲット/エフェクト)をそのままフィールド化する。

| フィールド | 型 | 内容 |
|---|---|---|
| `trigger` | Trigger (enum) | `ON_FLIP` / `WHILE_FALLING` / `ON_FALLEN` / `WHILE_FALLEN` |
| `target` | Target (enum) | `SELF` / `ADJACENT_LEFT` / `ADJACENT_RIGHT` / `OPPONENT_PLAYER` / `OWN_PLAYER` / `RANDOM_ALLY` / `OPPONENT_MIRROR` |
| `effect_type` | EffectType (enum) | `DAMAGE` / `DAMAGE_REDUCTION` / `LOCK` / `FORCE_ADVANCE` / `RECOVER` / `COUNTER` / `SYNC_STATE` |
| `value` | int | ダメージ量・軽減量など汎用パラメータ |

新しい砂時計は既存 enum の組み合わせで `.tres` を1個作るだけで追加でき、コード変更を必要としない。
既存の語彙で表現できない効果が必要になった場合のみ、`EffectType` に新しい値と対応するハンドラを追加する(この場合はGameDesign.mdへの追記提案を先に行う)。

### 2.3 `HourglassInstance`

対局中のみ存在する実行時インスタンス。静的データ(`HourglassData`)と可変状態(現在の状態)を分離する。

| フィールド | 型 | 内容 |
|---|---|---|
| `data` | HourglassData | 参照する静的データ |
| `state` | HourglassState (enum) | `UPRIGHT` / `FALLING` / `FALLEN` |

---

## 3. ロジック層

UIに依存しない、対局ルールそのものを扱う層。

### 3.1 `GameState`

対局中の唯一の真実(single source of truth)を保持する。

- 両プレイヤーのHP
- 手番情報
- 各スロット(相手左中右・自分左中右・控え×2×2)の `HourglassInstance`
- 状態変化時にシグナルを発行する(`hp_changed`, `hourglass_state_changed`, `hourglass_moved` 等)
- 反転・移動・交代・ターン経過の処理を提供する。位置による特性は「左マス=交代の入口」のみで、中央・右に固有のダメージ補正はない(GameDesign.md 5章)
- **【フェーズ17 V-1 実装済み】** 行動(反転/移動/交代/パス)は指した瞬間に盤面へ適用せず、
  `pending_action`(Dictionary、空なら未設定=パス)として保持する。実際の適用は
  `advance_and_end_turn()`の中で行う(GameDesign.md 2章・4.4)。`OnlineMatch.apply()`は
  `flip`/`move`/`swap_in`/`pass`について`set_pending_action()`を呼ぶだけになり、盤面を直接
  変更しない(`surrender`のみ従来どおり即座に`surrender()`を呼ぶ。盤面を変えずに終局させる
  性質のため予約の対象にならない)。これにより「apply()→advance_and_end_turn()」という
  既存の呼び出しの対(自分の手・オンライン相手の手・CPUの手・リプレイの巻き戻し・観戦の
  追いつき、の5経路すべて)を変えずに、解決タイミングだけをターン終了時へ移せている
- **【フェーズ21 Z-1 実装済み】** `advance_and_end_turn()`の処理順序は、
  `pending_action`を取り出す→自分の場を左→中央→右の順に1マスずつ解決→相手の駒への反転が
  設定されていればそれを解決→`effect_resolver.resolve_turn_tick()`→`current_turn`を交代→
  `turn_started`を発行。1マスの解決は「そのマスに設定された行動を適用する→**続けて必ず
  `advance_slot()`で1段階進行させる**」の2段で、行動の有無で進行の有無は変わらない
  (GameDesign.md 2章)。移動は2マスに関わるが、`move()`による入れ替え自体は**番号の若い方の
  マスの解決時に1度だけ**行い、その後そのマスを進行させる。もう一方のマスは自分の解決順が
  来たときに通常どおり進行するため、結果として関与2マスの駒がそれぞれ1回ずつ進行する
  (`_own_slot_kinds()`が`move`を若い方のマスにだけ登録することでこれを表現しており、
  以前あった「解決済みとして読み飛ばす」処理は不要になった)。
  フェーズ17 V-1では「行動を設定したマスは進行しない」方式だったが、自己対戦による
  バランス検証で、自陣への反転だけがコストを負い相手への反転が無償という非対称を生み、
  対局の12.8%が膠着することが判明したため、この条項ごと削除した(GameDesign.md 2章の経緯を参照)
- **【フェーズ17 V-1 実装済み】** 解決の区切りを`resolution_step_started(side, positions, kind)`
  シグナルで通知する。`kind`は`"advance"`(進行する)/`"idle"`(既に落ちきりで何も起きない)/
  `"flip"`/`"move"`/`"swap_in"`のいずれかで、`positions`は対象マス(移動のみ2個)。
  1マス分の解決を始める直前に発行されるため、UI層(`MatchTurnResolver`)はこれを区切りとして
  「どのマスへズームし、続くどの状態変化・ダメージがそのマスの結果なのか」を対応付けられる。
  GameStateはこのシグナルを発行するだけで、演出の存在を一切知らない
- 初期HP(`INITIAL_HP`)は30(GameDesign.md 3章)。UI層は`PlayerStatusBar`がこの定数を
  `hp_bar.max_value`・HP数値・残量による色分けの基準として参照するため、値を変えても
  シーン側の調整は要らない
- **【フェーズ19 X-1 実装済み】** 対局開始時の初期状態は場の位置ごとに異なる(GameDesign.md 2章・
  5章)。`START_STATES`(`BoardPosition`順に`UPRIGHT`/`FALLING`/`FALLEN`)を`GameState`が
  constとして持ち、`start_match()`が`_build_instances()`へ渡して場の3マスにのみ適用する
  (控えは従来どおり全て`UPRIGHT`。交代で場へ出る駒も`swap_in()`が`UPRIGHT`にする既存仕様のまま
  変更していない)。初期状態は`HourglassInstance`の生成時に代入するだけで、`advance_slot()`を
  経由しないため**右マスが`FALLEN`で始まっても落下ダメージは発生しない**(落下ダメージは
  「`FALLEN`へ到達した瞬間」に入るものであり、初期状態としての`FALLEN`は到達ではないため)。
  `advance_and_end_turn()`は対局開始直後には一度も呼ばれないため、最初の1手が指されるまで
  この初期状態がそのまま保たれる。継続効果(`WHILE_FALLING`/`WHILE_FALLEN`)は
  `resolve_turn_tick()`経由でしか回らないため、開始直後に勝手に発動することはなく、
  最初の手番終了時から通常どおり評価される
- **【フェーズ18 W-1】** 決着の要因を`end_reason`(`EndReason` enum: `HP_DEPLETED`/`TIMEOUT`/
  `SURRENDER`)として保持する。`match_ended(winner)`のシグネチャは変えず、UI層が終局後に
  `state.end_reason`を読んで結果パネル・ログの文言を出し分ける(GameDesign.md 3章「何で決着したか
  を1行で明示する」)。`force_match_end(winner, reason)`に既定引数を足し、持ち時間切れ=`TIMEOUT`、
  `surrender()`経由=`SURRENDER`、HPが0になった場合=`HP_DEPLETED`を記録する。決着を生んだ駒
  (落ちきった砂時計)の特定は`GameState`の責務とせず、既にダメージの発生源を追えているUI層
  (`MatchScreen._pop_fall_source()`)の情報をそのまま使う

### 3.2 `EffectResolver`

`EffectData` の評価と適用を1箇所に集約するクラス。

- トリガー発火(反転時/落下中/落ちきり時/落ちきり中)のたびに、対象となる `HourglassInstance` の `effects` を走査する
- `effect_type` ごとの処理関数を持つ対応表(dictionary的な分岐)を持ち、新しいエフェクト種別を追加する際はここに1エントリ追加するだけで済む構造にする
- `target` の解決(自分自身/隣接/相手プレイヤー/自分プレイヤー/味方ランダム/正面)もここで行う

UIは `GameState` のシグナルを購読して表示を更新するだけとし、ロジックを持たない。

---

## 4. シーン構成

責務を小さく分け、UI・ロジック・データを分離する。

```
Main
├── HomeScreen             # 起点となるホーム画面。下部2ボタンで機能を切り替える
│   ├── BottomNav           # 「デッキ」「バトル」の2ボタン(選択中は拡大表示)
│   ├── DeckTab              # デッキ編集ボタン + 砂時計一覧/ショップボタン
│   └── BattleTab            # ランダムマッチ/ルームマッチの大型ボタン
├── DeckListScreen         # 保存済みデッキの一覧(横長カードを横2列)・編集/入れ替え/削除/新規作成
├── DeckEditorScreen       # 1デッキの編成(左右2カラム、ドラッグ&ドロップ)・詳細パネル・保存
├── HourglassListScreen    # 全砂時計の一覧(未保有含む)・詳細パネル
├── ReplayListScreen       # 保存済みリプレイの一覧(オンライン/CPU戦をマージ)
├── BattleDeckPickerScreen # ランダムマッチ/ルーム作成/CPU戦の開始前に挟む、使用デッキ選択画面
│   (上記5画面はいずれも先頭の子として共通の ScreenHeader を持つ)
└── MatchScreen             # 盤面を挟んだ点対称レイアウト(GameDesign.md 9章)。配置フェーズ→対局フェーズを1画面で連続させる
    ├── TopBar                # 上段:左にHourglassSlotStrip(相手)、右にPlayerStatusBar(相手)
    ├── BoardArea             # 盤面の表示枠。clip_contents=trueでズーム時のはみ出しを切る
    │   └── BoardCamera        # ズーム/パンの対象(scale・positionをTweenする)
    │       └── GameBoard      # 盤面表示(場の3+3マスのみ。控えはTop/BottomBarへ撤去済み)
    │           ├── BoardRow(相手) → HourglassSlot ×3(左・中央・右)
    │           └── BoardRow(自分) → HourglassSlot ×3(左・中央・右)
    ├── BottomBar             # 下段:左にPlayerStatusBar(自分)、右にHourglassSlotStrip(自分)
    │   └── BottomMiddle       # 中央。モードごとに排他表示(下記3つのうち常に1つだけ)
    │       ├── PlacementControls # 配置フェーズ:「対局開始」ボタン
    │       ├── ReplayControls    # リプレイ再生:先頭へ/1手戻る/再生/1手進む/最後へ+手数
    │       └── MatchMenuControls # 対局中:「ターン終了」「ログ」「投了」
    ├── ActionMenu          # 選択中の駒の直下にポップアップし「反転/移動/交代」を表示
    ├── ResultOverlay       # 対局終了時に全面へ重なる結果パネル(勝敗・最終HP・総手数・ホームへ)
    └── MatchPlacementController # 配置フェーズの状態・操作(子ノード、UIシーンは持たない)
```

- `Main`:画面切り替え(`_show_only()`)はハードカットではなくクロスフェードで行う。表示中の画面と次の画面の`modulate:a`をTweenで補間し、実行中のTweenは新しい遷移の開始時に必ずkillしてから作り直すことで連打・割り込みに耐える。遷移中は透明な`ColorRect`ブロッカーを最前面に重ねて全画面の入力を塞ぐ
- `HourglassSlot`:1マス分の表示。`HourglassInstance` の状態を受け取ってイラスト差し替え・ロック等のアイコンオーバーレイを行う
- `GameBoard`:`OpponentRow`/`OwnRow` は `GameBoard` 直下の子として絶対座標配置する(手番側の列を琥珀色の帯で光らせる `OpponentRowFrame`/`OwnRowFrame`(`Panel`)は、盤面が見づらいというユーザー指摘を受けて廃止した。旧構成では両`BoardRow`がこれらの`Panel`の子だったため、廃止時は行を`GameBoard`直下へ再親付けし、offsetを「旧フレームの位置+行のローカルoffset」から`GameBoard`ローカルのoffsetへ変換して見た目の位置を変えずに移設した)。手番の表示は `MatchScreen` 上部バーのテキスト(「先手/後手のターン」「あなたの番です」等)のみで行う。操作可否は `set_interactive()` で切り替え、`MatchScreen` が `GameBoard.set_interactive(_can_act())` を毎回の表示更新時に呼んで伝播させる。**控え(`OpponentBenchGroup`/`OwnBenchGroup`)はGameBoardから撤去済み**(GameDesign.md 9章「HPバーの横に5個分のスロット」)で、`GameBoard`は場の3+3マス(`opponent_row`/`own_row`)のみを扱う。`get_slot_rect()`/`_slot_at()`は`OPPONENT_BOARD`/`OWN_BOARD`のみに対応し、`ActionMenu.SelectionType.BENCH`は扱わない(控えの矩形取得は`HourglassSlotStrip.get_bench_slot_rect()`が担う)
- `HourglassSlotStrip`(`scenes/hourglass_slot_strip.tscn`/`scripts/ui/hourglass_slot_strip.gd`):片方のプレイヤーの砂時計5個をHPバー横にまとめて表示するコンポーネント(GameDesign.md 9章)。内部は`HourglassSlot`×5の`HBoxContainer`で、先頭`GameState.BOARD_SIZE`枠は場に出ている駒の参照専用「ゴースト」表示(`HourglassSlot.show_deployed()`。常に上向きイラストを固定表示し、バッジ・台座光は出さず`set_interactive(false)`で常時非操作にする)、続く`GameState.BENCH_SIZE`枠が実際の控え(既存の`set_bench_mode(true)`表示を流用し、押すと`bench_pressed(bench_index)`を発火する。`bench_index`はスロット配列上の`GameState.BOARD_SIZE`分のオフセットを差し引いた0/1で、そのまま`GameState.swap_in()`の`bench_index`引数と一致する)。`MatchScreen`は`OpponentSlotStrip`/`OwnSlotStrip`の2個を直接保持し、`refresh_view()`で`state.board[side]`/`state.bench[side]`を渡して`show_state()`を呼ぶ。相手側は交代アクションの導線が存在しないため、`_ready()`で`opponent_slot_strip.set_interactive(false)`を1度呼ぶだけで恒久的に非操作(ホバー無し)にしている
- `GameBoard` の座標系(横長レイアウトへの刷新):AI生成イラスト(`assets/ui/processed/board_panel_perspective.png`)への依存をやめ、テーブル面を `BoardTable`(`Control`、`_draw()`のみのコード描画、無地)へ置き換えた。ユーザー指示「盤面をもっと横長に、画面の横幅を広く使ってほしい」を受け、`GameBoard` の `custom_minimum_size` を縦長の`Vector2(299, 628)`から横長の`Vector2(1040, 480)`へ変更し、`OpponentRow`(奥列)/`OwnRow`(手前列)を上下ではなく横一列3個ずつに展開する構成にした。`GameBoard`/`BoardRow` は台座位置を絶対座標で扱うため引き続き `VBoxContainer`/`HBoxContainer` ではなく `Control` を使う。`BoardTable._draw()` は、上端(奥)をやや狭くした軽い台形(`TOP_INSET_RATIO = 0.07`)をポリゴンで塗り(`TABLE_FILL`)、琥珀色の枠線(`TABLE_BORDER`)、中央の横区切り線(`DIVIDER_RATIO = 0.5`の高さに台形の辺を線形補間して両端座標を求める)、二重リングの紋章、4隅の薄い装飾楕円(`CORNER_ORNAMENT_*`)を描く。全て無地の図形のみで、新規画像アセットは追加していない。`GameBoard` 内部の配置(`GameBoard`ローカル座標、左上原点、B-2/B-3で控え撤去後の値):`BoardTable`はテーブル領域全体(`left=10,top=10,right=850,bottom=470`)を占める。以前はテーブル左側に余白列(`x=10〜180`)を確保し相手・自分の控え(`OpponentBenchGroup`/`OwnBenchGroup`)を縦に配置していたが、GameDesign.md 9章の「HPバーの横に5個分のスロット」化に伴い控えを`TopBar`/`OwnBar`側の`HourglassSlotStrip`へ撤去したため、この余白列ごと廃止し`GameBoard`の`custom_minimum_size`を`Vector2(1040, 480)`から`Vector2(860, 480)`へ縮小、`BoardTable`/`OpponentRow`/`OwnRow`の`offset_left`/`offset_right`を左へ180px詰めた(各行の幅・`offset_top`/`offset_bottom`は変更していない)。`MatchScreen`側の`BoardArea`(`CenterContainer`)は変更していないため、`GameBoard`が縮小した分だけ左右均等に再センタリングされ、以前あった「控えのぶん右へ偏って見える」問題が解消された(非ヘッドレスで実測: `GameBoard.get_global_rect()`が`(210, 120)〜(1070, 600)`となり、`BoardArea`の左右マージンが210pxずつで一致することを確認済み)。左/中央/右の位置ラベル(旧`PositionRow`)はフェーズ11 K-3で完全撤去済み(下記参照)。`OpponentRow`(`760x195`)/`OwnRow`(`820x210`、奥列より一回り大きい)は、手番強調用の`Panel`(`OpponentRowFrame`/`OwnRowFrame`。盤面が見づらいためB-4で廃止)を介さず`GameBoard`の直接の子として配置し、それぞれ3個の`HourglassSlot`を、行に対する比率(`x_ratios = [0.18, 0.5, 0.82]`)で求めた中心座標を基準に絶対配置する(奥列のスロットサイズ`100x120`、手前列`124x150`)。台座の光表現は、テーブル面が無地(台座イラストなし)になったことに伴い`HourglassSlot._draw()`側の自前描画の光る台座を既定(表示)のまま使う方式に統一した(以前の「テーブル画像側に台座を描き、駒側は`set_pedestal_visible(false)`で消す」方式から変更。`game_board.gd`の`_ready()`から該当の`set_pedestal_visible(false)`呼び出しは削除済み)。これら一連の構造変更は、CLAUDE.mdの規約に従い`tools/`配下の一時ビルドスクリプト(`load()`せず`Control.new()`等でノードを組み立て→`owner`設定→`PackedScene.pack()`→`ResourceSaver.save()`)経由で`game_board.tscn`を再生成し、`match_screen.tscn`の`GameBoard`インスタンスの`custom_minimum_size`は既存の`godot_apply_patch.gd`(`set_property`)で更新して適用した(手動でのtscnテキスト編集は行っていない。一時ビルドスクリプトは適用後に削除済み)。**【フェーズ11 K-3 実装済み】** `PositionRow`(左/中央/右の3枚プレート、「左」の「交代の入口」ラベル含む)は`scenes/game_board.tscn`から完全に削除した(`tools/godot_apply_patch.gd`の`delete_node`op経由、適用後`.bak`は削除)。削除に伴うレイアウト調整(周辺オフセットの再計算等)は不要だった。`BoardTable._draw()`が描く中央の区切り線・紋章は`PositionRow`とは独立したコード描画のため影響を受けていない。「左マスが交代の入口」という情報は、`HourglassSlotStrip`の控えを選択した瞬間に`GameBoard`の自分の場・左マスを`MoveTargetFrame`と同様の点滅ハイライトで示す方式へ置き換えた。実装は`MatchScreen._select()`(`scripts/ui/match_screen.gd`)に集約し、`selection_type == ActionMenu.SelectionType.BENCH`のとき`game_board.show_move_targets([GameState.BoardPosition.LEFT])`を呼び、それ以外では`game_board.clear_move_targets()`を呼ぶ(新規メソッドは追加せず、既存の移動先候補ハイライトAPIをそのまま再利用した)。選択解除時は既存の`_clear_selection()`内の`clear_move_targets()`呼び出しがそのまま効く。
- クリック可能な各コンポーネント(`HourglassSlot`/`HourglassCard`/`DeckListCard`/`DeckSlot`/`ReplayListCard`/`ClickArea`)は、押下確定の判定を `PressTracker`(RefCounted、押下→離した位置が要素内かどうかで確定/取消を返す)で共通化し、ホバー・押下の見た目アニメーションは `ClickArea` の静的関数(`animate_hover`/`animate_press`)を呼び出して統一する
- `ActionMenu`:GameDesign.md 4.2 の操作フロー(駒を選択→アクション表示→選択)に対応する。レイアウトコンテナには入れず `MatchScreen` 直下の浮動ノードとして持ち、選択された駒の画面座標を取得してその近くへ移動させたうえで表示する。矩形の取得元は選択種別で分岐し、`OWN_BOARD`/`OPPONENT_BOARD`は`GameBoard.get_slot_rect()`、`BENCH`は`own_slot_strip.get_bench_slot_rect()`から取得する。表示位置は、`OWN_BOARD`と`BENCH`(いずれも画面下寄りの`OwnRow`/`OwnSlotStrip`)は選択駒の**上**に、`OPPONENT_BOARD`は選択駒の**下**に出す(下に出す方が画面内に収まるため)
- `MatchScreen` の `BottomBar/BottomMiddle`(`CenterContainer`)は、**配置フェーズ・リプレイ再生・対局中の3モードで排他的に使う**。配置フェーズは`PlacementControls`(「対局開始」)、リプレイ再生は`ReplayControls`(再生コントロール)、対局中は`MatchMenuControls`(「ログ」「投了」)を表示する。3つは同時に表示されることがないため衝突しない。ログ/投了を画面左上へ絶対座標で置いていた頃は、相手の`HourglassSlotStrip`の先頭スロットと重なって駒が隠れていた(GameDesign.md 9章)
- `ResultOverlay`:対局終了時に `MatchScreen` 全体へ重ねる結果パネル。暗幕(`ColorRect`)でクリックを受け止めることで、終局後に盤面が操作されるのを防ぐ。「ホームへ」ボタンは `MatchScreen.back_pressed` を発火し、遷移先の判断は既存どおり `Main` 側が持つ。総手数は `MatchScreen` が1手適用ごとに数えて保持する(`GameState` は手数を持たず、盤面の状態のみを扱う責務のため)。パネル内のボタンは「ログ」「ホームへ」の2つを`ButtonRow`へ横並びに置く(フェーズ18 W-3)。「ログ」は`MatchBattleLog.set_open(true)`を呼ぶだけで、`LogPanel`は`.tscn`上で`ResultOverlay`より後ろの子=手前に描画されるため、z順の指定を追加せずそのまま結果パネルの上へ重なる。詳細テキストは「最終HP/総手数」に加えて決着の要因を1行持つ(GameDesign.md 3章)
- `MatchTurnResolver`の決着時の扱い(フェーズ18 W-2):HPを0にしたダメージイベントを再生した時点で**残りのイベントを破棄して打ち切る**(決着後のマスの解決は勝敗に影響しないため。GameDesign.md 3章)。打ち切る際はスポットライトを解除せず、`MatchResultPresenter.play_finishing_blow()`が原因の駒を照らしたまま「決着」表示を重ね、`FINISH_HOLD`の間を置く。これに伴い`MatchScreen._advance_turn_and_refresh()`は「決着したら`_turn_resolver.clear()`で演出を捨てる」分岐をやめ、**イベントが1件でもあれば決着していても再生する**。`MatchScreen._on_match_ended()`は、演出のキャプチャ中(`is_capturing()`)または再生中(`resolving`)に発火した場合は勝者を`_pending_result_winner`へ保留し、`on_turn_resolution_finished()`が演出の完了後に`_show_result()`を呼ぶ。投了・持ち時間切れは演出キューを伴わないため、従来どおり即座に結果パネルを出す
- `MatchResultPresenter`(フェーズ18 W-2/W-3):結果パネルの登場演出に加えて、**勝敗テキストの組み立てそのもの**(`show_for(winner)`)を持つ。決め手の1行が加わって視点の書き分けと一体で扱う必要が出たことと、`match_screen.gd`が1000行の上限に迫っていたことから移した(`MatchScreen._show_result()`は`show_for()`を呼ぶだけの1行)。視点の判定に必要な情報は`MatchScreen.is_self_view_fixed()`/`self_side()`/`move_count()`として公開している。決着を生んだ一撃は`note_hp_change()`が`_on_hp_changed`から毎回受け取る値のうち「HPを0にしたダメージ」だけを記録し、`format_finishing_blow()`が結果パネルの「決め手」1行を組み立てる(落ちきりの駒名+ダメージ / 効果によるダメージ / 持ち時間切れ / 投了)。**対局ログの決着行(`MatchBattleLog.record_match_end()`)も`show_for()`の冒頭で積む**。`match_ended`の発火時点で積むと、その後に解決演出が積む行の下へ埋もれてしまうため
- 終局後の上部バーの手番表示は「対局終了」に切り替える(`MatchScreen._refresh_turn_label()`の冒頭で`state.is_match_over()`を見る)。結果パネルの外側に「相手の手を待っています」が残ると、対局がまだ続いているように見えるため
- `MatchActionPresenter`(`scripts/ui/match_action_presenter.gd`、`_screen`参照を持つRefCounted):反転/移動/交代が適用された直後の演出を担う(GameDesign.md 9章)。`MatchTurnResolver`が「ターン終了時に自動で起きたこと」を見せるのに対し、こちらは「プレイヤーが指した手そのもの」を見せる。処理順序は(1)盤面を新しい状態へ同期、(2)対象マスへスポットライト、(3)`MatchBattleLog.format_action()`が組み立てた文言(対局ログと同一)を`MatchEventCaption`で該当駒の近くへフロート表示、(4)移動/交代は駒を滑り込ませる、(5)短い間を置いてスポットライトを解除。`presenting`フラグは`MatchTurnResolver.resolving`と同じ扱いで`MatchScreen._can_act()`/`_process()`が参照し、演出中の盤面操作と持ち時間の消費を止める。駒の滑り込みは`GameState`側の位置を一切動かさず、既に新しい位置へ反映済みの`HourglassSlot`について`VisualRoot.position`を「移動元とのオフセット」から`_rest_position`へ戻すTween(`HourglassSlot.play_slide_in()`)だけで表現する(O-6で入れた「演出の前に必ず一度`refresh_view()`で同期する」ルールと競合させないため)。行動の時点で対局が終了した場合(`state.is_match_over()`)と、リプレイの巻き戻し・観戦の追いつきループ中(`MatchReplayController.catching_up`)は演出を丸ごとスキップする。**【フェーズ17 V-2】** 行動がターン終了時まで遅延して適用されるようになったため、この演出の呼び出し元は「行動を指した直後」から「`MatchTurnResolver`が該当マスの解決ステップを再生する時」へ移った。`play(action)`が持っていたスポットライト・待ちの責務は`MatchTurnResolver`側へ移し、こちらは`play_flip()`/`play_move()`/`play_swap_in()`という「1ステップ分の見た目」を提供する部品になっている(実況テキストの文言生成・滑り込み・光の筋と持ち上げの中身は変更していない)
- 反転の演出は、移動/交代の滑り込みと同じ`MatchActionPresenter`が受け持つが、駒の位置が動かないため別の表現を使う(GameDesign.md 9章)。**行動した側の陣地から対象の駒へ向かって光の筋を伸ばす**のは`GameBoard`へ重ねた`FlipReachOverlay`(`scripts/ui/flip_reach_overlay.gd`、`Control`の`_draw()`のみのコード描画。`BoardTable`/`BarPanel`と同じ流儀で色は`UiPalette`、描画は`UiPaint`を経由する)が担い、始点・終点は`GameBoard.get_board_slot_rect()`で求めた画面座標をそのまま使う。**駒側の持ち上げ・着地**は`HourglassSlot.play_flip_lift()`が`VisualRoot`の`position`/`scale`だけを動かして表現し、`GameState`の状態と既存の`_animate_flip()`(アイコンの回転)には触らない。両者とも見た目専用のため、O-6で入れた「演出の前に必ず一度`refresh_view()`で同期する」ルールと競合しない
- `MatchBoardCamera`(`scripts/ui/match_board_camera.gd`、`_screen`参照を持つRefCounted):ターン終了時の解決演出で盤面だけをズーム/パンさせる(GameDesign.md 9章)。`MatchScreen`の`BoardArea`(`Control`、`clip_contents = true`)配下に置いた`BoardCamera`(`Control`)の`scale`と`position`をTweenするだけの薄い部品で、`GameBoard`側の座標系・レイアウトには一切触れない。`focus(rects)`は渡された矩形群(1マス、または移動で関与する2マス)の中心が`BoardArea`の中心へ来るように、`ZOOM_SCALE`倍で寄せる。`reset()`で等倍・原点へ戻す。**上下の`TopBar`/`BottomBar`は`BoardArea`の外にあるためズームの影響を受けない**(HPと砂時計スロットを常に画面内へ残すための構造)。`BoardCamera`は`GameBoard`の`custom_minimum_size`と同じ固定サイズを持ち、`BoardArea`の中央へ絶対座標で置く(`CenterContainer`のままだとコンテナがレイアウトのたびに`position`を上書きしてズームが戻ってしまうため、`BoardArea`は`CenterContainer`から素の`Control`へ変更した)
- ズーム中に画面座標を必要とする処理(実況テキストの表示位置・浮遊ダメージの飛び先・光の筋の始点/終点)は、`Control.get_global_rect()`が親の`scale`を反映しないため、`GameBoard.get_board_slot_rect()`側で`get_global_transform()`を掛けた矩形を返すようにしている。これにより既存の呼び出し側(`MatchActionPresenter`/`MatchEventCaption`/`MatchDamagePresenter`/`FlipReachOverlay`)を変更せずにズームへ追従する
- `MatchTurnResolver`は`resolution_step_started`を`{"kind": "step", ...}`としてキューへ積み、`play()`が(1)`MatchBoardCamera.focus()`で対象マスへ寄せる、(2)`kind`に応じて`MatchActionPresenter.play_flip()`/`play_move()`/`play_swap_in()`を呼ぶ、(3)続く状態変化・ダメージのイベントを従来どおり再生する、という順で1マスずつ処理する。**何も起きないマス(`kind == "idle"`)もズームの対象とし、間を置いてから次へ進む**(GameDesign.md 9章。「何も起きなかったこと」自体を見せるため)。全ステップの再生後に`MatchBoardCamera.reset()`で引きの画へ戻す
- 行動の実況・ログの文言(`MatchBattleLog.format_action()`)は、**自陣の駒を反転した場合は所属を書かない**(「先手が「ソード」を反転」)。相手の駒を反転した場合だけ「先手が後手の「ソード」を反転」と誰の駒かを明示する。同じ側を2度呼ぶ形が読みにくく、解決演出で大きく表示されるようになって目立つため。移動・交代の文言(「先手が「キング」を左→右へ移動」)と書式が揃う
- 予約マーク:`HourglassSlot.set_reservation(kind)`が、そのマスに設定された行動(反転/移動/交代)を示すバッジを駒の上に重ねる。`MatchScreen.refresh_view()`が`state.pending_action`から各マスの`kind`を求めて毎回同期するため、設定・設定し直し・解決後のクリアがすべて同じ経路で反映される
- 落下予告リング:`HourglassSlot.set_falling_warning(active, hostile)`が、次の解決で落ちきる駒へ脈動するリングを重ねる(GameDesign.md 9章)。判定は`BoardRow.refresh_falling_warnings(board_instances, hostile, suppressed_position)`が行い、状態が`FALLING`であることに加えて、**そのマスに反転が予約されていないこと**を条件とする(反転すると上向きへ戻ってから進行するため落下中で止まり、落ちきらない)。`suppressed_position`は`GameBoard.show_state()`が`state.pending_action`から陣営ごとに求めて渡す。移動・交代は駒の状態を変えないため予告に影響しない。行動が進行を止めなくなった(フェーズ21 Z-1)ことで、`FALLING`かつ反転の予約が無いマスは必ず落ちきるようになり、予告と実際に起きることが常に一致する
- 反転の演出(GameDesign.md 9章「反転はゲームの中心となる行動であるため、演出は他より作り込む」):`FlipReachOverlay`の着弾点に、中心の閃光・外へ広がる二重の輪・放射状の火花の3層を重ねる。駒側は`HourglassSlot.play_flip_lift()`が「沈み込み→持ち上げ→頂点で留まる→着地→潰れて弾む」の一連をつなぎ、あわせて足元へ台座と同じ扁平な楕円の衝撃波(`UiPaint.draw_ellipse_ring()`を新設)を着弾時と着地時の2回広げ、回転中は`icon.modulate`を1.0より明るい値へ振ってガラスと砂の反射を表す。**動かすプロパティは`VisualRoot.position:y`・`icon.scale:y`・`icon.modulate`に限る**(`icon.scale:x`と`rotation_degrees`は既存の`_animate_flip()`が、`VisualRoot.scale`はスポットライトが使っており、同じプロパティを複数のTweenで取り合うと点滅するため)。`_animate_flip()`の折り返し点の`scale:x`は0ではなく`FLIP_EDGE_SCALE`まで潰すに留め、持ち上がった駒が一瞬まるごと消えないようにする
- `MatchTurnResolver`は反転のステップだけ、行動を見せた後の間(`ACTION_HOLD`)を置かずに次のイベント(状態変化=アイコンの回転)へ進む。駒が持ち上がっている最中に回転が始まり、着地までが一続きの動きになる。反転が積む状態変化のうち最初の1件(=上向きへ戻ったこと)は`_suppress_state_event`によって実況にもログにも残さない(行動側が「…を反転」と伝えており、`format_state_event()`の「上向きへ進行」という語も実態に合わないため)。反転したマスは続けて進行する(フェーズ21 Z-1)ので、その後の「落下中へ進行」は通常どおり実況・記録される。`ACTION_HOLD`は移動/交代のときだけ使い、マスをまたぐ区切りではなく「行動を見せてから同じマスの進行を見せるまで」の間になったため0.6秒から0.3秒へ縮めた

- `GameBoard`:`OpponentRow`/`OwnRow` は `GameBoard` 直下の子として絶対座標配置する。手番の表示は `MatchScreen` 上部バーのテキストのみで行う。操作可否は `set_interactive()` で切り替え、`MatchScreen` が `GameBoard.set_interactive(_can_act())` を毎回の表示更新時に呼んで伝播させる。**控えはGameBoardから撤去済み**で、`GameBoard`は場の3+3マスのみを扱う
- `GameBoard` の座標系(横長レイアウトへの刷新):テーブル面を `BoardTable`(`Control`、`_draw()`のみのコード描画)へ置き換え。ユーザー指示を受け、`GameBoard` の `custom_minimum_size` を横長の`Vector2(860, 480)`へ変更。`BoardTable._draw()` は、上端(奥)をやや狭くした軽い台形をポリゴンで塗り、琥珀色の枠線、中央の横区切り線、二重リングの紋章、4隅の薄い装飾楕円を描く。`OpponentRow`(`760x195`)/`OwnRow`(`820x210`)は`GameBoard`の直接の子として配置し、それぞれ3個の`HourglassSlot`を、行に対する比率で求めた中心座標を基準に絶対配置する。
- クリック可能な各コンポーネントは、押下確定の判定を `PressTracker` で共通化し、ホバー・押下の見た目アニメーションは `ClickArea` の静的関数で統一する
- `ActionMenu`:GameDesign.md 4.2 の操作フローに対応。レイアウトコンテナには入れず `MatchScreen` 直下の浮動ノードとして持ち、選択された駒の画面座標を取得してその近くへ表示する
- `MatchScreen` の `BottomBar/BottomMiddle`(`CenterContainer`)は、**配置フェーズ・リプレイ再生・対局中の3モードで排他的に使う**
- `ResultOverlay`:対局終了時に `MatchScreen` 全体へ重ねる結果パネル。暗幕(`ColorRect`)でクリックを受け止めることで、終局後に盤面が操作されるのを防ぐ。詳細テキストは「最終HP/総手数」に加えて決着の要因を1行持つ
- `MatchTurnResolver`:HPを0にしたダメージイベントを再生した時点で**残りのイベントを破棄して打ち切る**。打ち切る際はスポットライトを解除せず、決着表示を重ねる
- `MatchResultPresenter`:結果パネルの登場演出に加えて、勝敗テキストの組み立てそのもの(`show_for(winner)`)を持つ。
- `MatchActionPresenter`:反転/移動/交代が適用された直後の演出を担う。処理順序は(1)盤面を新しい状態へ同期、(2)対象マスへスポットライト、(3)対局ログの文言表示、(4)移動/交代は駒を滑り込ませる、(5)短い間を置いてスポットライトを解除。
- `MatchBoardCamera`:ターン終了時の解決演出で盤面だけをズーム/パンさせる。
- `MatchReplayController`:リプレイ再生モードの棋譜保持と再生制御を`MatchScreen`から切り出したもの。
- `PlayerStatusBar`:1プレイヤー分のHPバー・HP数値・持ち時間をまとめた行。相手用・自分用の2つを `MatchScreen` の上部・下部にそれぞれ配置する。どちらの視点かは `MatchScreen` 側が決め、このシーン自体は「渡された値を表示するだけ」に留める
- `resources/theme/content_panel.tres`(`StyleBoxFlat`):対局画面の石のボードパネル(`board_panel.tres`)と同系統の質感を持つ、一覧・詳細・操作エリア向けの汎用コンテンツパネル。背景イラストの上に情報を置く各画面(デッキ一覧・デッキ編集・砂時計一覧・配置画面・リプレイ一覧等)の主要ブロックに共通適用する
- **UIクローム(ボタン・パネル枠・入力欄・棚板・名札等)はコード描画で作る**(GameDesign.md 9章)。以前は画面グループ単位のボタンシート画像を生成し `StyleBoxTexture` として割り当てていたが、品質管理のしやすさを理由に方針転換した。テキストは従来どおり画像・描画に焼き込まず `Button.text` をプロジェクト共通フォントで重ねる
- コード描画の実体は以下の3層に分ける。画面ごとに描画コードを書き散らさず、必ずこの共通層を経由させる
  - `scripts/ui/styles/ui_palette.gd`(`UiPalette`, `RefCounted`):プロジェクト全体のUI色の単一情報源。真鍮の明/中/暗、暗い下地、琥珀アクセント、無効時のグレー等をconstで持つ
  - `scripts/ui/styles/ui_paint.gd`(`UiPaint`, `RefCounted`):static関数だけの描画ユーティリティ。**第1引数は必ず `ci: RID`** とし `RenderingServer.canvas_item_add_*` 系で描く(`StyleBox._draw(to_canvas_item, rect)` からは `CanvasItem.draw_*` を呼べないため)。角丸矩形の頂点生成、多段階の縦グラデーション塗り、面取り(ベベル)、内側の落ち込み影、グレイン(ノイズ)重ねを提供する
  - 各`StyleBox`派生クラス(`CodedButtonStyle` 等)と、`Control._draw()`側(`BoardTable`/`BarPanel`/`HourglassSlot`)が、いずれも上記2つを呼んで描く
- コード描画で「無地の図形を置くだけ」にすると平坦でチープに見えるため、質感表現を必須要件として扱う。特に効くのは次の3点
  - **金属の反射カーブを最低5ストップで表現する**。上端付近に明るいハイライト帯、中央で落とし、**下端に照り返し(バウンス光)を入れる**。この下端の明るさが金属らしさの決め手であり、2色グラデーションでは出ない
  - **手続き的なグレイン(ノイズ)を薄く重ねる**(alpha 0.05〜0.10目安)。ノイズ画像は`static var`で1度だけ生成してキャッシュし、`canvas_item_add_texture_rect` の tile 指定で敷き詰める。フラットベクター感を消す最大の要因
  - **枠と中央パネルでグラデーションの向きを逆にする**(枠=上が明るい凸、中央パネル=上が暗い凹)。加えて中央パネル上端へ多重の落ち込み影を重ね、彫り込まれた構造として読ませる
- **意味を持たない小物の装飾(四隅のネジ/リベット、角の渦巻き・スクロール意匠)は付けない**。元の画像ボタンには存在したが、コード描画版で再現したところノイズに見えるとユーザーが判断し、完全撤去した。一方で、**機能を示す形と紋章は積極的に付ける**(次項)。両者の線引きは「そのボタンが何をするかを伝えているか」であり、伝えていない純粋な飾りは置かない
- **グループごとの個性は「外形の形」と「紋章」だけで表現し、材質は全グループ共通に保つ**。元の画像ボタンは「戻る=左向き矢印の形」「保存=チェックマーク」「反転/移動/交代=紋章入りの円形メダリオン」「タブ=砂時計の徽章付きピル」というように、形と紋章が機能を語る設計だった。全グループを同一の見た目へ統一した結果この個性が失われたため復元した。ただし材質(反射カーブ・グレイン・面取り・落ち込み影)をグループごとに変えることは禁止する。材質を共通に保つことが、個性を出しつつ全体が調和して見えるための条件である
- `CodedButtonStyle`(`scripts/ui/styles/coded_button_style.gd`, `extends StyleBox`)は、次の4つの`@export`で全ボタンを賄う
  - `State`: NORMAL / HOVER / PRESSED / DISABLED
  - `Shape`: ROUNDED_RECT / CIRCLE / PILL(両端が半円) / CHEVRON_LEFT(左辺が尖った五角形)
  - `Emblem`: NONE / HOURGLASS / SWAP_ARROWS / BENCH / CHECK。描画実体は`UiPaint`側のstatic関数に置き、太い暗色の輪郭+真鍮の塗り+上側のハイライトによる浮き彫り表現とする(細い線画にしない)
  - `EmblemPlacement`: CENTER / UPPER(下半分にテキストが入る) / RIGHT_INSET / TOP_BADGE(上端から少し飛び出す円形の徽章)
- 紋章とテキストの重なりは、`.tres`側で個別に余白を指定するのではなく **`_get_content_margin()`をオーバーライドし、`shape`と`emblem_placement`から自動的に決まるようにする**。これにより`.tres`は「どのグループが何であるか」だけを持つ単純な状態に保てる
- グループごとの割り当ては次の通り。`primary_large`/`secondary_large`/`standard_medium`/`sub_small`の4グループは既にどのシーンからも参照されていない(削除は別タスク)

| グループ | Shape | Emblem | Placement |
|---|---|---|---|
| `action_flip` | CIRCLE | HOURGLASS | UPPER |
| `action_move` | CIRCLE | SWAP_ARROWS | UPPER |
| `action_swap` | CIRCLE | BENCH | UPPER |
| `back_nav` | CHEVRON_LEFT | NONE | - |
| `confirm_save` | ROUNDED_RECT | CHECK | RIGHT_INSET |
| `nav_tab` | PILL | HOURGLASS | TOP_BADGE |
| `transport_round` | CIRCLE | NONE | - |
| `icon_square` | ROUNDED_RECT | NONE | - |
| `wide_text` | ROUNDED_RECT | NONE | - |**enum名に`Variant`を使うとGodot組み込み型と衝突してパースエラーになるため`State`とする**。対応する`.tres`の1行目は `[gd_resource type="StyleBox" script_class="CodedButtonStyle" format=3]`(`type="Resource"` にすると `Script inherits from native type 'StyleBox'` エラーになる)
- 既存の`.tscn`が参照している`resources/theme/buttons/img_{グループ名}_{state}.tres`は、**パスとExtResource参照を維持したまま中身だけをコードStyleBoxへ差し替える**。これによりシーン側の参照を書き換えずに全画面へ反映できる(J-0・L-2で実績のある手法)
- 以下の9-slice/原寸に関する制約は、**画像アセットのまま残す資産にのみ適用される**(砂時計のイラスト、背景イラスト等)。コード描画のStyleBoxは解像度に依存しないため、9-sliceも原寸制約も存在せず、表示サイズはレイアウトの都合で自由に決めてよい
- **`StyleBoxTexture`の`texture_margin_*`(9-slice/角保持スケーリング)は使用しない**。角部分だけ元ピクセルのまま残り縁が不自然に太くなるため(D-1で発覚した問題の根本原因)、`texture_margin_*`は常に0(未設定)とし、画像全体を単一の矩形として扱う。その代わり、**ボタン・パネル等の表示サイズは常に元画像のアスペクト比を保った倍率(縦横同じ倍率)でのみ決定する**。縦横を別々に指定して矩形を歪めることは禁止。置きたい場所に対して元画像のアスペクト比が合わない場合は、(a)その要素の固定サイズ自体をアスペクト比に合わせて再計算する、(b)固定サイズを崩せない場合は余白(レターボックス/ピラーボックス)を許容する、のいずれかで対応し、非等倍(縦横別倍率)の伸縮は行わない。既存の`board_panel.tres`(未使用、`BoardTable`のコード描画に置き換え済み)は本方針の適用外(参照されていないため削除候補だが未対応)

---

### 4.1 砂時計イラストの解像度と配置

砂時計のイラストは、実行時に使うものと、それを作るための元データを明確に分ける。unityroom向けの
Web配信ではpckのサイズがそのままロード時間に直結するため、**実行時に読まないファイルは
`.gdignore` を置いてGodotの管理外へ出す**(インポートもエクスポートもされなくなる)。

| ディレクトリ | 内容 | Godotの扱い |
|---|---|---|
| `assets/hourglasses/processed/{id}/state_*.png` | **実行時に読む唯一の画像**。幅400px基準へ縮小済み | インポートする |
| `assets/hourglasses/sources/{id}/` | 生成元(`source.png`)と縮小前の原寸`state_*.png` | `.gdignore` で無視 |
| `assets/hourglasses/processed_backup/` | 正規化前の旧版(現行とは内容が異なる) | `.gdignore` で無視 |
| `assets/hourglasses/incoming/` | 取り込み待ちの生成画像 | `.gdignore` で無視 |

解像度を幅400pxとしたのは、プロジェクト内で最大の表示サイズが`DeckEditorScreen`の
カード(132x168)であり、基準解像度1280x720を4K全画面へ拡大した場合でも実効336px程度に
収まるため。当初は生成された1038x1330をそのまま使っていたが、表示サイズに対して過大で、
実行時に読む30枚だけで23MBを占めていた(縮小後は4.4MB)。2倍表示でも輪郭がぼけないことを
非ヘッドレスのレンダリングで確認済み。

縮小の際は、**一律のピクセルサイズへ揃えるのではなく、全画像へ同じ倍率を掛ける**。
`state_falling`のみキャンバスが1077x1380で他の状態(1038x1330)と数%異なっており、
同一サイズへ揃えると状態を切り替えたときに絵柄の大きさが跳ねてしまうため。

新しい駒を追加する際の手順は `.claude/skills/add-hourglass/SKILL.md` に反映済み。

同じ理由から、**砂時計以外の取り込み元(`incoming/`)もすべて `.gdignore` で管理外に置く**。
下記はいずれも実行時に参照されておらず(`assets/ui/`・`assets/buttons/` に残る記述は
コード描画で色をサンプリングした出所を示すコメントのみ)、pckへ入れる理由がない。
元データとしての価値はあるためファイル自体は残す。

| ディレクトリ | 内容 |
|---|---|
| `assets/backgrounds/incoming/` | 背景の生成元(本番は `processed/{画面}/background.png`) |
| `assets/ui/incoming/` | UIパーツの生成元シート(フェーズ12でコード描画へ移行済み) |
| `assets/buttons/incoming/` | ボタンの生成元シート(同上) |

この整理により、インポート済みデータ(pckに入るリソースの目安)は約124MBから約17MBになった。
残る大半は画面背景4枚(約10MB)で、これも表示サイズに対して解像度が過大な可能性があるが、
砂時計と違って全画面に敷くため縮小の判断は別途行う。

---

## 5. 拡張運用について

- 新しい砂時計を追加する場合、原則として `HourglassData` の `.tres` を1個作成するだけで完結させる
- 既存の `EffectType` で表現できない効果が必要になった場合は、実装前に GameDesign.md への追記案を提示し、承認を得てから `EffectType` とハンドラを追加する
- オンライン対戦は非同期通信(手番ごとにサーバーへ送信→相手に反映)を前提とし、`GameState` の操作(反転/移動/交代)をそのまま通信メッセージの単位として扱える設計にする
- **`data/hourglasses/` をディレクトリ走査して駒を列挙する処理(`MatchSetup.all_hourglasses()`)は、
  エクスポート後のファイル名を考慮する必要がある**。エクスポートすると `.tres` はpck内へ
  `<name>.tres.remap`(実体は `.godot/exported/` 配下の `.res`)として格納されるため、
  `DirAccess` で列挙した名前は `.tres` で終わらない。`.remap` を除いた名前で判定し、
  `load()` には元の `.tres` パスをそのまま渡す(パス解決はGodotが `.remap` 経由で行う)。
  この不具合はエディタ実行では再現せず、**Web/エクスポート版でのみ全砂時計が0件になる**
  (砂時計一覧が空・デッキ編集の一覧が空・CPUデッキが生成できない・保存済みデッキが
  `find_by_id()` で復元できない、という形で全機能に波及する)。
  検証は `godot --headless --main-pack build/web/index.pck --script res://tools/tests/run_tests.gd`
  で行う(エクスポート済みpckをそのまま読み込んで実行するため、エディタ実行では隠れる
  この種のパス解決の差異を検出できる。既存の `_test_all_hourglass_resources_load()` が
  そのまま回帰テストとして機能する)

---

## 6. オンライン対戦の実装方針

- バックエンドは自前サーバーを立てず、**Firestore(Firebase)のようなサーバーレスDB**を使う。1手を1ドキュメント書き込みとして扱う
- 通信はGodot標準の `HTTPRequest` による **Firestore REST API呼び出し**で行う(認証はFirebase Authenticationの匿名サインイン)。unityroom向けのHTML5/WebGLエクスポートではGDExtension系プラグイン(サードパーティのFirebase SDKラッパー等)が不安定・非対応なことが多く、またFirebase公式C++ SDKもWebAssemblyターゲットを公式サポートしていないため、追加プラグイン不要でどの書き出し先でも確実に動く方式を優先する
- 相手の手の反映は、ドキュメントの**ポーリング(数秒間隔での定期取得)**によって行う。リアルタイムリスナー(gRPC-Web双方向ストリーミング)は実装が複雑なため採用しない。ターン制で1手ごとの時間的猶予があるため、数秒の遅延は体験上問題にならない
- `HomeScreen` の「対戦」タブを、**ランダムマッチ待機**・**ルームコード作成/参加**の2導線に分岐させる
- ランダムマッチのキューは、複数プレイヤーが同時に参加しても二重マッチや取りこぼしが起きないよう、**Firestoreのトランザクション(read-modify-write)でキューの追加/成立を原子的に処理する**。具体的には「待機中のドキュメントを1件取得→トランザクション内で取得できればマッチ成立とみなし両者のマッチIDを確定、取得できなければ自分が待機ドキュメントとして登録される」という手順を想定する
- 持ち時間の管理はロジック層の `MatchClock` が担う。1人あたり180秒(3分)固定で、`finish_turn()` は加算なしで手番を切り替えるだけの単純な減算式とする。時間切れは `GameState.match_ended` と同様の決着トリガーとして扱い、オンライン対戦時はこの持ち時間切れが切断・放置時の敗北条件を兼ねるため、別途タイムアウト監視の仕組みを持たない
- サーバー側での操作の正当性検証は行わず、クライアントの操作をそのまま信頼する(不正対策は将来検討)
- Firebaseの接続情報(`apiKey`/`projectId`等)は `FirebaseConfig`(Resource)として `data/firebase_config.tres` に保持する。Web向けAPIキーは元々クライアント埋め込み前提の値であり、Firestoreセキュリティルール側でアクセス制御する運用とする
- マッチ成立後、両者は `matches/{match_id}` ドキュメントへ自分のデッキ(5種のid配列)を `deck_a`/`deck_b` として書き込む。相手側はポーリングでこれを検知し `MatchScreen` の配置フェーズ(`MatchPlacementController`)に反映する(`OnlineSetup` が担当。手順・呼び出し順序は旧`DeckSelectScreen.setup_online()`から変更していない)
- 場3個の配置が確定したら、同様に `placement_a`/`placement_b`(3個のid配列、左・中央・右の順)を書き込む。**自分の配置を送信するまでは相手の`placement_*`フィールドを一切参照しない**実装とすることで、事実上の同時公開を実現する(暗号学的な担保はせず、クライアントの実装ルールとして運用する。既存の「クライアントを信頼する」方針と整合)。控え2個は「デッキ5個から場3個を除いたもの」として両者が個別に導出でき、別フィールドは持たない
- 両者の `placement_a`/`placement_b` が揃った時点で、双方が `MatchScreen` へ遷移し対局を開始する。オンライン時は `MatchScreen` の表示視点(自分/相手)を `state.current_turn` ではなく固定の `my_side` にし、自分の手番でない間は操作を受け付けない
- 対局中の実際の手の送受信は `OnlineMatch` が担当し(導入済み)、`MatchScreen` は自分の操作を `OnlineMatch.send_and_apply` 経由で送信しつつ即座にローカル反映する
- **投了は指し手と同じ`actions`配列の1件として送受信する**(`{"type": "surrender", "side": <投了した側>}`)。`OnlineMatch.apply()`のmatch文へ`"surrender"`分岐を1つ足し、`GameState.surrender(side)`を呼ぶだけで済むため、ポーリング・送信の仕組みを新設せずに相手へ伝わる。ただし投了は盤面を変えずに即終局する点で反転/移動/交代と性質が異なるため、**`MatchScreen`側では行動の演出(`MatchActionPresenter`)とターン交代(`_advance_turn_and_refresh()`)を行わない**(適用した時点で`match_ended`が発火し、以降の処理は結果パネルの表示に引き継がれる)。`actions`と`finished_at`/`winner`は同じドキュメントの別フィールドだが、`FirestoreClient.set_document()`が`updateMask`付きのPATCHでフィールド単位に書くため、投了側が両方をほぼ同時に書いても互いを打ち消さない

---

## 7. リプレイ・観戦の実装方針

- `matches/{match_id}` には既に `deck_a`/`deck_b`(5枚)・`placement_a`/`placement_b`(場3枚)・`actions`(手順)が保存済みで、控え2枚は「デッキ−配置」で導出できる。**初期配置のための新しいフィールドは追加せず、これらを再利用する**
- 対局終了時、`GameState.match_ended` を検知したタイミングで `MatchScreen` が `matches/{match_id}` へ `finished_at`(タイムスタンプ)・`winner`(`"a"`/`"b"`)を書き込む。この書き込みが「終了済みマッチ」の判定基準を兼ねる(未書き込み=対局中または放棄されたマッチ)
- リプレイ一覧の取得は、`player_a == 自分のuid` と `player_b == 自分のuid` の**2本の等価フィルタクエリ**をそれぞれ実行し、結果をクライアント側でマージ・`finished_at`降順ソートする(複合インデックスを要求する `OR` 条件や `orderBy` 併用を避ける、既存のクエリ方針を踏襲)
- リプレイ閲覧は `player_a`/`player_b` のuidが自分のuidと一致する場合のみ許可する(クライアント側での表示制御。Firestoreセキュリティルール側でも同様の制限を検討する)
- 保存件数の上限(直近30件)は、対局終了時の書き込み後に「終了済みマッチが30件を超えていないか」をチェックし、超過分を `finished_at` の古い順に削除するクリーンアップ処理で維持する。プレイヤー単位ではなくアプリ全体で30件とし、シンプルな実装に留める
- `ReplayListScreen`:`DeckListScreen` と同様の横長カード縦スクロール一覧。各カードは対局日時・勝敗・先手/後手に加え、`deck_a`/`deck_b` から自分・相手双方の初期デッキ5枚のアイコンを表示する。`BattleTab` に追加する「リプレイ」ボタンから遷移する
- 投了で終わった対局は、`actions`の末尾に`surrender`が1件入った状態で保存される。リプレイ再生時は他の手と同じく`OnlineMatch.apply()`へ流れて`match_ended`が発火するが、再生モードでは元々結果パネルを出さない仕様のため追加の分岐は要らない。手数表示では投了も1手として数える(将棋の棋譜で投了を1手と数えるのと同じ扱い)
- `ReplayPlaybackScreen`:新規シーンを作らず、既存の `MatchScreen` に「再生モード」を追加する形で実装する。再生モードでは `GameState` を `placement_a`/`placement_b` 由来の初期配置から開始し、保存済み `actions` を1件ずつ `OnlineMatch.apply()`(既存の静的関数)へ流し込んで進行を再現する。`ActionMenu` の代わりに、先頭へ/1手戻る/再生・一時停止/1手進む/最後へ、の5ボタンと手数表示を持つ再生用コントロールを表示し、駒のクリック操作は無効化する
- 観戦は既存の**ルームコード**を再利用する。`rooms/{code}` には対局成立後も `match_id` が残っているため、観戦者が同じコードを入力すると `rooms/{code}` から `match_id` を引き、`matches/{match_id}` の購読(ポーリング)を開始できる。ランダムマッチには共有可能なコードが存在しないため観戦導線を用意しない
- `MatchScreen` に「観戦モード」を追加する(対局モード・再生モードに続く3つ目のモード)。`OnlineMatch` のポーリング機構をそのまま使い、`send_and_apply` を呼ばずに `action_received` シグナルだけを購読して盤面へ反映する。`ActionMenu` は非表示にし、盤面操作は無効化する。対局終了の検知(`match_ended`)は通常通り行うが、`finished_at`/`winner` の書き込みは対局者側のみが行い、観戦者側では行わない
- `BattleTab` のルームコード入力欄に「観戦する」ボタンを追加し、参加導線と並べて配置する

### 7.1 CPU戦のローカルリプレイ保存(フェーズ11 K-2、実装済み)

- `LocalReplayService`(`scripts/net/local_replay_service.gd`、`RefCounted`のstaticクラス、
  `DeckSave`と同様「Autoloadを使わずstaticで持つ」流儀)が、CPU戦の棋譜を
  `user://cpu_replays.json` へ配列として保存する。1件のレコードは、オンライン版
  `matches/{id}` ドキュメントと対応する内容(`deck_a`/`deck_b`・`placement_a`/`placement_b`・
  `actions`・`finished_at`・`winner`)に加えて `id`(`"cpu_<unixtime>_<乱数>"`)・
  `source`(常に`"cpu"`、一覧画面でのオンライン/CPU戦の判別に使う)を持つ。
  `mark_finished(record)` が保存(+保存件数の上限維持)、`list_replays()` が
  `ReplayService.list_replays()`と同じ`{"id":..., "fields":{...}}`形の配列(`finished_at`降順)を
  返し、`get_replay(id)` がidに一致する1件をフラットな形(`MatchScreen.start_local_replay()`が
  そのまま読める形)で返す
- 保存件数の上限(直近30件、`RETENTION_LIMIT`)は、オンライン対戦(Firestore、
  `ReplayService.RETENTION_LIMIT`)とCPU戦(ローカル、`LocalReplayService.RETENTION_LIMIT`)を
  **それぞれ独立に**30件まで保持する(合算で管理すると片方の対局頻度が高い場合にもう片方が
  不当に圧迫されるため)
- CPU戦中の棋譜の蓄積は、新規`MatchCpuReplayRecorder`(`scripts/ui/match_cpu_replay_recorder.gd`、
  `MatchBattleLog`等と同様`_screen`参照を持つRefCounted)へ切り出している。
  `MatchScreen.start_cpu_match()`が`begin(board_a, bench_a, board_b, bench_b)`を呼び
  `deck_a`/`deck_b`/`placement_a`/`placement_b`のidをそこから算出、`_perform_action()`
  (自分の手)と`_maybe_trigger_cpu_turn()`(CPUの手)の両方が`record_action(action)`を呼んで
  `actions`を蓄積し、`_on_match_ended()`が`_is_cpu_match`の場合に`save_finished(winner)`を呼んで
  `LocalReplayService.mark_finished()`へ渡す。オンライン対戦の`OnlineMatch`がFirestoreへ
  逐次書き込む構造とは異なり、CPU戦は対局終了時に一括で1回だけローカル保存する
- `start_replay(match_id, client)`(Firestore版)と`start_local_replay(record)`
  (`LocalReplayService`版)は、いずれも共通の`MatchReplayController.start_from_doc(doc: Dictionary)`
  を呼ぶ。Firestoreの`get_document()`も`LocalReplayService.get_replay()`もフラットな
  `Dictionary`を返すため、この共通化だけで再生ロジック(`MatchReplayController._goto()`等)を
  完全に共有できる
- `ReplayListScreen.refresh()` は、Firestoreからの一覧取得(既存、サインイン失敗時は
  空扱い)と`LocalReplayService.list_replays()`(新規、ローカルのためサインイン不要)の
  両方を行い、クライアント側で`finished_at`降順にマージして1つの一覧として表示する
  (オンライン側のサインインが失敗してもCPU戦のリプレイだけは表示できるようにしている)。
  `ReplayListCard`は`fields.source == "cpu"`かどうかで、`player_a`/`player_b`のuid比較を
  スキップして常に自分を先手(側A)として扱い、`info_label`のテキスト末尾に
  `[CPU戦]`/`[オンライン]`の表示を追加する(専用のバッジ用ノードは追加せず、
  既存の`InfoLabel`へテキストとして組み込む形に留めている)。`Main._on_replay_selected()`は
  `match_id`が`"cpu_"`始まりかどうかで`start_local_replay()`/`start_replay()`を振り分ける
- 観戦機能はCPU戦の対象外のまま変更していない(ローカル対局に第三者が参加する経路が存在しないため)

---

## 8. CPU戦の実装方針

- CPUの思考ロジックは `CpuStrategy`(基底クラス、`RefCounted`)として切り出し、`MatchScreen` は具体的な思考の中身を知らずに `choose_action(state, side) -> Dictionary` を呼び出すだけにする。
- 合法手の列挙(反転可能な6駒・移動の3組み合わせ・交代2枠・パス)は `CpuStrategy` の静的関数としてまとめる。
- 実装として以下の戦略クラスを提供する:
  - `RandomCpuStrategy`: 列挙した合法手から一様ランダムに1手を選択する(テスト・検証ベースライン用)。
  - `SmartCpuStrategy`: 探索用GameState上でスナップショットを用いた局面展開を行い、HP差・落下ダメージ期待値・相手妨害価値・継続効果・テンポ損得を総合評価して最善手を選ぶ。初期配置を決定する `choose_placement(deck) -> Dictionary` も備える。
- CPUの手番になったら、`MatchScreen` が一定時間(0.6秒程度)待ってから `CpuStrategy.choose_action()` を呼び出し、`OnlineMatch.apply()`(既存の静的関数)で着手を反映する。
- CPU戦の配置生成は、`Main` がランダムな5枚を選出した後、`SmartCpuStrategy.choose_placement()` を用いて場3個・控え2個の初期配置を決定する。
- CPU戦はオンライン対戦ではないため、`matches/{match_id}` への書き込み(リプレイ・観戦)は一切行わない

---

## 9. 効果音・BGMの実装方針

- 効果音は `SoundBank`(`RefCounted` 継承のstaticクラス)に集約する。`MatchSetup`/`DeckSave`/`NetSession` と同じ「Autoloadを使わずstaticで持つ」流儀に揃える
- `ensure_ready(parent)` を `Main._ready()` から1度だけ呼び、`AudioStreamPlayer` のプール(常駐ノード)を生成する。staticクラス自体はNodeではないため、実際の再生には実ノードが要る
- `wire_buttons(root)` はシーンツリーを再帰的に走査し、全Buttonの `pressed` へ共通のボタン押下音を接続する。個別配線は漏れやすいため、`Main._ready()` で全体に対して1度呼ぶことを基本とするが、実行時に動的生成されるノード(例: `DeckListScreen` のカード一覧)は起動時の走査に含まれないため、生成元の画面スクリプト側で個別に呼び直す。`is_connected()` チェックにより二重接続は起きない
- 反転/移動/交代/被弾/決着の専用効果音は `MatchScreen` が該当処理箇所で直接 `SoundBank.play()` を呼ぶ。`ActionMenu` 配下のボタンは共通のボタン押下音と二重に鳴らさないため `wire_buttons()` の対象から除外する
- 音量設定は `user://sound_settings.json` へJSONで永続化する。`SoundBank._sfx_volume`/`_bgm_volume`(いずれも0.0〜1.0のfloat)は `static var` の初期化式でクラス初回アクセス時に自動読み込みされるため、`ensure_ready()` を待たずに早期から正しい値を返せる(ホーム画面の設定ボタンは `Main` より先に `_ready()` が走るため、ここで読んでおかないと初期表示に反映されない)。`get_sfx_volume()`/`set_sfx_volume()`・`get_bgm_volume()`/`set_bgm_volume()` で参照・変更し、`play()` 時と設定変更時に `AudioStreamPlayer.volume_db` を `linear_to_db()` で更新する(0%は `-inf` を避けるため `-80.0dB` 固定)。`is_muted()` は `_sfx_volume <= 0.0` の派生として残している
- ホーム画面右上に `SettingsButton`(`Button` 継承、既存の `img_icon_square` ボタン画像シートを流用)を配置し、押すと `SettingsPanel`(`scenes/settings_panel.tscn`、`ResultOverlay`/`SurrenderConfirm` と同じ「暗幕+`content_panel.tres` の中央パネル」パターン)が開く。パネル内の `HSlider` 2本(いずれも0〜100%。効果音は `SoundBank.set_sfx_volume()`、BGMは `SoundBank.set_bgm_volume()` を随時更新する)で音量を操作し、「閉じる」ボタンでパネルを閉じる
- 音源は**CC0(パブリックドメイン)ライセンスの外部フリー素材**を使う(GameDesign.md 9章)。効果音は `assets/sfx/`、BGMは `assets/bgm/` に置く。**取り込んだ素材の出所・作者・ライセンスは `assets/CREDITS.md` に必ず記録する**。CC0なので表示義務はないが、後から「この音はどこから来たのか」を追えないと、ライセンスの再確認も差し替えもできなくなるため
- **BGMは `MusicPlayer`(`scripts/logic/music_player.gd`、`RefCounted` 継承のstaticクラス)が担当し、`SoundBank` とは別クラスに分ける**。効果音が「1発鳴らして終わり」なのに対し、BGMはクロスフェード・ループ・自動再生制限の解除といった継続的な状態を持つため、同じクラスへ同居させると `SoundBank` が肥大化する。`ensure_ready(parent)` で `AudioStreamPlayer` を2本(クロスフェードで鳴り替えるため)生成する流儀は `SoundBank` と揃える
- **音量の単一情報源は `SoundBank` 側に置き続ける**。`_sfx_volume` と `_bgm_volume` の2つを持ち、`user://sound_settings.json` へ両方を保存する(旧形式の単一キー `volume` を見つけた場合は両系統の初期値として読み、次回保存時に新形式へ移行する)。`MusicPlayer` は自前で音量を永続化せず、`SoundBank.get_bgm_volume()` を参照し、`SoundBank.set_bgm_volume()` が `MusicPlayer.apply_volume()` を呼んで反映する。設定の読み書きを2クラスに分散させると、同じJSONファイルを互いに上書きし合うため
- **BGMの切り替えは `Main._show_only()`(画面切り替えのハブ)から1箇所で行う**。遷移先が `MatchScreen` なら対局曲、それ以外はホーム曲を指定する。画面ごとに個別へ `MusicPlayer.play()` を書き散らさない
- **クラシック曲はシームレスにループしない**ため、`AudioStreamPlayer.finished` を購読し、数秒の間を置いてから頭へ戻す「アルバム再生」方式で繰り返す。インポート設定でループを有効にすると `finished` が発火しなくなるため、**実行時に `stream.loop = false` を明示する**
- **ブラウザの自動再生制限に対応する**。`MusicPlayer.play()` は、最初のユーザー操作を検知するまで実際には鳴らさず、要求されたトラックを `_pending_track` として覚えておくだけにする。`Main` が最初のクリック/タップで `MusicPlayer.notify_user_gesture()` を呼び、そこで保留していたトラックの再生を始める
- **結果画面ではBGMを止め、勝敗別の短いジングルを鳴らす**(GameDesign.md 9章)。`SoundBank.Sfx` の `RESULT` を `RESULT_WIN`/`RESULT_LOSE` の2つへ分け、`MatchResultPresenter` が勝敗に応じて鳴らし分ける

---

## 未検討事項

- `EffectResolver` の対応表の具体的な実装方式(match文 vs 個別クラス継承)は、実装着手時に決定する
