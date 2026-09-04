# 砂時計アリーナ 実装設計書(Architecture v5.0)

本書は `docs/GameDesign.md` の仕様を Godot 4.x / GDScript 2.0 でどう実装するかの方針をまとめる。
仕様(ルール・数値・UI)は GameDesign.md が唯一の情報源であり、本書はその実装設計のみを扱う。

> **v1.0(位相制)の実装は撤去済み。** `GameState` / `HourglassData` / `EffectResolver` /
> `MatchScreen` 一式・`DeckListScreen` / `DeckEditorScreen` / `HourglassListScreen` /
> `BattleDeckPickerScreen` と `data/hourglasses/*.tres` は削除し、本書は v5.0 だけを記述する。
> 6〜10章(オンライン対戦・リプレイ・CPU戦・音・アカウント/通貨)の枠組みは
> v1.0 から引き継いだもので、v5.0 でもそのまま使っている。

---

## 1. 設計方針

- カードは `Resource` としてデータ駆動で管理し、コード変更なしで新規追加できる形にする
- 効果は「トリガー×ターゲット×エフェクト」の組み合わせで表現し、エフェクト種別ごとにハンドラを1箇所に集約する
- 既存のエフェクト種別の組み合わせだけで新しいカードを作れる状態を維持する(「新効果そのものの追加」と「既存効果の組み合わせによる新カード追加」を分けて運用する)
- UI層・対局ロジック層・データ層を分離する。ロジック層はUIに依存しない
- **キーワード(GameDesign.md 6章)は `CardEffectData` ではなく `CardData.keywords` として持つ**。
  キーワードは「トリガーで発火する効果」ではなく戦闘処理そのものの分岐(守護は対象選択、
  硝子は被ダメージ、貫通・毒砂・吸命は攻撃解決、連撃は攻撃回数、速落は召喚時)であり、
  効果の語彙へ押し込むと `CardEffectResolver` が戦闘のルールを持つことになるため

---

## 2. データ構造(Resource設計)

### 2.1 `CardEnums`(`scripts/data/card_enums.gd`)

v5.0のカードが使う語彙を1箇所へ集める。旧ルールの `GameEnums`(位相制の
`HourglassState` 等)とは別物であり、混ぜて使わない。

| enum | 値 |
|---|---|
| `Keyword` | `GUARD`(守護)/ `GLASS`(硝子)/ `PIERCE`(貫通)/ `POISON`(毒砂)/ `LIFESTEAL`(吸命)/ `DOUBLE_STRIKE`(連撃)/ `QUICK`(速落) |
| `NAMED`(const) | **語として見せる**キーワード。`GUARD` / `GLASS` / `PIERCE` / `QUICK` の4つ |
| `Trigger` | `ON_PLAY`(設置)/ `ON_FLIP`(反転)/ `ON_DEATH`(余砂)/ `ON_TURN_END`(落砂)/ `ON_DAMAGED`(被弾) |
| `EffectTarget` | `SELF` / `ENEMY_UNIT` / `ALL_ENEMY_UNITS` / `ALL_ALLY_UNITS` / `OPPONENT_PLAYER` / `OWN_PLAYER` / **`ALLY_UNIT`** |
| `EffectType` | `DAMAGE_PLAYER` / `DAMAGE_UNIT` / `DESTROY_UNIT` / `SWAP_STATS` / `ADD_TOTAL` / `DROP_SAND` / `DRAW` / `HEAL_PLAYER` / `DAMAGE_PLAYER_PER_ENEMY_UNIT` / `ADD_ATTACK` / `SUMMON` / `GRANT_KEYWORD` / `SILENCE` / **`RETURN_TO_HAND`** / **`INVERT_PLAYER_HP`** |

**`CardEnums` の enum へ新しい値を足すときは、必ず末尾へ置く**(下記11章)。

`keyword_name()` / `trigger_name()` は GameDesign.md 6章の日本語表記を返す。表示名を
UI側に散らさないため、語と enum の対応はここだけが持つ。

**能力の「語にする/しない」は enum ではなく `NAMED` で分ける。**2枚以上のカードに
載っている能力だけを語として見せ、1枚しか無いものは効果の文で書く(GameDesign.md 6章)。
戦闘処理はどちらも同じフラグで動くため、**enum を分けずに表示だけを切り替える**。
文字列は用途ごとに3つ持つ。

| 関数 | 長さ | 使う場所 |
|---|---|---|
| `keyword_name()` | 語(2〜3字) | 語にする能力。カードの面・詳細パネルの【】 |
| `keyword_short_text()` | 4字程度 | 語にしない能力の**カードの面**。左右の隅を数値バッジが占めるためここしか入らない |
| `keyword_description()` | 一文 | 詳細パネル・デッキ編集の一覧 |

`CardData.named_keywords()` / `plain_keywords()` が振り分け、`CardView` は面用の短い方、
`CardDetailPanel` は一文の方を使う。

### 2.2 `CardData`(Resource, `.tres`)

カード1種の静的定義。1カード = 1 `.tres`(`data/cards/{id}.tres`)。
**体力・攻撃力のフィールドは持たない**。総量から導出される(GameDesign.md 1章)。

| フィールド | 型 | 内容 |
|---|---|---|
| `id` | String | 一意識別子("sand", "sword" 等) |
| `display_name` | String | 表示名 |
| `cost` | int | 場に出すために支払うマナ |
| `total_sand` | int | 総量(体力+攻撃力)。場に出た時点で 体力=総量 / 攻撃力=0 |
| `pool_index` | int | プールへ加えられた順の通し番号。砂時計一覧の「追加順」がこれを読む |
| `keywords` | Array[Keyword] | 常在キーワード。0個でよい(バニラ) |
| `effects` | Array[CardEffectData] | キーワードで表せない固有効果。0個でよい |
| `rules_text` | String | 効果欄に出す一文。キーワードだけのカードは空 |
| `cannot_attack` | bool | 攻撃できない代わりに総量が大きい駒(GameDesign.md 6章)。守護と違い**語にしない**ため `keywords` ではなくフラグで持つ |
| `is_token` | bool | 効果で場に出る砂時計。**`CardLibrary.all_cards()` が返さない**ため、デッキ編集にも一覧にも現れない |
| `is_spell` | bool | 砂術(GameDesign.md 6章)。**盤面へ出ず、効果だけを起こして墓地へ行く**。true のとき `total_sand` / `keywords` / `cannot_attack` は使わない |
| `icon_upright` / `icon_falling` / `icon_fallen` | Texture2D | 体力が多い/半々/攻撃力に偏った状態のイラスト |
| `emblem` | Texture2D | そのカードだけの紋章(モチーフのアイコン)。白のシルエットで持ち、色は描画側が決める |

**イラストは全種で共通の1枚の色違いであるため、カードを見分けているのは実際には
`emblem` である**(GameDesign.md 9章)。紋章は能力の分類ではなくカードのモチーフを表すので、
`keywords` や `effects` から導出せず、`.tres` が1枚ずつ持つ。

`describe()` が「キーワード名 / 固有効果の文」を組み立てるため、UI側は表示文字列を
自分で作らない。

**`pool_index` はファイル名や一覧の並びから導出しない**(GameDesign.md 9章)。`CardLibrary` は
`data/cards/` を名前順に走査するため、既定の並びは id のアルファベット順であり追加順ではない。
番号は `.tres` を作るときに1つずつ入れる(`.claude/skills/add-hourglass/SKILL.md` の手順)。

### 2.3 `CardEffectData`(Resource)

効果1件分。`trigger` / `target` / `effect_type` / `value` に加えて、
**値が整数1つでは足りない2つの効果のためのフィールド**を持つ。

| フィールド | 使う効果 | 内容 |
|---|---|---|
| `card_id` | `SUMMON` | 出す砂時計の id(`CardLibrary.find_by_id()` で引く) |
| `keyword` | `GRANT_KEYWORD` | 与えるキーワード。既定は -1(なし) |

**`value` を流用して「守護は0番」のように持たせない。**どの整数が何を指すかを
呼び出し側が覚えている前提のコードになり、`.tres` を読んでも意味が取れなくなるため。

新しいカードは既存 enum の組み合わせで `.tres` を1個作るだけで追加でき、コード変更を要さない。

### 2.4 `CardInstance`(RefCounted)

場に出ている砂時計1体分の実行時状態。静的データと可変状態を分離する。

| フィールド | 内容 |
|---|---|
| `data` | 参照する `CardData` |
| `health` | 上の部屋に残っている砂。0で破壊 |
| `attack` | 下に落ちた砂。攻撃力そのもの |
| `summoned_this_turn` | 出したターンかどうか(反転も攻撃もできない) |
| `flipped_this_turn` | このターンに反転したか(1体1回) |
| `attacks_this_turn` | このターンに攻撃した回数(連撃なら2回まで) |
| `glass_intact` | 硝子がまだ残っているか |
| `granted_keywords` | 効果で後から与えられたキーワード。`data.keywords` は書き換えない(Resourceは全対局で共有されるため) |
| `silenced` | 効果を消されたか。true の間は `has_keyword()` が常に false を返し、`effects_for()` が空を返す |

**砂の移動を3つのメソッドで区別する。**取り違えるとルールが崩れるため名前で分ける。

- `drop_sand(n)` … 体力-n / 攻撃力+n。**総量は変わらない**(ターン終了の1粒・速落)
- `flip()` … 体力と攻撃力を入れ替える
- `take_damage(n)` … 体力-n のみ。**総量が減る**(GameDesign.md 4章)。硝子が残っていれば
  1度だけ0を返して無効化する

**キーワードの問い合わせは必ず `CardInstance.has_keyword()` を通す。**`CardData` を
直接見ると、後から与えられたキーワード(`GRANT_KEYWORD`)と、消された状態(`SILENCE`)を
取りこぼす。**`CardData.keywords` を書き換えて済ませてはいけない**。`.tres` は
`load()` が同じインスタンスを返すため、1回の対局で書き換えると以後その版の全対局
(リプレイ・シミュレーションを含む)へ残る。

`lifetime_damage()` は `health * attack + health * (health - 1) / 2`(GameDesign.md 1章)。
CPUの評価関数の基礎であり、ロジック層に置いてUI・CPUの双方から使う。

### 2.5 `CardLibrary`(RefCounted, staticのみ)

`data/cards/` を走査してカードを列挙する(`DeckSave` 等と同じ「Autoloadを使わずstaticで
持つ」流儀)。エクスポート後は `.tres` が `<name>.tres.remap` として格納されるため、
**`.remap` を除いた名前で判定し `load()` には元の `.tres` パスを渡す**(5章の既知の不具合。
これを怠るとWeb版でのみ全カードが0件になる)。

一覧の並び替え(GameDesign.md 9章)は `sorted_by_cost()` / `sorted_by_pool_index()` として
ここが持つ。**画面側が比較関数を書かない**(同じ並びを別の画面でも使うときに食い違うため)。
比較そのものは `compare_by_cost()` として公開し、**並べる対象が `all_cards()` ではない画面**
(デッキ編集の編成中の一覧・墓地の中身)も `sort_custom()` へこれを渡す。以前は
その2画面が自前で「コスト → id」の比較を書いており、総量を見ていないぶん**砂術が
同コストの砂時計より前へ出ていた**。
並べ替えは `all_cards()` の複製に対して行い、キャッシュそのものは並べ替えない。

---

## 3. ロジック層

UIに依存しない、対局ルールそのものを扱う層。

### 3.1 `MatchState`(`scripts/logic/match_state.gd`, Node)

対局中の唯一の真実を保持する。旧 `GameState` とは別クラスとして並走させている。

保持するもの:両プレイヤーの `hp` / `mana` / `max_mana` / `deck`(山札)/ `hand` /
`board`(6枠の `CardInstance`、空きは null)/ `graveyard`、`current_turn`、`first_side`、
`turn_count`、`end_reason`、`winner`。いずれも `Side`(A/B)をキーにした Dictionary。

定数は GameDesign.md 2章の数値をそのまま持つ:`INITIAL_HP = 30` / `BOARD_SIZE = 6` /
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

### 3.1.1 砂術(GameDesign.md 6章)

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

### 3.2 `CardEffectResolver`(`scripts/logic/card_effect_resolver.gd`, RefCounted)

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

### 3.3 検証

`tools/tests/v5_rules_tests.gd`(`run_tests.gd` から呼ぶ)が、生涯ダメージの式・砂の3つの
移動・初期手札と先手のドロー無し・空き枠が無い場合に出せないこと・召喚酔いと速落・相打ち・守護/硝子/貫通/
吸命/毒砂/連撃・設置効果6種・反転トリガー・疲労を検証する。`run_tests.gd` は1000行の
上限に達しているため、v5.0 のテストはこの別ファイルへ置く。

---

## 4. シーン構成

責務を小さく分け、UI・ロジック・データを分離する。

### 4.0 対局画面

**子がすべてコード描画の `Control` で Inspector から編集する値を持たないため、
`.tscn` を作らず1クラスの中で組み立てている**(画像や配置を差し替える余地が無く、
`.tscn` にしても編集する対象が存在しないため)。

| クラス | 責務 |
|---|---|
| `CardView`(`scripts/ui/card_view.gd`) | カード1枚の表示。**守護の枠の強調は `guard_frame` で切る**(砂時計一覧・デッキ編集は false。GameDesign.md 9章)。**手札と場で見た目を変える**(GameDesign.md 9章)。`Mode.HAND` はカードの枠を持ち **コスト=左上 / 総量=右下**、`Mode.BOARD` は**枠を持たず、丸い台座の上に立つ砂時計そのもの**として描き **攻撃力=左下 / 体力=右下**(コストは出さない)。体力と攻撃力の比で3枚のイラストを切り替え、守護は手札なら枠・場なら台座の輪を太くし、硝子は手札なら枠の内側・場ならガラスへ薄い膜を重ねる。**カード固有の紋章**は、場は台座の正面のメダル(`_draw_pedestal_plaque()`)、手札は左下の封蝋(`_draw_hand_seal()`)として出す |
| `BoardTable`(`scripts/ui/board_table.gd`) | 盤面12枠を載せる卓上。奥へ狭まる石と真鍮の台形を描き、中央に区切り線と紋章を置く。v1.0から流用しているが、v5.0では6+6枠を1枚の卓へ載せるために使う |
| `PlayerInfoBar`(`scripts/ui/player_info_bar.gd`) | 片方のプレイヤーの情報帯。HP・マナ(数字+ピップ)・山札・墓地・(相手のみ)手札の枚数・コインの有無 |
| `CardMatchSelection`(`scripts/ui/card_match_selection.gd`) | いま選んでいるもの(手札の1枚 / 自分の場の1枠 / 未選択)。選択の状態を1箇所へ集めて画面側の分岐を減らす |
| `CardMatchScreen`(`scripts/ui/card_match_screen.gd`) | 上記を並べ、`MatchState` と同期し、操作(出す/反転/攻撃/コイン/ターン終了/投了)を受ける |
| `CardMatchMulligan`(`scripts/ui/card_match_mulligan.gd`) | 対局開始前のマリガン画面。暗幕の上へ初期手札を並べ、選んだ枚数を `mulligan_confirmed(indices)` として返すところまでが責務で、適用は `MatchState` が行う |
| `CardMatchLog`(`scripts/ui/card_match_log.gd`) | 対局ログ。`MatchState` のシグナルを購読して日本語の行を積み、中央のモーダルとして開く。**記録と表示を同じクラスに持たせている**のは、実況に出す文と読み返す文を必ず一致させるため |
| `CardMatchTurnFeed`(`scripts/ui/card_match_turn_feed.gd`) | 手番バナー・相手の1手の実況・スポットライト。**ログと同じ文言**を `CardMatchLog.describe()` から引く |
| `CardMatchStrike`(`scripts/ui/card_match_strike.gd`) | 攻撃の演出の進行役。被ダメージの砂の飛散を**当たる瞬間まで持ち越す**。砂の演出(`unit_damaged`/`unit_ticked`)の受け口も持つ |
| `CardMatchShake`(`scripts/ui/card_match_shake.gd`) | 当たった瞬間の盤面の揺れ(GameDesign.md 9章)。**卓と場の駒だけ**を動かす |
| `CardMatchEffects`(`scripts/ui/card_match_effects.gd`) | 攻撃以外の演出の進行役(設置の着地 / 破壊の崩落 / 設置効果の光の筋 / 硝子の割れる閃光 / ドローと疲労の山札の脈打ち)。`CardMatchSound` と同じく `MatchState` のシグナルだけを見る |
| `CardUnitFx`(`scripts/ui/card_unit_fx.gd`) | `CardView` の子として駒へ重ねる演出のうち、**盤面の状態を一切参照しないもの**(着地・崩落・硝子の閃光)。いずれも起きた瞬間に渡された引数だけで完結する |
| `CardMatchSound`(`scripts/ui/card_match_sound.gd`) | 対局中の効果音(GameDesign.md 9章)。**画面側の操作ではなく `MatchState` のシグナルだけを見て鳴らす**。自分の手・CPU・オンラインで届いた手・リプレイの再生はいずれも `MatchAction.apply()` を通って同じシグナルを出すため、経路ごとに鳴らし忘れる余地が消える |
| `CardMatchTargets`(`scripts/ui/card_match_targets.gd`) | 置ける枠・殴れる相手の強調と、相打ちの予測 |
| `CardMatchResult`(`scripts/ui/card_match_result.gd`) | 結果パネル。勝敗・最終HP・総手数・決着の要因と「ログ」「ホームへ」 |
| `CardDeckListScreen`(`scripts/ui/card_deck_list_screen.gd`) | 保存済みデッキの一覧。**管理と対局前の選択を1つの画面が兼ねる**(4.5節) |
| `CardDeckEditorScreen`(`scripts/ui/card_deck_editor_screen.gd`) | デッキ編集(30枚・同名2枚まで)。共通の `ScreenHeader` を使う |
| `CardDeckSheet`(`scripts/ui/card_deck_sheet.gd`) | 共有用のデッキ表(GameDesign.md 9章)。**画面に置かず `SubViewport` の中だけで生きる**。`CardDeckShelf` を `readonly` の横10列にして敷き、作品名・バージョンを添える |
| `CardDeckSharePanel`(`scripts/ui/card_deck_share_panel.gd`) | デッキの受け渡し。**デッキ表の画像とデッキコードを1つのパネルにまとめる**(旧 `CardDeckCodePanel`) |
| `CardDeckFilter`(`scripts/ui/card_deck_filter.gd`) | 一覧の絞り込み(コスト・キーワード・名前)。条件の合成を1箇所へ集める |
| `CardListScreen`(`scripts/ui/card_list_screen.gd`) | カード一覧。選ぶと右の詳細パネルへ出す。ヘッダーの主アクションのボタンで並び順(コスト順 / 追加順)を往復する |
| `CardDetailPanel`(`scripts/ui/card_detail_panel.gd`) | カード1種の詳細。**キーワードは名前と説明の両方**を出す(語だけでは初見に伝わらない)。イラストの下に `CardEffectPreview` を挟む。**`SUMMON` を持つカードには、出るトークンの名前・総量・効果を1行で添える**(トークンは一覧に出ないため、ここで説明しないと調べる手段が無い。GameDesign.md 6章) |
| `CardEffectPreview`(`scripts/ui/card_effect_preview.gd`) | 能力の実演。**カードごとではなくキーワード / 効果の種類ごとに1本**の台本を持つ(下記) |
| `InkFigure`(`scripts/ui/ink_figure.gd`, staticのみ) | 実演の図版を紙のインクで描く部品(砂時計・HPバー・矢印・守護の輪・硝子の膜・砕けた印)。`UiPaint` と同じ流儀で、**第1引数に描画先の `CanvasItem`** を取る |
| `CardDeckShelf`(`scripts/ui/card_deck_shelf.gd`) | 編成中のデッキを**30枠の決まった棚**として描く(GameDesign.md 9章)。1つの `Control` が全枠を描き、当たり判定を矩形の表として持つ |
| `EmblemSeal`(`scripts/ui/emblem_seal.gd`, staticのみ) | カード固有の紋章を「押した印」として描く。**カードを並べる3画面(図鑑の一覧・工房の在庫棚・編成中の棚)で共有する**——別々に描くと必ず片方だけ古くなる。`InkFigure` と同じく第1引数に `CanvasItem` を取る(紋章はテクスチャのため `draw_texture_rect()` を使う) |
| `CardPileViewer`(`scripts/ui/card_pile_viewer.gd`) | 墓地の中身を見るモーダル。同じカードは1枚にまとめて枚数をバッジで出す |
| `CodedButton`(`scripts/ui/coded_button.gd`) | コードで組むボタンの生成を集約する。画面ごとに `theme_override` を並べると指定漏れのボタンが混ざるため |
| `CardViewStrike`(`scripts/ui/card_view_strike.gd`) | 攻撃の演出の段取り(寄る→溜める→当てる→戻る)。**`CardView` が1000行の上限に達したため切り出した**。分ける線は「駒の見た目」と「殴りに行く段取り」に引き、状態(offset / angle / flash)と描画は `CardView` 側に残す(絵に掛ける変換は描画のたびに要るため) |
| `CardMatchReplay`(`scripts/ui/card_match_replay.gd`) | リプレイの再生コントロール。**任意の手数の局面は初期状態から手を並べ直して作る** |
| `CardMatchOnline`(`scripts/ui/card_match_online.gd`) | オンライン対戦の3つの入口(開始・切断からの復帰・観戦)。`card_match_screen.gd` が1000行の上限に達したため切り出した。画面側には `main.gd` から呼ぶ薄い委譲だけが残る |

