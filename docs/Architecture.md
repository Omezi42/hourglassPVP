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
| `Trigger` | `ON_PLAY`(設置)/ `ON_FLIP`(反転)/ `ON_DEATH`(余砂) |
| `EffectTarget` | `SELF` / `ENEMY_UNIT` / `ALL_ENEMY_UNITS` / `ALL_ALLY_UNITS` / `OPPONENT_PLAYER` / `OWN_PLAYER` |
| `EffectType` | `DAMAGE_PLAYER` / `DAMAGE_UNIT` / `DESTROY_UNIT` / `SWAP_STATS` / `ADD_TOTAL` / `DROP_SAND` / `DRAW` / `HEAL_PLAYER` / `DAMAGE_PLAYER_PER_ENEMY_UNIT` |

`keyword_name()` / `trigger_name()` は GameDesign.md 6章の日本語表記を返す。表示名を
UI側に散らさないため、語と enum の対応はここだけが持つ。

### 2.2 `CardData`(Resource, `.tres`)

カード1種の静的定義。1カード = 1 `.tres`(`data/cards/{id}.tres`)。
**体力・攻撃力のフィールドは持たない**。総量から導出される(GameDesign.md 1章)。

| フィールド | 型 | 内容 |
|---|---|---|
| `id` | String | 一意識別子("sand", "sword" 等) |
| `display_name` | String | 表示名 |
| `cost` | int | 場に出すために支払うマナ |
| `total_sand` | int | 総量(体力+攻撃力)。場に出た時点で 体力=総量 / 攻撃力=0 |
| `keywords` | Array[Keyword] | 常在キーワード。0個でよい(バニラ) |
| `effects` | Array[CardEffectData] | キーワードで表せない固有効果。0個でよい |
| `rules_text` | String | 効果欄に出す一文。キーワードだけのカードは空 |
| `icon_upright` / `icon_falling` / `icon_fallen` | Texture2D | 体力が多い/半々/攻撃力に偏った状態のイラスト |

`describe()` が「キーワード名 / 固有効果の文」を組み立てるため、UI側は表示文字列を
自分で作らない。

### 2.3 `CardEffectData`(Resource)

効果1件分。`trigger` / `target` / `effect_type` / `value` の4フィールドのみ。
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

**砂の移動を3つのメソッドで区別する。**取り違えるとルールが崩れるため名前で分ける。

- `drop_sand(n)` … 体力-n / 攻撃力+n。**総量は変わらない**(ターン終了の1粒・速落)
- `flip()` … 体力と攻撃力を入れ替える
- `take_damage(n)` … 体力-n のみ。**総量が減る**(GameDesign.md 4章)。硝子が残っていれば
  1度だけ0を返して無効化する

`lifetime_damage()` は `health * attack + health * (health - 1) / 2`(GameDesign.md 1章)。
CPUの評価関数の基礎であり、ロジック層に置いてUI・CPUの双方から使う。

### 2.5 `CardLibrary`(RefCounted, staticのみ)

`data/cards/` を走査してカードを列挙する(`DeckSave` 等と同じ「Autoloadを使わずstaticで
持つ」流儀)。エクスポート後は `.tres` が `<name>.tres.remap` として格納されるため、
**`.remap` を除いた名前で判定し `load()` には元の `.tres` パスを渡す**(5章の既知の不具合。
これを怠るとWeb版でのみ全カードが0件になる)。

---

## 3. ロジック層

UIに依存しない、対局ルールそのものを扱う層。

### 3.1 `MatchState`(`scripts/logic/match_state.gd`, Node)

対局中の唯一の真実を保持する。旧 `GameState` とは別クラスとして並走させている。

保持するもの:両プレイヤーの `hp` / `mana` / `max_mana` / `deck`(山札)/ `hand` /
`board`(6枠の `CardInstance`、空きは null)/ `graveyard`、`current_turn`、`first_side`、
`turn_count`、`end_reason`、`winner`。いずれも `Side`(A/B)をキーにした Dictionary。

