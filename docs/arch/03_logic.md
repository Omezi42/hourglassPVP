# 3. ロジック層

UIに依存しない、対局ルールそのものを扱う層。

## 3.1 `MatchState`(`scripts/logic/match_state.gd`, Node)

対局中の唯一の真実を保持する。旧 `GameState` とは別クラスとして並走させている。

保持するもの:両プレイヤーの `hp` / `mana` / `max_mana` / `deck`(山札)/ `hand` /
`board`(6枠の `CardInstance`、空きは null)/ `graveyard`、`current_turn`、`first_side`、
`turn_count`、`end_reason`、`winner`。いずれも `Side`(A/B)をキーにした Dictionary。

定数は GameDesign.md 2章の数値をそのまま持つ:`INITIAL_HP = 24` / `BOARD_SIZE = 6` /
`DECK_SIZE = 30` / `MAX_MANA = 10` / `FIRST_PLAYER_HAND = 3` / `SECOND_PLAYER_HAND = 4` /
`FATIGUE_DAMAGE = 1` / `COIN_MANA = 1`。加えて、両者が延々とパスし続けた場合の保険として `MAX_TURNS = 200`
(到達したら `EndReason.DRAW` で打ち切る。シミュレーションが止まらなくなるのを防ぐためで、
実対局では持ち時間(GameDesign.md 5章)が先に尽きる)。

**手番の流れ**(GameDesign.md 3章)は `_begin_turn()` と `end_turn()` の2つだけで表す。

**繰り返し働くトリガー**(GameDesign.md 6章)の発火点は2つだけで、どちらも
既にある処理へ乗せる。**新しいループを増やさない。**

- **落砂(`ON_TURN_END`)**:`end_turn()` が砂を1粒落とす直前。**落とす前に発動する**のは、
  この1粒で壊れる駒にも最後の1回を働かせるため(壊れたあとに `ON_DEATH` が続く)
- **被弾(`ON_DAMAGED`)**:`damage_unit()` と `_resolve_unit_combat()` が
  `take_damage()` で実際に砂を削れたときだけ。**硝子で無効化されたときは発動しない**
  (受けたのはダメージではなく、防がれた攻撃であるため)。**発動は生き残った駒に限る**
  (死んだ駒は `ON_DEATH` が受け持つ)

- `_begin_turn()`:`turn_count` を進める → 最大マナ+1・全回復 → 自分の全ユニットの
  `begin_turn()`(召喚酔い・反転済み・攻撃回数のリセット)→ ドロー1枚 → `turn_started` を発行
- `end_turn()`:自分の全ユニットを `tick()`(1粒落とす)→ 体力0になったものを破壊 →
  山札が尽きていれば疲労1ダメージ → 手番を交代して `_begin_turn()`

**コイン**(GameDesign.md 2章)は `coin_available`(Side をキーにした bool)と
`use_coin(side)` の2つだけで表す。対局開始時に後手だけ true にし、使うと false に戻す。
**カードとしては持たない**。手札に置くと「0コストで場に出す」既存の経路と衝突するうえ、
盤面の枠を持たないカード(スペル)という概念を1枚のために導入することになるため。

**マリガン**(GameDesign.md 2章)は `start_match()` の引数 `use_mulligan` で有効にし、
有効な間は初期手札を配った時点で止まって `_begin_turn()` を呼ばない(`mulligan_pending`)。
`mulligan(side, indices)` は選択を受け取るだけで、**両者ぶんが揃ってから A → B の固定順で
適用する**。適用は山札を切り直すため乱数を消費し、**適用順が違うと以後の山札が食い違う**。
オンラインでは両者の確定が届く順序が保証されないため、順序を固定することが同じ対局を
再現する条件になる。

引き直しは「手札から外す → 同じ枚数を引く → 外したカードを山札へ混ぜて切り直す」の順で行う。
先に山札へ戻すと同じカードがその場で返ってくる。


**メインフェイズの操作は3つ**で、いずれも `can_*()` と実行のペアを持つ。UI・CPU・
オンラインの再生はすべてこの3つだけを呼ぶ。

- `play_card(side, hand_index, slot, target)` … マナを払って空き枠へ置く。**埋まっている
  枠へは出せず**(上書き設置は行わない)、空き枠が無い間は `can_play()` が false を返す。
  速落は `drop_sand(2)` して
  `summoned_this_turn` を下ろす。最後に `ON_PLAY` の効果を解決する
- `flip(side, slot)` … 体力と攻撃力を入れ替える。マナ不要・1体1ターン1回・出したターンは不可。
  `ON_FLIP` の効果を解決する
  `cannot_attack` を持つ駒は `can_attack()` が常に false を返す(反転はできる)