**砂術は `CardView.Mode.HAND` の中の分岐として描く**(GameDesign.md 9章)。
`Mode.SPELL` を足さないのは、**砂術に「場での見た目」が存在しない**ため。
モードは「手札か場か」を表す軸であり、そこへカードの種類を混ぜると、
`Mode.SPELL` と `Mode.BOARD` の組み合わせという有り得ない状態が表現できてしまう。
違いは3つだけで、いずれも `card.is_spell` を見て切り替える。

- 砂時計の絵を描かず、**紋章を中央へ大きく**置く
- **総量のバッジを出さない**(コストの左上だけ)
- 枠の色を変える(`UiPalette` へ砂術用の1色を足す)

**砂術は空き枠が無くても暗くしない**(GameDesign.md 6章の例外)。
`CardMatchScreen` が手札の暗転を決めるときに `is_spell` を見て枠の判定を飛ばす。
押したときは枠の強調ではなく、対象を取る砂術なら対象選択(`CardMatchSelection.TARGETING`)へ、
取らないならその場で `cast_spell()` を呼ぶ。

**砂時計の絵は、枠へ引き伸ばさず縦横比のまま収める**(`CardView._fit_art()`)。絵のキャンバスは
400x513(`state_falling` だけ 415x532)で、正方形の枠へ `draw_texture_rect()` すると横に潰れる。
枠の下端で揃えて横は中央へ置き、台座に立って見えるようにする。**倍率は3状態のうちいちばん高い
キャンバスを基準に共通化する**。状態ごとに自分の高さで割ると、キャンバスが数%大きい
`state_falling` に切り替わった瞬間だけ絵が縮んで見えるため。**ドラッグ中のプレビューも同じ
大きさで作る**(カードの枠 118x168 に合わせると、掴んだ瞬間に絵が膨らんで見える)。

**対局画面の右端 148px は行動の列とし、盤面・情報帯・手札はその手前で止める。**
反転・コイン・ターン終了・ログ・投了をこの1列へ縦に並べる。以前はログと投了だけが
手札の右隣にあり、そのぶん手札の領域が左へ寄って、盤面の駒の列と手札の中心が94pxずれていた。
情報帯も両者とも同じ幅(`BAR_WIDTH`)にして、対面させた2本の帯の右端を揃える。

**対局中のカード詳細・攻撃の予測・ホバーの拡大・ドラッグでの設置**(GameDesign.md 9章)は、
いずれも新しいクラスを足さずに既存のものへ寄せている。

- 詳細は `CardDetailPanel` を `interactive = false` で使い、**手札・自分の駒・相手の駒に
  カーソルを乗せている間**だけ、指しているカードと反対の端へ出す(GameDesign.md 9章)。
  盤面の左右の余白は190pxしかなく、卓へ重ねる以外に置き場が無い。
  **`interactive = false` のパネルは語のボタンと実演を持たない**ため、カーソルを
  動かして触る先が無く、外れたら消える形が成立する
- **出し消しは `CardMatchDetail`(`scripts/ui/card_match_detail.gd`、`_screen` 参照を持つ
  `RefCounted`)が持つ。**`card_match_screen.gd` が1000行の上限に近いための切り出しで、
  「いま出してよい状態か」(対象選択中・マリガン中・演出中でないか)の判定と、
  外れてから消すまでの猶予(`HIDE_DELAY`)、置き場の計算をここへ集める
- **置き場は指しているカードから対角**(`_place()`)。左右は反対の端(右へ出すときは
  行動の列の手前で止める)、上下は反対の段。**縦は卓(`TABLE_RECT`)の範囲へ収め、
  上下の情報帯には掛けない**(GameDesign.md 9章)。幅は340pxで、
  `CardDetailPanel.compact_width` として渡す
- **`CardMatchScreen` の const を `CardMatchDetail` の const から参照しない。**
  互いを参照する定数になり、**読み込みが循環して起動が固まる**(実際にそうなった)。
  卓の矩形と行動の列の位置は `_place()` の中で実行時に読む
- **`_detail` は `_build()` の途中で作るため、駒より後に用意される。**ホバーの受け口は
  `_on_view_hovered()` / `_on_view_left()` という関数にして、その時点の `_detail` を読む
  (生成時に `_detail.hover` を束ねると、まだ空の参照を掴んで駒が1つも作れなくなる)
- 予測は `MatchState.combat_preview()`(盤面を変えずに戦闘の結果だけを計算する)が返し、
  `CardView.preview_health` として体力のバッジの真下へ出す。**判定の順序は
  `_resolve_unit_combat()` と同じにすること**(硝子→毒砂)。攻撃側の予測は狙える相手が
  複数いると1つに定まらないため、**最も自分が削られる組**を出す(安全に見えて実は死ぬ、
  という取り違えを避けるため)
- ドラッグは `CardView` が `_get_drag_data()` / `_drop_data()` を持ち、枠側は
  `drop_handler`(Callable)で受ける。放されたら押して枠を選ぶ経路と同じ `_play_selected()`
  へ合流するため、設置効果の対象選択もそのまま働く
- **タッチ操作のゆらぎ吸収(`PressTracker`)**: スマホ等でのタップ時に指先がわずかに動いても
  キャンセル扱いにならないよう、8pxの許容マージン(`SLOP_MARGIN`)を持って判定する。また
  `InputEventScreenTouch` も直接受け取れるようにする

**「反転」だけは選んだ駒のすぐ下へ出し、他の行動(コイン・ターン終了・ログ・投了)を
画面右の列にまとめる**(GameDesign.md 9章)。反転は盤面の1体を指した操作であり、
右の列まで視線とカーソルを往復させると遠い。位置は `_refresh_buttons()` が毎回
`_flip_button_position()` から決める。**上ではなく下へ出す**のは、自分の場の上が
相手の場であり、以前ここで**相手のカードへ重なった**ため(実際にレンダリングして発覚した)。
駒の下端(y=436)と自分の情報帯の中身が始まる位置(y=464)のあいだへ収まる高さ
(`FLIP_BUTTON_SIZE`)にして、HP・マナ・山札を隠さない。

**選択中の枠は水色、守護の枠は真鍮色**と系統を分ける。どちらも「枠を強調する」表現のため、
同系色にすると取り違える。

**総手数は `MatchState.turn_count` をそのまま使う。**UI側で「ターン終了を押した回数」を
数えると、CPU同士で進めた場合や将来のリプレイ再生で0手になる(実際に検証中そうなった)。

**ログは結果パネルより後に `add_child()` する。**終局後は結果パネルが盤面全体を塞ぐため、
その上からログを開けないと読み返せない(GameDesign.md 9章)。

**v5.0のオンライン対戦は、山札の並びを「種」で共有して両者が同じ対局を再現する。**
配置フェーズが無いため、`OnlineSetup.push_setup()` / `wait_for_opponent_setup()` で
デッキ(30枚のid)と `seed` だけを交換し、そのまま `MatchState.start_match()` へ入る。
1手の送受信は v1.0 と同じ `matches/{id}.actions` をそのまま使い、適用は
`MatchAction.apply()` が受け持つ(`OnlineMatch.send()` は型に依存しないためそのまま流用できる)。

> **既知のトレードオフ:** 種を共有すると、改造したクライアントは相手の山札の並びと手札を
> 手元で計算できる。「サーバー側での正当性検証は行わない」という方針(GameDesign.md 11章)の
> 範囲として許容しているが、**不正対策を入れるときはここが最初の対象になる**。

**自分の1手は必ず `CardMatchScreen._perform()` を通す。**適用と送信をここ1箇所に
まとめることで、送信し忘れる操作の経路が生まれないようにしている。

**リプレイは局面のスナップショットを持たない。**棋譜は「両者のデッキ・種・手の並び」だけで、
巻き戻しは初期状態から手を並べ直して作る(v5.0はシャッフルが種から決まるため成立する)。
`Main._on_replay_selected()` は**棋譜が `seed` を持つかどうか**で v5.0 と v1.0 の
再生先を振り分ける。再生中は `_interactive = false` で操作をまとめて塞ぎ、
結果パネルも出さない(最後の手まで進めるたびに操作を塞ぐと前後に動かせなくなるため)。

**反転の段取りは `CardFlipBeam.play_flip()` が持つ**(光の筋と駒の裏返りが対になっており、対局画面へ置くと1000行の上限を圧迫するため)。**反転の演出は `CardFlipBeam`(光の筋)と `CardView.play_flip()`(駒の裏返り)の2段で作る。**
`MatchState.unit_flipped` を受けて、まず反転した側の情報帯から対象の駒へ光の筋を伸ばし、
届いたところで駒を持ち上げて裏返す。**光の筋は対局画面の `_draw()` ではなく独立した
オーバーレイのノードとして持つ**。`Control._draw()` は自分の子より背面に描かれるため、
画面側で描くと卓と駒に隠れて筋がほとんど見えない(実際にそうなった)。

**攻撃は `CardView.play_strike()` が駒そのものを動かして見せる**(GameDesign.md 9章)。
「寄る → 溜める → 当てる → 戻る」の4段を1本の `Tween` で組み、**駒は上端を支点に振れる**
(`_strike_pivot`)。`Control` の `pivot_offset` は回転と拡縮の両方に効いてしまうため、
描画側で上端を中心にした変換を掛ける。攻撃側だけが渡っていき、**防御側は当たった瞬間に
`play_shatter()` と小さな揺れで受ける**。攻撃の解決そのもの(`MatchState.attack()`)は
演出を待たず即座に済ませ、**演出は結果を後から見せるだけにする**。ロジックを演出の完了へ
依存させると、リプレイ・観戦・CPUの連続着手がすべて演出の尺に縛られるため。

**当たった瞬間の盤面の揺れは `CardMatchShake` が持つ**(GameDesign.md 9章)。
`CardMatchStrike._on_impact()` が、砂の飛散・持ち越した音と同じこの1点から呼ぶ。

- **揺らす対象は `bind()` で登録した卓と場の駒だけ**とし、情報帯・手札・行動の列は入れない。
  HP・マナ・山札は判断のために読み続けるものであり、攻撃のたびに揺れると読めなくなる
- **基準位置を控えてから `base + offset` を書く。**毎フレーム `position` へ足す形にすると
  揺れが累積して元の位置へ戻らない。**登録できるのは位置が後から変わらないものだけ**で、
  毎ターン並べ替わる手札は構造的に対象にできない
- 強さは当てた駒の攻撃力から決める。値は `CardMatchStrike.capture()` の時点で控える
  (適用後は倒された駒が盤面から消えており、攻撃力を引けない)
- **揺れている最中に次の攻撃が当たったら、振れ幅は足さずに大きいほうで上書きする。**
  連撃や6枠が並ぶ中盤で累積し、盤面がぶれ続けるのを防ぐ

**砂の演出は2種類を別のシグナルで受ける。**`MatchState` は被ダメージを `unit_damaged`、
ターン終了の1粒を `unit_ticked` として別々に発行し、`CardView` が
`play_shatter()`(砕けて外へ散る・赤)と `play_drop()`(下の部屋へ流れる・琥珀)で描き分ける。
**この2つを取り違えるとルールを誤解する**(前者は総量が減り、後者は総量が変わらない)ため、
演出上もっとも重要な区別として扱う(GameDesign.md 9章)。同じシグナルに相乗りさせない。

**攻撃以外の演出は `CardMatchEffects` が1箇所で受ける**(GameDesign.md 9章)。
`MatchState` へ足した5つのシグナル(`unit_shielded` / `cards_drawn` / `fatigue_damage` /
`effect_targeted` と既存の `unit_played` / `unit_destroyed`)だけを見て、
着地・崩落・光の筋・硝子の閃光・山札の脈打ちを出す。**攻撃の演出中に起きたぶんは
当たる瞬間まで持ち越す**(`CardMatchStrike._on_impact()` が `flush()` を呼ぶ)。
解決と同時に見せると、駒がまだ渡っている最中に相手が砕け始めるため。

**破壊の演出は「絵を縦に3つへ割って左右へ落とす」形にする。**割れ目を線で描いて薄くする
だけでは、絵が消えかけただけに見えて「壊れた」と読めなかった(実際に描画して確認した)。
**枠が空になった後も描き続ける**ため、`CardView.play_break()` は `CardData` を受け取って
絵と矩形をその時点で `CardUnitFx` へ渡す(次の同期で `card` は null になる)。

**硝子が割れたことは、与ダメージが0かどうかでは分からない**(膜が吸った場合も、
攻撃力0の駒に殴られた場合も0)。`MatchState` は受ける前の `glass_intact` を控えておき、
消えていたときだけ `unit_shielded` を出す。

**光の筋(`CardFlipBeam`)は同時に何本でも出せる**。全体に効く効果(スイープ)が対象の数だけ
伸ばすため、1本ぶんの状態ではなく `_beams` の配列として持つ。**進捗は Dictionary の要素**に置く
(ラムダは外側のローカル変数を値でキャプチャするため。11章)。色は反転=金 /
効果=対象に応じた色(相手なら赤・味方なら緑)で分ける。

**`effect_targeted` は効果を適用する直前に出す。**破壊のように対象が盤面から消える効果でも、
筋の行き先がまだ残っている状態で受け取れるようにするため。**余砂は既に盤面から降りており
出どころの枠が無い**(`_slot_of()` が -1 を返す)ので、その場合は筋を出さない。

**設置効果の対象選択**は `CardMatchSelection.TARGETING` として持つ。カードを出す枠まで
決めた時点でいったん止め、相手のカードを押すと `play_card()` の `target` へ渡して確定する。
相手の場が空のときは選ばせる意味がないためそのまま出す。案内は**行動ボタンの列へ出す**
(盤面へ重ねると、選ばせたい相手のカードそのものを隠してしまう)。

`Main` は `card_match_screen` を `_ready()` で生成して `_screens` へ加える(`.tscn` を
持たないため)。**対局(ランダムマッチ / ルームマッチ / CPU戦)はいずれも、開始の前に
デッキ選択画面(`CardDeckListScreen` の PICK モード)を挟む**。`Main._request_battle()` が
待たせる導線を `Callable` として控え、選ばれた時点で `CardDeckSave.set_selected_index()` を
書いてから呼ぶ。**保存済みのデッキが1つも無いときだけ選択画面を挟まない**(選ぶ対象が
存在せず、プリセットの「基本」で入るため。GameDesign.md 18章)。デッキは
`CardDeckSave`(`user://card_decks.json`、v1.0の `DeckSave` とは形式が違うためファイルを
分ける)の `selected_deck()` から読む。

**能力の実演(`CardEffectPreview`)は、カード1枚ずつではなく語彙ごとに台本を持つ**
(GameDesign.md 9章)。`show_card()` が `CardData` から
「named/plain キーワード → `Trigger.ON_FLIP` → `effects` の `EffectType`」の順に
台本(`Script` enum)の並びを組み、能力を持たないカードには基本の砂の動きの台本を当てる。
**カードが増えても、既存の語彙の組み合わせであれば実演は自動的に付く**ため、
新しい `.tres` を1個作るだけで済むという運用(1章)を崩さない。

**台本は「何が起きるか」だけを書き、「いつ起きるか」は書かない。**設置・反転・余砂で
同じ効果が載ることがあるため、台本が `stage["trigger_note"]` へ効果の中身だけを置き、
`_stage()` が entry の `trigger` から「場に出したとき」「反転したとき」「壊れたとき」を
前へ付ける。**これを怠ると、余砂のカードの実演が「場に出したとき、カードを1枚引く」と
嘘を言う**(スプラウトを足した時点で実際にそうなった)。トリガーを持たない実演
(守護・硝子など)は従来どおり `stage["note"]` へ完成した文を置く。

台本は「時刻 → 盤面の状態」を返す純粋な関数として書き、`_process()` で進めた
経過時間だけを状態として持つ。駒は `CardView` を流用せず**この中で簡略化して描く**
(実演で見せたいのは体力・攻撃力・砂・矢印の動きだけで、紋章や台座は情報を増やさないため)。

**描くのは紙のインクの図版**(GameDesign.md 9章)で、部品は `InkFigure` が持つ。

- **部品の組み合わせだけで図版を組めるようにする。**新しいキーワードが増えても、
  部品を1つ足せば台本が書ける状態を保つ(カードを毎日足す運用のため)
- **`InkFigure` は `UiPaint` と同じく static だけを持ち、第1引数に描画先を取る。**
  実演は `Control._draw()` からしか呼ばれないため RID ではなく `CanvasItem` を受け、
  `draw_polyline()` などをそのまま使う
- **砂時計の下の部屋の砂は台形で描く。**器が下へ広がっている以上、底は必ず満杯であり、
  三角形にすると砂が宙に浮いた山に見える(実際に描いて気づいた)
- **基本の砂の実演は1粒ずつ落とす。**飛ばして描くと「毎ターン1粒」というルールと
  食い違う。間を省くときは矢印ではなく「…」でつなぐ

**デッキ編集は「左=全カードのグリッド / 右=編成中のデッキ」の2カラムで組む**
(GameDesign.md 9章)。左は絞り込みの列(`CardDeckFilter`)+ 名前の検索欄 + `GridContainer`、
右は `PanelContainer` の中にデッキ名・枚数・`CardDeckShelf`(30枠の棚)の並び。
**以前は一覧を画面下部の横1行の横スクロールに置いていた**が、カードが増えるほど
目的の1枚へ届くまでの横送りが伸びるため、グリッド + 絞り込みへ変えた。

- **絞り込みと検索はモーダル(`CardDeckFilter` / `CardDeckFilterModal`)が集約して持つ。**
  画面上部にずらっと並べていたチップをモーダルダイアログへ移し、左カラム上の「絞り込み」ボタンから
  開く形にした。コスト・キーワード・名前の3条件を `matches(card)` として合成し、画面側は
  `changed` を受けて並べ直す。適用中の条件数がある場合はボタンにバッジを表示し、一括リセットも備える
