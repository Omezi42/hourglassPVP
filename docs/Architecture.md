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
| `set_id` | String | 所属するカードセットのid。空文字は基本セット(常に所有済み)。GameDesign.md 8章・21章 |
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

### 3.1.2 反転権(GameDesign.md 2章)

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
| `BoardTable`(`scripts/ui/board_table.gd`) | 盤面12枠を載せる卓(GameDesign.md 9章)。**木の額 / プレイマット2枚 / 中央の真鍮のレール**の3層で描く |
| `PlaymatLibrary`(`scripts/data/playmat_library.gd`, staticのみ) | プレイマットの定義(地の色・模様の種類・縁・箔・値段)。`UserProfileLibrary` と同じ流儀 |
| `PlaymatPaint`(`scripts/ui/styles/playmat_paint.gd`, staticのみ) | マットの描画。**卓とショップの見本で同じ関数を通す**(別々に描くと、買う前に見た絵と実際に敷かれる絵が食い違う) |
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
| `CardEffectPreview`(`scripts/ui/card_effect_preview.gd`) | 能力の実演。**カードごとではなくキーワード / 効果の種類ごとに1本**の台本を持つ(下記)。台本の並びの組み立てと図版の描画がここに残る |
| `CardEffectStage`(`scripts/ui/card_effect_stage.gd`, staticのみ) | 台本が組み立てる「その瞬間の盤面」の部品(空の盤面・駒・光の筋・ポップ・イージング)。**台本はこれを組み合わせるだけで書ける**状態を保つ |
| `CardEffectDemoKeyword`(`scripts/ui/card_effect_demo_keyword.gd`, staticのみ) | 常在キーワード7種と基本の砂の台本。**扱わない語には空の Dictionary を返させる**——既定の盤面を返させると、台本が無いことに気づけないまま何かが動いて見える |
| `CardEffectDemoEnemy`(`scripts/ui/card_effect_demo_enemy.gd`, staticのみ) | 「相手の砂時計へ効く効果」の実演の中身 |
| `InkFigure`(`scripts/ui/ink_figure.gd`, staticのみ) | 実演の図版を紙のインクで描く部品(砂時計・HPバー・矢印・守護の輪・硝子の膜・砕けた印)。`UiPaint` と同じ流儀で、**第1引数に描画先の `CanvasItem`** を取る |
| `CardDeckShelf`(`scripts/ui/card_deck_shelf.gd`) | 編成中のデッキを**30枠の決まった棚**として描く(GameDesign.md 9章)。1つの `Control` が全枠を描き、当たり判定を矩形の表として持つ |
| `EmblemSeal`(`scripts/ui/emblem_seal.gd`, staticのみ) | カード固有の紋章を「押した印」として描く。**カードを並べる3画面(図鑑の一覧・工房の在庫棚・編成中の棚)で共有する**——別々に描くと必ず片方だけ古くなる。`InkFigure` と同じく第1引数に `CanvasItem` を取る(紋章はテクスチャのため `draw_texture_rect()` を使う) |
| `CardPileViewer`(`scripts/ui/card_pile_viewer.gd`) | 墓地の中身を見るモーダル。同じカードは1枚にまとめて枚数をバッジで出す |
| `EmptyState`(`scripts/ui/empty_state.gd`) | 一覧に並べるものが無いとき/待っているときの見せ方(GameDesign.md 9章)。**印・見出し・1行の置き場を1箇所へ集める**——以前は画面ごとに `Label` を1つ置いており、広いパネルの左上に文が1行だけ残っていた。デッキ一覧・リプレイ一覧・戦績・パズル選択が使う |
| `CurrencyChip`(`scripts/ui/currency_chip.gd`) | 砂金の残高(GameDesign.md 9章・15章)。文字列は `CurrencyRules.label_text()` だけが決め、画面ごとに組み立てない。増えたときだけ脈打たせて数え上げる |
| `CodedButton`(`scripts/ui/coded_button.gd`) | コードで組むボタンの生成を集約する。画面ごとに `theme_override` を並べると指定漏れのボタンが混ざるため |
| `CardViewStrike`(`scripts/ui/card_view_strike.gd`) | 攻撃の演出の段取り(寄る→溜める→当てる→戻る)。**`CardView` が1000行の上限に達したため切り出した**。分ける線は「駒の見た目」と「殴りに行く段取り」に引き、状態(offset / angle / flash)と描画は `CardView` 側に残す(絵に掛ける変換は描画のたびに要るため) |
| `CardMatchReplay`(`scripts/ui/card_match_replay.gd`) | リプレイの再生コントロール。**任意の手数の局面は初期状態から手を並べ直して作る** |
| `CardMatchOnline`(`scripts/ui/card_match_online.gd`) | オンライン対戦の3つの入口(開始・切断からの復帰・観戦)。`card_match_screen.gd` が1000行の上限に達したため切り出した。画面側には `main.gd` から呼ぶ薄い委譲だけが残る |
| `CardMatchSpell`(`scripts/ui/card_match_spell.gd`) | 砂術を撃つ操作の段取り(GameDesign.md 6章)。`card_match_screen.gd` が1000行の上限に達したため切り出した |
| `CardMatchTouch`(`scripts/ui/card_match_touch.gd`) | 盤面と手札を押す/ドラッグする操作の受け口。**押した先で何が起きるかの分岐だけ**を持ち、適用は `MatchState` へ、対象選択の段取りは `CardMatchSpell` / `CardMatchEffectTarget` / `CardMatchFlipRight` へ渡す。**`_build()` より先に生成する**——組み立ての途中で駒のシグナルへ接続されるため、後から作ると接続の時点で null を掴む(`_detail` を後から作って踏んだのと同じ穴) |
| `CardMatchFlipRight`(`scripts/ui/card_match_flip_right.gd`) | 反転権(GameDesign.md 2章)の段取り。ボタンの生成・対象選択(`CardMatchSelection.Kind.FLIP_RIGHT`)・`MatchAction.flip_right()` の適用を1箇所へ集める。**「戻る」ボタンと同じ位置に置く**——戻るボタンは再生・観戦(`_interactive == false`)だけ、反転権は対局中(`_interactive == true`)だけに出るため両者は同時に見えず、行動の列を再配置せずに済む |

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

**手札の見た目は `CardView.HAND_SIZE_PX`(118x158)を基準に組み、各部の寸法はそこからの
比(`_hand_scale()`)で決める**。固定値のままだと、キーワード辞書のように小さく置いた
ときに名前とキーワードの行が札の外や総量のバッジの上へ出る(枠・輪郭の太さを大きさに
合わせる `CodedButtonStyle` と同じ考え方。11章)。**名前とキーワードは下の隅のバッジの帯
より上へ置く**(GameDesign.md 9章)。

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

**反転権(GameDesign.md 2章)は `play_flip()` の第4引数 `actor_side` で向きを渡す。**
通常の反転は「駒の持ち主 = 手を出した側」が常に成り立つため、光の筋は駒の持ち主の
情報帯から伸びる。反転権は敵味方どちらの駒も対象に取れ、この前提が崩れるため、
`MatchState.flip_right_used(actor_side, target_side, slot)` を別のシグナルとして受け、
`play_flip(self, target_side, slot, actor_side)` のように駒の持ち主(`target_side`)と
手を出した側(`actor_side`)を分けて渡す。

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
├── CardSoloMapScreen        # ソロモードのステージツリー(同上。10.15節)
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
- **ホーム画面の入口は `HomeTile`(`scripts/ui/home_tile.gd`)が持つ**(GameDesign.md 9章)。
  見出し・副題・紋章の透かし・中身の砂時計を1枚の札として描く。
  - **`Button` を継承する。**既存のタブが `Button` として参照している枠をそのまま
    置き換えられ、押下・無効・ホバーの扱いも native のまま使える
  - **文言は `text` へ入れず自前で描く**。見出しと副題を上下に置くため、
    native の中央揃え1行では収まらない
  - **紋章の透かしは `CodedButtonStyle.inner_rect()` の中へ収める。**
    ボタンの矩形を基準に置くと**額縁へ載り上がって外へはみ出す**(実際にそうなった)。
    額縁の太さはボタンの大きさで変わる(4章)ため目分量の余白では求められず、
    **内側の矩形を返す関数を1つ持ってそこだけを出どころにする**
  - **`.tscn` は書き換えず、`_ready()` で同じ場所・同じ大きさの札へ差し替える**
    (`_to_tile()`)。並び順(`get_index()`)も引き継ぐ
  - 副題は画面の外で変わる(デッキ・砂金)ため、**タブを開くたびに読み直す**
    (`HomeScreen._select_tab()` / `refresh_account()` から `DeckTab.refresh()`)