- `attack(side, slot, target_slot)` … `target_slot` が -1 なら相手プレイヤー、0以上なら
  相手の砂時計。**砂時計を攻撃した場合は相打ち**として `_resolve_unit_combat()` へ回す

**戦闘の処理順序**(`_resolve_unit_combat()`)は、キーワードの相互作用を壊さないため固定する。

1. 攻撃力・体力を**両者ぶん先に控える**(同時攻撃であり、片方の減少がもう片方の値に
   影響してはならない)
2. 双方が `take_damage()`(硝子はここで1度だけ吸う)
3. 貫通:実際にダメージが通った側だけ、`攻撃力 - 相手の元の体力` の超過分を本体へ
4. 吸命:実際に与えたダメージぶん自分のHPを回復
5. 毒砂:ダメージを与えた相手の体力を0にする
6. `_cleanup_dead()` で両陣営の死亡を回収し、`ON_DEATH`(余砂)を発火

**守護**は攻撃側ではなく防御側の問い合わせとして持つ。`attackable_slots(defender_side)` は
守護がいれば守護の枠だけを、いなければ全枠を返し、`can_attack_player()` は守護が1体でも
いれば false を返す。

## 3.1.1 砂術(GameDesign.md 6章)

**砂術のために新しいクラスを作らない。**盤面へ出ないだけで、効果の解決も棋譜への
記録もオンラインでの搬送も既存の経路をそのまま通せる。足すのは次の3点だけ。

| 足すもの | 内容 |
|---|---|
| `CardData.is_spell` | 砂術かどうか。`total_sand` は 0 のまま使わない |
| `MatchState.can_cast()` / `cast_spell()` | 手札の1枚を撃つ。**空き枠を要求しない** |
| `CardEffectResolver._return_to_hand()` | `RETURN_TO_HAND` の適用。**`_summon()` と対になる位置**へ置き、盤面への出し入れを1クラスにまとめる |
| `MatchAction.cast()` | `{"type": "cast", "side":, "hand_index":, "target": {...}}` |

- **`play_card()` へ相乗りさせない。**`can_play()` は空き枠が無いと必ず false を返し
  (GameDesign.md 3章)、`play_card()` は枠へ `CardInstance` を置くことが前提になっている。
  ここへ「砂術なら枠を見ない」という分岐を足すと、**砂時計を出す経路の条件が砂術のために
  緩む**。逆に `can_play()` は「砂術は出せない」を1行足して弾く
- **効果の解決は `CardEffectResolver` をそのまま使う。**盤面に置かない `CardInstance` を
  その場で作って `resolve(side, unit, Trigger.ON_PLAY, hint)` へ渡す。`_slot_of()` が
  -1 を返すため、**光の筋の出どころが陣地側になる**——これは余砂で既に通っている経路であり、
  砂術のために `_beam()` を変える必要がない
- **トリガーは `ON_PLAY` を流用し、新しい値を足さない。**砂術は1つしかトリガーを持たず、
  `ON_PLAY` は既に「カードを使ったとき」を意味している。表示だけは前置き(「場に出したとき」)を
  省く(`CardEffectPreview` / `CardDetailPanel`)
- **`EffectTarget.SELF` は砂術では使わない。**`_targets()` が `_slot_of()` の -1 を見て
  空を返すため何も起こらない。`.tres` を作るときに指定しないこと
- 撃った砂術は `graveyard` へ積む。**盤面を経由しないため `unit_played` は出さず**、
  新しいシグナル `spell_cast(side, card)` を出す(音と演出の受け口)

**砂術のために足す `EffectType` は2つだけ。**どちらも適用は `MatchState` ではなく
`CardEffectResolver` の private が持つ——`_summon()`(空き枠へ置く)と対になり、
盤面とプレイヤーへの操作が1箇所へ揃う。`MatchState` の公開メソッドが gdlint の上限へ
張り付いていることへの答えでもある(`gdlintrc` を緩める前に、減らせる場所を先に探すこと)。

- **`RETURN_TO_HAND`**(`_return_to_hand()`):盤面から駒を取り除いて持ち主の手札へ戻す
- **`INVERT_PLAYER_HP`**(`_invert_hp()`):プレイヤーのHPを `INITIAL_HP - 現在HP` にする。
  **増減は既存の `heal_player()` / `damage_player()` へ渡すこと。**HPの上限・0での決着・
  シグナルの発行がすべてそこにあり、`hp` を直接書き換えると3つとも取りこぼす
  (**満タンで撃つと自分が負ける**という、このカードの肝心の挙動が働かなくなる)**破壊ではないため `ON_DEATH`(余砂)は発火しない**。