- **編成中のデッキは `CardDeckShelf`(`scripts/ui/card_deck_shelf.gd`)が30枠の決まった棚として
  描く**(GameDesign.md 9章)。1枚ずつの `Control` を30個並べるのではなく、
  **1つの `Control` が全枠を `_draw()` で描き、当たり判定は矩形の表として持つ**。
  30個のノードを作ると、枚数を1枚動かすたびに生成と破棄が走る
  - **枠の数は `MatchState.DECK_SIZE` から実行時に読む**(横 `COLUMNS`=6、縦はその商)。
    定数へ焼くと、2章の枚数を動かしたときに棚だけが古い形のまま残る。
    **const から他クラスの const を参照しない**という制約(11章)にも掛かる
  - **枠の大きさは全枠そろう。**段ごとに詰め方を変えていた頃は、1枚動かすだけで
    駒の大きさが変わって落ち着かなかった
  - **空き枠も1つの枠として描き、当たり判定にも積む**(押しても何も起きない)。
    描く位置と押せる位置を同じループで決めないと、必ずどこかで食い違う
  - **バッジの半径は駒に比例させる**(`clampf(art_w * 0.20, 8, 13)`)
  - **共有のデッキ表(`CardDeckSheet`)も同じ棚を使う。**変えるのは `columns`(10)と
    `readonly`(ホバーも押下も受けない)の2つだけで、**共有のためだけの並べ方を作らない**
- **詳細(`CardDetailPanel`)は `interactive = false` で持ち、一覧のカードや編成中の駒へ
  カーソルを乗せている間だけ出す**(GameDesign.md 9章)。幅は右カラムぶん(400px)で、
  `compact` の中身は縦積み。**出す位置は `CardDetailPanel.place_near()` が決める**
  (カーソルの右下を既定に、はみ出す側だけ折り返す)。**置き場の規則を画面ごとに持たない**——
  対局画面も同じ関数を通し、収める範囲(`bounds`)だけを画面が渡す。
  パネルは `MOUSE_FILTER_IGNORE` でホバーを奪わないため、
  カーソルの近くへ出しても出し消しを繰り返さない。外れてから消すまでの猶予は
  対局画面と同じ理由で置く
- **左右のカラムは共通ヘッダーが決めるコンテンツ領域(`ScreenHeader.CONTENT_TOP` / `CONTENT_HEIGHT`)へ揃える**(`GRID_RECT` / `SIDE_RECT`)。**高さを画面ごとに数えない**(以前は584pxと直に書いてあり、実際のコンテンツ開始位置(y=136)と食い違って下端の外周余白24pxが消え、一覧の最下段が画面の端で切れていた)。
  以前は絞り込み列のぶん左側だけ下がり、右側上部に46pxの余白ができていたが、モーダル化により
  左右の高さが揃い、一覧グリッドも縦幅が広がってカードを探しやすくなった
- **編成中の欄は上から「デッキ名・枚数 / 30枠の棚」とする**。
  **マナカーブの棒グラフは持たない**(GameDesign.md 9章)。並びがコスト順に固定されている
  ため、`CardManaCurve` と `CardDeckBand` は参照0件になり削除した
- **「あと何枚」の帯も持たない**(GameDesign.md 9章)。空いている枠の数がそのまま残りであり、
  帯を出すと**そのぶん棚の高さが減って、足りているときと足りないときで駒の大きさが変わる**

一覧のカードには `CardView.badge` で「2/2」を出し、入れられないカードは暗くする。
**保存は30枚ちょうどのときだけ通す**(枚数が足りないデッキで対局へ入れないようにするため)。
編集画面は**必ずデッキ一覧から開く**ため、`open(index)` で何番目のデッキを編集するのかを
受け取り(-1 は新規作成)、閉じたら一覧へ戻る。デッキ名の入力欄は編成中の欄の上端へ置く
(共通ヘッダーの右側は保存・プリセット・コードで埋まっており、入力欄を足すと画面タイトルへ
食い込む)。
**ボタンの既定の文字色は共通テーマ側で明るくしてある。**`main_theme.tres` の
`Button/colors/font_color` は画像ボタン時代(明るい真鍮の面)に合わせた黒に近い色だったが、
コード描画のボタンは中央パネルが暗いスレートのため、その色では文字が沈んで読めない。
画面ごとに `theme_override_colors/font_color` を足して回る対症療法になっていたので、
**テーマの既定をオフホワイトへ変えた**(指定を書き忘れた画面だけ黒い文字になる状態を無くすため)。
`font_hover_color` だけは暗いままにしてある。ホバー時はパネルが明るい琥珀へ変わるため。

`CardMatchScreen.start_cpu_match()` が `MatchState` を生成し、CPUの手番は `Timer` で
`CPU_THINK_SECONDS` の間合いを置いてから `CardCpuStrategy.choose_action()` を1手ずつ適用する
(1手ずつなのは、まとめて指すと何が起きたか追えないため)。

```
Main
├── TitleScreen              # 起動して最初に出る画面。押すとホームへ移る
├── HomeScreen               # 下部3ボタン(ルール/デッキ/バトル)で機能を切り替える
├── ReplayListScreen         # 保存済みリプレイの一覧
├── AccountScreen            # アカウント(14章)
│   (上記のうち対局画面を除く各画面は、先頭の子として共通の ScreenHeader を持つ)
├── CardMatchScreen          # 対局・観戦・リプレイ再生(コードで組み立てる。4.0節)
├── CardDeckListScreen       # デッキ一覧 / 対局前のデッキ選択(同上。4.5節)
├── CardDeckEditorScreen     # デッキ編集(30枚・同名2枚まで。同上)
├── CardListScreen           # カード一覧(同上)
├── RuleScreen               # ルール(遊び方)の紙芝居(同上。4.2節)
├── KeywordDictScreen        # キーワード辞書(同上。4.3節)
└── CardRoomScreen           # ルームマッチ(同上。6.5節)
```

**v1.0(位相制)の画面と、それを支えていたクラスは削除済み。**`MatchScreen` 一式・
`GameBoard`/`HourglassSlot` 系・`DeckListScreen`/`DeckEditorScreen`/`HourglassListScreen`/
`BattleDeckPickerScreen`、および `GameState`/`EffectResolver`/`HourglassData`/`SkillData`/
`MatchSetup`/`DeckSave`/旧CPU戦略と `data/hourglasses/*.tres` を撤去した。
**v1.0の棋譜は再生できなくなったため、`ReplayListScreen` は `seed` を持つ棋譜だけを一覧に出す**
(記録そのものは消していない)。

- `TitleScreen`(`scenes/title_screen.tscn`/`scripts/ui/title_screen.gd`):起動時に出る入口の画面(GameDesign.md 9章)。背景・ロゴ・「クリックしてはじめる」の3要素だけを持ち、押されたら`start_requested`を出すところまでが責務で、遷移の演出は`Main`が持つ。ロゴは`assets/title/logo.png`があればそれを、無ければ`TitleLogo`のコード描画を表示する(`ResourceLoader.exists()`で分岐する。`preload`だとファイルが無い時点でコンパイルが通らないため)。背景も同様に`assets/backgrounds/processed/title/background.png`があればそれを、無ければホーム画面のものを流用する
- `TitleLogo`(`scripts/ui/title_logo.gd`、`Control._draw()`のみのコード描画):ロゴ画像が未配置のときの代替表示。金の面と影を1pxずらして重ね、濃紺の`draw_string_outline()`で縁取る。色は`UiPalette`経由
- `SandTransition`(`scripts/ui/sand_transition.gd`、`Control._draw()`のみのコード描画):タイトルからホームへ移るときだけ使う専用トランジション(GameDesign.md 9章)。`Main`が`_ready()`で1個生成して最前面へ置き、`cover()`(砂が上から降りて画面を覆う)と`reveal()`(砂が下へ抜ける)をawaitして使う。砂の層は、砂面を`EDGE_SEGMENTS`分割した折れ線と奥側の辺で作る四辺形へ**頂点カラーのグラデーション**を乗せて塗る(段ごとの単色塗りだと境目が縞に見えるため)。**アンカーは`set_anchors_preset()`ではなく`anchor_right`/`anchor_bottom`への直接代入で設定する**。`set_anchors_preset()`は「今の矩形を保つように」offsetを計算し直すため、コードで生成した直後(サイズ0)のノードへ使うと0サイズのまま固定され、何も描かれない。砂が出ている間は`mouse_filter = STOP`で下の画面の操作も塞ぐ
- `Main`:画面切り替え(`_show_only()`)はハードカットではなくクロスフェードで行う。**ただしタイトル→ホームだけは`_on_title_start_requested()`が「ロゴの演出→`SandTransition.cover()`→`_show_only()`→`SandTransition.reveal()`」の順に進める**(クロスフェード自体は砂の下で起きるため見えない)。表示中の画面と次の画面の`modulate:a`をTweenで補間し、実行中のTweenは新しい遷移の開始時に必ずkillしてから作り直すことで連打・割り込みに耐える。遷移中は透明な`ColorRect`ブロッカーを最前面に重ねて全画面の入力を塞ぐ。**v5.0の3画面は`.tscn`を持たないため`_ready()`で生成して`_screens`へ加える**
- **ホーム画面のタブ(`DeckTab` / `BattleTab` / `RulesTab`)は、上端112pxをアカウント帯のために
  空け、残りの領域の中央へ内容を置く**。ContentArea の高さは下部タブを除いた560pxしかないため、
  ここを守らないと内容が画面の外(上はアカウント帯の裏、下は下部タブの裏)へ出る。実際に
  ルールタブは先頭のボタンが画面上端で切れ、バトルタブは最終行が下部タブへ潜り込んでいた
- `ScreenHeader`(`scenes/screen_header.tscn`):対局画面を除く全画面が使う共通ヘッダー。外周余白24px・ヘッダー高88px・コンテンツ開始y=136をこの1箇所で決め、画面ごとに個別の値を持たせない(GameDesign.md 9章)
- クリック可能な各コンポーネント(`CardView`/`ReplayListCard`/`ClickArea`)は、押下確定の判定を `PressTracker`(RefCounted、押下→離した位置が要素内かどうかで確定/取消を返す)で共通化する

- `resources/theme/content_panel.tres`(`StyleBoxFlat`):一覧・詳細・モーダル向けの汎用コンテンツパネル。背景イラストの上に情報を置く各画面(デッキ一覧・デッキ編集・砂時計一覧・配置画面・リプレイ一覧等)の主要ブロックに共通適用する
- **UIクローム(ボタン・パネル枠・入力欄・棚板・名札等)はコード描画で作る**(GameDesign.md 9章)。以前は画面グループ単位のボタンシート画像を生成し `StyleBoxTexture` として割り当てていたが、品質管理のしやすさを理由に方針転換した。テキストは従来どおり画像・描画に焼き込まず `Button.text` をプロジェクト共通フォントで重ねる
- コード描画の実体は以下の3層に分ける。画面ごとに描画コードを書き散らさず、必ずこの共通層を経由させる
  - `scripts/ui/styles/ui_palette.gd`(`UiPalette`, `RefCounted`):プロジェクト全体のUI色の単一情報源。真鍮の明/中/暗、暗い下地、琥珀アクセント、無効時のグレー等をconstで持つ
  - `scripts/ui/styles/ui_paint.gd`(`UiPaint`, `RefCounted`):static関数だけの描画ユーティリティ。**第1引数は必ず `ci: RID`** とし `RenderingServer.canvas_item_add_*` 系で描く(`StyleBox._draw(to_canvas_item, rect)` からは `CanvasItem.draw_*` を呼べないため)。角丸矩形の頂点生成、多段階の縦グラデーション塗り、面取り(ベベル)、内側の落ち込み影、グレイン(ノイズ)重ねを提供する
  - 各`StyleBox`派生クラス(`CodedButtonStyle` 等)と、`Control._draw()`側(`BoardTable`/`BarPanel`/`HourglassSlot`)が、いずれも上記2つを呼んで描く
- **背景イラストを持たない画面(対局・カード一覧・デッキ編集)の下地は `ScreenBackdrop`
  (`scripts/ui/screen_backdrop.gd`、`Control._draw()` のみ)に集約する**。無地の `ColorRect` 1枚だと
  フラットベクターに見えるため、多段グラデーション + グレイン + 左右の落ち込みを掛ける。
  画面ごとに下地の色と描き方を持たせない
- **共通ヘッダー(`ScreenHeader`)はタイトルの後ろへ暗幕を敷き、下端に真鍮の細線を通す**。
  背景イラストが賑やかな画面(アカウント・リプレイ一覧)で画面名が読めなくなるため。暗幕は
  中央が濃く左右へ消える形にする(端まで一様に敷くと帯が1本乗ったように見える)。
  `Control._draw()` は自分の子より背面に描かれるため、タイトル・戻るボタン・主アクションには被らない
- コード描画で「無地の図形を置くだけ」にすると平坦でチープに見えるため、質感表現を必須要件として扱う。特に効くのは次の3点
  - **金属の反射カーブを最低5ストップで表現する**。上端付近に明るいハイライト帯、中央で落とし、**下端に照り返し(バウンス光)を入れる**。この下端の明るさが金属らしさの決め手であり、2色グラデーションでは出ない
  - **手続き的なグレイン(ノイズ)を薄く重ねる**(alpha 0.05〜0.10目安)。ノイズ画像は`static var`で1度だけ生成してキャッシュし、`canvas_item_add_texture_rect` の tile 指定で敷き詰める。フラットベクター感を消す最大の要因
  - **枠と中央パネルでグラデーションの向きを逆にする**(枠=上が明るい凸、中央パネル=上が暗い凹)。加えて中央パネル上端へ多重の落ち込み影を重ね、彫り込まれた構造として読ませる
- **UIに出す記号は、共通フォント(Zen Kaku Gothic New Bold)が字形を持つものだけを使う**。
  持たない文字は豆腐(□)になる。**エディタ実行では別のフォントで代替されて気づけず、
  書き出した版でだけ化ける**(実機で `▸`(U+25B8)・`▶`(U+25B6)が化けて発覚した)。
  使える: `●` `○` `◆` `■` `▲` `▼` `→` `←` `↑` `↓` `★` `※` `×`(U+00D7)`−`(U+2212)`＋`。
  使えない: `▸` `▶` `▷` `►` `◀` `✓` `✔` `✕`(U+2715)`▪` `⌛`。
  **手で cmap を確認する運用は続かない**(実際に `✕` が書き出した版で豆腐になった)ため、
  **`python tools/check_font_glyphs.py` が全 `.gd` / `.tres` の文字列を走査して報告する**。
  記号を足したら1度回す
- **共通テーマはボタンへ3px・ラベルへ2pxの暗い縁取りを掛けている。**暗い画面では文字を
  浮かせるために要るが、**紙や明るい面へ濃いインクの文字を置くと、縁取りで字の内側が
  潰れて読めなくなる**(砂時計図鑑で実際にそうなった)。明るい面を持つ画面は、その面の
  中の `Control` へ `add_theme_constant_override("outline_size", 0)` を掛ける
  (**テーマ側の既定は変えない**。暗い画面のほうが数として多い)
- **意味を持たない小物の装飾(四隅のネジ/リベット、角の渦巻き・スクロール意匠)は付けない**。元の画像ボタンには存在したが、コード描画版で再現したところノイズに見えるとユーザーが判断し、完全撤去した。一方で、**機能を示す形と紋章は積極的に付ける**(次項)。両者の線引きは「そのボタンが何をするかを伝えているか」であり、伝えていない純粋な飾りは置かない
- **グループごとの個性は「外形の形」と「紋章」だけで表現し、材質は全グループ共通に保つ**。元の画像ボタンは「戻る=左向き矢印の形」「保存=チェックマーク」「反転/移動/交代=紋章入りの円形メダリオン」「タブ=砂時計の徽章付きピル」というように、形と紋章が機能を語る設計だった。全グループを同一の見た目へ統一した結果この個性が失われたため復元した。ただし材質(反射カーブ・グレイン・面取り・落ち込み影)をグループごとに変えることは禁止する。材質を共通に保つことが、個性を出しつつ全体が調和して見えるための条件である
- `CodedButtonStyle`(`scripts/ui/styles/coded_button_style.gd`, `extends StyleBox`)は、次の4つの`@export`で全ボタンを賄う
  - `State`: NORMAL / HOVER / PRESSED / DISABLED
  - `Shape`: ROUNDED_RECT / CIRCLE / PILL(両端が半円) / CHEVRON_LEFT(左辺が尖った五角形)
  - `Emblem`: NONE / HOURGLASS / SWAP_ARROWS / BENCH / CHECK。描画実体は`UiPaint`側のstatic関数に置き、太い暗色の輪郭+真鍮の塗り+上側のハイライトによる浮き彫り表現とする(細い線画にしない)
  - `EmblemPlacement`: CENTER / UPPER(下半分にテキストが入る) / RIGHT_INSET / TOP_BADGE(上端から少し飛び出す円形の徽章)
- **枠・輪郭・面取りの太さは、要素の大きさに合わせて細くする**。`FRAME_THICKNESS`(12px)は
  高さ56px前後のボタンに合わせた値で、これを高さ26pxの小さなボタン(帯の「−」「+」)へ
  そのまま掛けると枠だけで面積の半分近くを占め、線が太すぎる印象になる。
  `_frame_thickness()` が「高さ56pxで12px / 高さ34pxで5px」の2点を通る直線として求め、
  輪郭(`_outline_width()`)と面取り(`_bevel_width()`)もその比で連動させる。
  **単純な短辺比例では小さい側が細くならない**ため、2点を通る直線にしている
- 紋章とテキストの重なりは、`.tres`側で個別に余白を指定するのではなく **`_get_content_margin()`をオーバーライドし、`shape`と`emblem_placement`から自動的に決まるようにする**。これにより`.tres`は「どのグループが何であるか」だけを持つ単純な状態に保てる
- グループごとの割り当ては次の通り。v5.0で使うのは`back_nav`/`confirm_save`/`nav_tab`/`icon_square`/`wide_text`の5つで、対局画面の丸いアクションボタン(`action_*`)と再生コントロール(`transport_round`)は画面ごと撤去したため削除済み

| グループ | Shape | Emblem | Placement |
|---|---|---|---|
| `back_nav` | CHEVRON_LEFT | NONE | - |
| `confirm_save` | ROUNDED_RECT | CHECK | RIGHT_INSET |
| `nav_tab` | PILL | HOURGLASS | TOP_BADGE |
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
| `assets/hourglasses/master/state_*.png` | **実行時に読む唯一の砂時計の絵**(サンドの3状態)。幅400px基準 | インポートする |
| `assets/hourglasses/processed/{id}/` | 色違いを焼いた参考用の絵。**実行時には読まない** | `.gdignore` で無視 |
| `assets/hourglasses/overrides/{id}/state_*.png` | そのカードだけの固有の絵(あれば色変換より優先) | インポートする |
| `assets/hourglasses/sources/{id}/` | 生成元(`source.png`)と縮小前の原寸`state_*.png` | `.gdignore` で無視 |
| `assets/hourglasses/processed_backup/` | 正規化前の旧版(現行とは内容が異なる) | `.gdignore` で無視 |
| `assets/hourglasses/incoming/` | 取り込み待ちの生成画像 | `.gdignore` で無視 |
| `assets/hourglasses/emblems/{id}.png` | **カード固有の紋章**。白のシルエット192px | インポートする |
| `assets/hourglasses/emblems/sources/` | 紋章の取り込み元SVG(icooon-mono) | `.gdignore` + `.gitignore` |

紋章のPNGは `tools/build_emblem_icons.gd` がSVGから焼き直す。カードを追加したら、
モチーフのSVGを `sources/{id}.svg` へ置いてこれを1度回す。

#### 絵は1組だけ持ち、色は実行時に付ける(GameDesign.md 9章)

**全58種はサンドの絵1枚の色違いであり、輪郭は完全に一致する。**色違いを焼いた画像を
種類の数だけ配ると、pckの7割(6.7MB)を同じ絵が占め、**カードを1種足すたびに約115KBずつ
積み上がる**。そこで実行時に持つのは1組だけにし、色は数値として持つ。

| クラス | 責務 |
|---|---|
| `HourglassTintTable`(`scripts/data/hourglass_tint_table.gd` + `data/hourglass_tints.tres`) | 絵のid → 「親のid + 色変換1段」の表。**親をたどると必ずサンドへ着く** |
| `HourglassArt`(`scripts/logic/hourglass_art.gd`, staticのみ) | 表に従って絵を焼き、`Texture2D` として配る。`SoundBank` と同じ「Autoloadを使わずstaticで持つ」流儀 |