- **ホーム画面のタブは、上端112pxをアカウント帯のために空け、残りの領域の中央へ内容を置く**。
  ContentArea の高さは下部タブを除いた560pxしかないため、ここを守らないと内容が画面の外
  (上はアカウント帯の裏、下は下部タブの裏)へ出る。実際にルールタブは先頭のボタンが画面上端で
  切れ、バトルタブは最終行が下部タブへ潜り込んでいた

#### タブの再編(GameDesign.md 9章・2026-09-10)

対局の入口が4つのタブすべてに散っていた状態を解くため、タブを行いで分け直す。

| タブ | クラス | 前身 |
|---|---|---|
| たたかう | `BattleTab` | ランダム/ルームはそのまま。`SoloTab` の3つを引き取り、記録の3つを外した |
| そろえる | `DeckTab` | **中身もクラスもそのまま**(デッキ編集 / 図鑑 / ショップ) |
| きろく | `RecordTab`(新規) | `BattleTab` から抜いた記録の3つ(ミッション / 戦績 / リプレイ) |
| おぼえる | `RulesTab` | **中身もクラスもそのまま** |

- **`.tscn` を持つ2つ(`DeckTab` / `BattleTab`)はクラス名を変えない。**
  `scenes/home_screen.tscn` がこの2つを instance しているため、名前を変えると参照の
  書き換えという実害のある作業を招く。**画面に出る名前と内部のクラス名が食い違うことは
  許容する**——ただし `BattleTab` が「たたかう」を担うのは意味の上でも食い違わない。
  `RulesTab` はコード生成だが、中身が変わらないため同じく維持する
- **`SoloTab` は削除した。**CPU戦・ソロモード・リーサルパズルの3つは `BattleTab` の
  下枠へ移り、遷移先のシグナル(`cpu_match_requested` 等)は `HomeScreen` の側で
  そのまま中継するため `Main` の配線は変わらない
- **`BattleTab` の `.tscn` の縦並び(`Margin/VBox`)は使わない。**枠を絶対座標へ置く
  構成に合わないため、**待機中の文言(`StatusLabel`)だけを引き取って残りは捨てる**
  (`_take_over_status_label()`)。`.tscn` そのものは書き換えない
- **枠の右側へ並べる行(日課の進み具合)は `HomeFrame` が描く。**枠は `Control` であり
  その `_draw()` は子より背面に描かれるため、**タブ側で描くと枠のパネルに隠れて何も
  見えない**(実際にミッションの進捗が消えた。11章)
- **背景の絵の上へ帯と幕を敷くのは `HomeScrim`(`scripts/ui/home_scrim.gd`)。**
  `Background` の直後(タブの中身・アカウント帯・下部タブより背面)へ1枚だけ置き、
  上=アカウント帯 / 中=タブの中身 / 下=下部タブ の3つを別々の濃さで落とす。
  **上下の帯は中より濃くし、上下で対称にする**——そこに乗るのは真鍮の小さな部品
  (名札・残高・タブ)で、枠のような大きな面を持たないため、地が明るいと輪郭が背景へ
  紛れる。中は `HomeFrame` が自分の面を持つぶん薄くてよい。**画面の端へ向かって濃くする**
  のが3つに共通の形で、絵の見えている中央がそのまま奥行きになる
- **3つの濃さは揃えて動かす。**一度「下の帯だけ外す」形にしたところ、**上と中にも同じ
  幕が掛かっていることが画面から読み取れず**、下だけ明るい不揃いな状態になった。
  片方だけ濃さを変えると画面の重心がそちらへ寄る
- アカウント帯の下端にだけ真鍮の細線を通し、**中央が濃く左右の端で消える**形にする
  (端まで一様に引くと帯が1本乗ったように見える。`ScreenHeader` の暗幕と同じ)
- **入口はどのタブも `HomeTile`(見出し + 副題1行 + 紋章)で組む。**`RulesTab` だけ
  「文字だけのボタン + その外に置いた説明文」で組んでおり、**4タブを切り替えると
  そこだけ作りが違って見えた**。説明は札の副題として1行に収める(GameDesign.md 9章
  「添えるのは文で1行までとし」)。**中身の説明はそれぞれの画面が持つ**ので、
  ホームの札は「そこで何ができるか」が分かれば足りる
- **4タブとも「枠(`HomeFrame`)の中に札を並べる」形へ揃える。**`DeckTab` だけ枠を
  持たないと、切り替えたときにそこだけ札が背景の上へ直に浮いて見える。`.tscn` の
  `CenterContainer` はそのまま使い、**縦並びの幅を枠の内側いっぱいに広げてから各札を
  左寄せにする**ことで、枠と中身の左端を揃えている
- **枠は `HomeFrame`(`scripts/ui/home_frame.gd`)が持つ。**`RulesTab._add_frame()` に
  あった「`content_panel.tres` のパネル + 見出しのラベル」を切り出し、たたかう・きろく・
  おぼえるの3タブで使う。**見出しは真鍮のプレートに載せる**(ラベルだけだと枠の一部に
  見えず、何の枠なのか読めない)
- **「前回の対局へ戻る」は `ResumeBand`(`scripts/ui/resume_band.gd`)として、たたかうタブの
  最上段へ出す**(GameDesign.md 9章)。以前は `HomeTile` を縦の列の先頭へ差し込んでいたが、
  **他の入口と同じ見た目の札では急ぐ用件だと分からない**。**縁を琥珀にして真鍮の札と系統を
  分け**、左端へ赤い印を打つ。帯の有無で枠の位置が変わるため、`BattleTab._layout()` が
  **どちらの場合も領域の中央へ置き直す**(上端へ寄せると下半分がまるごと空く)
- **下部タブは幅を共通にし、高さだけ変える。**幅まで変えると `HBoxContainer` の中で他の
  タブが横へ押し出され、選択するたびに4つの位置がずれる(実際にそうなった)。
  **選択していないタブを下端へ沈め、選択中だけを帯の中央へ置く**ことで、選択中の上端だけが
  持ち上がってせり出して見える
- **アカウント帯は `.tscn` で幅460pxしか無い**ため、`_ready()` で右端まで伸ばして
  残高を右へ寄せる(`ACCOUNT_BAR_RIGHT_INSET` はメニューのボタンのぶん)。
  **ホームの残高だけ `CurrencyChip.scale_factor` で大きく出す**——ヘッダーは面積に
  余裕があり、残高は「押す前に分かるべきこと」の代表(GameDesign.md 9章)であるため。
  ショップのヘッダーは主アクションの位置へ収めるので既定のまま。**高さは
  `height_override` で名札と揃える**(左右で背丈が違うと、同じ帯に載っているものとして
  読めない)
