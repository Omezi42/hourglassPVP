# 10.15 ソロモード(遠征)

GameDesign.md 27章の実装方針。**遠征の規則(道・山札・HP・候補)は対局画面から切り離した純粋なロジック
(`SoloRun`)に置き、対局そのものは既存の CPU 戦の経路(`_begin_state()`)へ薄い上書きを重ねる。**
遠征の規則をヘッドレステストで確かめられるようにするため。

| クラス | 責務 |
|---|---|
| `SoloGateData`(`scripts/data/solo_gate_data.gd`, Resource) | 関門1つぶんの特殊ルール。`data/solo_gates/{id}.tres`。1つ足すのは `.tres` 1個 |
| `SoloGateLibrary`(`scripts/logic/solo_gate_library.gd`, static) | `data/solo_gates/` を id 順に返す。`PuzzleLibrary` と同じ流儀(`.remap` の扱いを含む) |
| `SoloRun`(`scripts/logic/solo_run.gd`, RefCounted) | 遠征1回ぶんの状態と規則。道の生成・行き先の選択・勝敗の反映・候補の生成・山札への追加。`to_dict()` / `from_dict()` で保存できる。乱数は呼び出し側から受け取る |
| `SoloProgress`(`scripts/logic/solo_progress.gd`, static) | 遠征の保存(続きから再開)と、遠征をまたいで残る記録(最多勝利数・踏破回数・到達済みの節目)。`user://solo_progress.json` へアカウントごとに持つ |
| `CardMatchSolo`(`scripts/ui/card_match_solo.gd`, RefCounted) | `_screen` 参照を持つ切り出し。行き先の対局を始め、関門の特殊ルールを当て、終局で `SoloRun` へ結果を返し、砂金・節目の報酬を渡して結果パネルを出す |
| `CardSoloMapScreen`(`scripts/ui/card_solo_map_screen.gd`) | 遠征の画面。出発(作戦の3択)・道・候補の選択・山札の中身を出す(構成は9章のモックで決める) |
| `CardChallengeResult` / `StageRewardTokens` | 結果パネルと報酬の絵。リーサルパズル(10.12節)と共用 |

## `SoloGateData`

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

## `SoloRun`

**状態**(すべて `to_dict()` に入る)

| フィールド | 内容 |
|---|---|
| `theme_id` | 出発で選んだ作戦(`CardCpuDecks` の id) |
| `deck_ids: Array[String]` | いまの山札 |
| `hp` | 持ち越すHP。開始は `MatchState.INITIAL_HP` |
| `floor` | いま選ぶ段(0始まり。`FLOOR_COUNT` = 6 で踏破) |
| `wins` | この遠征で勝った数 |
| `route: Array` | 段ごとの行き先の配列。行き先は `{"kind": Kind, "cpu_deck": id, "gate": id}`(泉は空文字) |
| `offer: Array[String]` | 勝った直後に選べる候補。空なら候補待ちではない |
| `in_battle` | 行き先の対局を始めてから決着するまで true。**これが true のまま読み込んだら負けとして遠征を終える**(27章「中断と再開」) |
| `over` / `cleared` | 遠征が終わったか / 踏破したか |

**規則の定数**: `FLOOR_COUNT = 6` / `SPRING_HEAL = 8` / `OFFER_SIZE = 3` / `GATE_OFFER_SIZE = 4` / `THEME_CHOICES = 3` /
`EXPERT_FROM_FLOOR = 2` / `GOLD_PER_WIN = 20` / `CLEAR_GOLD = 100`。

**操作**

- `static theme_choices(rng) -> Array[String]` — 出発で示す作戦の id を3つ
- `static create(theme_id, rng) -> SoloRun` — 作戦の15種を1枚ずつ山札にし、道を作る
- `choose(index, rng)` — いまの段の行き先を選ぶ。泉なら回復して次の段へ進む。対局・関門なら `in_battle` を立てる
- `finish_battle(won, hp_left, rng)` — 決着を返す。勝ちなら `wins` と `floor` を進め、`hp` を控え、候補を作る(最終段なら踏破)。負けなら遠征を終える
- `take(card_id)` / `pass_offer()` — 候補から1枚足す / 見送る
- `difficulty()` — 段で決まる思考レベル(`EXPERT_FROM_FLOOR` 未満は中級)

**道の生成**: 1〜5段目は2〜3個の行き先。各段に対局か関門を1つ以上、泉は1段に1つまで・1段目には出さない。
6段目は対局1つだけ。**CPUデッキは1回の遠征で重複させない**(8つを切り混ぜて順に割り当てる)。

**候補の生成**: 1枚は作戦のCPUデッキの15種から、残りは「基本セット + `price > 0` のカードセット」のうち
トークンでないカードから。山札に既に2枚あるカード・同じ候補の中の重複は除く。候補を作れる数が足りなければ出せるだけ出す。

## `SoloProgress`

`user://solo_progress.json` にアカウントごと(未サインインは `"local"`)に
`{"run": {...} or null, "best_wins": int, "clears": int, "milestones": [String]}` を持つ。
以前の形式(ステージidの配列)を読んだときは空の記録として扱う。

- `load_run(uid) -> SoloRun` — 保存中の遠征。`in_battle` のまま残っていたら負けとして遠征を終え、`null` を返す
- `save_run(uid, run)` / `clear_run(uid)` — 行き先の選択・決着・候補の選択のたびに保存する
- `record(uid, run) -> Array[Dictionary]` — 決着のたびに呼び、最多勝利数・踏破回数を更新し、**初めて到達した節目**を返す

**節目**は `SoloRun.MILESTONES` の表で持つ(`{"id", "wins" or "cleared", "card_set", "icon"}`)。
解放は `AccountService.unlock_card_set()` / `unlock_icon()`(`unlock_free` の委譲。通信できないときは
`AccountStore.add_pending_unlock()` へ積み、次のサインインで流し直す)。

## 対局の組み立て(`CardMatchSolo`)

- `start(run)` — いまの行き先の対局を作る。`_begin_state()` へ、自分側に `run.deck_ids` の `CardData`、
  相手側に `CardCpuDecks.deck_of(cpu_deck)` を渡す。**30枚未満の山札を通すのはこの経路だけ**
  (`MatchState.start_match()` は枚数を検査しない)。思考レベルは `run.difficulty()`。相手の名札は `CardCpuDecks.foe_name()`
- `_begin_state()` の直後に `hp[自分] = run.hp` を差し替え、関門なら特殊ルールと盤面を当てる。`hp_changed` は出さない
  (情報帯は `refresh()` が `state.hp` を直接読む。信号を出すと音とログが「被弾」と誤読する)
- `on_match_ended()` — `run.finish_battle()` → `SoloProgress.save_run()` / `record()` → 砂金(`StageReward.grant_gold()`)と
  節目の解放 → 結果パネル。`CardMatchScreen._on_match_ended()` は `_solo.active()` のとき通常の砂金・戦績・リプレイを素通りする
- `_reset_for_new_match()` は `close()` を呼ぶため、`_begin_state()` の前に遠征を控えて戻す(10.12節と同じ穴)

## ソロモード限定カードの所有

**10.8.1節のカードセットの仕組みをそのまま使う。**3枚は `set_id` = `solo_chime` / `solo_ward` / `solo_goad` の
1枚セット(`price = 0` はショップに並べない印)。デッキ編集・図鑑は未所有のカードを弾く(10.8.1節)。
**`price == 0` のセットのカードは、CPUデッキにも遠征の候補にも入れない**(`tools/tests/cpu_deck_tests.gd` / `solo_mode_tests.gd` が確かめる)。
