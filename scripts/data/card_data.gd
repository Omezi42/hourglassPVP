class_name CardData
extends Resource
## 砂時計(カード)1種の静的定義(GameDesign.md 1章)。
## 場の体力・攻撃力は 総量 と 初期攻撃力 から導出する。

@export var id: String = ""
@export var display_name: String = ""
## 場に出すために支払うマナ。
@export var cost: int = 0
## 体力と攻撃力の合計。場に出た時点で 体力=総量-初期攻撃力 で始まる。
@export var total_sand: int = 0
## 場に出た時点ですでに下の部屋にある砂(GameDesign.md 1章)。コスト5以上・総量未満に限る(同7章)。
@export var initial_attack: int = 0
## プールへ加えられた順の通し番号(GameDesign.md 9章の「追加順」)。
## **ファイル名や一覧の並びから導出しない**。id のアルファベット順は追加順ではないため。
@export var pool_index: int = 0
## 所属するカードセットのid(GameDesign.md 8章・21章・27章)。空文字は基本セット
## (常に所有済み)。空でなければ `players/{uid}.owned_card_sets` に含まれるまで
## デッキへ入れられない(Architecture.md 10.8.1節)。
@export var set_id: String = ""
## レアリティ(GameDesign.md 8章)。弾のカードだけが読む。基本セットは使わない(常に2枚持つ)。
@export var rarity: CardEnums.Rarity = CardEnums.Rarity.COMMON
## 常在キーワード(GameDesign.md 6章)。0個でよい(バニラ)。
@export var keywords: Array[CardEnums.Keyword] = []
## キーワードで表せない固有効果。0個でよい。
@export var effects: Array[CardEffectData] = []
## 効果欄に出す一文。キーワードだけのカードは空でよい(キーワード名から自動生成する)。
@export var rules_text: String = ""
## フレーバーテキスト(GameDesign.md 1章)。対局の処理は読まない。出すのは図鑑だけ。
@export_multiline var flavor_text: String = ""
## コンボ系カード(GameDesign.md 6章)。自分のいまの総量(体力+攻撃力)が
## conditional_keyword_total と一致する間だけ、このキーワードを持つ。
## keywords 配列には含めない(常には持たないため)。-1 は「無し」。
@export var conditional_keyword: int = -1
@export var conditional_keyword_total: int = -1
## 攻撃できない代わりに総量が大きい駒(GameDesign.md 6章)。反転はできる。
## 守護と違い**語にしない**ため keywords ではなくフラグで持つ。
@export var cannot_attack: bool = false
## 反転できない駒(GameDesign.md 6章。「攻撃できない」の鏡像)。**反転権でも反転できない**。
## 放置すると攻撃力が総量-1まで伸びる時限爆弾として働く。語にしないためフラグで持つ。
@export var cannot_flip: bool = false
## 場にいる間、自分の砂時計の反転トリガーが2回発動する(GameDesign.md 6章。マエストロ)。語にしないためフラグで持つ。
## 何体いても2回まで。
@export var ally_flip_triggers_twice: bool = false
## 効果で場に出る砂時計(トークン)。CardLibrary.all_cards() が返さないため、
## デッキ編集にも砂時計一覧にも現れない。
@export var is_token: bool = false
## 手札にある間、相手の砂時計1体につきコストがこの値だけ下がる(GameDesign.md 6章。コロッサス)。
## 実際に払うコストは `MatchState.play_cost()` が出す。0なら下がらない。
@export var cost_down_per_enemy_unit: int = 0
## 手札にある間、自分のHPが cost_down_hp_threshold 以下ならコストがこの値だけ下がる(GameDesign.md 6章。バスティオン)。
## 実際に払うコストは `MatchState.play_cost()` が出す。0なら下がらない。
@export var cost_down_low_hp: int = 0
## cost_down_low_hp が効く自分のHPの上限(初期HPの半分)。
@export var cost_down_hp_threshold: int = 0
## 手札にある間、自分の最大マナが上限に届いているならコストがこの値だけ下がる(GameDesign.md 6章。カリヨン)。0なら下がらない。
@export var cost_down_full_mana: int = 0
## 相手の砂時計が自分の砂時計(この駒を含む)より多いあいだ、静止を持つ(GameDesign.md 6章。ホールド)。
## 常には持たないため keywords へは入れない。判定は `MatchState` が盤面の変わるたびに `CardInstance.held_still` へ書く。
@export var still_while_outnumbered: bool = false
## 相手のHPがこの値以下のあいだ、疾走を持つ(GameDesign.md 6章。チェイサー)。-1 は「無し」。
## 常には持たないため keywords へは入れない。判定は `MatchState` が盤面とHPの変わるたびに `CardInstance.held_quick` へ書く。
@export var quick_while_foe_hp_at_most: int = -1
## 場にいる間、自分の砂時計すべてが守護を無視して攻撃できる(GameDesign.md 6章。抜け道)。語にしないためフラグで持つ。
@export var allies_ignore_guard: bool = false
## 場にいる間、自分の砂術のコストがこの値だけ下がる(GameDesign.md 6章。セージ)。複数体なら足し合わせる。
@export var ally_spell_cost_down: int = 0
## 場にいる間、自分の山札の一番上が公開され、手札と同じように使える(GameDesign.md 6章「山札の上を扱う効果」。シビル)。
## 語にしないためフラグで持つ。消された駒は持たない。
@export var plays_deck_top: bool = false
## 場にいる間、自分の最大マナが上限に届いているなら、自分のカードのコストがこの値だけ下がる(GameDesign.md 6章。クロックワーク)。
## 複数体なら足し合わせる。実際に払うコストは `MatchState.play_cost()` が出す。
@export var ally_cost_down_at_full_mana: int = 0
## 場にいる間、自分の手番の終わりに残したマナを次の手番へ持ち越す(GameDesign.md 6章。スルース)。語にしないためフラグで持つ。
@export var carries_mana: bool = false
## 場にいる間、相手が出す・使うカードのコストがこの値だけ上がる(GameDesign.md 6章「封じる効果」。トール)。複数体なら足し合わせる。
## 実際に払うコストは `MatchState.play_cost()` が出す。消された駒は持たない。
@export var foe_cost_up: int = 0
## 自分が攻撃したときに相手から受ける反撃のダメージが、この値だけ少ない(0未満にはならない。GameDesign.md 6章「戦わせる効果」。フェンサー)。
## 攻撃されたとき・戦わされたときは減らない。
@export var attack_recoil_cut: int = 0
## 場にいる間、相手の山札の一番上が自分にだけ表向きで見える(GameDesign.md 6章「相手のカードを見る・写す効果」。スカウト)。語にしないためフラグで持つ。
## 消された駒は持たない。
@export var sees_foe_deck_top: bool = false

