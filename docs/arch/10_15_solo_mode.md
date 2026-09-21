# 10.15 ソロモード

GameDesign.md 27章の実装方針。**チュートリアルではなく、既存の対局エンジン
(`MatchState`)を土台にした一人用の高難度コンテンツ**として作る。専用の対局ルールを
新設せず、リーサルパズル(10.12節)がそうしているように、既存のクラスへ薄い
オーバーライドを重ねる形にする。

| クラス | 責務 |
|---|---|
| `SoloStageData`(`scripts/data/solo_stage_data.gd`, Resource) | 1ステージぶんの定義。`data/solo_stages/{id}.tres` |
| `SoloMatchConfig`(Resource、`SoloStageData` に埋め込む) | パズル型以外の4種が使う対局設定(下記) |
| `SoloLibrary`(`scripts/logic/solo_library.gd`, static) | `data/solo_stages/` を `order` 順に返す。`PuzzleLibrary`と同じ流儀(`.remap`の扱いを含む) |
| `SoloProgress`(`scripts/logic/solo_progress.gd`, static) | クリア記録。`user://solo_progress.json` へアカウントごとに持つ。`PuzzleProgress`と同じ流儀 |
| `CardSoloMapScreen`(`scripts/ui/card_solo_map_screen.gd`) | ステージの一覧。v1は分岐しない1本道のため、`CardPuzzlePickerScreen`と同じ「縦に並ぶ横長カード」の形をそのまま使う。**専用の確認パネル(`CardSoloStageDetail`)は作らない**——カード自体が名前・種別・説明・初回クリア報酬を出しており、「挑戦」を押すとそのまま始まる |
| `CardMatchSolo`(`scripts/ui/card_match_solo.gd`, RefCounted) | `_screen` 参照を持つ切り出し(`CardMatchPuzzle`/`CardMatchOnline`と同じ流儀)。対局設定の適用・特殊勝利条件の監視・連戦型のHP持ち越し・クリア時の報酬付与を行う |
| `CardSoloResult`(`scripts/ui/card_solo_result.gd`) | ステージの結果パネル。`CardPuzzleResult`と同じ理由で、対局の結果パネル(`CardMatchResult`)を流用しない |
| `CardMatchGeometry`(`scripts/ui/card_match_geometry.gd`, RefCounted) | `card_match_screen.gd`が1000行の上限に迫ったため、`hp_bar_center()`/`slot_center()`/`playable_hand_rects()`/`end_turn_button_rect()`の4つの座標系の問い合わせをここへ切り出した。ソロモード固有の役目は持たないが、この節の実装で足りなくなった行数を確保するために行った |

**`SoloStageData` のフィールド**

| フィールド | 型 | 内容 |
|---|---|---|
| `id` | String | 一意識別子 |
| `order` | int | ステージの並び順(v1は1本道のため、これがそのままツリー上の位置になる) |
| `display_name` / `description` | String | 名前と1〜2行の説明 |
| `stage_type` | enum(`Kind`) | `PUZZLE` / `CPU_MATCH` / `SPECIAL_RULE` / `GAUNTLET` / `RESTRICTED` |
| `requires` | Array[String] | 前提ステージのid。**複数持てるようにしておく**(v1では常に1つだが、将来の分岐に備える) |
| `reward_gold` | int | 初回クリア時の砂金 |
| `reward_icon_id` | String | 空なら無し。付与は`AccountService`の所有配列(10.8節と同じ経路) |
| `reward_card_set_id` | String | 空なら無し。`CardSetLibrary`のid(ソロモード限定の1枚セット。10.8.1節・下記) |
| `puzzle` | PuzzleStageData | `stage_type == PUZZLE` のときだけ使う。**既存のリーサルパズルと全く同じ形式を埋め込みで再利用する**(新しいフィールドを作らない) |
| `match_config` | SoloMatchConfig | `PUZZLE` 以外で使う |

**`SoloMatchConfig` のフィールド**

