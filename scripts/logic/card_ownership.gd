class_name CardOwnership
extends RefCounted
## カードの所持数とデッキへ入れられる枚数(GameDesign.md 8章 / Architecture.md 10.8.1節)。
## `players/{uid}` のフィールド(`card_counts` / `owned_card_sets`)を受け取る純関数だけを持つ。
## `AccountService` のキャッシュからも、書き込み直前に読んだ生のフィールドからも同じ物差しで数えるため。

## レジェンドは同名1枚までしか入れられない。
const LEGENDARY_LIMIT := 1


## 所持数の上限(これを超えて出たぶんは砂粒へ変わる)。レジェンドだけ1、ほかは同名2枚まで。
## 基本セット(`set_id` が空)のカードはレアリティを読まない。
static func cap(card: CardData) -> int:
	if not card.set_id.is_empty() and card.rarity == CardEnums.Rarity.LEGENDARY:
		return LEGENDARY_LIMIT
	return CardDeckSave.COPY_LIMIT


## 所持数。保存された値と「そのカードのセットを持っていれば2」の大きいほうを返す。
## 基本セットは常に2枚持つ。**前にセットを買った人の移行は書き込みではなく、ここで読むときに行う。**
static func count_in(fields: Dictionary, card: CardData) -> int:
	if card.set_id.is_empty():
		return CardDeckSave.COPY_LIMIT
	var counts: Variant = fields.get("card_counts", {})
	var stored := int((counts as Dictionary).get(card.id, 0)) if counts is Dictionary else 0
	var sets: Variant = fields.get("owned_card_sets", [])
	# 移行の対象は旧セットにあった52枚。後から足すレジェンドは、旧セットを買った人にも渡さない。
	var migratable := card.rarity != CardEnums.Rarity.LEGENDARY
	var migrated := (
		CardDeckSave.COPY_LIMIT
		if migratable and sets is Array and (sets as Array).has(card.set_id)
		else 0
	)
	return maxi(stored, migrated)


## デッキへ入れられる枚数 = min(上限, 所持数)。デッキ編集の検証と保存デッキの検査が使う。
static func deck_limit_in(fields: Dictionary, card: CardData) -> int:
	return mini(cap(card), count_in(fields, card))