- **`CurrencyChip` は単位と数値を別々に描く。**「砂金」は毎回同じ語であり、数値と同じ
  大きさで並べると**読みたいほうが埋もれる**。単位を小さくくすませ、数値を大きく・
  影を1pxずらして敷いてから重ねる。紋章と文字のあいだには縦の細線を通し、
  **紋章がただ左に置いてあるだけに見えないようにする**

#### `HomeTile` へ足すもの

- **`primary`(塗りつぶした真鍮の面)**。いまは `CodedButton.apply_styles(tile, "primary_action")`
  を外から呼んで実現しているが、**タブごとに呼び忘れると強弱が崩れる**ため `HomeTile.make()`
  の引数として持たせる
- **`badge`(未受取の数の印)**。ミッションが使う。**札とタブの両方に出す**ため、
  下部タブのボタンへも同じ印を打てる形(静的な描画関数)にする
- **紋章の透かしの大きさに上限を掛ける。**いまは札の寸法から比率で決めているため、
  大きな札(「そろえる」のデッキ編集は600x306px)では紋章が巨大になって文字より主張する
  (モックで実際に起きた)。**比率で決めたうえで上限で止める**
- `ScreenHeader`(`scenes/screen_header.tscn`):対局画面を除く全画面が使う共通ヘッダー。外周余白24px・ヘッダー高88px・コンテンツ開始y=136をこの1箇所で決め、画面ごとに個別の値を持たせない(GameDesign.md 9章)
- クリック可能な各コンポーネント(`CardView`/`ReplayListCard`/`ClickArea`)は、押下確定の判定を `PressTracker`(RefCounted、押下→離した位置が要素内かどうかで確定/取消を返す)で共通化する

- `resources/theme/content_panel.tres`(`StyleBoxFlat`):一覧・詳細・モーダル向けの汎用コンテンツパネル。背景イラストの上に情報を置く各画面(デッキ一覧・デッキ編集・砂時計一覧・配置画面・リプレイ一覧等)の主要ブロックに共通適用する
- **UIクローム(ボタン・パネル枠・入力欄・棚板・名札等)はコード描画で作る**(GameDesign.md 9章)。以前は画面グループ単位のボタンシート画像を生成し `StyleBoxTexture` として割り当てていたが、品質管理のしやすさを理由に方針転換した。テキストは従来どおり画像・描画に焼き込まず `Button.text` をプロジェクト共通フォントで重ねる
- コード描画の実体は以下の3層に分ける。画面ごとに描画コードを書き散らさず、必ずこの共通層を経由させる
  - `scripts/ui/styles/ui_palette.gd`(`UiPalette`, `RefCounted`):プロジェクト全体のUI色の単一情報源。真鍮の明/中/暗、暗い下地、琥珀アクセント、無効時のグレー等をconstで持つ
  - `scripts/ui/styles/ui_paint.gd`(`UiPaint`, `RefCounted`):static関数だけの描画ユーティリティ。**第1引数は必ず `ci: RID`** とし `RenderingServer.canvas_item_add_*` 系で描く(`StyleBox._draw(to_canvas_item, rect)` からは `CanvasItem.draw_*` を呼べないため)。角丸矩形の頂点生成、多段階の縦グラデーション塗り、面取り(ベベル)、内側の落ち込み影、グレイン(ノイズ)重ねを提供する
  - 各`StyleBox`派生クラス(`CodedButtonStyle` 等)と、`Control._draw()`側(`BoardTable`/`BarPanel`/`HourglassSlot`)が、いずれも上記2つを呼んで描く
- **背景イラストを持たない画面の下地は `ScreenBackdrop`
  (`scripts/ui/screen_backdrop.gd`、`Control._draw()` のみ)に集約する**。無地の `ColorRect` 1枚だと
  フラットベクターに見えるため、多段グラデーション + グレイン + 左右の落ち込みを掛ける。
  画面ごとに下地の色と描き方を持たせない
- **下地は「場所」として描く**(GameDesign.md 9章)。`ScreenBackdrop.Room` が
  無地 / 書庫 / 記録室 / 控えの間 / 帳場 の5つを持ち、画面は `room` を1行入れるだけにする。
  **部品(板壁・歯車・作業灯・吊り看板・木箱・本棚・引き出し)は
  `RoomPaint`(`scripts/ui/styles/room_paint.gd`, staticのみ)が持つ。**
  `UiPaint` と違い第1引数に `CanvasItem` を取る(`InkFigure` と同じ流儀)——
  `draw_line()` などのインスタンス側の描画と、`UiPaint` の RID 側の描画の両方を使うため
  - **`WorkshopBackdrop` も同じ部品から組む。**工房だけが独自に壁を持っていると、
    壁の描き方を変えたときにそこだけ取り残される
  - **場所ごとの違いは「壁の色味」と「据え付ける造作」の2つだけ**にする。
    部品まで場所ごとに分けると、増やすたびに全種を描き足すことになる
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
- グループごとの割り当ては次の通り。**実際に `resources/theme/buttons/` へ置いてあるのはこの7つだけ**で、
  対局画面の丸いアクションボタン(`action_*`)・再生コントロール(`transport_round`)・
  保存ボタン(`confirm_save`)は、それぞれの画面が撤去された/共通ヘッダーへ寄せられた時点で削除した。
  **`.tres` を増やすときは、そのグループを実際に読む呼び出し(`CodedButton` のグループ定数)を必ず同時に足す**——
  読まれない `.tres` は誰にも気づかれないまま残り、後から「使っているのかどうか」を判定できなくなる

| グループ | Shape | Emblem | Placement | 使う場所 |
|---|---|---|---|---|
| `back_nav` | CHEVRON_LEFT | NONE | - | 共通ヘッダーの戻る |
| `nav_tab` | PILL | HOURGLASS | TOP_BADGE | ホーム画面の下部タブ |
| `wide_text` | ROUNDED_RECT | NONE | - | 既定の横長ボタン |
| `icon_square` | ROUNDED_RECT | NONE | - | 一覧の行などの小さな正方形 |
| `primary_action` | ROUNDED_RECT | NONE | - | **塗りつぶした真鍮の面**(`filled`)。最も頻繁に押す操作 |
| `icon_menu` | ROUNDED_RECT | MENU | CENTER | ホーム画面のハンバーガー |
| `icon_discord` | ROUNDED_RECT | DISCORD | CENTER | 設定メニューのDiscord導線 |