| フィールド | 型 | 内容 |
|---|---|---|
| `player_deck_ids` / `opponent_deck_ids` | Array[String] | 30枚ぶんのid。**プレイヤー自身の構築デッキは使わない**(GameDesign.md 27章) |
| `opponent_count` | int | `GAUNTLET`(連戦型)でのみ2以上。既定1 |
| `own_board_units` / `foe_board_units` | Array[String] | `"id:体力:攻撃力"` の文字列(`PuzzleStageData`の`own_units`/`foe_units`と同じ表現)。空なら通常どおり空の盤面から開始 |
| `win_condition` | enum(`WinCondition`) | `HP_ZERO`(既定)/ `SURVIVE_TURNS` / `DESTROY_ALL_ENEMY_UNITS` |
| `survive_turns` | int | `win_condition == SURVIVE_TURNS` のときの目標ターン数 |
| `sand_drop_count` | int | 既定1。`MatchState.sand_drop_count` へそのまま渡す |
| `hp_override` | int | 0なら`MatchState.INITIAL_HP`のまま。0より大きければ両者のHPをこの値で開始する |
| `mana_frozen` | bool | true なら自分のターン開始時に最大マナが増えない |
| `flip_disabled` | bool | true なら`MatchState.flip_disabled`へ渡す(3章の通常の反転を止める。反転権は対象外) |
| `clash_damage_multiplier` | int | 既定1。`MatchState.clash_damage_multiplier`へ渡す |

**`MatchState` へ足す4つの上書き用プロパティ**(GameDesign.md 27章「特殊ルールのバリエーション」)。
いずれも**既定値のままなら今までの全モード(PvP・通常のCPU戦・リーサルパズル・誘導対局)を
一切変えない**。ソロモードの `CardMatchSolo` が `start_match()` の直後、`_begin_turn()`が
最初に走る前に設定する。

- `sand_drop_count: int = 1` — `end_turn()` が各ユニットへ`tick()`する際、この粒数を渡す
  (既存の `drop_sand(1)` 呼び出し箇所を `drop_sand(sand_drop_count)` へ変える)
- `flip_disabled: bool = false` — `can_flip()` の先頭で true なら常に false を返す。
  **反転権(`use_flip_right()`)はこのフラグを見ない**(GameDesign.md 27章の明記どおり)
- `clash_damage_multiplier: int = 1` — `_resolve_unit_combat()` と `combat_preview()`
  (UIの予測)が双方の`take_damage()`へ渡す量にこの倍率を掛ける。**双方に同じ倍率が
  かかるため、相打ちの対称性は崩れない**
- `mana_frozen: bool = false` — `_begin_turn()` の「最大マナ+1」を、trueの間だけ止める。
  **側を区別しない1つのフラグ**とし、対象の対局では両者へ同じ制約をかける

**HPの上書き・盤面の上書きは、新しいAPIを作らずルール画面(4.2節)と同じ「差し替え」で行う**。
`MatchState.start_match()`で通常どおり対局を作った直後、`CardMatchSolo`が`hp`と`board`を
直接書き換える。**HPの下限・上限チェックは`heal_player()`/`damage_player()`を経由しないため
ここでは働かないが、初期化時の一度きりの代入であり問題にならない**(3.1.1節の`INVERT_PLAYER_HP`
実装時に確立した既存の注意点と同じ)。

**特殊勝利条件は`MatchState`本体を変えず、外側の監視で判定する**(`CardMatchPuzzle`が
リーサルパズルの成否を`MatchState`の外で判定しているのと同じ考え方)。

- `SURVIVE_TURNS`:`turn_started`シグナルで手番数を数え、目標へ達し、かつ自分のHPが
  残っていればステージクリアとする。**通常のHP0での敗北判定(`MatchState`本体)はそのまま
  生かしておく**——生き残る前に自分が倒されたら、既存の経路で普通に負ける
- `DESTROY_ALL_ENEMY_UNITS`:`unit_destroyed`のたびに相手の場を数え、6枠すべて空になった
  時点でクリアとする

**思考レベルは常に上級で固定する**(GameDesign.md 27章)。`CardMatchSolo`は
`CardCpuStrategy.Difficulty.EXPERT`を明示的に渡し、選択画面(8.2節)を挟まない
(誘導対局が`NORMAL`を明示固定しているのと対になる)。

**`GAUNTLET`(連戦型)は、`_screen`のCPU対局を`opponent_count`回繰り返しつつ、
プレイヤーのHPだけを次の対局へ持ち越す**。持ち越すのは`hp`のみで、山札・手札・盤面は
対局ごとに引き直す(「合間の回復は無い」というルールの本体はHPの持ち越しだけで表現でき、
デッキやマナまで持ち越すと1戦目の事故がそのまま2戦目の難度を歪めるため)。

