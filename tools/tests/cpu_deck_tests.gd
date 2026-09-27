extends RefCounted
## CPU戦の完成したデッキの表(GameDesign.md 13章、`scripts/logic/card_cpu_decks.gd`)の
## 健全さを見張る。カードを消したり枚数の制限を変えたりしたときに、黙って別の中身へ
## すり替わるのを防ぐ(Architecture.md 8章)。

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_every_deck_resolves_without_filling()
	_test_every_deck_is_exactly_thirty_cards()
	_test_no_card_exceeds_the_copy_limit()
	_test_no_card_is_from_a_price_zero_solo_set()


func _test_every_deck_resolves_without_filling() -> void:
	for row: Dictionary in CardCpuDecks.DECKS:
		if row.has("cards"):
			for card_id: String in row["cards"] as Dictionary:
				_assert.call(
					CardLibrary.find_by_id(card_id) != null,
					"%s: card id '%s' should exist in data/cards" % [row["id"], card_id]
				)


func _test_every_deck_is_exactly_thirty_cards() -> void:
	for row: Dictionary in CardCpuDecks.DECKS:
		var deck: Array = CardCpuDecks.deck_of(str(row["id"]))
		_assert.call(
			deck.size() == MatchState.DECK_SIZE,
			(
				"%s should build exactly %d cards (got %d)"
				% [row["id"], MatchState.DECK_SIZE, deck.size()]
			)
		)


func _test_no_card_exceeds_the_copy_limit() -> void:
	for row: Dictionary in CardCpuDecks.DECKS:
		var deck: Array = CardCpuDecks.deck_of(str(row["id"]))
		var counts := {}
		for card: CardData in deck:
			counts[card.id] = int(counts.get(card.id, 0)) + 1
		for id: String in counts:
			_assert.call(
				int(counts[id]) <= CardDeckSave.COPY_LIMIT,
				(
					"%s: '%s' appears %d times (limit %d)"
					% [row["id"], id, counts[id], CardDeckSave.COPY_LIMIT]
				)
			)


## ソロモード限定のカードセット(price == 0)は通貨で買えないため、CPUに見せても
## 購入へつながらない(GameDesign.md 13章)。
func _test_no_card_is_from_a_price_zero_solo_set() -> void:
	for row: Dictionary in CardCpuDecks.DECKS:
		var deck: Array = CardCpuDecks.deck_of(str(row["id"]))
		for card: CardData in deck:
			if card.set_id.is_empty():
				continue
			_assert.call(
				CardSetLibrary.price(card.set_id) > 0,
				"%s: '%s' is from price<=0 set '%s'" % [row["id"], card.id, card.set_id]
			)
