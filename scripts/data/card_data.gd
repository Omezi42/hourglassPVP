class_name CardData
extends Resource
## 砂時計(カード)1種の静的定義(GameDesign.md 1章)。
## パラメータは コスト / 総量 / キーワードまたは効果 の3つだけで、
## 体力・攻撃力は総量から導出されるため持たない。

@export var id: String = ""
@export var display_name: String = ""
## 場に出すために支払うマナ。
@export var cost: int = 0
## 体力と攻撃力の合計。場に出た時点で 体力=総量 / 攻撃力=0 で始まる。
@export var total_sand: int = 0
## プールへ加えられた順の通し番号(GameDesign.md 9章の「追加順」)。
## **ファイル名や一覧の並びから導出しない**。id のアルファベット順は追加順ではないため。
@export var pool_index: int = 0
## 常在キーワード(GameDesign.md 6章)。0個でよい(バニラ)。
@export var keywords: Array[CardEnums.Keyword] = []
## キーワードで表せない固有効果。0個でよい。
@export var effects: Array[CardEffectData] = []
## 効果欄に出す一文。キーワードだけのカードは空でよい(キーワード名から自動生成する)。
@export var rules_text: String = ""
## 攻撃できない代わりに総量が大きい駒(GameDesign.md 6章)。反転はできる。
## 守護と違い**語にしない**ため keywords ではなくフラグで持つ。
@export var cannot_attack: bool = false
## 効果で場に出る砂時計(トークン)。CardLibrary.all_cards() が返さないため、
## デッキ編集にも砂時計一覧にも現れない。
@export var is_token: bool = false

## 砂術(GameDesign.md 6章)。**盤面へ出ず、効果だけを起こして墓地へ行く。**
## true のとき total_sand / keywords / cannot_attack は使わない。
@export var is_spell: bool = false

@export_group("Icons")
## どの絵を使うか(Architecture.md 4.1節)。空ならこのカードの id をそのまま使う。
## ガード=`king` / グロウ=`judge` のように、別のカードの絵を借りる場合だけ書く。
## **絵そのものへの参照は持たない**。全種が原本1枚の色違いであり、実際の絵は
## HourglassArt が起動時に作るため(GameDesign.md 9章)。
@export var art_id: String = ""

## そのカードだけの紋章(モチーフのアイコン)。砂時計の絵は全種で共通の1枚を
## 色違いにしたものなので、**どのカードかを見分けているのはこの紋章**になる
## (GameDesign.md 9章)。白のシルエットで持ち、色は描画側が決める。
@export var emblem: Texture2D

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


func has_keyword(keyword: int) -> bool:
	return keywords.has(keyword)


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