`UiPaint.Emblem` には、いま誰も使っていない紋章(`SWAP_ARROWS` / `BENCH` / `CHECK` /
`ADVANCE` / `AWAKEN` / `HEAL` / `STRIKE`)が残っている。**enumの並びは `.tres` が
整数で保存する保存データ**(11章)であり、途中の値を消すと `icon_menu` / `icon_discord` の
紋章がずれるため、**使っていなくても消さない**。**enum名に`Variant`を使うとGodot組み込み型と衝突してパースエラーになるため`State`とする**。対応する`.tres`の1行目は `[gd_resource type="StyleBox" script_class="CodedButtonStyle" format=3]`(`type="Resource"` にすると `Script inherits from native type 'StyleBox'` エラーになる)
- 既存の`.tscn`が参照している`resources/theme/buttons/img_{グループ名}_{state}.tres`は、**パスとExtResource参照を維持したまま中身だけをコードStyleBoxへ差し替える**。これによりシーン側の参照を書き換えずに全画面へ反映できる(J-0・L-2で実績のある手法)
- 以下の9-slice/原寸に関する制約は、**画像アセットのまま残す資産にのみ適用される**(砂時計のイラスト、背景イラスト等)。コード描画のStyleBoxは解像度に依存しないため、9-sliceも原寸制約も存在せず、表示サイズはレイアウトの都合で自由に決めてよい
- **`StyleBoxTexture`の`texture_margin_*`(9-slice/角保持スケーリング)は使用しない**。角部分だけ元ピクセルのまま残り縁が不自然に太くなるため(D-1で発覚した問題の根本原因)、`texture_margin_*`は常に0(未設定)とし、画像全体を単一の矩形として扱う。その代わり、**ボタン・パネル等の表示サイズは常に元画像のアスペクト比を保った倍率(縦横同じ倍率)でのみ決定する**。縦横を別々に指定して矩形を歪めることは禁止。置きたい場所に対して元画像のアスペクト比が合わない場合は、(a)その要素の固定サイズ自体をアスペクト比に合わせて再計算する、(b)固定サイズを崩せない場合は余白(レターボックス/ピラーボックス)を許容する、のいずれかで対応し、非等倍(縦横別倍率)の伸縮は行わない。(かつて存在した`board_panel.tres`は`BoardTable`のコード描画へ置き換えたため削除済み)

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
- ルームマッチは両者の入室後、`rooms/{code}.started` が `true` になるまでロビーで待つ。デッキと持ち時間を確認でき、開始操作はホストだけが行う。開始後、両者は `matches/{match_id}` ドキュメントへ自分のデッキ(30枚のid配列)を `deck_a`/`deck_b` として、先手側は山札の `seed` も書き込む(`OnlineSetup` が担当)。相手側はポーリングでこれを検知する。**v5.0は配置フェーズを持たないため、交換するのはデッキと種だけ**で、揃った時点で `MatchState.start_match()` へ入る(4.0節)
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
- **先手・後手は`MatchSides.assign()`が五分五分に振る**(GameDesign.md 11章)。
  振るのは**対局を成立させた側だけ**(`MatchmakingQueue._claim()` / `RoomMatch.join_room()`)で、
  結果は上記のcommitの中で`matches/{id}`の`player_a`(先手)・`player_b`(後手)として
  書かれる。両者は既存の判定(`player_a == 自分のuid`なら先手)をそのまま通るため、
  **側を決める経路は1本のまま変わらない**。双方が別々に振ると必ず食い違うため、
  振る場所を1箇所に閉じることがこの機能の要件になる
  - **`opponent_uid`と`is_host`は側とは無関係**であり、従来どおり
    creator / joiner の役から決める(部屋の開始操作はホストだけが行う)
  - **CPU戦・ソロモード・誘導対局・パズルは`MatchState.Side.A`固定のまま**
    (`start_match()`の第3引数を触らない)
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
両者が入室するとロビーへ入り、ホストが `started` を立てるまで対局へ遷移しない。
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
- **反転権(GameDesign.md 2章)は2箇所に分けて検討する。**片方だけでは
  「体力を残したまま弱めて、攻撃力を相手へ渡すだけ」になり実質使われない置物になると
  実測で分かったため(`docs/BalanceReport_v5.md` 12.2節)、攻撃とセットの1手を別に持つ。
  - **`_choose_flip_right_setup()` は攻撃より前(`_choose_attack()` の手前)に検討する。**
    いま持っている最大攻撃力ではまだ倒せない相手が、反転させれば(新しい体力 = 相手の
    いまの攻撃力)倒せるようになる場合だけ反転権を使う。使った直後の `choose_action()` の
    再評価で `_choose_attack()` が普通に仕留める——**反転権と攻撃が2手にまたがる連携として
    自然に繋がる**のは、`choose_action()` が1手ごとに盤面を読み直す貪欲法だからこそ成立する
  - **`_choose_flip_right()`(通常の反転の次)は、自分の駒を得な状態へ戻す案と、
    相手の駒を確実に破壊できる(反転させた結果その場で体力が0になる)場合だけを見る。**
    それ以外の「相手を生かしたまま弱める」使い方は上の `_setup()` の役目であり、
    ここでは扱わない(扱うと同じ相手を二重に検討することになる)
  - **どちらも、敵の駒に反転トリガー(グロウ/ホイール/ティック/ページ)があれば触らない**——
    誰が反転させても持ち主を利する形で発火するため(GameDesign.md 6章)。破壊する場合の
    余砂(ON_DEATH)は、`_choose_flip_right()` 側(反転そのもので破壊する経路)だけ避ける。
    `_setup()` 側は攻撃の一撃で破壊するため、他の除去と同じく余砂は避けない
    (`_choose_attack()` も攻撃で殺す際に余砂を避けていないため、ここだけ特別扱いしない)
  - **希少な資源のため `FLIP_RIGHT_MIN_GAIN` 未満の得なら温存する**(`_choose_flip_right()`
    のみ。`_setup()` は「倒せるかどうか」の二値なので閾値を持たない)。コインと同じく
    使えたかどうかは `use_flip_right()` の戻り値だけで判断する(4.5節・3.1.2節)
  - **`_setup()` を足す前は、確実に破壊できる好機自体が少なく、反転権はほとんど
    使われなかった。**足した後は先手2・後手3で5指標すべてが目標圏へ収まることを確認した
    (`docs/BalanceReport_v5.md` 12.4節)
- マリガンの選択は `choose_mulligan()` が持つ(コスト4以上を戻す)
- CPUの手番になったら `CardMatchScreen` が `CPU_THINK_SECONDS` の間合いを置いてから
  1手だけ適用し、また間合いを置く。**まとめて指すと何が起きたか追えない**ため1手ずつ進める
- 適用の経路は自分の手・オンラインの手・リプレイ再生と同じ `MatchAction.apply()`。
  CPUのためだけの経路を作らない
- CPUのデッキは `CardDeckSave.random_deck()`(全カード×2の山から30枚)。誘導対局のときだけ
  プリセットの「基本」を使う(GameDesign.md 18章)。**ソロモード限定カード(10.15節)は
  常にこの山から除く**(所有していないプレイヤーがCPU側の駒として先に見てしまうのを
  避けるため)
- CPU戦はオンライン対戦ではないため、`matches/{match_id}` への書き込みは行わない。
  棋譜は `LocalReplayService` がローカルへ保存する(7.1節)

### 8.1 CPU戦の思考レベル(GameDesign.md 13章)

- `CardCpuStrategy.Difficulty`(`BEGINNER` / `NORMAL` / `EXPERT`)を持ち、`difficulty` プロパティ
  (既定 `NORMAL`)で切り替える。**既存の全ロジックは `NORMAL` としてそのまま残す**——
  反転権の検証(`docs/BalanceReport_v5.md` 12章)が `NORMAL` 相当で行われているため、
  この段を動かすとバランス指標が総崩れになる
- **`BEGINNER` は別経路 `_choose_action_beginner()` を持つ**。既存の `choose_action()` の
  貪欲法(価値計算)を一切通さず、
  - 出す:手札を先頭から見て、出せる最初の1枚をそのまま出す(価値比較をしない)。
    対象を1体取る効果は `_random_target()` でランダムに選ぶ
  - 攻撃:攻撃できる駒と、選べる対象(本体を含む)をそれぞれランダムに選ぶ
    (`_choose_attack_random()`)。守護がいれば無視できないのは `attackable_slots()` が
    通常どおり返す集合のままなので、ここでの分岐は要らない
  - 反転・反転権:呼ばない。使わせないことがそのまま弱さになるため、判定自体を削る
