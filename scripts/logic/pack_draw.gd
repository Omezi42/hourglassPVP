class_name PackDraw
extends RefCounted
## パックの抽選(GameDesign.md 21章)。通信も保存も持たない純関数。乱数は呼び出し側から受け取る。
## 確率・天井は `PackDefinition` が持ち、ここへは書かない。


## 弾の公開済みカードをレアリティ別に並べる。キーは `CardEnums.Rarity`、値は `CardData` の配列。
## 公開済みのカード(`CardSetLibrary.card_ids`)だけが対象で、未公開は出ない。
static func pool_by_rarity(pack: PackDefinition) -> Dictionary:
	var pools := {}
	for rarity in CardEnums.Rarity.values():
		pools[rarity] = []
	for set_id in pack.set_ids:
		for card_id in CardSetLibrary.card_ids(set_id):
			var card := CardLibrary.find_by_id(card_id)
			if card != null:
				(pools[card.rarity] as Array).append(card)
	return pools


## 1パック(`pack.cards_per_pack` 枚)を引く。`pity` はレジェンドが出ないまま開けたパック数。
## 戻り値: {"cards": Array[CardData], "pity": 引いた後の天井カウンタ}
static func draw_pack(
	pack: PackDefinition, pools: Dictionary, pity: int, rng: RandomNumberGenerator
) -> Dictionary:
	var cards: Array[CardData] = []
	var got_legendary := false
	for slot in pack.cards_per_pack:
		var last := slot == pack.cards_per_pack - 1
		var rarity := _roll_rarity(pack, pools, last, pity, rng)
		var pool: Array = pools[rarity]
		var card: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		cards.append(card)
		if rarity == CardEnums.Rarity.LEGENDARY:
			got_legendary = true
	return {"cards": cards, "pity": 0 if got_legendary else pity + 1}


## 天井まであと何パックか(「レジェンド確定まで あと12パック」)。確定するパックを含めて数える。
static func packs_until_pity(pack: PackDefinition, pity: int) -> int:
	return maxi(pack.pity_packs - pity, 1)


static func _roll_rarity(
	pack: PackDefinition, pools: Dictionary, last: bool, pity: int, rng: RandomNumberGenerator
) -> CardEnums.Rarity:
	var legendary_pool: Array = pools[CardEnums.Rarity.LEGENDARY]
	if last and pity >= pack.pity_packs - 1 and not legendary_pool.is_empty():
		return CardEnums.Rarity.LEGENDARY
	# 公開済みのカードが無いレアリティは外し、残りの確率を按分し直す(未公開のレジェンドを引かないため)。
	var total := 0.0
	for rarity in CardEnums.Rarity.values():
		if not (pools[rarity] as Array).is_empty():
			total += pack.rate(rarity, last)
	var roll := rng.randf() * total
	var chosen := CardEnums.Rarity.COMMON
	for rarity: CardEnums.Rarity in CardEnums.Rarity.values():
		if (pools[rarity] as Array).is_empty():
			continue
		var rate := pack.rate(rarity, last)
		if rate <= 0.0:
			continue
		chosen = rarity
		roll -= rate
		if roll < 0.0:
			break
	return chosen
