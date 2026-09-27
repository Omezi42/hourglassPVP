# 10.15 ソロモード(遠征)

GameDesign.md 27章の実装方針。**遠征の規則(道・山札・HP・束・恩恵・工房)は対局画面から切り離した純粋なロジック
(`SoloRun`)に置き、対局そのものは既存の CPU 戦の経路(`_begin_state()`)へ薄い上書きを重ねる。**
遠征の規則をヘッドレステストで確かめられるようにするため。

| クラス | 責務 |
|---|---|
| `SoloGateData`(`scripts/data/solo_gate_data.gd`, Resource) | 関門1つぶんの特殊ルール。`data/solo_gates/{id}.tres`。1つ足すのは `.tres` 1個 |
| `SoloGateLibrary`(`scripts/logic/solo_gate_library.gd`, static) | `data/solo_gates/` を id 順に返す。`PuzzleLibrary` と同じ流儀(`.remap` の扱いを含む) |
| `SoloBoonData`(`scripts/data/solo_boon_data.gd`, Resource) | 恩恵1つぶんの効果。`data/solo_boons/{id}.tres`。効果の数値は既定0で、使うものだけ書く |
| `SoloBoonLibrary`(`scripts/logic/solo_boon_library.gd`, static) | `data/solo_boons/` を id 順に返す。`SoloGateLibrary` と同じ流儀 |
| `SoloRun`(`scripts/logic/solo_run.gd`, RefCounted) | 遠征1回ぶんの状態と規則。道の生成・行き先の選択・勝敗の反映・束/恩恵の候補生成・工房・山札への反映。`to_dict()` / `from_dict()` で保存できる。乱数は呼び出し側から受け取る |
| `SoloProgress`(`scripts/logic/solo_progress.gd`, static) | 遠征の保存(続きから再開)と、遠征をまたいで残る記録(最多勝利数・踏破回数・到達済みの節目)。`user://solo_progress.json` へアカウントごとに持つ |
| `CardMatchSolo`(`scripts/ui/card_match_solo.gd`, RefCounted) | `_screen` 参照を持つ切り出し。行き先の対局を始め、恩恵・関門の特殊ルールを当て、終局で `SoloRun` へ結果を返し、砂金・節目の報酬を渡して結果パネルを出す。「遠征の札」(`SoloMatchPlaque`)の生成・更新・後始末も持つ |
| `SoloMatchPlaque`(`scripts/ui/solo_match_plaque.gd`, Control) | 遠征の対局中に卓の左へ常に出す「遠征の札」。段数・行き先の種類・特殊勝利条件の関門だけ持つ残りの数を表示する。`CardMatchSolo` が結果パネル・ログより背面に置く |
| `CardSoloMapScreen`(`scripts/ui/card_solo_map_screen.gd`) | 遠征の画面。出発・道・行き先の詳細・束・恩恵・工房・記録の状態の出し分けと、`SoloRun`/`SoloProgress`への保存・読み込みだけを持つ。見た目は下記の子へ委ねる |
| `SoloDepartureView`(`scripts/ui/solo_departure_view.gd`, Control) | 出発の画面。作戦の札を3枚並べ、押すと`theme_chosen`を出す |
| `SoloRouteView`(`scripts/ui/solo_route_view.gd`, Control) | 道の画面。6段の駒を描く。駒を押しても対局は始めず`destination_selected`(選択解除は-1)を出すだけで、選んだ駒に真鍮の輪を付ける(`set_selected()`)。`show_record()`で押せない表示モード(遠征の記録で再利用)にもなる |
| `SoloStatusPanel`(`scripts/ui/solo_status_panel.gd`, Control) | 道の右側の状態パネル。作戦名・持っている恩恵・HPのバー(上限は`SoloRun.max_hp`)・勝った数・`SoloDeckList`と「遠征をやめる」(`abandon_requested`) |
| `SoloDestinationPanel`(`scripts/ui/solo_destination_panel.gd`, Control) | 行き先の詳細。道で駒を選んだときに状態パネルの代わりに同じ位置へ出す。相手・狙い・CPUの強さ・15種の絵(対局・関門)、回復後のHP(泉)、または工房の案内を出し、「挑む」(泉は「休む」、工房は「入る」。`challenge_pressed`)/「戻る」(`back_pressed`)を持つ |
| `SoloBundleOverlay`(`scripts/ui/solo_bundle_overlay.gd`, Control) | 束のオーバーレイ。道を暗幕で覆い、束(作戦ごとの3枚を横長の札で縦に並べる)から1つ選んで`bundle_chosen`/`skip_pressed`を出す。右端に`SoloDeckList`でいまの山札を出す |
| `SoloBoonOverlay`(`scripts/ui/solo_boon_overlay.gd`, Control) | 恩恵のオーバーレイ。関門に勝った直後に出す。恩恵の札(コード描画のメダル+名前+効果)を3枚並べ、押すと`boon_chosen`を出す(見送りは無い) |
| `SoloWorkshopOverlay`(`scripts/ui/solo_workshop_overlay.gd`, Control) | 工房のオーバーレイ。山札の種類ごとに1枚(2枚あるものは`×2`)並べ、押して選ぶと「抜く」「複製する」を出す。`card_removed`/`card_duplicated`/`skip_pressed`を出す |
| `SoloRunSummary`(`scripts/ui/solo_run_summary.gd`, Control) | 遠征の記録。`open()`で終わった遠征を1度だけ出す。押せない`SoloRouteView`(`show_record()`)・持っている恩恵・`SoloDeckList`・「出発へ」を持つ |
| `SoloDeckList`(`scripts/ui/solo_deck_list.gd`, Control) | 山札の一覧(コスト順・スクロール)。状態パネル・束/工房のオーバーレイ・遠征の記録が共用する |
| `SoloUiPaint`(`scripts/ui/solo_ui_paint.gd`, static) | 出発の札・状態パネル・行き先の詳細・束/恩恵の札・山札欄が共用する額縁パネルの描画と、当たり判定だけの透明ボタン |
| `CardChallengeResult` / `StageRewardTokens` | 結果パネルと報酬の絵。リーサルパズル(10.12節)と共用。`StageReward`は複数の節目(カードセット・アイコン)が同時に届いたときのため`card_set_ids`/`icon_ids`の配列も持つ |