- **`EXPERT` は `NORMAL` の関数へ軽い分岐を足すだけに留め、新しい探索を書かない**
  (GameDesign.md 13章「複数手先の探索は行わない」)。追加する評価軸は7つ:
  - `_choose_attack()`:本体を殴る前に、相手の場に残る攻撃可能な駒の合計攻撃力が
    自分の残りHPを上回るなら、本体を殴る手の価値を割り引く(`_expert_face_caution()`)。
    次の相手の手番で受け返す被害を、探索せずに「いまの盤面の合計」で近似する
  - `_choose_attack()` / `_trade_value()`:相打ちで自分の守護持ちが失われる場合、
    その駒が場に残ることで防いでいた被弾ぶんを割り引く(`_expert_guard_retention_penalty()`)。
    後続のターンで本体・他の駒が守護無しの被弾を受けやすくなることの近似
  - `_choose_flip()`:反転で体力が下がった結果、**相手がいま持っている最大攻撃力で
    その場で仕留められる**ようになる反転は避ける(`_expert_flip_is_risky()`)。
    2章の「攻撃力が体力を上回ったら返す」という最適解自体は変えず、危険な1手だけを弾く
  - `choose_mulligan()`:中級以下はコストの上限だけで戻すが、上級は**残す手札の
    コスト1〜2の枚数**を見て、それが少ないほど重いカードをより積極的に戻す
    (`_expert_mulligan_threshold()`)。**「通常の反転が使えない駒を反転権で戻す」は
    `NORMAL` の `_choose_flip_right()` が既に行っており(この戦闘システムは常に
    1対1の相打ちで、複数体の合計攻撃力という概念が無いため拡張の余地が薄い)、
    上級専用の追加候補から外した**
  - `_effect_target()`:ダメージを与える効果(`DAMAGE_UNIT`)は、硝子が残っている
    駒を候補から外してから最善の1体を選ぶ(`_expert_damageable_enemy()`)。
    **確定破壊(`DESTROY_UNIT`)は硝子を無視して通るため対象外**(`destroy_unit()` は
    ダメージ処理を経由しない)。中級は効果の種類を見ずに「生涯ダメージが最大」だけで
    選ぶため、硝子で無効化される一撃を選ぶことがある
  - `_best_slot()`:このカードを出した残りマナで、他に何も出せなくなる出し方に
    わずかなペナルティを掛ける(`_mana_leftover_penalty()`)。端数のマナを1〜2残す
    ような出し方をわずかに優先する程度に留め、コストの分布次第で逆転しない範囲の値にする
  - `_should_use_coin()`:中級は「あと1マナ足せば出せる手がある」だけで切るが、
    上級は**コインを使った場合に出せる中でいちばん高い1枚の価値**と、
    **使わずに温存した場合にいま出せる中でいちばん高い1枚の価値**を比較し、
    前者が上回るときだけ切る(`_expert_should_use_coin()`)
- **難易度はCPU自己対戦のバランス検証(全体指標・カード別勝率)の対象にしない**。
  検証は常に `NORMAL` で行う(GameDesign.md 7章の指標は `NORMAL` の値のまま)
- 誘導対局(4.1.5節)は `CardMatchTutorial` 経由のCPU戦であり、**`difficulty` を
  明示的に `NORMAL` へ固定して**渡す(選択画面を挟まないため既定のままでも実質同じだが、
  将来既定値を変えたときに誘導対局の難易度が黙って変わらないようにするため)

### 8.2 CPU戦の思考レベル選択画面

| クラス | 責務 |
|---|---|
| `CardCpuDifficultyPicker`(`scripts/ui/card_cpu_difficulty_picker.gd`) | 初級/中級/上級を選ぶモーダル。暗幕+`content_panel.tres`の中央パネルという既存パターン(`SettingsPanel`等)を踏襲する |

- **CPU戦のときだけ**、デッキ選択(`CardDeckListScreen.open_pick()`)の直後にこのモーダルを挟む。
  `Main._on_deck_picked()` の後続として `_pending_cpu_difficulty` のようなフラグを持たせず、
  `Main._start_cpu_match()` の直前に一度だけ開く(デッキ選択とモーダルの2段を
  `_pending_battle` の1つのCallableへ畳み込むと分岐が読みにくくなるため、
  CPU戦の入口関数側で明示的に1段追加する)
- **選んだ値は `CardDeckSave` と同じ「Autoloadを使わずstaticで持つ」流儀**で
  `user://cpu_difficulty.json` へ永続化する(`CardCpuDifficultySave`)。前回選んだ値を
  次回の初期選択にするため(GameDesign.md 13章「対局のたびに選び直せる」)
- 誘導対局・リプレイ再生・観戦はこの画面を通らない

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

### 10.7.1 プレイマット(GameDesign.md 9章・21章)

対局の卓へ敷く見た目の品。**画像ではなくコード描画**で作り、1件が持つのは
地の色・模様の種類・縁の色・箔の色だけにする(種類を足しても配布物が増えない)。

**既定は「なし」(`PlaymatLibrary.NONE_ID`)であり、卓に何も敷かない。**
`DEFAULT_ID` はこの `NONE_ID` を指す。`MATS` には `"none"` を通常のマットと同じ形の
エントリとして持たせ(`display_name()` 等の既存メソッドがそのまま動くように)、
`PlaymatPaint.draw_mat()` の先頭で `mat_id == PlaymatLibrary.NONE_ID` を弾いて何も描かない
ことで表現する。**新しい模様(`Weave`)は増やさない**——「無地の布」ではなく「布そのものが
無い」状態であり、木の額とレールの内側がそのまま見える(マット導入前の見た目に戻る)。
「砂の海」はこの変更で `price` を `PRICE_STANDARD` へ変え、他の品と同じくショップで買う。

- **マットは切り抜きの効く層(`BoardTable.MatLayer`)として敷く。**模様(砂紋の弧・
  唐草の蔓)は矩形の外まで伸びるため、`_draw()` で直に描くと**卓の外——情報帯や手札の
  上——へ漏れる**(実際に漏れた)。`clip_contents` を立てた `Control` を1枚ずつ置く。
  **ショップとアカウント画面の見本も同じ理由で切り抜く**
- **層は子ノードにする。**`Control._draw()` は自分の子より背面に描かれるため、
  木の額をクラス側が描き、その上へマット、さらにその上へレールの層を重ねる
- **敷き替えは `CardMatchScreen._set_playmats()`**(私設)。このクラスは gdlint の
  公開メソッドの上限へ張り付いており、切り出した進行役は他の私設メンバも直に触っている
  - CPU戦 = 自分の設定 + `PlaymatLibrary.CPU_ID`
  - オンライン = 自分の設定 + `AccountService.fetch_profile()` の `playmat_id`
    (表示名・アイコン・称号と同じ経路)
  - **リプレイ・観戦は既定**。`_reset_for_new_match()` が毎回既定へ戻し、
    対局へ入る側だけが敷き替える(棋譜はマットを記録しない)
- **値段は品ごとに違う**ため、`ShopCatalog.price()` は `id` を受け取る形にしてある
  (アイコン・エモートは品種で一律)

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

### 10.8.1 カードセット(GameDesign.md 8章・21章)

**基本セット以後のカードは、`ShopCatalog` へ「カードセット」という4つ目の品種として乗せる。**
アイコン・エモート・プレイマットが「初期解放に含まれないものが並ぶ」という規則だけを
持つのに対し、カードセットは**対局の中身そのもの**を左右するため、既存の3種と同じ扱いに
しない(GameDesign.md 21章)。

| クラス/フィールド | 責務 |
|---|---|
| `CardData.set_id`(String) | そのカードが属するカードセットのid。空文字は基本セット(常に所有済み) |
| `CardSetLibrary`(`scripts/data/card_set_library.gd`, static) | セットの定義(id・表示名・狙いの一文・カードidの並び・価格)。`UserProfileLibrary` / `ShopCatalog` と同じ流儀 |
| `players/{uid}.owned_card_sets`(Array[String]) | 所有済みのセットid。`owned_icons` 等と同じ場所に置く |

- **`price = 0` は「ショップで売らない」印とする**(GameDesign.md 8章「買い切り以外の
  追加手段も検討してよい」)。`ShopCatalog`のカードセット品目は`price > 0`のものだけを
  並べ、`price == 0`のセットはステージクリア等の別経路(10.15節のソロモードなど)でしか
  所有できない