色変換1段の定義は次のとおりで、`tools/tint_hourglass_icons.gd` の `_tint()` と同じもの
(明度と彩度の下駄を足してある)。**1画素の色だけで決まる**ため、そのままシェーダになる。

```
s < threshold の画素は触らない   … 無彩色のガラスと輪郭を色付けしないため
h' = h + hue
s' = clamp(max(s * sat + sat_bias, floor), 0, 1)
v' = clamp(v * value + value_bias, 0, 1)
```

- **焼くのは `SubViewport` + シェーダで、結果を `ImageTexture` として持つ。**描画側は
  今までどおり `Texture2D` を受け取るだけで、`CardView` / `CardDetailPanel` /
  `CardDeckShelf` / `CardDeckListScreen` / `ReplayListCard` のいずれも変更しない。
  **描画のたびにシェーダを掛ける方式は採らない**。カードの絵は5つの画面がそれぞれ別の
  描き方(`draw_texture_rect` と `TextureRect`)で出しており、5箇所へシェーダを配ると
  1箇所書き漏らしただけで色が違うカードが出る
- **`CardData.icon_upright` などはプロパティの getter へ変え、`.tres` からは絵への参照を外す。**
  `.tres` が持つのは絵のidだけになる(既定はカードのid。ガード=`king` / グロウ=`judge` のように
  別の絵を指す場合だけ `art_id` を書く)
- **親から順に焼く。**深さは最大2段(サンド → 元絵9種 → その色違い)。親の焼き上がりを
  次の段の入力にするため、シェーダは1段ぶんだけを知っていればよい
- **焼き上がる前に配る `ImageTexture` は、サンドの絵で初期化しておき、焼けた時点で
  `set_image()` で中身を差し替える。**同じオブジェクトを配り続けるので、受け取った側は
  何も知らなくてよい。焼きは `Main._ready()` から始めて58フレーム(約1秒)で終わり、
  その間はタイトル画面が出ているため、砂時計の絵は1枚も画面に無い
- **固有の絵(`overrides/{id}/`)があればそれをそのまま配り、色変換を行わない**
  (GameDesign.md 9章)

**色の数値は `tools/fit_hourglass_tints.py` が現行の絵から逆算した。**既知の変換を持つ
40種は完全に一致し(誤差1/255はPNGの丸め)、経緯の記録が無い9種とその子8種は
平均1.4〜4.3/255の近似になる。**この差は輪郭のコントラストがわずかに緩む形で出る**ため、
数値を作り直したら現行の絵と並べて目で確かめること。

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

### 4.1.6 Web配信のロード時間(pckを小さく保つ)

unityroomはpckとwasmを**全部読み終えてから**ゲームが始まるため、pckの大きさが
そのまま起動待ちになる。wasm(37MB・gzipで約9.5MB)は公式テンプレートの固定費で
下げられないため、**削れるのはpckだけ**である。次の3つを常に守る。

- **実行時に読まないディレクトリには必ず `.gdignore` を置く**。検証用の
  スクリーンショットを置く `scratchpad/` と `logs/` は、置き忘れると
  1枚0.8MBのPNGが丸ごとpckへ入る(実際に12MB分が入っていた)
- **テクスチャは非可逆(WebP)で取り込む**(`compress/mode=1`)。砂時計・紋章は
  `lossy_quality=0.85`、背景は0.75。ロスレスのままだと砂時計63枚で7.6MB・
  背景2枚で5.2MBを占める。非可逆にすると合わせて1.7MBになり、
  実際にレンダリングして輪郭の劣化が見えないことを確認済み
- **同じ絵の色違いを画像として配らない**(4.1節)。砂時計の絵は58種ぶんで6.7MBあり、
  **pckの69%を1枚の絵の色違いが占めていた**。1組だけ配って色を実行時に付ける形にすると
  0.12MBになり、**カードを増やしてもここは増えない**
- **背景は1920x1080を覆う最小サイズまで縮める**。基準解像度は1280x720であり、
  2752x1290のような原寸をそのまま持つ理由がない

**ロスレスのctexはgzipでほとんど縮まない**ため、pckの数字がそのまま転送量になる。
wasmだけがgzipで1/4になる点と混同しないこと。

#### BGMはpckへ入れず、実行時に取りに行く

BGM3曲は合計8.8MBあり、上の3点を守ってもなおpckの7割を占める。**曲を短く切るのではなく、
起動を待たせないようにする**ことで解決する。

- Webプリセットの `exclude_filter` に `assets/bgm/*` を入れ、pckから外す
  (**`export_presets.cfg` はエディタが書き出すたびにフィルタを空へ書き戻す**。
  実際に2度これが起きて、pckが4.1MBから15MBへ膨らみ、同時に
  `data/discord_webhook.txt` が落ちて募集通知が飛ばなくなった。
  **人が確認する運用では防げないため、`tools/export_web.sh` が書き出しの直前に
  `tools/ensure_export_filters.py` でフィルタと `export_path` を揃え直し、
  書き出した後に `tools/verify_web_pck.gd` でpckの中身を名指しで検査する**)
- **エディタの書き出し先も `build/web/index.html` へ揃えてある。**以前は
  `build/砂時計pvp.html` を指しており、エディタから書き出すと別名のpckが並んで
  できあがった。unityroomへ上げるのは `index.pck` 1つだけなので、どちらを上げるのか
  迷う状態そのものを無くしている
- **Discordのお知らせ用に作る画像・GIFは `assets/` の下へ出さない**
  (`tools/discord/out/`。`.gdignore` 済み)。`assets/mascot/` へ置いていた頃は
  Godotがそれらをインポートし、告知用のバナーやカード画像がpckへ入っていた
- `MusicPlayer` は、Web版では `res://` を試さずに `HTTPRequest` で
  `https://cdn.jsdelivr.net/gh/Omezi42/hourglassPVP@main/assets/bgm/{曲}.ogg` を取得し、
  `AudioStreamOggVorbis.load_from_buffer()` で鳴らす

**置き場所をリポジトリそのもの(jsDelivr経由)にしているのは、unityroomへ上げるのが
`index.pck` だけだからである。**`index.html` の隣へ素のoggを置く形は、その追加ファイルが
配信されないため使えない。jsDelivrは `Access-Control-Allow-Origin: *` を返すため、
unityroomのオリジンからでも読める(実測で確認済み)。

> **この方式は「リポジトリを公開のまま保つ」ことが前提になる。**非公開にすると
> CDNが404を返し、BGMだけが鳴らなくなる(ゲーム自体は動く)。

**この方式が成立するのは、BGMがもともとすぐには鳴らないから**である。ブラウザの自動再生制限で
最初のクリックまで再生を保留しており(9章)、その間にダウンロードが終わる。取得に失敗しても
無音のまま対局は成立するので、エラーで止めない。

**デスクトップ側は `res://` から読む経路をそのまま残す**(`exclude_filter` はWebプリセット
だけのもの)。判定は `OS.has_feature("web")` で行う。`ResourceLoader.exists()` は
pckから除外した後も true を返すことがあり、有無の判定には使えない(実測)。

`tools/balance/` のシミュレーション結果(1.1MB)も実行時に読まないため同様に除外する。

---

### 4.1.5 はじめてのプレイ(GameDesign.md 18章)

| クラス | 責務 |
|---|---|
| `CardPresetDecks`(`scripts/logic/card_preset_decks.gd`, static) | プリセット3つを「idと枚数の表」として持つ。30枚に足りない場合はコストの安い順に埋めるため、**表が古くなっても対局へ入れなくなることはない** |
| `CardPresetPicker`(`scripts/ui/card_preset_picker.gd`) | プリセットを選ぶモーダル。名前だけでは何のデッキか分からないため、狙いの一文を必ず添える |
| `CardMatchTutorial`(`scripts/ui/card_match_tutorial.gd`) | 誘導対局の指示。段階ごとに1つだけ操作を求め、`MatchState` のシグナルで達成を判定する。**帯の中身(すなえる・文・「つぎへ」「閉じる」)は `_band` という1つの `Control` の子として相対座標で持つ**。マリガン中だけ帯を下げるため、動かすのが `_band.position` の1箇所で済む |
| `SunaeruPortrait`(`scripts/ui/sunaeru_portrait.gd`) | 指示の帯の左端に置くすなえるの立ち絵。**絵を持つだけのノード**にし、何を言うかは `CardMatchTutorial` が持つ |

**指示は「文」だけでなく「いま触るもの」も示す**(GameDesign.md 18章)。`CardMatchTutorial`
は `watch()` で対局画面そのものを受け取り、段階ごとの対象(出せる手札 / ターン終了ボタン /
攻撃できる駒 / 反転できる駒)を脈打つ枠で囲む。`mouse_filter` は IGNORE のままで枠だけを
描くため、**手を塞がない**という方針(GameDesign.md 18章)と両立する。

**囲むのは「いま出せる手札」だけで、空き枠は囲まない。**両方を光らせると盤面の大半が
枠だらけになり、どれを押せばよいのか却って分からなくなる(実際に描画して確認した)。
押した後に空き枠が光るのは通常の操作のとおり。

**出せる札が1枚も無い間は、代わりにターン終了を示す**(GameDesign.md 18章)。マナは手番の
始めに増えるため、`_process()` で毎フレーム見て**状態が切り替わったときだけ**文を組み直す。

**段階を終えたときの一言には、その場の実際の数値を差し込む。**駒の名前・砂の前後・
相打ちで双方が削れた量を `MatchState` から読んで前置きにする。
**攻撃だけは後から数える**必要がある。`attack_performed` はダメージの解決より前に出るため、
続けて届く `unit_damaged` / `hp_changed` を数えながら文を組み直す。

**誘導対局は専用のモードを作らず、CPU戦へ指示を重ねるだけにする。**`start_tutorial_match()` は
`start_cpu_match()` をプリセットの「基本」で呼び、その後 `CardMatchTutorial.watch()` を張る。
専用モードを作ると、対局のルールが2箇所に分かれて食い違う余地が生まれる。

**指示は手を塞がない**(`mouse_filter` は IGNORE)。従わない操作を禁止すると
「言われた通りにしか動かせない」体験になるため(GameDesign.md 18章)。

**途中で閉じるボタンは持たない**(GameDesign.md 18章)。`close()` は締めの一文の
「とじる」からしか呼ばない。一度閉じると以降の段階の案内が二度と読めなくなるため。

**すなえるの絵は `assets/mascot/mascot_avatar.png` 1枚だけを実行時に読む**(GameDesign.md 18章)。
生成元(`tools/build_mascot.py` の出力する原寸とDiscord用のプレビュー)は
`assets/mascot/sources/` へ移し `.gdignore` で管理外に置く。表示は96px程度のため、
取り込みは非可逆(WebP)にする(4.1.6節)。

**表情の差分は持たない。**口を描かない設計(GameDesign.md 18章)のため差分を作る余地が薄く、
1枚で足りる。段階が進んだときの反応は、絵の差し替えではなく**跳ねる動き**で見せる。

**指示の置き場所は卓の上端へ渡した帯**(`BAND_RECT`)。画面の最上段へ敷くと相手のHP・マナ・
山札を覆い、攻撃や反転の判断に要る情報が誘導対局の間ずっと読めなくなる(実際に描いて確認した)。

**マリガンの間だけ帯を確定ボタンの下(`MULLIGAN_BAND_TOP`)へ下げ、`_tutorial` を `_mulligan` より
後に `add_child()` する**(GameDesign.md 18章)。以前は暗幕の下に敷かれて読めないため、
マリガンが終わるまで帯ごと隠していたが、**いちばん案内が要る最初の画面が無言になっていた**。
マリガン画面は見出し・手札・確定ボタンで y=66〜432 を使うため、下げる先はその下しかない。

**段階を終えたときの説明は `Timer` で流さず「つぎへ」を押すまで残す**(GameDesign.md 18章)。
以前は0.9秒で次の指示へ自動的に切り替えており、読み切る前に消えるため
**案内が最初の1回しか出ていないように見えていた**。段階をすべて終えたら締めの一文
(`OUTRO_TEXT`)を出し、そのボタンが「とじる」に変わってから閉じる。

---

### 4.2 ルール画面(GameDesign.md 16章)

| クラス | 責務 |
|---|---|
| `RulePages`(`scripts/ui/rule_pages.gd`, static) | 紙芝居の中身。章・見出し・本文・盤面の種類を Dictionary の配列として1箇所へ持つ |
| `RuleStage`(`scripts/ui/rule_stage.gd`, Control) | 1ページ分の盤面。`RulePages` の指定に従って `CardView` 等を並べ、`play()` で演出を再生する |
| `RuleScreen`(`scripts/ui/rule_screen.gd`, Control) | 目次・本文・`RuleStage`・ページ送りを並べる画面 |
| `RulesTab`(`scripts/ui/rules_tab.gd`, Control) | ホーム画面の「ルール」タブ。**「遊んで覚える」と「読んで覚える」の2つの枠**に分け、入口だけを持つ(GameDesign.md 9章) |

**盤面は `CardView` / `BoardTable` / `PlayerInfoBar` / `CardInstance` / `MatchState` を
そのまま使う。**ルール画面専用の描画を1つも書かないことが要件で、教材用の絵を別に持つと
対局画面と食い違った時点で誤った予習になる(GameDesign.md 16章)。同じ理由で、演出も
`CardView.play_drop()` / `play_shatter()` / `play_flip()` を直接呼ぶ。

**第7章の盤面は `MatchState` を実際に生成してから、`board` と `hp` を教材用の局面へ
差し替えて作る。**`PlayerInfoBar.show_state()` が `MatchState` を要求するため、
情報帯(HP・マナ・山札・墓地)を本物と同じ描画で出すにはこれが要る。ランダムな
デッキから引いた局面をそのまま見せると、説明したい形が毎回変わってしまう。

**`RulesTab` と「ルール」のタブボタンは `HomeScreen._ready()` がコードで生成する。**
`scenes/home_screen.tscn` を書き換えずに済ませるためで、タブボタンは既存の
「デッキ」ボタンを `duplicate()` して文言だけ差し替える(スタイルの指定漏れが起きない)。
これは v5.0 の画面が `.tscn` を持たないのと同じ流儀。

**初回起動の判定は `UiState`(`scripts/logic/ui_state.gd`、`user://ui_state.json`)が持つ。**
`CardDeckSave` 等と同じ「Autoloadを使わずstaticで持つ」流儀。ホーム画面を一度でも開いたら
記録し、以後は「デッキ」タブから始める(GameDesign.md 9章)。
### 4.3 キーワード辞書(GameDesign.md 17章)

| クラス | 責務 |
|---|---|
| `KeywordEntries`(`scripts/ui/keyword_entries.gd`, static) | 辞書の中身。語 → 表示名・説明・実演の `CardEffectPreview.Demo`・分類(常在 / トリガー)の対応表と並び順を1箇所へ持つ |
| `KeywordDictScreen`(`scripts/ui/keyword_dict_screen.gd`, Control) | 左=語の一覧 / 右=選んだ語の詳細。共通の `ScreenHeader` を使う |
| `KeywordEntryView`(`scripts/ui/keyword_entry_view.gd`, VBoxContainer) | 1語ぶんの表示(語 / 説明 / 実演 / その語を持つ砂時計)。**辞書画面の右カラムとポップの中身はどちらもこれ**で、同じ語を2箇所で別々に組み立てて片方だけ古くなる状態を防ぐ |
| `KeywordPopup`(`scripts/ui/keyword_popup.gd`, Control) | 詳細パネルから出す1語ぶんのモーダル。暗幕 + コンテンツパネルの既存パターン |

**`CardEnums` は「語と文を返す」既存の責務のまま変えない。**並び順・分類・実演の割り当ては
辞書側の関心であり、対局のロジックが読む語彙へ表示の都合を混ぜないため `KeywordEntries` が持つ。

**その語を持つ砂時計は表へ書かず、`CardLibrary` から実行時に集める**
(`KeywordEntries.cards_with()`)。カードを1枚追加したときに辞書を書き換える作業が
発生しないことが、データ駆動で運用する(1章)ための条件になる。

**トリガー(設置 / 反転 / 余砂)は `Keyword` とは別の enum のため、辞書の項目は
`{"kind": ..., "value": ...}` の形で持つ**。両者を1つの整数へ混ぜると、値が衝突していないことを
呼び出し側が知っている前提のコードになる。

**`CardDetailPanel` の効果欄は語ごとの行にする。**`Label` 1つへ全文を流し込む形をやめ、
1行を「語のボタン + 説明の `Label`」にした。ボタンは `keyword_pressed(entry)` を出すだけで、
**ポップ自体は画面側が持つ**(パネルは画面の上の小さなノードとして置かれ、そこへ全画面の
暗幕を持たせられないため)。

**語のボタンと実演を出すのは `interactive`(既定 true)のときだけで、これを持つのは
砂時計一覧だけ**(GameDesign.md 17章)。デッキ編集と対局画面は `interactive = false` で
使い、同じ行を「【語】 説明」の1つの `Label` として描き、`CardEffectPreview` を作らない。
**ホバーで出して外れたら消えるパネルの中に、押しに行く先を置いてはいけない。**
`show_card()` / `clear()` は `_preview` が null でも通るようにしてある。
効果の文は「余砂:カードを1枚引く」のように語を頭に持つため、【】で括って前へ出すときは
文の側の語を取り除く(`_strip_term()`。そのままだと語を2度読ませることになる)。

**`interactive = false` のパネルは、中身の高さぴったりまで縮める**(`_fit()`)。
そのために**効果の欄をスクロールで包まない**——包むと高さが中身から決まらなくなる。
幅は `compact_width` で渡す(既定は `COMPACT_SIZE.x`、対局画面は340px)。

**実演(`CardEffectPreview`)は語を直接指定して再生できるようにする**(`show_demo()`)。
既存の `show_card()` は `CardData` から台本の並びを組む入口であり、辞書は語がすでに
決まっているためその手前へ入る。

---

---

### 4.4 画面の見かた(GameDesign.md 20章)

| クラス | 責務 |
|---|---|
| `ScreenGuideEntries`(`scripts/ui/screen_guide_entries.gd`, static) | 項目の表(光らせる場所の名前・見出し・説明)。**9章で決めた表示の約束を引き写す**だけの場所で、新しい取り決めを作らない |
| `ScreenGuideStage`(`scripts/ui/screen_guide_stage.gd`, `extends RuleStage`) | 見せる盤面。`RuleStage._compose_board()` に手札・行動の列・駒の状態を足し、**光らせる場所を組み立てながら控える** |
| `ScreenGuideScreen`(`scripts/ui/screen_guide_screen.gd`) | 左=項目の一覧 / 中央=盤面 / 下=説明。共通の `ScreenHeader` を使う |

**`RuleStage` を継承して盤面を共有する。**ルール画面(4.2節)と同じく
「専用の説明図を作らない」ことが要件のため、情報帯・卓・12枠の組み立ては
`_compose_board()` として切り出して両者で使う(以前は `_build_board()` が
第7章の局面を直に組んでいた)。

**光らせる場所は表に持たず、組み立てながら `_mark()` で控える。**座標を別の表に
書くと、配置を変えたときに黙ってずれる。`region()` が `_content` の座標を
拡縮後の位置へ移して返す。

**光る枠は盤面より手前の独立したオーバーレイに描く**(`Control._draw()` は自分の子より
背面に描かれるため。11章)。**周りを暗幕で落とす案は採らない**。光らせる場所は
「上下2本の情報帯」のように離れて複数あることがあり、その外側だけを塗るには盤面を
格子状に走査することになる(毎フレーム数千の矩形を描くことになり割に合わない)。
代わりに外へ広がる輪を3重に重ねる。

**教材の盤面では、最初の `PlayerInfoBar.show_state()` を被弾として演出しない。**
初期値30から教材用のHPへ差し替えるため、そのままだと開いた瞬間に「-6」が浮く
(ルール画面の第7章でも同じことが起きていた)。

---

### 4.5 デッキを複数持つ(GameDesign.md 9章)

