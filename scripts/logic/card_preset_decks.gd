class_name CardPresetDecks
extends RefCounted
## 構築せずに遊べるプリセットデッキ(GameDesign.md 18章)。
## `CardDeckSave` と同じ「Autoloadを使わずstaticで持つ」流儀。
##
## **カードのidと枚数だけを表として持つ**。カードを増やしたときにここを書き換える必要は
## 無いが、書き換えれば新しいカードをプリセットへ入れられる。20枚に足りない場合は
## コストの安い順に埋めるため、**表が古くなっても対局に入れなくなることはない**。

const PRESETS: Array[Dictionary] = [
	{
		"id": "basic",
		"name": "基本",
		"summary": "軽いカードを中心に、砂の進み方と相打ちを素直に体験する",
		"cards":
		{
			"grain": 2,
			"sand": 2,
			"shield": 2,
			"dash": 2,
			"glass": 2,
			"drill": 2,
			"sword": 2,
			"lock": 2,
			"twin": 2,
			"wall": 2,
		},
	},
	{
		"id": "rush",
		"name": "速攻",
		"summary": "速落と貫通で早く殴りきる",
		"cards":
		{
			"grain": 2,
			"dash": 2,
			"sand": 2,
			"drill": 2,
			"sword": 2,
			"vamp": 2,
			"lance": 2,
			"twin": 2,
			"swarm": 2,
			"echo": 2,
		},
	},
	{
		"id": "heavy",
		"name": "重厚",
		"summary": "守護と大型で受け止め、盤面を残して勝つ",
		"cards":
		{
			"shield": 2,
			"glass": 2,
			"lock": 2,
			"hammer": 2,
			"guard": 2,
			"mirror": 2,
			"poison": 2,
			"glow": 2,
			"sweep": 2,
			"wall": 2,
		},
	},
]


## 既定として使うプリセット(デッキを保存していないプレイヤー・誘導対局)。
static func basic() -> Array:
	return deck_of("basic")


## id からデッキ(CardData を20枚)を組む。足りない分はコストの安い順に補う。
static func deck_of(preset_id: String) -> Array:
	for preset in PRESETS:
		if preset["id"] == preset_id:
			return _build(preset["cards"])
	return CardDeckSave.default_deck()


static func _build(counts: Dictionary) -> Array:
	var deck: Array = []
	for card_id: String in counts:
		var card := CardLibrary.find_by_id(card_id)
		if card == null:
			continue
		for i in int(counts[card_id]):
			if deck.size() < MatchState.DECK_SIZE:
				deck.append(card)
	if deck.size() < MatchState.DECK_SIZE:
		deck = _fill(deck)
	return deck


## 表に載っているカードが減った場合の保険。同名2枚の制限を守って安い順に埋める。
static func _fill(deck: Array) -> Array:
	var pool := CardLibrary.all_cards().duplicate()
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	for card: CardData in pool:
		while deck.size() < MatchState.DECK_SIZE and deck.count(card) < CardDeckSave.COPY_LIMIT:
			deck.append(card)
		if deck.size() >= MatchState.DECK_SIZE:
			break
	return deck