- **無料で所有させる経路は `AccountService.unlock_card_set(uid, set_id)` の1本に集約する。**
  `purchase()`と同じ`commit()`の形を使うが、残高の確認・減算を行わない点だけが違う。
  今後、買い切り以外の入手経路(記念配布等)を足すときもここを通す
- **`CardLibrary` はプールを絞らない。**全カードを返す既存の責務は変えず、
  「デッキへ入れられるかどうか」の絞り込みは**呼び出し側**(デッキ編集・CPU戦のランダムデッキ
  生成)が `set_id == "" or owned_card_sets に含む` で行う。`CardLibrary` 自体に
  アカウントの状態を持ち込まない
- **デッキ編集(`CardDeckEditorScreen` / `CardDeckShelf`)は、未所有セットのカードを
  ロック表示にする。**選ぶとショップの該当セットへ遷移する導線を出す
- **砂時計一覧(`AlmanacBook` 等)は、未保有をシルエット表示にする。**9章に既にある
  「未収集はシルエットと『?』で示す」「保有の仕組みが入るまでは全件を収集済みとして扱う」
  という布石を、ここで初めて実装する
- **購入は `AccountService.purchase()` の既存の流儀(残高の確認・減算・所有への追加を
  1回の `commit()` で行う)へ、`owned_card_sets` の追加として乗せる。**新しい書き込み経路は
  作らない
- **CPU戦のデッキ生成(GameDesign.md 13章)は、購入できるカードセット(`price > 0`)を
  所有状況に関わらず含める**(ユーザー判断。対局中に「このカードが欲しい」と思わせる
  出会いの場にするため)。**`price == 0`のセット(27章のソロモード限定セットなど)だけを
  除く**——通貨で買えない以上、CPUに見せても購入導線にならない。
  `CardDeckSave.random_deck()` はカードごとに
  `set_id.is_empty() or CardSetLibrary.price(set_id) > 0` を見て一律に判定し、
  プレイヤー個人の所有状況(`owned_card_sets`)は参照しない

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

### 10.12.1 エンドレスモード(手続き生成・GameDesign.md 24章)

| クラス | 責務 |
|---|---|
| `PuzzleGenerator`(`scripts/logic/puzzle_generator.gd`, staticのみ) | 出題する `PuzzleStageData` をその場で組み立て、実際にシミュレーションして解けることを確かめてから返す |

**「盤面を丸ごとランダムに振って、解があるかどうかを総当たりで探す」方式は採らない。**
合法な行動の組み合わせは1手番でも数十〜数百に及び、それを深さ数手ぶん総当たりすると
一瞬で数十万〜数百万ノードに膨らむ(実測はしていないが、行動の枝の数から明らか)。
Web書き出し(WebAssembly)の実行速度で毎回これを間に合わせるのは無理がある。

代わりに、**「先に正解の手順を組み立て、それが実際に機能することだけを検証する」
方式にする。**

1. **正解の部品(kit)を先に決める。**「素の攻撃力で殴る駒」「反転してから殴る駒」
   「相手プレイヤーへ固定ダメージを与える砂術」を2〜4個組み合わせ、その合計が
   ちょうど相手のHPに一致するように**相手のHPの方を後から合わせる**(逆算)
2. **任意で「守護」の壁を挟む。**部品のうち1つを「まず守護を割るためだけに使う」
   役へ回し、その分は相手HPの合計に数えない。守護が残っている間は本体を殴れない
   というルール(6章)がそのまま「先にこれを片づけないと後が続かない」という
   手順の縛りになる
3. **紛らわしい選択肢(distractor)を足す。**攻撃してもマナ・盤面に影響しない
   キーワードだけの駒、使うとマナが枯れて本命の砂術が撃てなくなる手札の1枚などを
   加える。**正解の部品を1つでも欠くと合計が足りなくなる**ように数値を組んでいるため、
   紛らわしい選択肢を混ぜても正解の通り道は増えない(4章「なぜ相打ちと消える砂の
   両方が必要か」と同じく、数値の integrity を先に保証してから飾りを足す考え方)
4. **組み上げた局面を、実際に `MatchState` へ流して検証する。**
   `tools/tests/puzzle_mission_tests.gd` の `_build()`/`_solve()` と同じやり方で、
   意図した手順(反転 → 守護を割る → 残りの駒で本体を殴る → 砂術を撃つ)を
   `MatchState` の実メソッドへそのまま適用し、**相手のHPが実際に0以下になることを
   確認できたものだけ**を採用する。**確認できなければ黙って別の乱数で作り直す**
   (プレイヤーには常に「検証済みの1問」だけが渡る)
5. **1手番で選べる行動の数(分岐)を、検証の対象になった局面そのものから数える。**
   深い探索はせず、**いまの盤面で選べる1手目の数**(出せる手札・撃てる砂術・
   反転できる駒・攻撃できる駒とその対象の組み合わせ)を数え上げるだけに留める。
   これが少なすぎる局面は「択が多い」という狙いに合わないため作り直す
6. **何度作り直しても基準に届かない場合は、直前に検証だけは通った1問を渡す。**
   出題そのものを止めてしまうと「エンドレスが遊べない」という最悪の壊れ方になるため、
   難易度の狙いより「必ず1問渡す」ことを優先する

**この方式は、正解の部品に使うカードの性質を絞ることで安全性を確保している。**
自陣の駒(kit・紛らわしい駒とも)に使うのは、**貫通・連撃・毒砂・吸命のいずれも
持たず、固有効果(`effects`)も持たないカード**に限る。これらのキーワードは
「面へ攻撃したときの合計ダメージ」を静かに変えてしまい(連撃は2倍、貫通は
超過分が本体へ抜ける等)、**組み立てた数値のつじつまが合わなくなる**ため。
守護の壁に使うカードは、同じ安全な集合のうち**守護を持つもの**(シールド・ガード)
から選ぶ。相手プレイヤーへ固定ダメージを与える砂術は、**設置効果が
「相手プレイヤーへ固定ダメージ」の1つだけで完結するもの**(サンドショット)に限る。
効果が複数絡む・値が盤面の状態で変わるカード(スウォームの「敵の数×1」等)は
**次にプールを触る回に対象を広げる拡張点として残す**(いまは対象にしない)。

**紛らわしい自陣の駒は、攻撃力をごく小さく(1)保つ。**正解の部品から1つでも
欠けたときの不足分より紛らわしい駒の攻撃力の合計が必ず小さくなるようにしておくことで、
「本来要らない駒を足せば帳尻が合ってしまう」という抜け道を作らない。

**エンドレスの問題は保存しない。**`PuzzleLibrary`(Stage1〜10)とは別の生成経路であり、
`PuzzleProgress`(初回クリアの記録)も触らない。`CardMatchPuzzle` は
`start(target, endless)` の第2引数でこれを区別し、`endless` のときは
`_grant()` を呼ばず、結果パネルへ「次の問題へ」(`PuzzleGenerator.generate()` を
呼び直して `start()` する)を追加で出す。

---

### 10.13 日曜イベントとその告知(GameDesign.md 15章・25章)

| クラス | 責務 |
|---|---|
| `SundayEventRules`(`scripts/logic/sunday_event_rules.gd`, static) | いま日曜イベント中かどうかの判定と、報酬の倍率適用 |
| `functions/`(Firebaseプロジェクト直下、Node.js) | `announceSundayEvent`(定期告知)・`discordInteractions`(将来のスラッシュコマンドの受け口) |

**`SundayEventRules.is_active()` は `Time.get_datetime_dict_from_system(true)` の
UTC時刻を +9時間して日本時間へ換算し、曜日を見る。**サーバー側で正当性検証を行わない
既存方針(GameDesign.md 11章)に揃え、**クライアントのローカル時刻をそのまま信頼する**。

