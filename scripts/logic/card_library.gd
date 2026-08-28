class_name CardLibrary
extends RefCounted
## data/cards/ を走査してカード定義を列挙する(Autoloadを使わずstaticで持つ流儀)。

const CARDS_DIR := "res://data/cards"

static var _cache: Array[CardData] = []


## 定義済みの全カード。id順に並ぶ。
static func all_cards() -> Array[CardData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return _cache
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納されるため、除いた名前で判定する。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var card: CardData = load(CARDS_DIR + "/" + base)
		if card != null:
			_cache.append(card)
	return _cache


static func find_by_id(id: String) -> CardData:
	for card in all_cards():
		if card.id == id:
			return card
	return null


## id の配列からデッキ(CardData の配列)を復元する。
static func deck_from_ids(ids: Array) -> Array:
	var cards: Array = []
	for id in ids:
		var card := find_by_id(str(id))
		if card != null:
			cards.append(card)
	return cards


## **戻り値は `Array[String]` にすること。**`OnlineSetup.push_setup()` が
## `Array[String]` を受け取るため、untyped の `Array` を返すと実行時に型が合わず
## 関数ごと呼ばれない(対局のデッキが相手へ届かず、両者が待ち続ける)。
static func ids_from_deck(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card in cards:
		ids.append(card.id)
	return ids