`CardDeckSave` は `user://card_decks.json` へ
`{"decks": [{"name": ..., "ids": [...]}], "selected": n}` の形で**何個でも**保存する。
**旧形式(デッキ1つだけの `{"deck": [...]}`)も読める**ようにしてあり、複数デッキを
持つ前に保存したデッキが更新の時点で消えることはない。30枚に満たない件・カードが
揃わない件は読み込みの時点で落とす(枚数の足りないデッキで対局へ入れないため)。

`selected` は**対局前の選択画面の初期値でしかない**。使うデッキは対局のたびに選び直す
ため、一覧側に「使用中」を示すバッジは出さない(GameDesign.md 9章)。

**一覧と選択画面は `CardDeckListScreen` 1つが `Mode`(MANAGE / PICK)で兼ねる。**
選ぶ側だけ別の画面を作ると、同じ見た目を2箇所で組み立てて片方が古くなる。
モードで変わるのは「ヘッダーの主アクション(新規作成・入れ替え)を出すか」と
「カードを押して選べるか、編集・削除のボタンだけを押せるか」の2点だけにする。

**並び替えは専用のモードに入って行う**(GameDesign.md 9章)。カード個別に常時
並び替えのボタンを置くと、編集・削除と合わせて1枚に4つのボタンが並ぶ。
入れ替えは1つ隣との交換(↑ ↓)とし、押すたびに保存する。

---

## 5. 拡張運用について

- 新しい砂時計を追加する場合、原則として `HourglassData` の `.tres` を1個作成するだけで完結させる
- 既存の `EffectType` で表現できない効果が必要になった場合は、実装前に GameDesign.md への追記案を提示し、承認を得てから `EffectType` とハンドラを追加する
- オンライン対戦は非同期通信(手番ごとにサーバーへ送信→相手に反映)を前提とし、`MatchState` の操作(出す/反転/攻撃/コイン/ターン終了)をそのまま通信メッセージの単位として扱える設計にする
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
- **ルームコードは4桁の数字**(`RoomMatch.CODE_LENGTH`)。取りうる番号が1万通りしか
  無いため、**空いている番号を選んで作る**(`create_document()` の `exists:false`)。
  埋まっていた場合は、その部屋が `ROOM_STALE_SECONDS` より古く、まだ対局が始まって
  いなければ番号ごと引き取る(`updateTime` を前提条件にした `commit()`)。**この
  引き取りが無いと、放置された部屋が番号を占め続けて作れなくなる**。観戦は
  `rooms/{code}` を辿るため部屋の文書自体は消さない(7章)
- ランダムマッチのキューは、複数プレイヤーが同時に参加しても二重マッチや取りこぼしが起きないよう、**Firestoreのトランザクション(read-modify-write)でキューの追加/成立を原子的に処理する**。具体的には「待機中のドキュメントを1件取得→トランザクション内で取得できればマッチ成立とみなし両者のマッチIDを確定、取得できなければ自分が待機ドキュメントとして登録される」という手順を想定する
- 持ち時間の管理はロジック層の `MatchClock` が担う。**1手番につき60秒で、手番が移るたびに
  その側の残り時間を60秒へ戻す**(GameDesign.md 5章)。時間切れは `MatchState.match_ended` と
  同様の決着トリガーとして扱い、オンライン対戦時はこの持ち時間切れが切断・放置時の敗北条件を
  兼ねるため、別途タイムアウト監視の仕組みを持たない
- **手番の始まりは `start_turn(side)` の1本だけで表し、「側が変わったときだけ戻す」**。
  1手番のうちに何度も指す(出す→攻撃→反転)たびに戻すと、指し続けている限り時間が尽きない。
  旧 `finish_turn(next_side)`(active_side を移すだけ)は、戻す判定と手番の移動が
  2つの関数に分かれて食い違うため廃止した
- **時間切れは敗北ではなく手番の強制終了**(GameDesign.md 5章)。手として
  `{"type": "time_up", "side":}` を送り合い、`MatchState.time_up()` が適用する。
  **切断とみなして即座に負けにする従来の `{"type": "timeout"}` は別物として残してある**
  (下記の猶予から呼ぶ)。過去の棋譜が持つ `timeout` の意味を変えないためでもある
- **連続回数は `MatchState.turn_forfeits` が持つ**。手として送り合うため両者で同じ値になり、
  `TURN_FORFEIT_LIMIT` による敗北判定がこれを見る。**回数を `MatchClock` へ置かない**
  (時計はUIが対局ごとに作り直すため、そこへ回数を置くと復帰・観戦で失われる)。
  **時間切れを重ねても持ち時間は短くしない**(GameDesign.md 5章)ため、`MatchClock` は
  回数そのものを知らない
- **`end_turn()` は冒頭でその側の回数を0へ戻し、`time_up()` は `end_turn()` を呼んだ後に
  数え直した値を書き戻す**。「1手でも指せば数え直す」を1箇所で表すためで、順序を逆にすると
  連続を数えられない。リセットを `play_card()` 等の側へ配ると、増えるたびに書き漏らす
- **`time_out` は「手番側の時計が尽きた」という通知であり、自分の時間切れとは限らない**。
  `tick()` が減らすのは `active_side` の時計なので、相手の手番でも発火する。受け口
  (`CardMatchScreen._on_local_timeout()`)は**引数の側が自分でなければ何もしない**。
  ここで側を見ずに `my_side` で申告すると、**相手が時間切れになった瞬間に自分が負けを
  送る**(実際にそうなっていた)。相手の時間切れは `_watch_opponent_timeout()` が
  猶予を置いて拾う側の仕事で、経路が別々にある
- **相手を待つ猶予(`OPPONENT_TIMEOUT_GRACE`)は20秒**。時間切れ自体が敗北でなくなった以上、
  ここに掛かるのは「申告そのものが届かない=切断」の判定だけになった。生きている相手は必ず
  `time_up` を送ってくるため、ポーリングの間隔(1.5秒・失敗時は最大8秒まで伸びる)と送信の
  再試行より十分長く取る。**短いと、通信が一時的に詰まっただけの相手を切断とみなして勝つ**
- **時間切れは盤面に何も起こさないため、ログと実況の両方へ出す**。`CardMatchLog` は
  `turn_forfeited` を購読して `_append(..., "time_up", side, -1)` で積み、
  `CardMatchTurnFeed.NARRATED` へ `"time_up"` を足して相手のぶんだけ実況する。
  出さないと、相手が何もせず手番が戻ってきたようにしか見えない
- **残り時間が赤くなる境目は固定の秒数ではなく、その手番の持ち時間の半分**とする
  (`PlayerInfoBar.clock_total`)。持ち時間はいま常に60秒だが、ルームマッチで持ち時間を
  切った対局など「1手番の枠」が変わりうる経路が残っているため、割合で持つ形は変えない
- サーバー側での操作の正当性検証は行わず、クライアントの操作をそのまま信頼する(不正対策は将来検討)
- Firebaseの接続情報(`apiKey`/`projectId`等)は `FirebaseConfig`(Resource)として `data/firebase_config.tres` に保持する。Web向けAPIキーは元々クライアント埋め込み前提の値であり、Firestoreセキュリティルール側でアクセス制御する運用とする
- マッチ成立後、両者は `matches/{match_id}` ドキュメントへ自分のデッキ(30枚のid配列)を `deck_a`/`deck_b` として、先手側は山札の `seed` も書き込む(`OnlineSetup` が担当)。相手側はポーリングでこれを検知する。**v5.0は配置フェーズを持たないため、交換するのはデッキと種だけ**で、揃った時点でそのまま `MatchState.start_match()` へ入る(4.0節)
- オンライン時は対局画面の表示視点(自分/相手)を `state.current_turn` ではなく固定の `my_side` にし、自分の手番でない間は操作を受け付けない
- マリガン(GameDesign.md 2章)は手と同じ `actions` の1件として送り合う。**両者ぶんが揃ってから A → B の固定順で適用する**(適用が山札を切り直して乱数を消費するため、届いた順に適用すると同じ種から始めた対局が食い違う)
- 対局中の実際の手の送受信は `OnlineMatch` が担当し、対局画面は自分の操作を `OnlineMatch.send_and_apply` 経由で送信しつつ即座にローカル反映する
- **投了は指し手と同じ`actions`配列の1件として送受信する**(`{"type": "surrender", "side": <投了した側>}`)。`OnlineMatch.apply()`のmatch文へ`"surrender"`分岐を1つ足し、`MatchState.surrender(side)`を呼ぶだけで済むため、ポーリング・送信の仕組みを新設せずに相手へ伝わる。ただし投了は盤面を変えずに即終局する点で他の手と性質が異なるため、**対局画面側では手の演出とターン交代を行わない**(適用した時点で`match_ended`が発火し、以降の処理は結果パネルの表示に引き継がれる)。`actions`と`finished_at`/`winner`は同じドキュメントの別フィールドだが、`FirestoreClient.set_document()`が`updateMask`付きのPATCHでフィールド単位に書くため、投了側が両方をほぼ同時に書いても互いを打ち消さない

### 6.2 切断からの復帰(GameDesign.md 11章)

**局面のスナップショットは保存しない。**`matches/{id}` には「両者のデッキ・山札の種・
指した手の並び」が残っており、そこから作り直せる(リプレイ・観戦とまったく同じ経路)。
`OnlineResume`(`scripts/net/online_resume.gd`、`user://online_match.json`)が持つのは
**どの対局のどちら側だったか**だけで、対局が始まった時点で書き、終局と対局前の中断で消す。

`CardMatchScreen.resume_online_match()` は、ドキュメントを読んで
`_begin_state()` → 記録済みの手をすべて `MatchAction.apply()` → `OnlineMatch.start(id, 適用済みの数)`
の順に復元する。終局済み(`finished_at` がある / 手を並べ終えた時点で決着している)なら
戻さずに理由を出す。

**復帰しても持ち時間は戻らない。**こちら側は初期値から数え直すが、**相手はこちらの残り時間を
自分の手元で減らし続けている**(6.1節)ため、再読み込みで時計を延ばす抜け道にはならない。

**戻れる対局があるかどうかは、ホーム画面では通信せずに判定する**(記録の有無だけを見る)。
押した時点で初めて `matches/{id}` を読む。毎回ホームで通信すると、オフラインでも
遊べる(CPU戦)という前提を崩すため。

---

### 6.1 通信の堅牢化(フェーズ26)

自己検証で、オンライン対戦が「通信が理想的に成功し続ける場合しか成立しない」実装に
なっていることが分かった。以下はいずれもその修正であり、ルール(GameDesign.md)は変えていない。

- **HTTP通信は必ずタイムアウトを設定する**。`HTTPRequest.timeout`の既定値は0(無制限)で、
  応答が返らないと`await request_completed`が永久に解決せず、その導線(サインイン・
  マッチング・手の送信)が固まったまま復帰しない。生成・タイムアウト・一時的失敗の
  リトライ・JSONのパースは`HttpJson`(`scripts/net/http_json.gd`、staticのみ)へ集約し、
  `FirebaseAuth`と`FirestoreClient`の両方がこれを経由する。リトライの対象は
  「応答が得られなかった/429/5xx」だけで、400番台は呼び出し側の判断が要るため再試行しない
- **IDトークンを自動更新する**。Firebaseの匿名サインインで得るIDトークンは1時間で失効する。
  更新の仕組みが無いと、長く遊んだセッションで以降のFirestore通信がすべて401で黙って失敗し、
  画面上は「相手が指してこない」ようにしか見えない。`FirebaseAuth`が`refreshToken`と
  有効期限を保持し、`ensure_fresh_token()`が期限の5分前から`securetoken.googleapis.com`で
  更新する。`FirestoreClient`は全リクエストの前にこれを呼び、それでも401が返った場合は
  1度だけ強制更新して再送する(クライアント時刻がずれている場合に備える)
- **マッチ成立は1回のcommitで原子的に行う**。以前はキュー/ルームのclaimと
  `matches/{id}`の`player_a`/`player_b`の書き込みが別々だったため、掴まれた側が
  `match_id`を見て`matches/{id}`を読んだときにまだ空という窓があった。この窓に入ると
  `BattleTab._on_matched()`の判定(`player_a == 自分のuid`なら先手)が両者ともfalseになり、
  **双方が後手(side B)として`deck_b`を書き、互いに`deck_a`を待ち続けて対局が始まらない**。
  `MatchmakingQueue`は「相手のキュー更新 + 自分のキュー更新 + `matches/{id}`の作成
  (`exists:false`)」の3write、`RoomMatch`は「ルーム更新 + `matches/{id}`の作成」の2writeを
  1つの`commit()`にまとめ、この窓自体を無くした
- **キューに残った切断済みプレイヤーを掴まない**。ブラウザを閉じたプレイヤーのキュー
  ドキュメントは残り続けるため、後から来た人がそれを掴んで永久に相手のデッキを待つ状態に
  なっていた。`joined_at`が`STALE_SECONDS`より古い候補は掴まずに削除し、待機中の自分は
  `HEARTBEAT_SECONDS`ごとに`joined_at`を更新して自分が生きていることを示す
  (更新が頻繁だと相手のclaimの前提条件(`updateTime`)を無効化してしまうため、
  ポーリング間隔より十分長い間隔にしている)
- **手の送信を確実にする**。`OnlineMatch`は`actions`配列をread-modify-writeで書くが、
  以前は`set_document()`の成否を見ておらず、失敗しても盤面だけ進んで相手と食い違っていた。
  現在は`updateTime`を前提条件にした`commit()`へ変え、競合・失敗時はドキュメントを
  読み直して再試行する。送信は`_send_queue`へ積んで1件ずつ処理し、順序と重複を保証する
- **自分の手をポーリングが拾って二重適用する競合を無くす**。送信した手にはFirestoreへ
  書く時点で`by`(自分のuid)を付け、ポーリング側は`by`が自分のものである手を配らない。
  以前は「書き込み完了 → `_known_action_count`の更新」の間にポーリングの読み取りが
  挟まると、自分の手が`action_received`として自分に返り、同じ手が2度適用されていた。
  `by`は`OnlineMatch.apply()`もリプレイ再生も参照しない追加キーのため、既存の棋譜と互換性がある
- **受け取った手は1ポーリングにつき1件だけ配る**。対局画面の受け口は
  予約マークの表示・解決演出で数秒awaitするため、同時に2件流し込むとターン進行が
  二重に走る。残りは`_inbox`に留めて次のポーリングで配る
- **終局・画面離脱でポーリングを止める**。以前は`stop()`が次の対局開始時にしか呼ばれず、
  ホームへ戻った後もFirestoreを読み続けていた。`_on_match_ended()`(リプレイ保存の
  書き込みの後)と、戻る/ホームへボタンの両方から止める。**停止したノードは解放しない**。
  ポーリング・送信のコルーチンがawaitの途中で残っている可能性があり、解放すると
  「Resumed function on a freed object」になるため。`_polling`をfalseにした時点で
  以降は何もしない不活性なノードとして残す
- **持ち時間の同期**(GameDesign.md 11章):送信する手に`clock`(送信側の残り時間)を添え、
  受け取った側は`MatchClock.remaining[相手側]`をその値で上書きする。時間切れは
  `{"type": "timeout", "side": ...}`を投了と同じ`actions`の1件として送る。相手の
  申告が来ない(切断した)場合は、相手の残り時間が0になってから`OPPONENT_TIMEOUT_GRACE`
  の猶予を置いて、待っている側の勝利として終局させる。この判定と通信状態の表示は
  `MatchNetController`(`scripts/ui/match_net_controller.gd`、`_screen`参照を持つRefCounted)へ
  切り出している(`match_screen.gd`が1000行の上限に近いため)
- **対局開始前の中断**(GameDesign.md 11章):`OnlineSetup`に`cancel()`を持たせ、
  ポーリングを即座に打ち切ったうえで`matches/{id}`へ`abandoned`を書く。待っている側は
  `_poll_for_ids()`がこのフィールドを見つけた時点で待機をやめ、「対戦相手が対局を
  取りやめました」を表示する。配置フェーズがオンラインのときだけ、対局画面の戻るボタンを
  表示してこの導線を出す
- **Firestoreのセキュリティルール**は`firestore.rules`にリポジトリ同梱で置く。
  適用はFirebaseコンソール側の操作であり、このファイルは「何を許可する前提で
  実装しているか」の記録として持つ

---

### 6.3 対戦相手の募集をDiscordへ通知する(GameDesign.md 11章)

`QueueNotifier`(`scripts/net/queue_notifier.gd`、staticのみ)がDiscordのWebhookへ
1行を投げる。`MatchmakingQueue.join()` が**最初の `_try_claim_or_check()` で相手を
掴めなかった時点**で1度だけ呼ぶ。ここが「自分が待機側になった」ことの確定であり、
即座にマッチした場合は通らないため、条件分岐を足さずに仕様を満たせる。

**WebhookのURLはリポジトリへ置かない。**`data/discord_webhook.txt` に置き `.gitignore`
で管理外にする。**Godotのエクスポートはgitではなくファイルシステムを見るため、管理外でも
pckには入る**。リポジトリへ置けない理由は2つ。

- リポジトリは公開のまま保つ必要がある(BGMの配信にjsDelivrを使うため。4.1.6節)
- **GitHubはpublicリポジトリに含まれるDiscordのWebhook URLを検出し、Discord側が
  自動的に無効化する**(secret scanningの提携先にDiscordが含まれる)。コミットすれば
  この機能は黙って壊れる

ファイルが無ければ通知を送らないだけで、対局には影響しない(クローン直後やテストは
この状態になる)。**逆に言うと、pckへ入っていない状態と設定していない状態は
画面上まったく同じに見える**(黙って通知だけが飛ばなくなる)。

> **`.txt` は「リソース」ではないため、`export_filter="all_resources"` だけでは
> pckへ入らない。**`export_presets.cfg` の `include_filter` へ
> `data/discord_webhook.txt` を明示しない限り、エディタ実行では通知が飛ぶのに
> **書き出した版でだけ飛ばない**。実際にこれで unityroom 版の通知が一度も
> 届いていなかった。確認は
> `python -c "print(b'discord_webhook' in open('build/web/index.pck','rb').read())"` で足りる。

**クライアントへ埋めるのはWebhookに限り、Botトークンは絶対に置かない。**Webhookは
「そのチャンネルへ投稿する」以外に何もできないが、Botトークンはサーバーの操作権限を
持つため、pckから取り出された時点でサーバーごと失われる。

**送信の土台は `MatchmakingQueue` ではなくシーンツリーのルートにする。**キューは
対局が成立した時点でもキャンセルした時点でも `queue_free()` されるため、そこへ
HTTPRequest をぶら下げると送信の途中で巻き添えに消える。画面には何も出ないため、
「通知だけが飛ばない」という形でしか気づけなかった。

結果は `notify_waiting()` の `on_done`(Callable)で返し、`MatchmakingQueue` が
`announce_result` として画面へ流す。**文言としては出さない**(GameDesign.md 11章)。
`BattleTab` は届いたときだけ待機中の文言の右へ `StatusBadge`(丸い印)を出し、
説明はカーソルを乗せたときのツールチップに預ける。**受け口を Callable
にしているのは、待っている
うちにキューが解放されることがあるため**で、`Callable.is_valid()` が偽になった時点で
呼ばない(解放済みのオブジェクトで再開すると "Resumed function on a freed object" になる)。
届くまでは `ANNOUNCE_RETRY_SECONDS` の間を置いて試し直し、届いたら送り直さない。

**同じプレイヤーの連投を抑える仕組みは持たない**(GameDesign.md 11章)。以前は
2分の間隔を `static var` で持っていたが、失敗したときにその印を戻し忘れると
**入り直しても二度と飛ばなくなる**という形で、連投を抑える仕組みがそのまま
通知を封じる仕組みとして働いた。仕組み自体を無くしてこの穴を塞いでいる。
`can_send()` はWebhookが設定済みかどうかだけを答える。

バージョンは `ProjectSettings.get_setting("application/config/version")` から読む
(`project.godot` の `config/version`)。日付方式(`2026.08.29`)。

