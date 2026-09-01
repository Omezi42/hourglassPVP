class_name KeywordEntries
extends RefCounted
## キーワード辞書の中身(GameDesign.md 17章)。語 → 表示名・説明・実演・分類 の対応と
## 並び順を1箇所へ集める(Autoloadを使わずstaticで持つ流儀)。
##
## **`CardEnums` は「語と文を返す」既存の責務のまま変えない。**並び順・分類・実演の
## 割り当ては辞書側の関心であり、対局のロジックが読む語彙へ表示の都合を混ぜないため。
##
## **その語を持つ砂時計は表へ書かず `CardLibrary` から実行時に集める**
## (カードを1枚足したときに辞書を書き換える作業が発生しないようにするため)。

## 項目の種類。常在の能力とトリガーは別々の enum のため、値を1つの整数へ混ぜない。
enum Kind { KEYWORD, TRIGGER }

const CATEGORY_NAMES := {Kind.KEYWORD: "常在", Kind.TRIGGER: "トリガー"}

## 繰り返し発動するトリガーの説明。1行に収まらないため定数へ出している。
const TURN_END_TEXT := "自分のターンの終わりに、砂が1粒落ちる直前へ発動する。場に残っているかぎり毎ターン発動する。"
const DAMAGED_TEXT := "ダメージを受けたときに発動する。硝子で無効にした場合と、砕けた場合は発動しない。"

## トリガーの説明。`CardEnums` はトリガーの表示名しか持たないため、ここで文を添える。
const TRIGGER_DESCRIPTIONS := {
	CardEnums.Trigger.ON_PLAY: "手札から場に出したときに効果が発動する。",
	CardEnums.Trigger.ON_FLIP: "反転したときに効果が発動する。反転は毎ターン行えるため、何度でも発動する。",
	CardEnums.Trigger.ON_DEATH: "破壊されたときに効果が発動する。",
	CardEnums.Trigger.ON_TURN_END: TURN_END_TEXT,
	CardEnums.Trigger.ON_DAMAGED: DAMAGED_TEXT,
}

## 実演の台本。持たない語は -1 とし、実演の枠自体を出さない。
## 設置・余砂は「いつ発動するか」だけを表すため、単体で見せる動きが無い。
const DEMOS := {
	CardEnums.Keyword.GUARD: CardEffectPreview.Demo.GUARD,
	CardEnums.Keyword.GLASS: CardEffectPreview.Demo.GLASS,
	CardEnums.Keyword.PIERCE: CardEffectPreview.Demo.PIERCE,
	CardEnums.Keyword.QUICK: CardEffectPreview.Demo.QUICK,
	CardEnums.Keyword.POISON: CardEffectPreview.Demo.POISON,
	CardEnums.Keyword.LIFESTEAL: CardEffectPreview.Demo.LIFESTEAL,
	CardEnums.Keyword.DOUBLE_STRIKE: CardEffectPreview.Demo.DOUBLE_STRIKE,
}

## 語にする4種 → 語にしない3種 → トリガー5種の順に並べる。
## 語にするものを先に置くのは、カードの面へ出ているぶん引かれる回数が多いため。
const ORDER: Array[Array] = [
	[Kind.KEYWORD, CardEnums.Keyword.GUARD],
	[Kind.KEYWORD, CardEnums.Keyword.GLASS],
	[Kind.KEYWORD, CardEnums.Keyword.PIERCE],
	[Kind.KEYWORD, CardEnums.Keyword.QUICK],
	[Kind.KEYWORD, CardEnums.Keyword.POISON],
	[Kind.KEYWORD, CardEnums.Keyword.LIFESTEAL],
	[Kind.KEYWORD, CardEnums.Keyword.DOUBLE_STRIKE],
	[Kind.TRIGGER, CardEnums.Trigger.ON_PLAY],
	[Kind.TRIGGER, CardEnums.Trigger.ON_FLIP],
	[Kind.TRIGGER, CardEnums.Trigger.ON_DEATH],
	[Kind.TRIGGER, CardEnums.Trigger.ON_TURN_END],
	[Kind.TRIGGER, CardEnums.Trigger.ON_DAMAGED],
]


## 辞書に載る全項目。1件は {"kind": Kind, "value": int}。
static func all_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pair in ORDER:
		entries.append({"kind": pair[0], "value": pair[1]})
	return entries


static func keyword_entry(keyword: int) -> Dictionary:
	return {"kind": Kind.KEYWORD, "value": keyword}


static func trigger_entry(trigger: int) -> Dictionary:
	return {"kind": Kind.TRIGGER, "value": trigger}


## 見出しに出す語。**語にしない能力(毒砂・吸命・連撃)は、カードの面と同じ短い
## 言い換え**(「破壊」など)を出す。カードに出ていない語をここだけで見せると、
## 盤面と辞書で呼び名が食い違うため(GameDesign.md 6章)。
static func title(entry: Dictionary) -> String:
	var value: int = int(entry["value"])
	if int(entry["kind"]) == Kind.TRIGGER:
		return CardEnums.trigger_name(value)
	if CardEnums.is_named(value):
		return CardEnums.keyword_name(value)
	return CardEnums.keyword_short_text(value)


static func description(entry: Dictionary) -> String:
	var value: int = int(entry["value"])
	if int(entry["kind"]) == Kind.TRIGGER:
		return str(TRIGGER_DESCRIPTIONS.get(value, ""))
	return CardEnums.keyword_description(value)


static func category(entry: Dictionary) -> String:
	return str(CATEGORY_NAMES.get(int(entry["kind"]), ""))


## 実演の台本。持たない語は -1。
static func demo(entry: Dictionary) -> int:
	if int(entry["kind"]) == Kind.TRIGGER:
		if int(entry["value"]) == CardEnums.Trigger.ON_FLIP:
			return CardEffectPreview.Demo.FLIP
		return -1
	return int(DEMOS.get(int(entry["value"]), -1))


## その語を持つ砂時計。定義済みの全カードから毎回集めるため、
## カードを追加したときに辞書側を書き換える必要がない。
static func cards_with(entry: Dictionary) -> Array[CardData]:
	var found: Array[CardData] = []
	var value: int = int(entry["value"])
	var is_trigger: bool = int(entry["kind"]) == Kind.TRIGGER
	for card in CardLibrary.all_cards():
		if is_trigger:
			if _has_trigger(card, value):
				found.append(card)
		elif card.has_keyword(value):
			found.append(card)
	return found


static func _has_trigger(card: CardData, trigger: int) -> bool:
	for effect in card.effects:
		if effect != null and effect.trigger == trigger:
			return true
	return false