定数は GameDesign.md 2章の数値をそのまま持つ:`INITIAL_HP = 30` / `BOARD_SIZE = 6` /
`DECK_SIZE = 20` / `MAX_MANA = 10` / `FIRST_PLAYER_HAND = 3` / `SECOND_PLAYER_HAND = 4` /
`FATIGUE_DAMAGE = 1` / `COIN_MANA = 1`。加えて、両者が延々とパスし続けた場合の保険として `MAX_TURNS = 200`
(到達したら `EndReason.DRAW` で打ち切る。シミュレーションが止まらなくなるのを防ぐためで、
実対局では持ち時間(GameDesign.md 5章)が先に尽きる)。

**手番の流れ**(GameDesign.md 3章)は `_begin_turn()` と `end_turn()` の2つだけで表す。

- `_begin_turn()`:`turn_count` を進める → 最大マナ+1・全回復 → 自分の全ユニットの
  `begin_turn()`(召喚酔い・反転済み・攻撃回数のリセット)→ ドロー1枚 → `turn_started` を発行
- `end_turn()`:自分の全ユニットを `tick()`(1粒落とす)→ 体力0になったものを破壊 →
  山札が尽きていれば疲労1ダメージ → 手番を交代して `_begin_turn()`

**コイン**(GameDesign.md 2章)は `coin_available`(Side をキーにした bool)と
`use_coin(side)` の2つだけで表す。対局開始時に後手だけ true にし、使うと false に戻す。
**カードとしては持たない**。手札に置くと「0コストで場に出す」既存の経路と衝突するうえ、
盤面の枠を持たないカード(スペル)という概念を1枚のために導入することになるため。

**メインフェイズの操作は3つ**で、いずれも `can_*()` と実行のペアを持つ。UI・CPU・
オンラインの再生はすべてこの3つだけを呼ぶ。

- `play_card(side, hand_index, slot, target)` … マナを払って空き枠へ置く。枠が埋まって
  いれば**上書きし、元のカードを墓地へ送る**。速落は `drop_sand(2)` して
  `summoned_this_turn` を下ろす。最後に `ON_PLAY` の効果を解決する
- `flip(side, slot)` … 体力と攻撃力を入れ替える。マナ不要・1体1ターン1回・出したターンは不可。
  `ON_FLIP` の効果を解決する
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

### 3.2 `CardEffectResolver`(`scripts/logic/card_effect_resolver.gd`, RefCounted)

`CardEffectData` の評価と適用を1箇所に集約する。`MatchState` が生成して保持し、
`resolve(side, unit, trigger, hint)` を設置・反転・余砂の3箇所から呼ぶ。

- `effect_type` ごとの分岐を1つの `match` に持ち、新しい種別を足すときはここへ1分岐を
  加えるだけで済む形を保つ
- `target` の解決(自分自身/相手1体/相手全体/味方全体/プレイヤー)もここで行う
- **対象を1体選ぶ効果(`ENEMY_UNIT`)は、`hint`(`{"side":..., "slot":...}`)で受け取る。**
  指定が無い・その枠が既に空いている場合は「生涯ダメージが最大の1体」を自動で選ぶ。
  これによりUIは対象選択を実装するまで指定なしで呼べ、CPU・リプレイ再生も同じ経路を通る

### 3.3 検証