手札が上限に達している場合の扱いは持たない(このゲームは手札の上限を定義していない)。
**戻すのは `CardData` であり、`CardInstance` の状態(受けたダメージ・与えられたキーワード)は
すべて失われる**——手札へ戻ったカードは新品の1枚として扱う。

## 3.1.2 反転権(GameDesign.md 2章)

**新しいクラスを作らず、`MatchState` へ `flip()` と対になるメソッドを1組足すだけにする。**
先手・後手で総回数(`FLIP_RIGHT_FIRST` / `FLIP_RIGHT_SECOND`。**値は要検証の仮置き**)が
違う点以外は、通常の反転と同じ「体力と攻撃力を入れ替え、`ON_FLIP` を解決する」処理を再利用する。

- `flip_right_remaining: Dictionary`(Side → 残り回数)を `start_match()` で先手・後手それぞれ
  の総量に初期化する。使うたびに1減り、**ターンをまたいでも0に戻さない**(`_begin_turn()` は
  一切触らない)
- `_can_use_flip_right(side, target_side, slot)` は `can_flip()` を呼ばない。**通常の反転の
  制限(1体1ターン1回・出したターンは不可)を無視する**という仕様(2章)をそのまま表しており、
  見るのは「自分の手番か」「残り回数があるか」「対象の枠に砂時計がいるか」の3つだけ。
  **公開しない**——`MatchState` は既にgdlintの公開メソッド上限(11章)へ張り付いているため、
  コイン(`use_coin()` のみで `can_use_coin()` を持たない)と同じく、UIは戻り値だけで
  成否を判断する。対象を選ぶ前の「押した枠に駒がいるか」は盤面を直接読めば足りる
- `use_flip_right(side, target_side, slot)` は `flip()` とほぼ同じ手順(`unit.flip()` →
  シグナル → `_fire(ON_FLIP)` → 死亡なら `_destroy_unit()`)を踏むが、**`unit_flipped` ではなく
  専用の `flip_right_used(actor_side, target_side, slot)` を出す**。反転権は敵味方どちらの駒も
  対象に取れるため、「誰が手を出したか(actor_side)」と「駒の持ち主(target_side)」が
  別々の値になりうる。既存の `unit_flipped(side, slot)` は「持ち主=手を出した側」を前提に
  UI側(光の筋の向き)が組まれているため、同じ信号へ相乗りさせず分ける
- `MatchAction.flip_right(side, target_side, slot)` / `apply()` の `"flip_right"` 分岐を足す。
  棋譜・オンライン送信・リプレイはすべて既存の `MatchAction` の経路をそのまま通る

## 3.2 `CardEffectResolver`(`scripts/logic/card_effect_resolver.gd`, RefCounted)

`CardEffectData` の評価と適用を1箇所に集約する。`MatchState` が生成して保持し、
`resolve(side, unit, trigger, hint)` を設置・反転・余砂の3箇所から呼ぶ。

- `effect_type` ごとの分岐を1つの `match` に持ち、新しい種別を足すときはここへ1分岐を
  加えるだけで済む形を保つ
- `target` の解決(自分自身/相手1体/相手全体/味方全体/プレイヤー)もここで行う
- **`SUMMON` は空き枠が無ければ何もしない**(GameDesign.md 6章)。出した駒は
  `summoned_this_turn` を立てた状態で置き、その `ON_PLAY` は解決しない
  (効果で出た駒の設置効果まで連鎖すると、1枚のカードが何をするか読めなくなるため)
- **`ALLY_UNIT` は効果を持つ駒自身を除く**(GameDesign.md 6章)。`_targets()` が
  自分の枠を `exclude_slot` として渡す
- **対象を1体選ぶ効果(`ENEMY_UNIT` / `ALLY_UNIT`)は、`hint`(`{"side":..., "slot":...}`)で受け取る。**
  指定が無い・その枠が既に空いている場合は「生涯ダメージが最大の1体」を自動で選ぶ。
  これによりUIは対象選択を実装するまで指定なしで呼べ、CPU・リプレイ再生も同じ経路を通る

## 3.3 検証

`tools/tests/v5_rules_tests.gd`(`run_tests.gd` から呼ぶ)が、生涯ダメージの式・砂の3つの
移動・初期手札と先手のドロー無し・空き枠が無い場合に出せないこと・召喚酔いと速落・相打ち・守護/硝子/貫通/
吸命/毒砂/連撃・設置効果6種・反転トリガー・疲労を検証する。`run_tests.gd` は1000行の
上限に達しているため、v5.0 のテストはこの別ファイルへ置く。