## `SoloGateData` / `SoloBoonData`

`SoloGateData`のフィールドは変更なし(下表)。

| フィールド | 型 | 内容 |
|---|---|---|
| `id` / `display_name` / `description` | String | 一意識別子・名前・1〜2行の説明 |
| `own_board_units` / `foe_board_units` | Array[String] | 初期盤面。`"id:体力:攻撃力"`(`PuzzleStageData` と同じ表現)。空なら空の盤面 |
| `win_condition` | enum `WinCondition` | `HP_ZERO`(既定)/ `SURVIVE_TURNS` / `DESTROY_ALL_ENEMY_UNITS` |
| `survive_turns` | int | `SURVIVE_TURNS` のときの目標(`MatchState.turn_count`、両者の手番の通し数) |
| `sand_drop_count` | int | 既定1。`MatchState.sand_drop_count` へ渡す |
| `flip_disabled` | bool | `MatchState.flip_disabled` へ渡す(反転権は対象外) |
| `clash_damage_multiplier` | int | 既定1。`MatchState.clash_damage_multiplier` へ渡す |

**`MatchState` の上書き用プロパティは3つ**(`sand_drop_count` / `flip_disabled` / `clash_damage_multiplier`)。
既定値のままなら他の全モードを一切変えない。`CardMatchSolo` が `_begin_state()` の直後、最初の手番の前に設定する。
盤面の上書きは新しいAPIを作らず、`board` を直接差し替える(ルール画面・4.2節と同じ)。

**特殊勝利条件は `MatchState` 本体を変えず、外側の監視で判定する。**`SURVIVE_TURNS` は `turn_started` で目標を超えた
自分の手番に相手を投了させ、`DESTROY_ALL_ENEMY_UNITS` は `unit_destroyed` のたびに相手の場を数えて空なら投了させる。
通常のHP0の決着はどちらでも生かしておく。

`SoloBoonData`のフィールドは、`id` / `display_name` / `description` に加えて効果の数値6つ(既定0)を持つ。
1つの恩恵は1つだけ非0にする(`tools/tests/solo_mode_tests.gd`が確かめる)。

| フィールド | 効果 |
|---|---|
| `max_hp_bonus` | 丈夫な体: 最大HP+N。`SoloRun.take_boon()`が得た瞬間にHPもN回復する |
| `spring_bonus` | 深い泉: 泉の回復+N(`SoloRun.spring_bonus()`) |
| `extra_bundles` | 目利き: 束の数が`SoloRun.BUNDLE_COUNT + N`になる(`SoloRun.extra_bundles()`) |
| `foe_hp_penalty` | 先制の砂: 対局開始時、相手のHPをN引く(`CardMatchSolo._apply_run_state()`) |
| `extra_opening_draw` | 用意周到: 対局の最初の手札をN枚多く引く(`CardMatchSolo._begin_battle()`) |
| `win_heal` | 勝ち癖: 勝利のたびにHPをN回復(上限`max_hp`。`SoloRun.finish_battle()`) |

## `SoloRun`

**状態**(すべて `to_dict()` に入る)