`tools/tests/v5_rules_tests.gd`(`run_tests.gd` から呼ぶ)が、生涯ダメージの式・砂の3つの
移動・初期手札と先手のドロー無し・上書き設置・召喚酔いと速落・相打ち・守護/硝子/貫通/
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
| `CardView`(`scripts/ui/card_view.gd`) | カード1枚の表示。**手札と場で見た目を変える**(GameDesign.md 9章)。`Mode.HAND` はカードの枠を持ち **コスト=左上 / 総量=右下**、`Mode.BOARD` は**枠を持たず、丸い台座の上に立つ砂時計そのもの**として描き **攻撃力=左下 / 体力=右下**(コストは出さない)。体力と攻撃力の比で3枚のイラストを切り替え、守護は手札なら枠・場なら台座の輪を太くし、硝子は手札なら枠の内側・場ならガラスへ薄い膜を重ねる |
| `BoardTable`(`scripts/ui/board_table.gd`) | 盤面12枠を載せる卓上。奥へ狭まる石と真鍮の台形を描き、中央に区切り線と紋章を置く。v1.0から流用しているが、v5.0では6+6枠を1枚の卓へ載せるために使う |
| `PlayerInfoBar`(`scripts/ui/player_info_bar.gd`) | 片方のプレイヤーの情報帯。HP・マナ(数字+ピップ)・山札・墓地・(相手のみ)手札の枚数・コインの有無 |
| `CardMatchSelection`(`scripts/ui/card_match_selection.gd`) | いま選んでいるもの(手札の1枚 / 自分の場の1枠 / 未選択)。選択の状態を1箇所へ集めて画面側の分岐を減らす |
| `CardMatchScreen`(`scripts/ui/card_match_screen.gd`) | 上記を並べ、`MatchState` と同期し、操作(出す/反転/攻撃/コイン/ターン終了/投了)を受ける |
| `CardMatchLog`(`scripts/ui/card_match_log.gd`) | 対局ログ。`MatchState` のシグナルを購読して日本語の行を積み、中央のモーダルとして開く。**記録と表示を同じクラスに持たせている**のは、実況に出す文と読み返す文を必ず一致させるため |
| `CardMatchResult`(`scripts/ui/card_match_result.gd`) | 結果パネル。勝敗・最終HP・総手数・決着の要因と「ログ」「ホームへ」 |
| `CardDeckEditorScreen`(`scripts/ui/card_deck_editor_screen.gd`) | デッキ編集(20枚・同名2枚まで)。共通の `ScreenHeader` を使う |
| `CardManaCurve`(`scripts/ui/card_mana_curve.gd`) | コスト別の枚数の棒グラフ |
| `CardListScreen`(`scripts/ui/card_list_screen.gd`) | カード一覧。選ぶと右の詳細パネルへ出す |
| `CardDetailPanel`(`scripts/ui/card_detail_panel.gd`) | カード1種の詳細。**キーワードは名前と説明の両方**を出す(語だけでは初見に伝わらない) |
| `CardPileViewer`(`scripts/ui/card_pile_viewer.gd`) | 墓地の中身を見るモーダル。同じカードは1枚にまとめて枚数をバッジで出す |
| `CodedButton`(`scripts/ui/coded_button.gd`) | コードで組むボタンの生成を集約する。画面ごとに `theme_override` を並べると指定漏れのボタンが混ざるため |
| `CardMatchReplay`(`scripts/ui/card_match_replay.gd`) | リプレイの再生コントロール。**任意の手数の局面は初期状態から手を並べ直して作る** |

**行動のボタン(反転・コイン・ターン終了)は画面右の列にまとめる。**当初は選択した駒の
すぐ上へ「反転」を出していたが、自分の場の上は相手の場であり、**相手のカードへ重なって
しまった**(実際にレンダリングして発覚した)。選択中の駒は枠の色で示すため、
ボタンを駒の近くへ置く必要はない。

**選択中の枠は水色、守護の枠は真鍮色**と系統を分ける。どちらも「枠を強調する」表現のため、
同系色にすると取り違える。

**総手数は `MatchState.turn_count` をそのまま使う。**UI側で「ターン終了を押した回数」を
数えると、CPU同士で進めた場合や将来のリプレイ再生で0手になる(実際に検証中そうなった)。

**ログは結果パネルより後に `add_child()` する。**終局後は結果パネルが盤面全体を塞ぐため、
その上からログを開けないと読み返せない(GameDesign.md 9章)。

**v5.0のオンライン対戦は、山札の並びを「種」で共有して両者が同じ対局を再現する。**
配置フェーズが無いため、`OnlineSetup.push_setup()` / `wait_for_opponent_setup()` で
デッキ(20枚のid)と `seed` だけを交換し、そのまま `MatchState.start_match()` へ入る。
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

**反転の演出は `CardFlipBeam`(光の筋)と `CardView.play_flip()`(駒の裏返り)の2段で作る。**
`MatchState.unit_flipped` を受けて、まず反転した側の情報帯から対象の駒へ光の筋を伸ばし、
届いたところで駒を持ち上げて裏返す。**光の筋は対局画面の `_draw()` ではなく独立した
オーバーレイのノードとして持つ**。`Control._draw()` は自分の子より背面に描かれるため、
画面側で描くと卓と駒に隠れて筋がほとんど見えない(実際にそうなった)。

