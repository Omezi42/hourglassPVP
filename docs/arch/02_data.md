# 2. データ構造(Resource設計)

## 2.1 `CardEnums`(`scripts/data/card_enums.gd`)

v5.0のカードが使う語彙を1箇所へ集める。

| enum | 値 |
|---|---|
| `Keyword` | `GUARD`(守護)/ `GLASS`(硝子)/ `PIERCE`(貫通)/ `POISON`(毒砂)/ `LIFESTEAL`(吸命)/ `DOUBLE_STRIKE`(連撃)/ `QUICK`(速落) |
| `NAMED`(const) | **語として見せる**キーワード。`GUARD` / `GLASS` / `PIERCE` / `QUICK` の4つ |
| `Trigger` | `ON_PLAY`(設置)/ `ON_FLIP`(反転)/ `ON_DEATH`(余砂)/ `ON_TURN_END`(落砂)/ `ON_DAMAGED`(被弾) |
| `EffectTarget` | `SELF` / `ENEMY_UNIT` / `ALL_ENEMY_UNITS` / `ALL_ALLY_UNITS` / `OPPONENT_PLAYER` / `OWN_PLAYER` / **`ALLY_UNIT`** |
| `EffectVisualStyle` | `STRIKE` / `DESCEND` / `DRAIN` / `SPIN` / **`PULSE`**(その場で光の輪)/ **`RECALL`**(包んで手札へ戻す)|
| `EffectOrigin` | `UNIT` / `SPELL` / `DEATH`。紋章の出どころ(4.0節) |
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

## 2.2 `CardData`(Resource, `.tres`)

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

## 2.3 `CardEffectData`(Resource)

効果1件分。`trigger` / `target` / `effect_type` / `value` に加えて、
**値が整数1つでは足りない2つの効果のためのフィールド**を持つ。

| フィールド | 使う効果 | 内容 |
|---|---|---|
| `card_id` | `SUMMON` | 出す砂時計の id(`CardLibrary.find_by_id()` で引く) |
| `keyword` | `GRANT_KEYWORD` | 与えるキーワード。既定は -1(なし) |

**`value` を流用して「守護は0番」のように持たせない。**どの整数が何を指すかを
呼び出し側が覚えている前提のコードになり、`.tres` を読んでも意味が取れなくなるため。

## 2.3.1 コンボ系カード(条件付き効果。GameDesign.md 6章)

「総量(体力+攻撃力)がちょうどNのとき」を条件に発動する効果のための、2つの仕組みを持つ。
**新しい語(キーワード)は作らない**(既存の毒砂・吸命・連撃と同じく「1枚だけの固有効果」の
延長として扱う。過去に「共鳴」という共通の語を提案したが、2枚使い回すだけの理由では
語彙を増やさない方針とした)。

- **`CardEffectData.condition_scope`**(`CardEnums.ConditionScope`: `NONE` / `SELF` /
  `TARGET` / `ANY_ALLY`)と **`condition_total`**(見る総量の値。-1で条件なし)。
  トリガー起動の効果(設置・反転・余砂・落砂・被弾のいずれでも)へ乗せられる汎用の条件。
  `SELF` はその効果を持つ駒自身の総量、`ANY_ALLY` は自分の場のどこかに条件を満たす駒が
  いるか、`TARGET` は `ENEMY_UNIT` / `ALLY_UNIT` の対象選択そのものを条件で絞り込む
  (`CardEffectResolver._single_unit()` がヒント・自動選択の両方でこの絞り込みを掛ける)
- **`CardData.conditional_keyword` / `conditional_keyword_total`**:常在のためだけの仕組み。
  `keywords` 配列には入れず、`CardInstance.has_keyword()` が「いまの総量が
  `conditional_keyword_total` と一致する間だけ `conditional_keyword` を持つ」と判定する。
  既存の毒砂・貫通などの戦闘処理(`_resolve_unit_combat()` 等)はすべて `has_keyword()` を
  経由して判定しているため、**条件付きで毒砂を持たせる場合、戦闘側のコードは一切変更しない**
  で済む(このために `has_keyword()` を必ず通す設計にしてある。2.4節)

**`Keyword.DAMAGE_BOOST`**(「この砂時計が戦闘で与えるダメージが2倍になる」)は、上記の
`conditional_keyword` でしか使わない新設のキーワードで、`NAMED` には入れない。
`attack()`(プレイヤーへの直接攻撃)・`combat_preview()`・`_resolve_unit_combat()` の3箇所で
`attacker_power` / `defender_power` を計算した直後に `has_keyword(DAMAGE_BOOST)` を見て
2倍にする。**`clash_damage_multiplier`(27章のソロモード特殊ルール)と違い、持っている側
にしか掛からない非対称な倍率**であるため、相打ちの対称性を崩す(意図した挙動)。

新しいカードは既存 enum の組み合わせで `.tres` を1個作るだけで追加でき、コード変更を要さない。

## 2.4 `CardInstance`(RefCounted)

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

## 2.5 `CardLibrary`(RefCounted, staticのみ)

`data/cards/` を走査してカードを列挙する(`DeckSave` 等と同じ「Autoloadを使わずstaticで
持つ」流儀)。エクスポート後は `.tres` が `<name>.tres.remap` として格納されるため、
**`.remap` を除いた名前で判定し `load()` には元の `.tres` パスを渡す**(5章の既知の不具合。
これを怠るとWeb版でのみ全カードが0件になる)。

一覧の並び替え(GameDesign.md 9章)は `sorted_by_cost()` / `sorted_by_pool_index()` として
ここが持つ。**画面側が比較関数を書かない**(同じ並びを別の画面でも使うときに食い違うため)。
比較そのものは `compare_by_cost()` として公開し、**並べる対象が `all_cards()` ではない画面**
(デッキ編集の編成中の一覧・墓地の中身)も `sort_custom()` へこれを渡す。画面ごとに
自前の「コスト → id」比較を書くと、総量を見ないぶん**砂術が同コストの砂時計より前へ出る**。
並べ替えは `all_cards()` の複製に対して行い、キャッシュそのものは並べ替えない。