---

### 6.4 バージョンが違う相手とマッチングしない(GameDesign.md 11章)

`GameVersion`(`scripts/logic/game_version.gd`、staticのみ)が
`application/config/version`(人が読む日付方式)と `application/config/build_id`
(マッチングの突き合わせに使うビルドID)を読む唯一の場所になる。

**ビルドIDと日付方式のバージョンは、`tools/export_web.sh` が書き出しの直前に
`tools/stamp_build_id.py` を通して `project.godot` へ書き込む。**バージョンだけを手で
更新する値として残していたところ、書き出しを重ねても古い日付のままで、募集の通知に
何日も同じ数字が出ていた。同じ日に2回以上書き出した場合は `-2` `-3` と後ろへ足す。
値はUTCの書き出し時刻(`20260829-143052`)で、**時刻順に文字列比較できる**ため
「どちらが古いか」を判定でき、画面へ出す文言を書き分けられる。手で更新する値を
増やさないために自動化しており、**書き込んだ値はそのままコミットする**
(直近のビルドがどれかを追えるようにするため)。

**エディタ実行は最後に書き出したときのIDを持つ。**書き出した版と手元で対戦して
検証できる利点を取り、「ビルド以降にエディタで何を変えても同じ扱い」という緩さを
許容している。ビルドIDを厳密にすると検証のたびに書き出しが必要になる。

- **`MatchmakingQueue`**:キュー文書へ `build` を書き、`_try_claim_or_check()` が
  自分と違う候補を掴まない。**掴まないだけで削除はしない**(古い版の人が待つ権利は
  残す。`STALE_SECONDS` による掃除とは目的が違う)。全候補が版違いだった場合は
  `version_mismatch(newer_exists)` を発行して画面へ返す
- **`RoomMatch`**:ルーム文書へ `build` を書き、`join_room()` / `spectate()` が
  参加前に突き合わせる。参加側で弾くため、作成側が版違いの相手を掴むことはない
- **絞り込みはクライアント側で行う**。`query_waiting()` は `match_id == ""` の
  単一フィールドの等価フィルタで、ここへ `build` を足すと複合インデックスを
  要求することになる(6章のクエリ方針に反する)

**`build` を持たない相手(この機能より前の版)は版違いとして扱う。**盤面が食い違う
可能性があるのはまさにその組み合わせであり、未設定を「何でも通す」側へ倒すと
守りたいケースを素通りさせる。


### 6.5 ルームマッチ画面(GameDesign.md 11章)

| クラス | 責務 |
|---|---|
| `CardRoomScreen`(`scripts/ui/card_room_screen.gd`) | ルームマッチの3つの入口(部屋を作る / コードで参加 / 観戦)と、その待機。使用デッキと持ち時間の設定もここに置く |

**`RoomMatch` を持つのはこの画面**であり、`BattleTab` からは参加・観戦・部屋作成の
コードをすべて外した(バトルタブに残るのはランダムマッチ・CPU戦・リプレイ・戦績・復帰)。
待機中の巡回ドット・キャンセル・失敗の文言は、バトルタブと同じ組み立てをこの画面が
自前で持つ。**共通化しない**のは、バトルタブ側は「マッチング中」の1状態しか持たないのに対し、
こちらは部屋の作成・相手待ち・参加・観戦待ちと状態が4つあり、片方に合わせると
もう片方が使わない分岐を抱えるため。

**持ち時間の入/切は `rooms/{code}` の `time_limit` として持つ**(GameDesign.md 5章)。
部屋を作る側が書き、参加する側は `join_room()` が読んで `RoomMatch.time_limit` へ控える。
**画面はマッチ成立時にこの値を対局画面まで運ぶ**(`matched` → `Main` →
`CardMatchScreen.start_online_match()` → `CardMatchOnline.start()`)。
`CardMatchOnline` は `time_limit` が偽のとき `MatchClock` を生成しない。
**`_clock == null` は既にCPU戦が通っている経路**(`_process()` の先頭・手の送信の
`clock` 付与・相手の時間切れ監視がいずれも null を見て降りる)ため、
持ち時間なしのために新しい分岐を足す必要はない。

**切断からの復帰でも持ち時間の設定を引き継ぐ**。`OnlineResume` のレコードへ
`time_limit` を足し、`resume()` はその値を見て時計を作るかどうかを決める。
`time_limit` を持たない古い記録は、これまでどおり持ち時間ありとして扱う。

**観戦は、対局が始まっていなければ同じ画面で待つ**(GameDesign.md 11章)。
`RoomMatch.spectate()` は `match_id` が空でも失敗させず、`spectate_waiting` を1度出してから
`POLL_INTERVAL_SECONDS` ごとに読み直す。**バージョンの突き合わせは待ち始める前に行う**
(版が違う部屋を待ち続けても、始まった瞬間に弾かれるだけのため)。

**参加コードのコピーは `DisplayServer.clipboard_set()`**。Web版ではブラウザに拒否される
ことがあるが、**失敗しても画面には何も出さない**。コード自体が大きく出ており、
手入力で足りるため(GameDesign.md 11章)。

### 6.6 対局中エモートの送受信と表示(GameDesign.md 9章)

- 定型文の定義は `EmoteLibrary`(`scripts/data/emote_library.gd`、staticのみ)で管理する。
- エモートは `{"type": "emote", "side": side, "emote_id": emote_id}` として `MatchAction.emote()` で生成され、他の手と同様に `OnlineMatch.send()` 経由で Firestore の `matches/{id}.actions` に追記される。
- `MatchAction.apply()` では盤面状態の変更を行わず、`return true` で安全に通過する。
- UI演出は `EmoteBubble`(`scripts/ui/emote_bubble.gd`)が担当し、発言側の `PlayerInfoBar.show_emote()` を通じて名札付近に約3.8秒間(完全不透明で3.0秒)フェードイン・自動フェードアウト表示する。**`Tween.set_parallel(true)` は「直前のtweenerと並行に走らせる」指定であり、段を区切る手段ではない**(待機のあとに置くとフェードアウトが待機と同時に始まり、実際には0.3秒しか見えていなかった)。段の区切りは `chain()`、並行は `parallel()` で1つずつ明示する。
- **エモートのボタンは `CardMatchScreen.ACTION_BUTTON_SIZE` を使い、「ログ」「投了」と同じ `CodedButton.make()` で作る。**寸法を別に持つと、同じ列に並んだときに1つだけ別のボタンに見える。
- **選択肢のポップアップ(`EmotePopupPanel`)は `PanelContainer` を継承し、余白だけを持つ空のスタイルを当てて面は `_draw()` で描く**(多段グラデーション + グレイン + 落ち込み影 + 真鍮の枠)。テーマ既定の平坦なパネルのままだと、盤面の上でここだけ別のUIから来たように見える。行の区切りも `HSeparator`(テーマ既定の白い線)ではなく真鍮の細線にする。**面を描くのに `Control` を直に使わない**。子より背面に描かれる性質は望ましいが、コンテナでないと中身の大きさに合わせて自分の大きさが決まらず、パネルが0サイズのまま何も描かれない(実際にそうなった)。
- 画面側(`CardMatchEmote`)では送信後9秒間のクールダウンを持ち、吹き出しが完全に消えて余韻を待ってから再利用できるようにする。**残り時間は `CardMatchScreen._process()` から渡される `delta` だけで減らす**(専用の `Timer` を併せて持たせると二重に減り、クールダウンが半分の速さで明けてしまう)。
- **エモートは棋譜へ記録しない**(`CardMatchScreen._record()` が弾く)。盤面を動かさないため、残すとリプレイの手数だけが増え、コマ送りで何も起きない手を挟むことになる。オンラインでは通信の経路として `actions` に載せるが、これは受信のための搬送であって記録ではない。
- **エモートのUIは対局画面より後に `add_child()` されるため、結果パネル・ログより手前に描かれる**(Godotは後の子ほど手前)。終局後はボタンとポップアップを隠して、結果パネルの操作を塞がないようにする。
- 吹き出し(`EmoteBubble`)の大きさは `_ready()` で文字から決める。**`_draw()` の中で `size` を書き換えない**(レイアウトが変わって再描画が呼ばれ、毎フレーム描き直し続けるため)。
- マリガン中(`state.mulligan_pending` / `_mulligan.visible`)はエモート送信を無効化し、**ボタン自体を隠す**(無効の見た目のボタンが「ログ」「投了」の隣に並ぶと、そこだけ色が違って見えるため)。
- 相手のエモートミュートフラグ(`mute_opponent_emotes`)をサポートし、ミュート中は相手からのエモート吹き出し表示をスキップする。

## 7. リプレイ・観戦の実装方針

- `matches/{match_id}` には既に `deck_a`/`deck_b`(30枚のid)・`seed`(山札の並び)・`actions`(手順)が保存済みで、**任意の局面は初期状態から手を並べ直して作れる**。局面のスナップショットは持たない(4.0節)
- 対局終了時、`MatchState.match_ended` を検知したタイミングで対局画面が `matches/{match_id}` へ `finished_at`(タイムスタンプ)・`winner`(`"a"`/`"b"`)を書き込む。この書き込みが「終了済みマッチ」の判定基準を兼ねる(未書き込み=対局中または放棄されたマッチ)
- リプレイ一覧の取得は、`player_a == 自分のuid` と `player_b == 自分のuid` の**2本の等価フィルタクエリ**をそれぞれ実行し、結果をクライアント側でマージ・`finished_at`降順ソートする(複合インデックスを要求する `OR` 条件や `orderBy` 併用を避ける、既存のクエリ方針を踏襲)
- リプレイ閲覧は `player_a`/`player_b` のuidが自分のuidと一致する場合のみ許可する(クライアント側での表示制御。Firestoreセキュリティルール側でも同様の制限を検討する)
- 保存件数の上限(直近30件)は、対局終了時の書き込み後に「終了済みマッチが30件を超えていないか」をチェックし、超過分を `finished_at` の古い順に削除するクリーンアップ処理で維持する。プレイヤー単位ではなくアプリ全体で30件とし、シンプルな実装に留める
- `ReplayListScreen`:`DeckListScreen` と同様の横長カード縦スクロール一覧。各カードは対局日時・勝敗・先手/後手に加え、`deck_a`/`deck_b` からデッキを代表する数枚のアイコンを表示する(30枚をそのまま並べるとカードに収まらないため)。`BattleTab` に追加する「リプレイ」ボタンから遷移する
- 投了で終わった対局は、`actions`の末尾に`surrender`が1件入った状態で保存される。リプレイ再生時は他の手と同じく`OnlineMatch.apply()`へ流れて`match_ended`が発火するが、再生モードでは元々結果パネルを出さない仕様のため追加の分岐は要らない。手数表示では投了も1手として数える(将棋の棋譜で投了を1手と数えるのと同じ扱い)
- 再生画面は新規シーンを作らず、対局画面に「再生モード」を追加する形で実装する。再生モードでは `MatchState` をデッキと種から作り直し、保存済み `actions` を1件ずつ `MatchAction.apply()` へ流し込んで進行を再現する。行動の列には、先頭へ/1手戻る/再生・一時停止/1手進む/最後へ、の5ボタンと手数表示、および一覧へ戻る導線を置き、盤面のクリック操作は無効化する
- 観戦は既存の**ルームコード**を再利用する。`rooms/{code}` には対局成立後も `match_id` が残っているため、観戦者が同じコードを入力すると `rooms/{code}` から `match_id` を引き、`matches/{match_id}` の購読(ポーリング)を開始できる。ランダムマッチには共有可能なコードが存在しないため観戦導線を用意しない
- 対局画面に「観戦モード」を追加する(対局モード・再生モードに続く3つ目のモード)。`OnlineMatch` のポーリング機構をそのまま使い、`send_and_apply` を呼ばずに `action_received` シグナルだけを購読して盤面へ反映する。行動のボタンは出さず、盤面操作は無効化する。対局終了の検知(`match_ended`)は通常通り行うが、`finished_at`/`winner` の書き込みは対局者側のみが行い、観戦者側では行わない
- `BattleTab` のルームコード入力欄に「観戦する」ボタンを追加し、参加導線と並べて配置する

### 7.1 CPU戦のローカルリプレイ保存(フェーズ11 K-2、実装済み)

- `LocalReplayService`(`scripts/net/local_replay_service.gd`、`RefCounted`のstaticクラス、
  `DeckSave`と同様「Autoloadを使わずstaticで持つ」流儀)が、CPU戦の棋譜を
  `user://cpu_replays.json` へ配列として保存する。1件のレコードは、オンライン版
  `matches/{id}` ドキュメントと対応する内容(`deck_a`/`deck_b`・`seed`・
  `actions`・`finished_at`・`winner`)に加えて `id`(`"cpu_<unixtime>_<乱数>"`)・
  `source`(常に`"cpu"`、一覧画面でのオンライン/CPU戦の判別に使う)を持つ。
  `mark_finished(record)` が保存(+保存件数の上限維持)、`list_replays()` が
  `ReplayService.list_replays()`と同じ`{"id":..., "fields":{...}}`形の配列(`finished_at`降順)を
  返し、`get_replay(id)` がidに一致する1件をフラットな形(対局画面の再生モードが
  そのまま読める形)で返す
- 保存件数の上限(直近30件、`RETENTION_LIMIT`)は、オンライン対戦(Firestore、
  `ReplayService.RETENTION_LIMIT`)とCPU戦(ローカル、`LocalReplayService.RETENTION_LIMIT`)を
  **それぞれ独立に**30件まで保持する(合算で管理すると片方の対局頻度が高い場合にもう片方が
  不当に圧迫されるため)
- CPU戦の棋譜は `CardMatchScreen._cpu_record`(Dictionary)へ溜める。**`start_cpu_match()` が
  山札の種を決めてから対局を始める**のがこの記録の前提で、両者のデッキのidと種をここで控え、
  以後は手を送るのと同じ `_perform()` が `actions` へ1件ずつ足す。終局後の後始末を持つ
  `CardMatchOutcome` が `LocalReplayService.mark_finished()` へ渡す。オンライン対戦の
  `OnlineMatch` がFirestoreへ逐次書き込むのとは異なり、CPU戦は終局時に一括で1回だけ保存する
- **再生の入口は `CardMatchScreen.start_replay(record)` の1つだけ**。Firestoreの
  `get_document()` も `LocalReplayService.get_replay()` もフラットな `Dictionary` を返すため、
  オンライン対戦とCPU戦で再生の経路を分ける必要がない
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

- CPUの思考は `CardCpuStrategy`(`scripts/logic/card_cpu_strategy.gd`、`RefCounted`)へ切り出し、
  `CardMatchScreen` は思考の中身を知らずに `choose_action(state, side) -> Dictionary` を呼ぶだけにする
- 1手番の中の順序は「場に出す → 攻撃する → 反転する → 終える」の貪欲法。**攻撃してから
  反転する**のが要点で、逆にすると攻撃力の高い状態を捨ててしまう。価値の物差しは
  `CardInstance.lifetime_damage()`(GameDesign.md 1章)を使う
- **砂術は「出す」の中で一緒に選ぶ。**1手番の順序へ新しい段を足さず、`_choose_play()` が
  手札の砂時計と砂術を同じ物差しで比べる。物差しは**その1枚で動く生涯ダメージの差**とし、
  砂時計は `lifetime_damage()`、砂術は「効果を適用したら盤面の評価がいくつ変わるか」を
  仮の適用で見積もる。**対象を取る砂術は、対象が1体もいなければ撃たない**
  (自動選択に任せると、対象のいない除去を無駄撃ちする)
- マリガンの選択は `choose_mulligan()` が持つ(コスト4以上を戻す)
- CPUの手番になったら `CardMatchScreen` が `CPU_THINK_SECONDS` の間合いを置いてから
  1手だけ適用し、また間合いを置く。**まとめて指すと何が起きたか追えない**ため1手ずつ進める
- 適用の経路は自分の手・オンラインの手・リプレイ再生と同じ `MatchAction.apply()`。
  CPUのためだけの経路を作らない
- CPUのデッキは `CardDeckSave.random_deck()`(全カード×2の山から30枚)。誘導対局のときだけ
  プリセットの「基本」を使う(GameDesign.md 18章)
- CPU戦はオンライン対戦ではないため、`matches/{match_id}` への書き込みは行わない。
  棋譜は `LocalReplayService` がローカルへ保存する(7.1節)

---

## 9. 効果音・BGMの実装方針