- **`CurrencyRules` はこの判定を呼ぶだけで、曜日の計算そのものを持たない。**
  `grant_amount(kind, won)` が `SundayEventRules.is_active()` を見て、
  ランダムマッチ(`MatchKind.RANDOM`)かつ true のときだけ倍率(2倍)を掛ける。
  ルームマッチ・CPU戦は `is_active()` を見ない
- **表示は `HomeScreen` と `CardMatchOutcome`(結果パネル)の2箇所だけに足す。**
  いずれも `SundayEventRules.is_active()` を読むだけの1行で、通常時は何も出さない
- **Firebase Cloud Functions を1つ追加する。**この作品が初めて持つ「常駐しないが
  サーバー側で動くコード」であり、GameDesign.md 10章冒頭の「バックエンドは自前サーバーを
  立てず、サーバーレスDBを使う」という方針の範囲内(Cloud Functions自体もサーバーレスの
  実行環境である)

| 関数 | トリガー | 役割 |
|---|---|---|
| `announceSundayEvent` | Cloud Scheduler(`0 0 * * 0`, Asia/Tokyo) | Discordの#お知らせへ日曜イベント開始のメッセージを投稿する |
| `discordInteractions` | HTTPS(Discordの Interactions Endpoint URL) | 将来のスラッシュコマンドを受け付ける入口。現時点ではコマンドを1つも持たず、`PING`(type 1)への`PONG`(type 1)応答だけを返す |

- **常駐プロセスは持たない。**いずれの関数も呼ばれたときだけ実行され、
  リクエストの外で状態を保持しない
- **DiscordのBotトークン・Interactionsの公開鍵は Firebase Functions のシークレット管理
  (`firebase functions:secrets:set`)へ置き、リポジトリへは一切コミットしない。**
  6.3節のWebhook URL(`data/discord_webhook.txt`)と同じ扱いで、`functions/` 側は
  環境変数からのみ読む
- **`discordInteractions` の署名検証は `discord-interactions`(公式ライブラリ)の
  `verifyKey()` を必ず通す。**検証を怠ると、Discord以外の第三者からのリクエストを
  受け付けてしまう
- **クライアント(Godot)側の変更は「判定・倍率・バナー表示」だけに留める。**
  告知そのものはクライアントを経由しない(6.3節の募集通知はクライアント発火だが、
  こちらはサーバー側の定期実行が発火する点が異なる)
- **将来スラッシュコマンドを足すときは `discordInteractions` へ分岐を1つ足すだけにする。**
  Botのプロセスを新設せず、この1関数へ集約する

---

### 10.14 Discordスラッシュコマンド(GameDesign.md 26章)

| クラス/ファイル | 責務 |
|---|---|
| `tools/export_card_data_json.gd` | ヘッドレスで `CardLibrary` を読み、`functions/data/cards.json` へ書き出す |
| `DiscordCardArt`(`scripts/ui/discord_card_art.gd`) | `/card` 用の詳細画像の描画。図鑑の右のページ(`AlmanacPage`)を元にするが、個人の戦績・裏返し操作・キーワードのボタンは持たない静的な1枚絵 |
| `tools/export_discord_card_art.gd` | `DiscordCardArt` を全カードぶん順に表示し、レンダリングされたフレームをキャプチャして `functions/data/card_art/{id}.png` へ書き出す |
| `tools/record_effect_gif.gd` / `.tscn`(既存) | カード1枚ぶんの実演(`CardEffectPreview`)を、詳細パネルと同じ地の上で1周分だけPNG連番として書き出す。**新規に作らず、既にある紹介動画用の撮影ツールをそのまま使う** |
| `tools/export_discord_effect_gifs.sh` | 上記を全カードぶんループで呼び出す |
| `tools/encode_discord_gifs.sh` | PNG連番をGIFへエンコードする。`record_effect_gif.gd` の冒頭コメントに既にある `magick`(ImageMagick)のコマンド列をそのまま使い、**全カードぶんループで回すラッパーにする**(Pillowでの再実装はしない) |
| `DiscordLinkService`(`scripts/net/discord_link_service.gd`, static) | アカウント画面の「Discord連携コード」発行。`DeckCodeService` と同じ「8桁の数字を発行してFirestoreへ預ける」方式 |
| `functions/discord_commands.js`(Node.js) | `/card` `/deck` `/link` `/profile` のハンドラ。`discordInteractions` から呼ばれる |
| `functions/deck_sheet_canvas.js`(Node.js) | `/deck` 用の簡易デッキ表画像を `@napi-rs/canvas` で描画する。ゲーム内の `CardDeckSheet` とは別実装であり、見た目の一致は求めない |
| `functions/fonts/ZenKakuGothicNew-Bold.ttf` | `assets/fonts/` からコピーした同梱フォント。`firebase.json` の `functions.source` が `functions` ディレクトリだけを見るため、`functions/` の外にあるファイルはデプロイされない |
| `functions/.gdignore` | `functions/data/card_art/*.png` をGodotのインポート対象から外す。**置き忘れると `.png.import` が大量に生成される**(実際に70個生成された)。4.1.6節の「実行時に読まないディレクトリには`.gdignore`を置く」の実例 |
| `announceCardSpotlight` | Cloud Scheduler(毎日正午12:00 JST)。カードスポットライトの自動投稿 |
| `tools/discord/register_commands.py` | 4つのスラッシュコマンドをDiscordへ登録する(既存の `tools/discord/apply_permissions.py` と同じ、`~/.hourglass_discord.json` からBotトークンを読む流儀)。コマンドの追加・変更のたびに実行し直す。ギルドコマンドとして登録するため反映は即時 |

**カードデータのJSON化は `tools/export_web.sh` のビルド工程に組み込むが、画像・実演GIFは
別扱いにする。**`export_discord_card_art.gd`(静止画のキャプチャ)も `record_effect_gif.gd`
(GIFの素材フレーム)も、**実際にレンダリングされたピクセルを読む必要があるため
`--headless` では動かず、GPUの描画コンテキストを持つ通常起動が要る**(実測で確認済み)。
`export_web.sh` は全工程を `--headless` で回すことを前提にしたビルドスクリプトのため、
ここへ非ヘッドレスの手順を混ぜると無人実行が壊れる。**画像・GIFは
`tools/export_web.sh` の外に置き、カードを追加・変更したとき(`add-hourglass` Skillの
手順の一部として)手動で実行し直す運用にする。**`functions/data/cards.json` だけは
中身が数値の差分にすぎず実行コストも小さいため、引き続きビルドのたびに更新する。
**画像・GIF・JSONのいずれもリポジトリへコミットする**(6.3節のWebhook URLのような
秘匿情報ではないため、`data/discord_webhook.txt` とは扱いが異なる)。

**実演GIFは語彙ごとではなく、カードごとに1本にする。**既存の `record_effect_gif.gd` は
そのカードが持つ能力すべて(複数のキーワード・トリガーがあれば台本を繋げて)を
通しで1周ぶん録る設計に既になっており、これをそのまま使うほうが「1枚のカードが
何をするか」を1本で見せられて `/card` の目的に合う。**カードが増えるたびに
生成本数も増える**が、1カードあたり数秒程度のため、70種規模であれば
書き出しの手間として許容できる。生成はカードのidをそのままGIFのファイル名にする
(`effect_gifs/{id}.gif`)。

**`/deck` の画像はGodotを使わず、Functions側(Node.js)で完結させる。**
組み合わせが無数にあるデッキ表は事前生成できず、都度Godotを起動して描画するのは
常駐サーバーを持たない方針(10章)と相性が悪いため、`@napi-rs/canvas` で
「コスト順に30枚のカード名・コスト・総量を並べただけの簡易画像」を独自に描く。
ゲーム内の `CardDeckSheet` と見た目を合わせる必要はない。**`node-canvas` ではなく
`@napi-rs/canvas` を選んだ**のは、前者がネイティブのCairoライブラリに依存し
Cloud Functionsのビルド環境でのインストールが不安定になりやすいため。後者は
プリビルドバイナリを持ち、APIもnode-canvasに近い。