| フィールド | 内容 |
|---|---|
| `theme_id` | 出発で選んだ作戦(`CardCpuDecks` の id) |
| `deck_ids: Array[String]` | いまの山札 |
| `hp` / `max_hp` | 持ち越すHPと、恩恵「丈夫な体」で伸びる上限。開始はどちらも `MatchState.INITIAL_HP` |
| `floor` | いま選ぶ段(0始まり。`FLOOR_COUNT` = 6 で踏破) |
| `wins` | この遠征で勝った数 |
| `route: Array` | 段ごとの行き先の配列。行き先は `{"kind": Kind, "cpu_deck": id, "gate": id}`(泉・工房は空文字) |
| `offer: Array[Dictionary]` | 勝った直後に選べる束の候補。束は`{"theme": id, "cards": [id, id, id]}`。空なら候補待ちではない |
| `boon_offer: Array[String]` | 関門に勝った直後に選べる恩恵の候補。空なら候補待ちではない |
| `boons: Array[String]` | 得た恩恵のid(同じ恩恵は1回の遠征で1度だけ) |
| `last_gate_id` | `boon_offer`を作った関門のid(恩恵の画面の小見出し用。保存はするが規則には使わない) |
| `workshop_open` | 工房を開いている間 true |
| `chosen: Array[int]` | 段ごとに選んだ行き先のindex。`choose()`のたびに足す。道の画面(`SoloRouteView`)が、選び終えた段のどの駒を明るくするかに使う |
| `in_battle` | 行き先の対局を始めてから決着するまで true。**これが true のまま読み込んだら負けとして遠征を終える**(27章「中断と再開」) |
| `over` / `cleared` | 遠征が終わったか / 踏破したか |

**規則の定数**: `FLOOR_COUNT = 6` / `SPRING_HEAL = 8` / `THEME_CHOICES = 3` / `EXPERT_FROM_FLOOR = 2` /
`GOLD_PER_WIN = 20` / `CLEAR_GOLD = 100` / `MAX_DECK_COPIES = 2` / `BUNDLE_COUNT = 3` / `BUNDLE_CARDS = 3` /
`BOON_OFFER_SIZE = 3`。

**操作**

- `static theme_choices(rng) -> Array[String]` — 出発で示す作戦の id を3つ
- `static create(theme_id, rng) -> SoloRun` — 作戦の15種を1枚ずつ山札にし、道を作る
- `choose(index, rng)` — いまの段の行き先を選ぶ。泉なら回復して次の段へ進み、工房なら`workshop_open`を立てる。対局・関門なら `in_battle` を立てる
- `finish_battle(won, hp_left, rng)` — 決着を返す。勝ちなら`win_heal()`を足して`wins`と`floor`を進め、関門なら恩恵の候補(`boon_offer`)を、それ以外は束の候補(`offer`)を作る(最終段なら踏破)。負けなら遠征を終える
- `take_boon(id)` — 恩恵を1つ得る。丈夫な体は即座にHPも回復する。得たあとで束の候補を作る
- `take_bundle(index)` / `pass_offer()` — 束を1つ選んで3枚まとめて山札に足す / 見送る
- `workshop_remove(id)` / `workshop_duplicate(id)` / `workshop_skip()` — 山札から1枚抜く/複製する(2枚まで)/何もしない。いずれも工房を閉じ、次の段へ進む
- `difficulty()` — 段で決まる思考レベル(`EXPERT_FROM_FLOOR` 未満は中級)
- `spring_bonus()` / `extra_bundles()` / `foe_hp_penalty()` / `extra_opening_draw()` / `win_heal()` — 得た恩恵の対応する効果の合計

**道の生成**: 1〜5段目は2〜3個の行き先。各段に対局か関門を1つ以上、泉と工房は合わせて1段に1つまで・1段目には出さない。
6段目は対局1つだけ。**CPUデッキは1回の遠征で重複させない**(8つを切り混ぜて順に割り当てる)。

**束の生成**: 1つは選んだ作戦(`theme_id`)の束、残りは他の作戦から重ならないように選ぶ。作戦ごとの15種から、山札に
既に2枚あるカードを除いて3枚。3枚そろわない作戦は束にしない。数は`BUNDLE_COUNT + extra_bundles()`。

**恩恵の生成**: まだ持っていない恩恵から`BOON_OFFER_SIZE`つ。

## `SoloProgress`

`user://solo_progress.json` にアカウントごと(未サインインは `"local"`)に
`{"run": {...} or null, "best_wins": int, "clears": int, "milestones": [String], "finished": {...} or null}` を持つ。
以前の形式(ステージidの配列)を読んだときは空の記録として扱う。`SoloRun.from_dict()`自体も、束が
カードidの配列だった旧形式(`max_hp`無し)を読んだとき、候補を捨てて`max_hp`を既定値へ戻すことで壊れずに読む
(Pitfalls.md「データとコードの境目」)。