**砂の演出は2種類を別のシグナルで受ける。**`MatchState` は被ダメージを `unit_damaged`、
ターン終了の1粒を `unit_ticked` として別々に発行し、`CardView` が
`play_shatter()`(砕けて外へ散る・赤)と `play_drop()`(下の部屋へ流れる・琥珀)で描き分ける。
**この2つを取り違えるとルールを誤解する**(前者は総量が減り、後者は総量が変わらない)ため、
演出上もっとも重要な区別として扱う(GameDesign.md 9章)。同じシグナルに相乗りさせない。

**設置効果の対象選択**は `CardMatchSelection.TARGETING` として持つ。カードを出す枠まで
決めた時点でいったん止め、相手のカードを押すと `play_card()` の `target` へ渡して確定する。
相手の場が空のときは選ばせる意味がないためそのまま出す。案内は**行動ボタンの列へ出す**
(盤面へ重ねると、選ばせたい相手のカードそのものを隠してしまう)。

`Main` は `card_match_screen` を `_ready()` で生成して `_screens` へ加える(`.tscn` を
持たないため)。**CPU戦は `BattleDeckPickerScreen` を挟まずこの画面へ直行する**。
あの画面は v1.0 の5枚デッキ用で20枚デッキに対応していないため、v5.0のデッキ編集が
できた時点で差し替える。デッキは `CardDeckSave`(`user://card_decks.json`、v1.0の
`DeckSave` とは形式が違うためファイルを分ける)から読み、未保存なら
`default_deck()`(コストの安い順に10種を2枚ずつ)を使う。

