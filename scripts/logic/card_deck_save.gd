class_name CardDeckSave
extends RefCounted
## v5.0のデッキ(20枚・同名2枚まで)の保存(`DeckSave` と同じ「Autoloadを使わずstaticで
## 持つ」流儀)。v1.0の5枚デッキとは形式が違うため、保存先のファイルを分けている。

const SAVE_PATH := "user://card_decks.json"
const COPY_LIMIT := 2


## 保存済みのデッキ(CardData の配列)。1つも無ければ既定のデッキを組んで返す。
static func load_deck() -> Array:
	var ids := _load_ids()
	var deck := CardLibrary.deck_from_ids(ids)
	if deck.size() == MatchState.DECK_SIZE:
		return deck
	# デッキを保存していないプレイヤーはプリセットの「基本」で対局へ入る
	# (GameDesign.md 18章)。これまでも既定のデッキで入れていたが、中身が画面に
	# 出ておらず、何を使っているのか分からなかった。
	return CardPresetDecks.basic()


static func save_deck(cards: Array) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"deck": CardLibrary.ids_from_deck(cards)}))


## デッキがまだ無いときに使う既定のデッキ。マナカーブが偏らないよう、
## コストの安い順に10種を選んで2枚ずつ入れる。
static func default_deck() -> Array:
	var pool := CardLibrary.all_cards().duplicate()
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	var deck: Array = []
	for card in pool:
		if deck.size() >= MatchState.DECK_SIZE:
			break
		for i in COPY_LIMIT:
			deck.append(card)
	return deck


## ランダムな混成デッキ(CPUの相手用)。同名2枚までの制限を守る。
static func random_deck(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for card in CardLibrary.all_cards():
		for i in COPY_LIMIT:
			pool.append(card)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, MatchState.DECK_SIZE)


static func _load_ids() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var ids: Variant = (parsed as Dictionary).get("deck", [])
	return ids if typeof(ids) == TYPE_ARRAY else []