- `load_run(uid) -> SoloRun` — 保存中の遠征。`in_battle` のまま残っていたら負けとして遠征を終え、`finished`(理由`"abandoned_mid_battle"`)を保存して `null` を返す
- `save_run(uid, run)` / `clear_run(uid)` — 行き先の選択・決着・候補の選択のたびに保存する
- `record(uid, run) -> Array[Dictionary]` — 決着のたびに呼び、最多勝利数・踏破回数を更新し、**初めて到達した節目**を返す
- `save_finished(uid, run, reason)` / `take_finished(uid) -> Dictionary` — 遠征が終わったとき(負け・踏破・対局途中の中断)の`SoloRun.to_dict()`と理由(`"abandoned_mid_battle"`か空)を`{"run", "reason"}`で持つ。`take_finished`は読んだら消し、`CardSoloMapScreen.open()`が`SoloRunSummary`を1度だけ出すのに使う。**「遠征をやめる」では呼ばない**(自分で終えたため記録は出さない)

**節目**は `SoloRun.MILESTONES` の表で持つ(`{"id", "wins" or "cleared", "card_set", "icon"}`)。
解放は `AccountService.unlock_card_set()` / `unlock_icon()`(`unlock_free` の委譲。通信できないときは
`AccountStore.add_pending_unlock()` へ積み、次のサインインで流し直す)。

## 対局の組み立て(`CardMatchSolo`)

- `start(run)` — いまの行き先の対局を作る。`_begin_state()` へ、自分側に `run.deck_ids` の `CardData`、
  相手側に `CardCpuDecks.deck_of(cpu_deck)` を渡す。**30枚未満の山札を通すのはこの経路だけ**
  (`MatchState.start_match()` は枚数を検査しない)。思考レベルは `run.difficulty()`。相手の名札は `CardCpuDecks.foe_name()`
- `_begin_battle()`: `_begin_state()`(マリガンの手札を配るところまで)の直後、恩恵「用意周到」の追加ドローを
  `MatchState._draw_one()`で直接足す(`draw()`が出す`hand_changed`/`cards_drawn`は、初期手札のドローに音を
  鳴らさない`_begin_state()`と同じ理由で使わない)。そのあと`_apply_run_state()`でHP・関門の特殊ルールを当ててから、
  `CardMatchCpu.begin_mulligan()`(CPU戦・オンラインと共用)でCPU側のマリガンを決め、自分の手札(追加ドローぶんを
  含む)をマリガン画面へ出す
- `_apply_run_state()`: 自分のHPを`run.hp`へ差し替え、恩恵「先制の砂」があれば相手のHPを`foe_hp_penalty()`だけ
  引く(下限1)。関門なら特殊ルールと盤面を当てる。**`hp_changed` は出さない**
  (情報帯は `refresh()` が `state.hp` を直接読む。信号を出すと音とログが「被弾」と誤読する)
- `on_match_ended()` — `run.finish_battle()` → `SoloProgress.record()` → 遠征が終わっていれば`save_finished(uid, run, "")`のあと`clear_run()`、
  続いていれば`save_run()` → 砂金(`StageReward.grant_gold()`)と節目の解放 → 結果パネル。
  `CardMatchScreen._on_match_ended()` は `_solo.active()` のとき通常の砂金・戦績・リプレイを素通りする
- `max_hp()` — いまの遠征の最大HP。`CardMatchScreen.refresh_bars()`が`PlayerInfoBar.show_state()`へ渡し、
  情報帯のHPの器の割合・「/ N」の表記を`MatchState.INITIAL_HP`ではなくこの値で描かせる(24を超える恩恵込みの
  最大HPでも器が崩れないようにするため)
- `_reset_for_new_match()` は `close()` を呼ぶため、`_begin_state()` の前に遠征を控えて戻す(10.12節と同じ穴)

## ソロモード限定カードの所有

**10.8.1節のカードセットの仕組みをそのまま使う。**3枚は `set_id` = `solo_chime` / `solo_ward` / `solo_goad` の
1枚セット(`price = 0` はショップに並べない印)。デッキ編集・図鑑は未所有のカードを弾く(10.8.1節)。
**`price == 0` のセットのカードは、CPUデッキにも遠征の束にも入れない**(束は各作戦の`CardCpuDecks`の15種だけから
選ぶため、構造上そもそも混ざらない。`tools/tests/cpu_deck_tests.gd` / `solo_mode_tests.gd` が確かめる)。