## 砂術(GameDesign.md 6章)。**盤面へ出ず、効果だけを起こして墓地へ行く。**
## true のとき total_sand / keywords / cannot_attack は使わない。
@export var is_spell: bool = false

@export_group("Icons")
## どの絵を使うか(Architecture.md 4.1節)。空ならこのカードの id をそのまま使う。
## 別のカードの絵を借りる砂術だけが書く(砂時計は1種ごとに固有の絵を持つ)。
## **絵そのものへの参照は持たない**。実際の絵は HourglassArt が焼いた絵を配るため。
@export var art_id: String = ""

## そのカードだけの紋章(モチーフのアイコン)。絵の飾りまで読めない小さな表示では、
## **どのカードかを見分けているのはこの紋章**になる(GameDesign.md 9章)。白のシルエットで持ち、色は描画側が決める。
@export var emblem: Texture2D

## 3状態のイラスト。
## 体力が満ちている(=場に出た直後に近い)状態のイラスト。
var icon_upright: Texture2D:
	get:
		return HourglassArt.texture(art_key(), HourglassArt.State.UPRIGHT)

## 砂が落ちている途中の状態のイラスト。
var icon_falling: Texture2D:
	get:
		return HourglassArt.texture(art_key(), HourglassArt.State.FALLING)

## 攻撃力に偏った(=砂が落ちきりに近い)状態のイラスト。
var icon_fallen: Texture2D:
	get:
		return HourglassArt.texture(art_key(), HourglassArt.State.FALLEN)


## 実際に使う絵の id。
func art_key() -> String:
	return art_id if not art_id.is_empty() else id


## 場に出た時点の体力。
func initial_health() -> int:
	return total_sand - initial_attack


func has_keyword(keyword: int) -> bool:
	return keywords.has(keyword)


## 札の名前の下の行に出す分類名(GameDesign.md 6章)。砂術はトリガーを持たないため「砂術」、
## 条件付きの常在能力だけを持つカードは「常在」。どれにも当たらなければ空文字。
func category_name() -> String:
	if is_spell:
		return "砂術"
	if not effects.is_empty():
		return CardEnums.trigger_name(effects[0].trigger)
	if (
		conditional_keyword >= 0
		or cost_down_per_enemy_unit > 0
		or cost_down_low_hp > 0
		or cost_down_full_mana > 0
		or still_while_outnumbered
		or quick_while_foe_hp_at_most >= 0
		or allies_ignore_guard
		or ally_spell_cost_down > 0
		or plays_deck_top
		or ally_cost_down_at_full_mana > 0
		or carries_mana
		or foe_cost_up > 0
		or attack_recoil_cut > 0
		or sees_foe_deck_top
	):
		return "常在"
	return ""


func effects_for(trigger: int) -> Array[CardEffectData]:
	var found: Array[CardEffectData] = []
	for effect in effects:
		if effect != null and effect.trigger == trigger:
			found.append(effect)
	return found


## デッキ編集・墓地の一覧に出す1行。語にする能力は語で、語にしない能力は
## 説明文で書く(GameDesign.md 6章)。カードの面はもっと狭いため、そちらは
## CardEnums.keyword_short_text() の短い言い換えを使う。
func describe() -> String:
	var parts: PackedStringArray = []
	if is_spell:
		return rules_text if not rules_text.is_empty() else "効果なし"
	if cannot_attack:
		parts.append("攻撃できない")
	if cannot_flip:
		parts.append("反転できない")
	for keyword in named_keywords():
		parts.append(CardEnums.keyword_name(keyword))
	for keyword in plain_keywords():
		parts.append(CardEnums.keyword_description(keyword))
	if not rules_text.is_empty():
		parts.append(rules_text)
	if parts.is_empty():
		return "効果なし"
	return " / ".join(parts)


## 語として見せるキーワードだけ。カードの面に出す。
func named_keywords() -> Array:
	var found: Array = []
	for keyword in keywords:
		if CardEnums.is_named(keyword):
			found.append(keyword)
	return found


## 語にしないキーワード。カードの面には短い言い換えで出す。
func plain_keywords() -> Array:
	var found: Array = []
	for keyword in keywords:
		if not CardEnums.is_named(keyword):
			found.append(keyword)
	return found