- 効果音は `SoundBank`(`RefCounted` 継承のstaticクラス)に集約する。`MatchSetup`/`DeckSave`/`NetSession` と同じ「Autoloadを使わずstaticで持つ」流儀に揃える
- `ensure_ready(parent)` を `Main._ready()` から1度だけ呼び、`AudioStreamPlayer` のプール(常駐ノード)を生成する。staticクラス自体はNodeではないため、実際の再生には実ノードが要る
- `wire_buttons(root)` はシーンツリーを再帰的に走査し、全Buttonの `pressed` へ共通のボタン押下音を接続する。個別配線は漏れやすいため、`Main._ready()` で全体に対して1度呼ぶことを基本とするが、実行時に動的生成されるノード(例: `DeckListScreen` のカード一覧)は起動時の走査に含まれないため、生成元の画面スクリプト側で個別に呼び直す。`is_connected()` チェックにより二重接続は起きない
- 出す/反転/攻撃(相打ち)/被弾/決着の専用効果音は対局画面が該当処理箇所で直接 `SoundBank.play()` を呼ぶ。行動の列のボタンは共通のボタン押下音と二重に鳴らさないため `wire_buttons()` の対象から除外する
- 音量設定は `user://sound_settings.json` へJSONで永続化する。`SoundBank._sfx_volume`/`_bgm_volume`(いずれも0.0〜1.0のfloat)は `static var` の初期化式でクラス初回アクセス時に自動読み込みされるため、`ensure_ready()` を待たずに早期から正しい値を返せる(ホーム画面の設定ボタンは `Main` より先に `_ready()` が走るため、ここで読んでおかないと初期表示に反映されない)。`get_sfx_volume()`/`set_sfx_volume()`・`get_bgm_volume()`/`set_bgm_volume()` で参照・変更し、`play()` 時と設定変更時に `AudioStreamPlayer.volume_db` を `linear_to_db()` で更新する(0%は `-inf` を避けるため `-80.0dB` 固定)。`is_muted()` は `_sfx_volume <= 0.0` の派生として残している
- ホーム画面右上に `SettingsButton`(`Button`)を配置し、押すと `SettingsPanel`(`scenes/settings_panel.tscn`、`ResultOverlay`/`SurrenderConfirm` と同じ「暗幕+`content_panel.tres` の中央パネル」パターン)が開く。パネル内の `HSlider` 2本(いずれも0〜100%。効果音は `SoundBank.set_sfx_volume()`、BGMは `SoundBank.set_bgm_volume()` を随時更新する)で音量を操作し、その下に公式Discordサーバーへの導線、最後に「閉じる」ボタンを置く(GameDesign.md 9章)
- **ボタンの見た目はハンバーガー(`UiPaint.Emblem.MENU` / `img_icon_menu_*.tres`)とし、文言を持たない。**`StyleBox` はリソース参照のため `.tscn` のパッチ(値がJSON)では差し替えられず、`HomeScreen._ready()` が `CodedButton.apply_styles()` で指定する。同じ理由で、Discordのボタン(`img_icon_discord_*.tres`)も `SettingsPanel` がコードで組み立てて「閉じる」の直前へ挿す。**どちらも文言を持たない正方形のアイコンボタン**にして、メニューの中身が増えても同じ形で並べられるようにする
- **`EmblemPlacement.CENTER` の紋章は、単位座標の上限(±0.85)まで使ってはいけない。**`draw_emblem` へ渡る `size` はボタン矩形の 0.42 倍(半径)であり、±0.85 まで描くと額縁の内側の凹んだパネルからはみ出して枠へ載り上がる(ハンバーガーが実際にそうなっていた)。±0.55 程度に留める
- **Discordのマークだけは多角形で似せず、公式のシンボル(`assets/ui/brands/discord_mark.svg`)をテクスチャとして敷く。**他の紋章と同じ真鍮の浮き彫りにしないのは、ブランドのマークを塗り替えないため(Discordの規定は blurple / 白 / 黒 のいずれかを求める)。SVGは `svg/scale=8`(192px)でインポートし、出所は `assets/CREDITS.md` へ記録する
- **リンクを開くのは `OS.shell_open()`**。Web書き出しでは `window.open` になるため、押した操作を起点にしないとブラウザに塞がれる(BGMの自動再生制限と同じ事情)。招待URLは `SettingsPanel.DISCORD_INVITE_URL` の1箇所だけが持つ
- 音源は**CC0(パブリックドメイン)ライセンスの外部フリー素材**を使う(GameDesign.md 9章)。効果音は `assets/sfx/`、BGMは `assets/bgm/` に置く。**取り込んだ素材の出所・作者・ライセンスは `assets/CREDITS.md` に必ず記録する**。CC0なので表示義務はないが、後から「この音はどこから来たのか」を追えないと、ライセンスの再確認も差し替えもできなくなるため
- **BGMは `MusicPlayer`(`scripts/logic/music_player.gd`、`RefCounted` 継承のstaticクラス)が担当し、`SoundBank` とは別クラスに分ける**。効果音が「1発鳴らして終わり」なのに対し、BGMはクロスフェード・ループ・自動再生制限の解除といった継続的な状態を持つため、同じクラスへ同居させると `SoundBank` が肥大化する。`ensure_ready(parent)` で `AudioStreamPlayer` を2本(クロスフェードで鳴り替えるため)生成する流儀は `SoundBank` と揃える
- **音量の単一情報源は `SoundBank` 側に置き続ける**。`_sfx_volume` と `_bgm_volume` の2つを持ち、`user://sound_settings.json` へ両方を保存する(旧形式の単一キー `volume` を見つけた場合は両系統の初期値として読み、次回保存時に新形式へ移行する)。`MusicPlayer` は自前で音量を永続化せず、`SoundBank.get_bgm_volume()` を参照し、`SoundBank.set_bgm_volume()` が `MusicPlayer.apply_volume()` を呼んで反映する。設定の読み書きを2クラスに分散させると、同じJSONファイルを互いに上書きし合うため
- **BGMの切り替えは `Main._show_only()`(画面切り替えのハブ)から1箇所で行う**。遷移先に応じた曲は `Main._track_for()` が決める(対局画面なら対局曲、`TitleScreen`ならタイトル曲、それ以外はホーム曲)。画面ごとに個別へ `MusicPlayer.play()` を書き散らさない
- **クラシック曲はシームレスにループしない**ため、`AudioStreamPlayer.finished` を購読し、数秒の間を置いてから頭へ戻す「アルバム再生」方式で繰り返す。インポート設定でループを有効にすると `finished` が発火しなくなるため、**実行時に `stream.loop = false` を明示する**
- **曲の終端の `TAIL_FADE` 秒前から音量を絞る**(GameDesign.md 9章)。再生開始時に `stream.get_length()` から逆算したタイマーを張り、発火時にまだ同じ曲が同じプレイヤーで鳴っていればフェードアウトを始める。タイトル曲のように**曲の途中を切り出した音源**でも切れ目が唐突に聞こえないようにするため。フェード中は `set_volume()` が音量を戻さないよう `_tail_fading` で守る
- **タイトル曲は元の録音を再エンコードせず、Oggのページ境界でそのまま切り出して使う**。この環境には ffmpeg/oggenc が無く、また再エンコードは音質を落とすため。切り出しは「granule_position が目標サンプル数を超えたページまでを残し、最後のページへ EOS フラグを立ててCRCを再計算する」だけで、ページの中身には触れない
- **ブラウザの自動再生制限に対応する**。`MusicPlayer.play()` は、最初のユーザー操作を検知するまで実際には鳴らさず、要求されたトラックを `_pending_track` として覚えておくだけにする。`Main` が最初のクリック/タップで `MusicPlayer.notify_user_gesture()` を呼び、そこで保留していたトラックの再生を始める
- **対局中の効果音は `CardMatchSound` が1箇所で鳴らす**(GameDesign.md 9章の6種のうち、
  ボタン押下を除く5種)。対応は 出す=`MOVE` / 反転=`FLIP` / 攻撃(相打ち)=`SWAP` /
  被弾=`DAMAGE` / 決着=`RESULT_WIN`・`RESULT_LOSE`。**攻撃(相打ち)は「砂時計どうしの攻撃」
  のときだけ鳴らし**、本体を殴った場合は被弾(HPの減り)の側で鳴る。HPの増減は
  `hp_changed` が新しい値しか渡さないため、直前の値をこのクラスが控えて減少だけを拾う
- **砂時計の破壊(`UNIT_BREAK`)と硝子の膜割れ(`GLASS_BREAK`)は、音源を増やさず
  高さで鳴き分ける**(GameDesign.md 9章)。`SoundBank.SFX_PATHS` は被弾と同じ
  `damage.ogg` を指し、`SFX_PITCH` が破壊を低く・膜割れを高くする。素材を1つ足すたびに
  CC0の音源を探して `assets/CREDITS.md` へ出所を記録する手間が生まれるため、
  **区別を付けたいだけの場面では音源を増やさない**
  - **`pitch_scale` は再生のたびに入れ直す。**`AudioStreamPlayer` はプールで使い回すため、
    前に鳴らした音の高さが残る(入れ忘れると、破壊の直後の被弾まで低く鳴る)
  - 受け口は `unit_destroyed` と `unit_shielded` で、いずれも `MatchState` のシグナル。
    画面側の分岐を増やさずに、リプレイ・観戦・CPUのすべてで同じように鳴る
- **攻撃の演出中は、効果音を当たる瞬間まで持ち越す**(`CardMatchStrike._on_impact()` が
  `CardMatchSound.flush()` を呼ぶ)。砂の飛散を持ち越すのと同じ理由で、解決と同時に鳴らすと
  駒がまだ渡っている最中に衝突音だけが先に鳴り、因果が逆に聞こえる
- **決着でBGMを止めた後、「もう一度」で対局曲へ戻すのは `_begin_state()` の役目**。
  画面が切り替わらないため `Main._show_only()` を通らず、止めたままになる
- **結果画面ではBGMを止め、勝敗別の短いジングルを鳴らす**(GameDesign.md 9章)。`SoundBank.Sfx` の `RESULT` を `RESULT_WIN`/`RESULT_LOSE` の2つへ分け、`MatchResultPresenter` が勝敗に応じて鳴らし分ける

---

## 10. アカウント・通貨の実装方針

GameDesign.md 14章(アカウント)・15章(通貨)の実装方針。認証は Firebase Authentication、
プレイヤーごとのデータは Firestore の `players/{uid}` ドキュメントで扱う。

### 10.1 認証(`FirebaseAuth` の拡張)

- **HTTP通信では `HTTPRequest.accept_gzip` を必ず false にする**(`HttpJson`)。Web書き出しでは
  ブラウザが `Content-Encoding` を透過的に展開してからGodotへ渡すにも関わらず、`HTTPRequest` は
  応答ヘッダを見て自前でもう一度展開しようとし、`stream_peer_gzip.cpp` で失敗して
  `RESULT_SUCCESS` にならない。**エディタ実行では再現せず、書き出した版でのみ全ての通信が
  失敗する**(画面上は「接続できませんでした」としか見えない)。やり取りするJSONはいずれも
  小さく、圧縮しない実害がないため常に無効にする

- **ID/パスワードは、Firebase の「メール/パスワード」プロバイダへ合成アドレスとして渡す**。
  ユーザーが入力したIDを `<id>@hourglass-arena.local`(`SYNTHETIC_EMAIL_DOMAIN`)という形の
  アドレスへ変換して `accounts:signUp` / `accounts:signInWithPassword` を呼ぶ。この方式には
  次の利点がある。
  - **IDの重複チェックが自動的に効く**。Firebase はアドレスの一意性を保証するため、
    重複時は `EMAIL_EXISTS` が返る。専用のID台帳コレクションを持たずに済む
  - パスワードのハッシュ化・保管を自前で持たない。クライアントは平文パスワードを
    Google のエンドポイントへ送るだけで、`user://` にも Firestore にも保存しない
  - 実在しないドメインのため、メールによる復旧は行えない(GameDesign.md 14章の明記どおり)。
    将来メールを任意項目にする場合は `accounts:update` で本物のアドレスへ変更すればよい
- IDは小文字へ正規化し、英数字とアンダースコア・ハイフンのみに制限する(アドレスとして
  成立しない文字を弾くため)。この検証は送信前にクライアント側で行い、エラー文言を
  自前で出す(Firebase のエラーコードをそのまま見せない)
- **匿名 → 登録済みへの昇格は `accounts:signUp` へ現在のIDトークンを添えて行う**
  (新規作成ではない)。`idToken` を付けると「新しいアカウントを作る」ではなく
  「そのトークンのユーザーへ認証情報を結びつける」意味になり、**uid が変わらないまま**
  永続アカウントになる。これにより匿名時代のリプレイ(`player_a`/`player_b` は uid で
  引く)と `players/{uid}` の残高がそのまま引き継がれる。新しくサインアップして
  データを移し替える方式は採らない
- **`accounts:update`(setAccountInfo)は使ってはいけない**。2023年9月15日以降に作られた
  プロジェクトでは**メール列挙保護が既定で有効**で、その状態ではメールアドレスの追加・変更が
  `Please verify the new email before changing email` として拒否される。ここで使うのは
  実在しない合成ドメインのアドレスのため検証メールが永久に届かず、登録が一切できなくなる。
  当初 `accounts:update` で実装して実際にこの状態になったため、記録として残す。
  `accounts:signUp` によるリンクは列挙保護が有効なままでも通る(実測で確認済み)
- **認証トークンを `user://` へ永続化する**(`AccountStore`)。保存するのは `refresh_token`・
  `uid`・最後に使ったIDのみで、**パスワードは保存しない**。起動時は保存済みの
  `refresh_token` で `securetoken` を叩いて復帰し、失敗した場合のみ新しい匿名サインインを
  行う。これが無いと起動のたびに別の uid が発行され、オンライン対戦のリプレイが
  一覧から消える(アカウント機能の導入前に実際にそうなっていた)
- `NetSession.sign_in()` の「進行中のサインインがあればその完了を待つ」挙動は変えない。
  復帰・新規匿名サインイン・ID ログインのいずれもこの1本の経路を通す

### 10.2 プレイヤーデータ(`players/{uid}`)

| フィールド | 型 | 内容 |
|---|---|---|
| `display_name` | String | 表示名(10文字まで)。未設定は空文字 |
| `login_id` | String | 登録済みなら入力されたID。匿名なら空文字(表示用) |
| `icon_id` | String | アイコンID(未設定時は `"sand"`) |
| `title_id` | String | 称号ID(未設定時は `"novice"`) |
| `currency` | int | 砂金の残高 |
| `cpu_reward_date` | String | CPU戦の報酬を数えている日付(`YYYY-MM-DD`) |
| `cpu_reward_count` | int | その日付にCPU戦で報酬を得た回数 |
| `owned_icons` | Array[String] | ショップで買ったアイコンのid。初期解放の8種は含めない |
| `owned_emotes` | Array[String] | ショップで買ったエモートのid。初期解放の4種は含めない |
| `emote_slots` | Array[String] | 対局中に出す4つ。空なら初期の4種を使う |
| `updated_at` | float | 最終更新時刻(Unix時間) |

- 利用可能なアイコンと称号の定義は `UserProfileLibrary`(`scripts/data/user_profile_library.gd`)に集約する。初期解放アイコンは紋章8種(`sand`, `hour`, `crown`, `shield`, `sword`, `eye`, `halo`, `burst`)とし、マスコット(`mascot`)は将来のショップ要素として初期配布から除外する。
- 読み書きは `AccountService`(`scripts/net/account_service.gd`、`ReplayService` と同じ
  static のみのクラス)に集約する。対局画面や各画面が `FirestoreClient` を直接
  叩かないようにするため
- **残高の加算は read-modify-write を `commit()` の前提条件付きで行う**。`OnlineMatch` の
  手の送信と同じ流儀で、`updateTime` を前提条件にして競合したら読み直して再試行する。
  同じアカウントを2つのタブで開いた場合に加算が消えないようにするため
- **通信に失敗した加算はローカルへ退避する**(`AccountStore` の `pending_currency`)。
  次に `AccountService.grant()` が成功した時点で退避分を足し込んでから書く。CPU戦は
  オフラインでも成立するため、この経路が無いと獲得が消える

### 10.3 通貨の付与(`CurrencyRules`)

- 報酬額と条件は `scripts/logic/currency_rules.gd`(static のみ)へ表として持つ。
  GameDesign.md 15章の数値をコードへ散らさないため
- 対局画面は対局の種別(ランダムマッチ / ルームマッチ / CPU戦)と勝敗・総手数を
  渡すだけにする。**オンライン対戦がランダムマッチかルームマッチかは、これまで
  対局画面が区別していなかった**ため、`HomeScreen.online_match_found` と
  オンライン対局の開始経路に対局種別を1つ足して伝える
- ローカル対戦(pass&play)・観戦・リプレイ再生は報酬の対象外。いずれも「自分が
  1人のプレイヤーとして対局した」とは言えないため
- 判定は終局時に1度だけ行い、結果を `MatchResultPresenter` が結果パネルへ
  1行として出す(GameDesign.md 9章)

### 10.4 リプレイのアカウント紐づけ

- オンライン対戦のリプレイは `matches/{id}` の `player_a`/`player_b` が uid を持つ既存の
  構造をそのまま使う。10.1 の永続化により uid が変わらなくなることで、追加の紐づけを
  持たずに「アカウントの記録」として成立する
- **保持件数の上限(30件)をアカウント単位に変える**。`ReplayService._enforce_retention()` は
  終了済みマッチをアプリ全体で古い順に消しており、プレイヤーが増えると他人の記録を
  消してしまう。`list_replays()` が返す「自分の対局だけ・新しい順」の並びをそのまま使い、
  上限より後ろを消す。これに伴い `FirestoreClient.query_finished_matches_oldest_first()` は
  参照0件になったため削除した
- CPU戦のリプレイ(`LocalReplayService`、`user://cpu_replays.json`)は保存先をローカルの
  まま維持し、レコードへ `owner_uid` を足して一覧で自分のものだけを出す。アカウントを
  切り替えたときに他のアカウントの記録が混ざらないようにするため。**保持上限も所有者ごとに
  数え**、別のアカウントの記録を巻き添えで消さない。`owner_uid` を持たないレコード
  (アカウント機能の導入前に保存されたもの)は、いま遊んでいるアカウントのものとして扱う。
  サインインできておらず `owner_uid` が空のときは、絞り込む基準が無いため全件返す
- 相手の表示名は `AccountService.fetch_display_name()` が `players/{uid}` から引き、
  uidごとにキャッシュする。対局画面のHPバー(`PlayerStatusBar.setup()`)と
  リプレイ一覧のカードが使う。未設定・取得失敗なら従来どおり「自分」「相手」に落とす

### 10.5 UI

- `AccountScreen`(`scenes/account_screen.tscn`)を追加する。他の画面と同じ共通
  `ScreenHeader`(4章)に従い、画面中央に幅1060pxの2カラムパネルを配置する。
  - **左カラム**: 名札プレビュー、表示名編集、アイコン選択(4x2グリッド)、称号選択(ScrollContainer対応リスト)、プロフィール保存ボタン。
  - **右カラム**: アカウント状態、登録・ログインフォーム、ログアウトボタン、注意文。
  - **ボタンスタイル**: 全ボタンに `CodedButton`(真鍮スタイル)を適用し、画面全体の質感を統一する。
- 入口は2つ。`TitleScreen` と `HomeScreen` のヘッダー。`Main` は他の画面と同様に
  `_show_only()` で切り替える
- ホーム画面のヘッダーには設定中のアイコン、表示名と砂金の残高を出す。残高は `AccountService` が
  キャッシュしている値を読むだけにし、画面を開くたびに通信しない

### 10.5.1 表示名に使える文字(GameDesign.md 14章)

`TextGlyphs`(`scripts/logic/text_glyphs.gd`、staticのみ)が、同梱フォントに字形が
あるかどうかだけを答える。**対応する文字の一覧をコードへ持たず、`Font.has_char()` で
フォント自身に問い合わせる。**表を持つと、フォントを差し替えたときに黙って食い違うため。
判定した結果は文字コードごとにキャッシュする。

- `AccountScreen` は入力のたびに `sanitize()` を通し、使えない文字を取り除いて
  1行の注意を出す(GameDesign.md 14章の「入力欄では受け付けない」)
- `AccountService.fetch_display_name()` は、**受け取った他プレイヤーの表示名を
  `TextGlyphs.replace_unsupported()` へ通してから返す**。相手のクライアントが何を
  送ってくるかはこちらで制御できないため、入力側の制限だけでは自分の画面が化ける

**フォントを扱うがロジック層へ置く。**参照するのは `FontFile` リソース1つで、UIの
ノード・レイアウトには一切触れない。ここをUI層に置くと、`AccountService`(net層)が
UI層へ依存することになる。

### 10.6 デッキコード(GameDesign.md 9章)

**画面へ出すコードは8桁の数字であり、中身は持たない。**`deckcodes/{コード}` へ
「id*枚数」を `,` で連ねた文字列(`CardDeckCode.to_text()`)を預け、番号だけを渡す。
30枚の組み合わせは1億通りをはるかに超えるため、**中身を持ったまま8桁へ収めることは
原理的にできない**。

| クラス | 責務 |
|---|---|
| `DeckCodeService`(`scripts/net/deck_code_service.gd`, static) | 預ける(`publish`)・引く(`fetch`)。`AccountService` と同じく `FirestoreClient` を受け取る形にし、UI が Firestore を直接叩かない |
| `CardDeckCode`(static) | デッキ ⇄ テキストの変換(`to_text` / `from_text`)と、戦績が使う指紋(下記) |

- **発行は `CardDeckCodePanel` の「コードを発行」を押したときだけ行う。**画面を開くだけで
  預けると、使われないドキュメントが際限なく増える。**同じ構築には同じ番号を返す**ため、
  `publish()` は指紋 → コードの対応をセッション内でキャッシュする
- **コードは使われていない番号を選んで作る**(`create_document()` の `exists:false`)。
  衝突したら引き直す
- **預けたデッキは消さない**(GameDesign.md 9章)。保持件数の上限も持たない
- **`CardDeckCode.fingerprint()` は画面へ出さない内部の識別子**として残す。戦績
  (10.7節)がデッキ別の勝率を数えるのに使っており、**記録のたびに通信させるわけには
  いかない**ため、こちらは従来どおりローカルで完結する文字列(`HG1-` + deflate + Base64)。
  読み込みの経路は無く、突き合わせにしか使わない

**プールから消えたカードを含むコードは読めない。**`from_text()` が `CardLibrary` に
無い id を見つけた時点で空の配列を返す。カードが増えるぶんには既存のコードは読める。

### 10.6.1 デッキ表の画像(GameDesign.md 9章)

**共有の入口は `CardDeckSharePanel` の1つだけ**とし、デッキ表とデッキコードを同じ
パネルへ並べる(旧 `CardDeckCodePanel` を改名した)。ヘッダーの主アクションは3つまでで
既に保存・プリセットが埋まっており、**分けると4つ目が必要になる**という事情もある。

| クラス | 責務 |
|---|---|
| `CardDeckSheet`(`scripts/ui/card_deck_sheet.gd`) | 表そのものの組み立てと描画。大きさは `SHEET_SIZE` の固定値 |
| `ImageShare`(`scripts/logic/image_share.gd`, static) | PNGをクリップボードへ置く / ファイルへ保存する。Web と それ以外の分岐を1箇所へ集める |