**デッキ編集は「カード名 × 枚数」の縦リスト + マナカーブ + 全カードの横スクロール**の
3ブロックで組む(GameDesign.md 9章)。20枚をカードの絵で並べると画面に入らないため、
編成中はテキストのリストにする。一覧のカードには `CardView.badge` で「2/2」を出し、
入れられないカードは暗くする。**保存は20枚ちょうどのときだけ通す**(枚数が足りない
デッキで対局へ入れないようにするため)。`Main` の「デッキ編集」は v1.0 のデッキ一覧を
挟まずこの画面へ直行する(v5.0はまだデッキを1つしか持たないため)。

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
├── HomeScreen               # 下部2ボタン(デッキ/バトル)で機能を切り替える
├── ReplayListScreen         # 保存済みリプレイの一覧
├── AccountScreen            # アカウント(14章)
│   (上記のうち対局画面を除く各画面は、先頭の子として共通の ScreenHeader を持つ)
├── CardMatchScreen          # 対局・観戦・リプレイ再生(コードで組み立てる。4.0節)
├── CardDeckEditorScreen     # デッキ編集(20枚・同名2枚まで。同上)
└── CardListScreen           # カード一覧(同上)
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
- **意味を持たない小物の装飾(四隅のネジ/リベット、角の渦巻き・スクロール意匠)は付けない**。元の画像ボタンには存在したが、コード描画版で再現したところノイズに見えるとユーザーが判断し、完全撤去した。一方で、**機能を示す形と紋章は積極的に付ける**(次項)。両者の線引きは「そのボタンが何をするかを伝えているか」であり、伝えていない純粋な飾りは置かない
- **グループごとの個性は「外形の形」と「紋章」だけで表現し、材質は全グループ共通に保つ**。元の画像ボタンは「戻る=左向き矢印の形」「保存=チェックマーク」「反転/移動/交代=紋章入りの円形メダリオン」「タブ=砂時計の徽章付きピル」というように、形と紋章が機能を語る設計だった。全グループを同一の見た目へ統一した結果この個性が失われたため復元した。ただし材質(反射カーブ・グレイン・面取り・落ち込み影)をグループごとに変えることは禁止する。材質を共通に保つことが、個性を出しつつ全体が調和して見えるための条件である
- `CodedButtonStyle`(`scripts/ui/styles/coded_button_style.gd`, `extends StyleBox`)は、次の4つの`@export`で全ボタンを賄う
  - `State`: NORMAL / HOVER / PRESSED / DISABLED
  - `Shape`: ROUNDED_RECT / CIRCLE / PILL(両端が半円) / CHEVRON_LEFT(左辺が尖った五角形)
  - `Emblem`: NONE / HOURGLASS / SWAP_ARROWS / BENCH / CHECK。描画実体は`UiPaint`側のstatic関数に置き、太い暗色の輪郭+真鍮の塗り+上側のハイライトによる浮き彫り表現とする(細い線画にしない)
  - `EmblemPlacement`: CENTER / UPPER(下半分にテキストが入る) / RIGHT_INSET / TOP_BADGE(上端から少し飛び出す円形の徽章)
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
- **受け取った手は1ポーリングにつき1件だけ配る**。`MatchScreen._on_action_received()`は
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
- **BGMの切り替えは `Main._show_only()`(画面切り替えのハブ)から1箇所で行う**。遷移先に応じた曲は `Main._track_for()` が決める(`MatchScreen`なら対局曲、`TitleScreen`ならタイトル曲、それ以外はホーム曲)。画面ごとに個別へ `MusicPlayer.play()` を書き散らさない
- **クラシック曲はシームレスにループしない**ため、`AudioStreamPlayer.finished` を購読し、数秒の間を置いてから頭へ戻す「アルバム再生」方式で繰り返す。インポート設定でループを有効にすると `finished` が発火しなくなるため、**実行時に `stream.loop = false` を明示する**
- **曲の終端の `TAIL_FADE` 秒前から音量を絞る**(GameDesign.md 9章)。再生開始時に `stream.get_length()` から逆算したタイマーを張り、発火時にまだ同じ曲が同じプレイヤーで鳴っていればフェードアウトを始める。タイトル曲のように**曲の途中を切り出した音源**でも切れ目が唐突に聞こえないようにするため。フェード中は `set_volume()` が音量を戻さないよう `_tail_fading` で守る
- **タイトル曲は元の録音を再エンコードせず、Oggのページ境界でそのまま切り出して使う**。この環境には ffmpeg/oggenc が無く、また再エンコードは音質を落とすため。切り出しは「granule_position が目標サンプル数を超えたページまでを残し、最後のページへ EOS フラグを立ててCRCを再計算する」だけで、ページの中身には触れない
- **ブラウザの自動再生制限に対応する**。`MusicPlayer.play()` は、最初のユーザー操作を検知するまで実際には鳴らさず、要求されたトラックを `_pending_track` として覚えておくだけにする。`Main` が最初のクリック/タップで `MusicPlayer.notify_user_gesture()` を呼び、そこで保留していたトラックの再生を始める
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
| `currency` | int | 砂金の残高 |
| `cpu_reward_date` | String | CPU戦の報酬を数えている日付(`YYYY-MM-DD`) |
| `cpu_reward_count` | int | その日付にCPU戦で報酬を得た回数 |
| `updated_at` | float | 最終更新時刻(Unix時間) |

- 読み書きは `AccountService`(`scripts/net/account_service.gd`、`ReplayService` と同じ
  static のみのクラス)に集約する。`MatchScreen` や各画面が `FirestoreClient` を直接
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
- `MatchScreen` は対局の種別(ランダムマッチ / ルームマッチ / CPU戦)と勝敗・総手数を
  渡すだけにする。**オンライン対戦がランダムマッチかルームマッチかは、これまで
  `MatchScreen` が区別していなかった**ため、`HomeScreen.online_match_found` と
  `MatchScreen.start_placement_then_online()` に対局種別を1つ足して伝える
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
  `ScreenHeader`(4章)に従い、状態表示・表示名の変更・登録・ログイン・ログアウトを持つ
- 入口は2つ。`TitleScreen` と `HomeScreen` のヘッダー。`Main` は他の画面と同様に
  `_show_only()` で切り替える
- ホーム画面のヘッダーには表示名と砂金の残高を出す。残高は `AccountService` が
  キャッシュしている値を読むだけにし、画面を開くたびに通信しない

## 未検討事項

- `EffectResolver` の対応表の具体的な実装方式(match文 vs 個別クラス継承)は、実装着手時に決定する