**`/card` `/deck` はいずれもコマンド応答の中で画像を返すが、届け方が異なる。**
`/card` の画像・GIFはビルドのたびにリポジトリへコミット済み(上記)であり、
**BGMの配信(Architecture.md 4.1.6節)と同じくjsDelivr経由でリポジトリから直接読む**
(`https://cdn.jsdelivr.net/gh/Omezi42/hourglassPVP@main/functions/data/...`)。
コマンド応答のEmbedへこのURLをそのまま埋め込むだけで済み、Bot側は1バイトも
アップロードしない。**jsDelivrはキャッシュするため、pushしてから数分〜数時間は
古い版が返ることがある**(BGMと同じ制約)。一方 `/deck` は都度その場で生成した
バイト列であり、リポジトリに存在しないため、ファイルとして直接添付する
(`multipart/form-data` で `files[0]` として送る)必要がある。

**`/deck` は3秒の応答期限を超えうるため、deferred responseを使う。**
`discordInteractions` はまず `DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE`(type 5、
`flags: 64` でephemeralを維持したまま)を即座に返し、画像の生成が終わってから
`PATCH /webhooks/{application_id}/{token}/messages/@original` を叩いて本文と
画像を追送する。**`res.json()` で最初の応答を返した後も、`await` で追送処理を
終えてから関数を返す。**Cloud Functionsはレスポンス送信後にCPUがスロットルされる
ことがあり、`res.json()` の直後に `return` すると追送処理が保証されないため、
`sendDeckFollowup()` の完了を待ってからハンドラを終える。

**Firestoreへ新設するもの**

| コレクション/ドキュメント | 内容 |
|---|---|
| `discord_links/{discord_user_id}` | `{uid: string}`。`/link` が1件を上書きする |
| `discord_link_codes/{コード}` | `{uid: string}`。9章のデッキコードと同じ「8桁の数字を引換券として預ける」方式。`/link` が読んだら `discord_links` へ書き写し、**引換券自体は消さない**(9章の「預けたデッキは消さない」と同じ方針) |
| `bot_spotlight_history/{card_id}` | `{last_shown: timestamp}`。そのカードを最後に紹介した日時。**カードごとに1件**であり、抽選のたびに全件(プールの枚数ぶん)を読んで、`last_shown` が30日以内でないものを候補にする |

**`bot_spotlight_history` は範囲クエリを組まない。**プールの枚数は今のところ70枚
(今後も日単位でしか増えない)であり、全件読んでFunctions側でフィルタするほうが、
複合インデックスを要する範囲クエリを組むより単純になる(6章のクエリ方針と同じ考え方)。

**`/link` のコード発行はGodot側(`DiscordLinkService.publish_code()`)が行う。**
`AccountService` 経由で自分のuidを `discord_link_codes/{発行したコード}` へ書く、
9章の `DeckCodeService.publish()` とほぼ同じ実装で、**衝突したら引き直す**点も同じ。

**`/profile` が返す砂金・戦績は `players/{uid}` と `match_records` からそのまま読む。**
Functions側もクライアントと同じFirestoreを直接読むため、専用のAPIは作らない。
オンライン対戦の通算成績は `match_records` を `player_a`/`player_b` で検索して集計する
(10.9節のクエリ方針=単一フィールドの等価フィルタという制約にそのまま従う)。
**19章の戦績(CPU戦込みの通算)は `user://` のローカル保存のためサーバー側から読めず、
`/profile` には出せない。**

**すべてのコマンド応答は Discord の `flags: 64`(ephemeral)を付けて返す。**
画像・GIFの添付があっても、ephemeralのまま返せる(Discord APIの制約ではない)。
カードスポットライト(`announceCardSpotlight`)だけは通常のメッセージとして投稿する
(コマンドへの応答ではなく、コミュニティ全体へ向けた自発的な投稿であるため)。

**`discordInteractions` の分岐が増える。**現状はPING応答だけを持つ1つの関数だが、
`data.name`(コマンド名)で `/card` `/deck` `/link` `/profile` の4つへ分岐を足す。
署名検証(`verifyKey()`)は既存のまま全コマンド共通で通す。

**新設したコレクションは `firestore.rules` へも追記する。**クライアントからの直接書き込みは
`discord_link_codes` の発行(自分のuidを書く)だけを許可し、`discord_links` の書き込みは
Cloud Functions側(`/link` の処理)からしか行わない形にする。

---

### 10.15 ソロモード

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

### ソロモード限定カードの所有(GameDesign.md 27章)

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

### ホーム画面のソロタブ

`SoloTab`(`scripts/ui/solo_tab.gd`)は`DeckTab`/`BattleTab`/`RulesTab`と同じ形で、
大きなボタン3つ(CPU戦・リーサルパズル・ソロモード)を縦に並べる。CPU戦・リーサルパズルの
遷移先(`Main._start_cpu_match()`系・`CardPuzzlePickerScreen`)はそのまま流用し、
**ボタンの置き場所だけをBattleTabから移す**。

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

### 非ヘッドレスの静止画・動画キャプチャ(`--write-movie` / スクリーンショット)

Discord用のカード画像・実演GIF(10.14節)を作る過程で踏んだもの。

- **`--headless` では実際のピクセルが得られない。**`get_viewport().get_texture().get_image()`
  も `--write-movie` も、GPU(またはソフトウェアレンダラ)で実際に描画された結果を読むため、
  `--headless` を付けると空またはエラーになる。静止画・GIFの撮影ツールはすべて
  通常起動(ウィンドウを開く)で実行する。**ビルドスクリプト(`export_web.sh`)が
  全工程を `--headless` で回す前提になっている場合、これらのツールはそこへ組み込まず
  別に持つ**
- **Windows版Pythonの標準出力はCRLFで返る。**`IDS=$(python script.py)` のように
  bashへ複数行の結果を渡すと、各行の末尾に `\r` が残ったまま単語分割される。
  この `\r` 付きの文字列を外部プログラム(Godot等)へパスとして渡すと、
  パスの解決自体が失敗し、しかも**エラーメッセージが「ディレクトリが開けない」
  のような一見無関係な内容になる**ため原因に気づきにくい。`tr -d '\r'` を通すか、
  コマンドライン引数を経由させずファイル内で相対パスとして直接開く
- **同じ出力ディレクトリへ複数の `--write-movie` プロセスを重複して走らせると、
  互いに干渉して撮影が失敗する。**デバッグ中に起動したプロセスが完了(またはkill)する
  前に本番の一括実行を始めると、まったく同じ症状(大半のカードが0バイトで、
  最後に処理したものだけ正常)が起きる。バッチ処理の前に `tasklist` で
  Godotプロセスが残っていないことを確認する

### Node.js(Cloud Functions)側

- **`@napi-rs/canvas` はシステムに日本語フォントが1つも登録されていない前提で動く。**
  Cloud Functions(Linux)には日本語フォントが入っておらず、フォントを指定せずに
  `fillText()` すると**文字がすべて豆腐(□)になる**(実測で確認済み。10.6.1節の
  `SubViewport` のフォント解決と同種の問題がNode.js側にもある)。`GlobalFonts
  .registerFromPath()` で同梱フォントを明示的に登録してから使う
- **`functions/` の外にあるファイルはデプロイされない。**`firebase.json` の
  `functions.source` が `functions` ディレクトリだけを指すため、
  `assets/fonts/` のようなプロジェクトルート直下のファイルを参照しようとしても
  本番環境には存在しない。フォントのように実行時に要るファイルは `functions/` の
  中へコピーして持たせる

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