- **表は `SubViewport` の中で組み、その `ViewportTexture` をそのままパネルへ映す**。
  書き出す画像と画面に見えているものが同じ実体になるため、**見本と書き出しが食い違う
  経路そのものが無い**。`HourglassArt` が焼き付けに使っているのと同じ流儀
- **棚は `CardDeckShelf` を使い回す**(`columns = 10` / `readonly = true`)。
  共有のためだけに似た並べ方をもう1つ書くと、片方だけが古くなる。
  **大きさは 1280x720 の固定**(枠の数が固定になったため高さも決まる)
- **並びは `CardLibrary.compare_by_cost` を通す。**画面ごとに並べ方を決めない
  (GameDesign.md 9章)
- **コードは既に発行済みのときだけ載せる。**画像を出すためだけに `publish()` を
  呼ぶと、見せるだけのつもりで通信し、使われない番号を預けることになる
- **画像をクリップボードへ置けるのは Web だけ。**Godot 4.6 の `DisplayServer` は
  `clipboard_get_image()` しか持たない(`clipboard_set_image()` は存在しない)ため、
  `ImageShare` は Web では `JavaScriptBridge` から `navigator.clipboard.write()` を呼び、
  **断られたらDOMオーバーレイで画像を表示して右クリックコピーできるようにする**(併せて保存リンクも用意)。
  それ以外の環境では `user://` へ保存して保存先を1行で示す。判定は `OS.has_feature("web")` で行う
- **`JavaScriptBridge.create_callback()` の戻り値は変数へ持ち続ける。**その場で捨てると
  JS 側から呼び戻される前に解放され、結果が返らない
- **`SubViewport` 内のフォント解決と文字化け対策。** `SubViewport` は親 Control の `theme` を
  自動継承しないため、`project.godot` の `[gui] theme/custom` に `main_theme.tres` を設定し、
  さらに `CardDeckSheet` 自体も `THEME_PATH` を `_ready()` で読み込む。
  `CardDeckShelf` のフォールバック先もエンジン組み込みフォントではなく
  同梱の日本語フォント(`ZenKakuGothicNew-Bold.ttf`)を参照させ、Web書き出し環境等で
  画像内の日本語文字が豆腐(□)に化けるのを防ぐ

---

### 10.7 戦績(GameDesign.md 19章)

| クラス | 責務 |
|---|---|
| `MatchStats`(`scripts/logic/match_stats.gd`, static) | `user://match_stats.json` へ積み上げる。アカウント(uid)ごとに「種別別の通算 / カード別 / デッキ別」を持つ |
| `CardStatsScreen`(`scripts/ui/card_stats_screen.gd`) | 左に通算とデッキ別、右にカード別。共通の `ScreenHeader` を使う |
| `CardMatchOutcome`(`scripts/ui/card_match_outcome.gd`) | 終局後の後始末(リプレイの保存・砂金の付与・戦績の記録)。`card_match_screen.gd` が1000行の上限に達したため切り出した |

**リプレイから集計しない。**リプレイは直近30件しか残らないため(GameDesign.md 12章)、
古い対局が消えるたびに通算の勝率が変わってしまう。終局のたびに1件足す積み上げ方式にして、
保持件数と切り離す。

**テストは `MatchStats.reset_for_test()` を通す。**以後の保存が無効になるため、
`user://` の実データを書き換えずに検証できる。

**カード別は「そのカードを入れたデッキで戦った勝率」**であり、カードの強さではない
(強さの測り方は `docs/BalanceReport_v5.md` 2章の方式による)。画面の見出しにもそう書く。

---

### 10.8 ショップと所有(GameDesign.md 21章)

| クラス | 責務 |
|---|---|
| `ShopCatalog`(`scripts/data/shop_catalog.gd`, static) | 品揃えと価格。**中身そのものは持たない**——アイコンは `UserProfileLibrary`、エモートは `EmoteLibrary` が持ち、ここは「初期解放に含まれないものが並ぶ」という規則と値段だけを持つ |
| `CardShopScreen`(`scripts/ui/card_shop_screen.gd`) | ショップ画面。共通の `ScreenHeader` を使い、右の主アクションへ残高を出す |
| `EmoteSlotPanel`(`scripts/ui/emote_slot_panel.gd`) | 所有しているエモートから4つを選ぶモーダル。アカウント画面のヘッダーの主アクションから開く |

**品揃えを表として別に持たない。**`ShopCatalog.items()` は
「全アイコン − 初期解放のアイコン」と「全エモート − 初期解放のエモート」を並べるだけにする。
表を別に持つと、アイコンを1つ足したときに**ショップへ並べ忘れた品**と
**初期解放でも購入品でもない、どこにも出ないid**が生まれる。

**所有と枠は `AccountService` が持つ**(`players/{uid}` の3フィールド)。
- `owned_icon_ids()` / `owned_emote_ids()` は**初期解放を必ず先頭に含めて返す**。
  呼ぶ側が「初期の8種 + 買った分」を自分で足す形にすると、足し忘れた画面で
  既定のアイコンすら選べなくなる
- `emote_slots()` は保存済みが空なら `EmoteLibrary.DEFAULT_EMOTE_IDS` を返す。
  **所有しなくなったidは起こり得ない**(買ったものは消えないため)が、
  プールから消えた場合に備えて所有していないidは落とす
- `purchase()` は `grant()` と同じ流儀で、`updateTime` を前提条件にした `commit()` で
  **残高の確認と減算と所有への追加を1回の書き込みで行う**。残高を読んでから別に書くと、
  2つのタブで同時に押したときに2つとも買えてしまう
- **未サインインでは買えない**。`AccountStore` へ退避して後から反映する形(`grant()` の
  経路)は使わない。**砂金の獲得は取りこぼすと失われるが、購入は取りこぼしても
  何も失われない**ため、退避する理由がない

**対局中に出すエモートは `AccountService.emote_slots()` から引く**
(`CardMatchEmote` が `EmoteLibrary.get_emote_ids()` を直に読まないようにする)。
**CPUの返答も同じ4つから選ぶ**——プレイヤーが持っていないエモートをCPUだけが喋ると、
どこで手に入るのか分からない品が対局中に現れることになる。

**アカウント画面のアイコン一覧はスクロールできるようにする**(GameDesign.md 14章)。
左カラムは高さが決まっており、9種買うと17個で5行になって下端のボタンを押し出す。
`ScrollContainer` は `.tscn` を変えず `account_screen.gd` が実行時に挟む
(既に `CodedButton` を実行時に足しているのと同じ流儀)。

---

### 10.9 対局の記録と分析(GameDesign.md 22章)

| クラス | 責務 |
|---|---|
| `MatchRecordService`(`scripts/net/match_record_service.gd`, static) | 分析用の記録を `match_records/{match_id}` へ1件書き、続けて集計 `stats/global` を増分で更新する。`ReplayService` と同じく `FirestoreClient` を受け取る形にし、対局画面が Firestore を直接叩かない |
| `tools/analyze_matches.py` | 記録を読んで集計し、Discordへ投稿する道具。求めたときだけ動かす |

**記録は `matches/{id}` を読み直して作る。**必要なもの(デッキ30枚・種・手順・両者のuid)は
すべてそこに揃っており、**終局の直前に `ReplayService.mark_finished()` が書き終えている**。
対局画面へ棋譜の写しを持たせる案は採らない——オンライン対戦は自分の手しか手元に残しておらず、
相手の手を含めた並びを正しく持つのは Firestore の側だけであるため。

**先着1件だけを通すのは `create_document()`(`exists:false`)。**両者が書きにいくため、
2件目は必ず失敗する。**この失敗は正常な結果であり、再試行しない。**

**集計を更新するのは、記録を書けた側だけ。**`create_document()` が true を返した側だけが
`stats/global` を触ることで、1局を2回数える経路が構造的に無くなる。更新は
`AccountService.grant()` と同じ流儀で、**`updateTime` を前提条件にした `commit()` で
競合したら読み直して再試行する**(初回だけは `exists:false`)。

**呼ぶのは `CardMatchOutcome.finish()` の中、リプレイの保存の後。**終局後の後始末を1箇所へ
集める既存の役割に乗せる。**`await` しない**——結果パネルの表示を通信で待たせないためで、
これは砂金の付与が既に通っている扱いと同じ。失敗しても画面には何も出さない
(GameDesign.md 22章)。

**CPU戦・観戦・リプレイ再生では呼ばれない。**`finish()` 自体が `_interactive` のときにしか
呼ばれず(観戦・再生を除外)、その中で `_cpu_record` が空でありオンラインの `_match_id` を
持つ場合だけ記録する。

**集計は版で分けず `stats/global` の1件へ通算で貯める**(GameDesign.md 22章)。
カードごとの成績は `cards` の下の map(`{id: {"g": 採用局数, "w": 勝った局数}}`)として持つ。
**1局につき両者のデッキを1回ずつ数える**ため、`games` の2倍が `cards` の分母になる。

**戦績画面(`CardStatsScreen`)は、ヘッダーの主アクションのボタン1つで「自分」と「みんな」を
往復する**(`CardListScreen` の並び替えと同じ流儀)。みんなの側は開いた時点で1度だけ
`stats/global` を読み、結果をセッション内に控える。**読めなかったときはその旨を1行で出す**
(自分の戦績はローカルにあるため、通信できなくても従来どおり読める)。

---

### 10.10 対局中演出・QOL(GameDesign.md 9章)

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

### 10.11 デイリーミッション(GameDesign.md 23章)

| クラス | 責務 |
|---|---|
| `DailyMissionData`(`scripts/data/daily_mission_data.gd`, static) | 課題の表(id・数え方・目標・文言・報酬)と数え方の enum(`Metric`) |
| `DailyMissionService`(`scripts/net/daily_mission_service.gd`, static) | 日付判定・進捗・受取。`user://daily_missions.json` へ**アカウント(uid)ごとに**貯める |
| `DailyMissionPanel`(`scripts/ui/daily_mission_panel.gd`) | 確認と受取のモーダル。ホーム画面が最初に開いたときだけ作る |

**課題は Resource ではなくコードの表で持つ。**カード(`.tres`)と違って Inspector から
編集する余地が無く、`Metric` とコードが1対1で対応する。1件足すのは `all()` へ1行足すだけ。
**`Metric` の並びは保存データではない**(進捗は課題の id をキーに持つ)。

**進捗は `MatchState` のシグナルだけで数える。**`DailyMissionService.watch(state, my_side)` を
`_begin_state()` から張り、`unit_flipped` / `spell_cast` / `unit_played` / `attack_performed` と、
落砂のために足した **`trigger_fired(side, trigger)`** を数える。`trigger_fired` は
`MatchState._fire()`(効果の解決を1箇所へ通す私設のヘルパ)が、**効果を持つ駒のときだけ**出す。
呼び出し側へ数える処理を配ると、トリガーを足すたびに書き漏らす。

**数えたぶんは終局まで書かない**(`commit()`)。10手に満たない対局は数えないため、
対局中に書き込むと取り消せない。書くのは `CardMatchOutcome.finish()` の1箇所で、
**戦績(`MatchStats`)と同じ行に並べる**。観戦・リプレイ再生は `_interactive` が false で
`watch()` を張らない。パズルは `finish()` へ到達しないため数えない。

**受取だけは通信を要する**(`AccountService.grant()`)。残高はアカウントにあり、
手元で受取済みにすると権利だけが消える(ショップと同じ扱い。10.8節)。

---

### 10.12 リーサルパズル(GameDesign.md 24章)

| クラス | 責務 |
|---|---|
| `PuzzleStageData`(`scripts/data/puzzle_stage_data.gd`, Resource) | 1問の初期配置。盤面の駒は **`"id:体力:攻撃力"` の文字列**で持つ |
| `PuzzleLibrary`(`scripts/logic/puzzle_library.gd`, static) | `data/puzzles/` を走査して `order` 順に返す。`CardLibrary` と同じ流儀(`.remap` の扱いを含む) |
| `PuzzleProgress`(`scripts/logic/puzzle_progress.gd`, static) | クリア記録。`user://puzzle_progress.json` へアカウントごとに持つ |
| `CardMatchPuzzle`(`scripts/ui/card_match_puzzle.gd`, RefCounted) | 局面の差し替えと正誤の判定。`CardMatchOnline` と同じ `_screen` 参照の切り出し |
| `CardPuzzleResult`(`scripts/ui/card_puzzle_result.gd`) | 正解 / 失敗のパネル。「もう一度」「一覧へ」 |
| `CardPuzzlePickerScreen`(`scripts/ui/card_puzzle_picker_screen.gd`) | ステージ選択。共通ヘッダー + 横2列のグリッド |

**専用の対局画面(`CardPuzzleScreen`)は作らない。**盤面・手札・演出・ログはすべて
`CardMatchScreen` のものをそのまま使い、パズル側は「固定の局面を作る」「解けたかを見る」
だけを持つ。誘導対局(4.1.5節)と同じ理由で、**専用モードを作ると対局のルールが2箇所へ
分かれて食い違う余地が生まれる**。

**局面は `MatchState` を普通に作ってから差し替える**(ルール画面の教材の盤面と同じ作り方。
4.2節)。置いた駒は `summoned_this_turn` を下ろす——そのままだと反転も攻撃もできず、
どの問題も解けない。

> **`start()` は局面を作ってから `_stage` を覚える。**`_begin_state()` は画面の後始末
> (`_reset_for_new_match()`)を通り、そこで `close()` が `_stage` を消す。先に覚えると
> その場で消え、**判定が一切働かない**(実際にそうなり、結果パネルが出なかった)。

**画面側へ足したのは3つだけ**:`puzzle` プロパティ(`CardMatchScreen` は公開メソッドの
上限に張り付いているため、入口はメソッドではなくプロパティにした)、`_perform()` の
1手ごとの判定、`_on_match_ended()` の分岐。**パズルではリプレイも砂金も戦績も残さない**
(`_match_kind` は `NONE`)。

**問題が解けることはテストで確かめる**(`tools/tests/puzzle_mission_tests.gd`)。
問題ごとの解答手順を持ち、`MatchState` へ直接流して相手のHPが0になることを見る。
**データが読めることだけを見て終えると、届かない問題を出荷してしまう。**

---

## 11. 開発時の落とし穴

検証で繰り返し踏んだもの。**いずれも「エディタ実行やヘッドレステストでは再現せず、
書き出した版や実機でだけ壊れる」種類**であり、気づく手段を持たないと同じ穴を掘り直す。

### 検証の抜け

- **新しい `class_name` を持つスクリプトを追加した直後は `godot --headless --path . --import` を
  1度実行する。**`.godot/global_script_class_cache.cfg` へ登録されず、`--script` 起動が
  「Could not find type "..." in the current scope」で失敗する
- **`tools/tests/run_tests.gd` は `scripts/ui/` を読まないため、UIのパースエラーを検出できない。**
  UIを触ったら `--quit-after` での起動スモークまで回す
- **GUIのクリックはヘッドレスでは一切届かない**(`push_input` しても
  `gui_get_hovered_control()` は none のまま)。押下の確認は非ヘッドレスで行う
- **演出のスクリーンショットは `Engine.time_scale` を0.2程度へ落として撮る。**
  `get_viewport().get_texture().get_image()` + `save_png` は演出より実時間のコストが
  大きく、0.3秒程度の動きは撮り逃して「実装が効いていない」ように見える
- **エクスポート済みpckに対しても回す**
  (`godot --headless --main-pack build/web/index.pck --script res://tools/tests/run_tests.gd`)。
  `.tres` が `.tres.remap` になることに起因するパス解決の差異は、これでしか出ない

### データとコードの境目

- **`CardEnums` の enum の並びは保存データである。**`.tres` は enum を整数で保存するため、
  途中へ値を挿入すると**既存のカードの効果・対象・トリガーが丸ごとずれる**。
  実際に `ADD_ATTACK` を `ADD_TOTAL` の隣へ入れたところ、エコーのドローが砂落としになり、
  スイープの全体除去が別の対象になった。**新しい値は必ず末尾へ足す。**
  並びの読みやすさより、保存済みの `.tres` との整合を優先する
- **`.tres` から読んだ `CardData` を書き換えない。**`load()` は同じインスタンスを返すため、
  対局中に書き換えるとその版の全対局(リプレイ・シミュレーションを含む)へ残る。
  キーワードの付与・消去は `CardInstance` 側の `granted_keywords` / `silenced` で持つ
- **`@export` の配列は `PackedStringArray` ではなく `Array[String]` にする。**
  エクスポート時のテキスト→バイナリ変換で **`PackedStringArray` の中身が丸ごと落ちる**。
  `.tres` には値が書かれているのに、書き出した版では空の配列になる。実際にリーサルパズルの
  `hand_ids` / `own_units` / `foe_units` がこれで空になり、**盤面にも手札にも砂時計が
  1つも無い状態で出荷した**。エディタ実行でもヘッドレステストでも再現せず、
  **pckに対してテストを回して初めて出る**(5章の `.remap` と同じ種類の穴)

### GDScript

- **型付き配列(`Array[String]`)を要求する関数へ untyped の `Array` を渡すと、
  実行時に関数ごと呼ばれない。**コンパイルは通り、その経路を通るまで気づけない。
  渡す値は生成側の戻り値の型まで揃える
- **ラムダは外側のローカル変数を値でキャプチャする。**シグナルの引数をラムダから
  外側の変数へ代入しても伝わらない。`Array` / `Dictionary` でラップして要素へ代入する
- **`var x := ProjectSettings.get_setting(...)` は Variant 推論の警告でコンパイルが落ちる**
  (警告がエラー扱いのため)。`var x: Variant = ...` と明示する

### Godotの挙動

- **`set_anchors_preset()` は「今の矩形を保つように」offsetを計算し直す。**コードで生成した
  直後(サイズ0)のノードへ使うと0サイズのまま固定され、何も描かれない。
  `anchor_right` / `anchor_bottom` への直接代入で設定する
- **`Control._draw()` は自分の子より背面に描かれる。**画面側で描いた線は子ノードに隠れる。
  手前に出したいものは独立したオーバーレイのノードにする
- **後から `add_child()` した子ほど手前に描かれる。**モーダル・暗幕は最後の子へ置く
- **`Label.autowrap_mode` は `size` より先に立てる。**折り返しが無効なあいだ Label の
  最小幅は文章そのものの幅であり、`Control` はそれより小さくならない。後から折り返しを
  有効にしても既に広がった `size` は戻らず、狭い欄に置いた説明文どうしが重なる
- **`MOUSE_FILTER_PASS` はイベントを背面の兄弟ではなく親へ渡す。**全面に敷いた
  `MarginContainer` より前の子は、ホバーを奪われて押せなくなる
- **`ResourceLoader.exists()` は pck から除外した後も true を返すことがある**(実測)。
  ファイルの有無の判定には使えない。Web/デスクトップの分岐は `OS.has_feature("web")` で行う
- **`class_name` を持つ2つのスクリプトが、互いの const を const から参照してはいけない。**
  読み込みが循環して**起動したまま固まる**(エラーも出ない)。実際に `CardMatchDetail` の
  const から `CardMatchScreen.TABLE_RECT` を読んで踏んだ。参照は関数の中(実行時)へ移す
- **`.tscn` はテキストとして直接編集しない。**`tools/godot_apply_patch.gd` か
  一時ビルドスクリプト(適用後に削除)経由で更新する。ルートにスクリプトを持つシーンを
  再生成する際は `root.set_script()` を忘れない(忘れるとその画面が一切起動しなくなる)

### 触ってはいけないもの

- **`user://` 配下の実データ(`card_decks.json` 等)に触らない。**過去に誤って削除する事故が
  発生している。テストで扱う場合は必ず「控える → 上書き → 検証 → 戻す」の往復にする

### 行数の上限

- gdlint の `max-file-lines` が1000行。`card_match_screen.gd` と `run_tests.gd` は
  この上限に張り付いているため、**足す前に切り出す**
  (`_screen` 参照を持つ `RefCounted` へ分ける既存の流儀に従う)

---

## 未検討事項

- `EffectResolver` の対応表の具体的な実装方式(match文 vs 個別クラス継承)は、実装着手時に決定する