**`CardMatchScreen`は`puzzle`と同じ形で`solo: CardMatchSolo`の公開getterを持つ**
(`_solo`は`CardMatchBuild`が`_puzzle`と並べて生成する)。`Main._on_solo_stage_selected()`が
`stage.stage_type`を見て、`PUZZLE`なら`card_match_screen.puzzle.start(stage.puzzle)`、
それ以外は`card_match_screen.solo.start(stage)`を呼び分ける。`_on_match_ended()`も
`_puzzle.active()`の直後に`_solo.active()`を同じ形で見て、該当すれば`CardMatchOutcome`
(通常の砂金・戦績・リプレイ)を素通りする——ソロモードの報酬は`CardMatchSolo._grant()`が
別に持つため、`MatchStats`(戦績)へ固定デッキの結果を混ぜない。

**無料の付与は`AccountService.unlock_free(client, uid, kind, id)`の1本に集約する。**
`purchase()`と同じ「`updateTime`を前提条件にした`commit()`」の形を使い、残高の確認・減算
だけを行わない。`unlock_card_set()`と`unlock_icon()`はこれへ`ShopCatalog.Kind`を渡すだけの
薄い委譲にしてある——**品種ごとに同じ30行を書き写すと、片方だけ直し忘れる**。
通信に失敗した分は`AccountStore.add_pending_unlock(key, id)`へ積み、次のサインインで
流し直す(15章の砂金と同じ扱い)。置き場は品種ごとに分ける(`_pending_key()`)——
1つの配列へ混ぜると、復帰したときに互いの品種として解放しようとする。
**カードセットの置き場だけは`pending_card_sets`という以前からの名前をそのまま使う**
(変えると、この変更の前に積まれていた分が読めなくなる)。

## ソロモード限定カードの所有(GameDesign.md 27章)

**10.8.1節のカードセットの仕組みをそのまま使う。**ソロモードのためだけに
`solo_exclusive`/`owned_cards`のような別の所有フィールドを作らない——8章が
「買い切り以外の追加手段」を明示的に許容しており、ステージのクリアはその1つとして
そのまま乗る。**10.8.1節はこのソロモードの実装と合わせて着手し、両方が同じ
`CardData.set_id` / `CardSetLibrary` / `players/{uid}.owned_card_sets` を使う。**

- 新カード3枚は `set_id = "solo"` を持ち、`CardSetLibrary` に「ソロモードセット」
  として1件登録する。**`price = 0` はショップに並べない印**とする
  (`ShopCatalog.items()`はカードセットの品目を作るとき`price > 0`のものだけを拾う)
- 付与は `AccountService.unlock_card_set(uid, set_id)` を新設して行う。`purchase()`と
  同じ「`updateTime`を前提条件にした`commit()`」で`owned_card_sets`へ追加するが、
  **残高の確認・減算は行わない**(無料付与のため)。**通信に失敗した付与はローカルへ
  退避し、次に成功した時点でまとめて反映する**(15章の砂金と同じ扱い。ソロモードは
  オフラインでも遊べるCPU戦を含むため必要)
- **デッキ編集・砂時計図鑑は、`set_id != "" and not owned_card_sets.has(set_id)`の
  カードを弾く**(10.8.1節)。図鑑の「未収集はシルエット+『?』」の表現
  (`AlmanacEntry.locked`として枠組みだけ作ってあった)を、この3枚で初めて実際に使う
- **`CardDeckSave.random_deck()`(CPU戦のデッキ生成)は、`price == 0`のカードセットに
  属するカードだけを除く**(10.8.1節の決定どおり)。ソロモード限定セットは`price == 0`
  のためCPUデッキには一切混ざらない

## ホーム画面のソロタブ

`SoloTab`(`scripts/ui/solo_tab.gd`)は`DeckTab`/`BattleTab`/`RulesTab`と同じ形で、
大きなボタン3つ(CPU戦・リーサルパズル・ソロモード)を縦に並べる。CPU戦・リーサルパズルの
遷移先(`Main._start_cpu_match()`系・`CardPuzzlePickerScreen`)はそのまま流用し、
**ボタンの置き場所だけをBattleTabから移す**。
