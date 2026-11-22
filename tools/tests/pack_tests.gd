extends RefCounted
## 弾とパック(GameDesign.md 8章・15章・21章 / Architecture.md 10.8.1節)。
## レアリティの割り振り・確率表・抽選・天井・上限超えの砂粒・既購入者の2枚扱い・デッキの枚数上限。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const UID := "uid-pack-tests"
const PACK_ID := "first"
const SEED := 20261122
const DRAWS := 3000
const BALANCE := 5000
const SYNTHETIC_LEGENDARY_ID := "__legend"
const BOUGHT_SETS := [
	"combo_five", "still_time", "grave_sand", "echo_time", "chase_sand", "sweep_sand", "chant_sand"
]

var _assert: Callable
var _client: FirestoreClient
var _path := AccountService.path(UID)
var _pack: PackDefinition


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_pack = PackDefinition.load_pack(PACK_ID)
	_assert.call(_pack != null, "first pack should load")
	if _pack == null:
		return
	_test_rarity_assignment()
	_test_tables()
	_test_draw()
	_test_pity()
	_test_ownership()
	var auth := FirebaseAuth.new(null)
	auth.uid = UID
	_client = FakeClient.new(auth)
	(Engine.get_main_loop() as SceneTree).root.add_child(_client)
	await _test_open_packs()
	await _test_free_pack()
	await _test_overflow_dust()
	await _test_craft()
	_client.queue_free()
	AccountService.reset()


func _reset(fields: Dictionary) -> void:
	AccountService.reset()
	_client.store.clear()
	_client.commit_count = 0
	_client.fail_reads = 0
	_client.store[_path] = {"fields": fields, "update_time": "t0"}


func _fields() -> Dictionary:
	return _client.store[_path]["fields"]


func _test_rarity_assignment() -> void:
	var counts := {}
	for set_id in _pack.set_ids:
		for id in CardSetLibrary.card_ids(set_id):
			var card := CardLibrary.find_by_id(id)
			counts[card.rarity] = int(counts.get(card.rarity, 0)) + 1
	_assert.call(counts.get(CardEnums.Rarity.COMMON, 0) == 24, "first pack has 24 commons")
	_assert.call(counts.get(CardEnums.Rarity.RARE, 0) == 18, "first pack has 18 rares")
	_assert.call(counts.get(CardEnums.Rarity.EPIC, 0) == 10, "first pack has 10 epics")
	var spot := {
		"middle": CardEnums.Rarity.COMMON,
		"phase": CardEnums.Rarity.RARE,
		"crest": CardEnums.Rarity.EPIC,
	}
	for id in spot:
		_assert.call(CardLibrary.find_by_id(id).rarity == spot[id], "rarity of %s" % id)


func _test_tables() -> void:
	for rates: Array[float] in [_pack.slot_rates, _pack.last_slot_rates]:
		var sum := 0.0
		for rate in rates:
			sum += rate
		_assert.call(is_equal_approx(sum, 1.0), "slot rates should sum to 1")
	_assert.call(_pack.last_slot_rates[CardEnums.Rarity.COMMON] == 0.0, "last slot has no commons")
	_assert.call(
		_pack.price == 100 and _pack.cards_per_pack == 5 and _pack.pity_packs == 40,
		"pack constants"
	)
	var table := RarityTable.get_table()
	_assert.call(table.gain_of(CardEnums.Rarity.EPIC) == 100, "epic dust gain")
	_assert.call(table.cost_of(CardEnums.Rarity.LEGENDARY) == 1600, "legendary craft cost")
	_assert.call(table.cost_of(CardEnums.Rarity.COMMON) == 40, "common craft cost")


func _test_draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pools := PackDraw.pool_by_rarity(_pack)
	var published := 0
	for rarity in pools:
		published += (pools[rarity] as Array).size()
	_assert.call(published == 52, "pool holds the 52 published cards")
	var first_slots := {}
	for _i in DRAWS:
		var result := PackDraw.draw_pack(_pack, pools, 0, rng)
		var cards: Array = result["cards"]
		_assert.call(cards.size() == 5, "a pack has 5 cards")
		_assert.call(
			(cards[4] as CardData).rarity != CardEnums.Rarity.COMMON, "last slot is rare or better"
		)
		for slot in 4:
			var r: CardEnums.Rarity = (cards[slot] as CardData).rarity
			first_slots[r] = int(first_slots.get(r, 0)) + 1
		_assert.call(int(result["pity"]) == 1, "pity grows without a legendary")
	var common_share: float = first_slots[CardEnums.Rarity.COMMON] / float(DRAWS * 4)
	_assert.call(
		absf(common_share - 0.76 / 0.995) < 0.03, "commons dominate slots 1-4 (%f)" % common_share
	)
	_assert.call(
		not first_slots.has(CardEnums.Rarity.LEGENDARY), "unpublished legendaries never come out"
	)


func _synthetic_pools() -> Dictionary:
	var pools := PackDraw.pool_by_rarity(_pack)
	(pools[CardEnums.Rarity.LEGENDARY] as Array).append(_synthetic_legend())
	return pools


func _synthetic_legend() -> CardData:
	var legend := CardData.new()
	legend.id = SYNTHETIC_LEGENDARY_ID
	legend.set_id = "combo_five"
	legend.rarity = CardEnums.Rarity.LEGENDARY
	return legend


func _test_pity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pools := _synthetic_pools()
	for _i in 200:
		var forced := PackDraw.draw_pack(_pack, pools, _pack.pity_packs - 1, rng)
		var cards: Array = forced["cards"]
		_assert.call(
			(cards[4] as CardData).rarity == CardEnums.Rarity.LEGENDARY, "pity forces the last slot"
		)
		_assert.call(int(forced["pity"]) == 0, "pity resets after a legendary")
	var pity := 0
	for _i in 2000:
		pity = int(PackDraw.draw_pack(_pack, pools, pity, rng)["pity"])
		_assert.call(pity < _pack.pity_packs, "the counter never passes the ceiling")
	_assert.call(PackDraw.packs_until_pity(_pack, 28) == 12, "12 packs left at 28")
	_assert.call(PackDraw.packs_until_pity(_pack, 39) == 1, "the 40th pack is the sure one")


func _test_ownership() -> void:
	var middle := CardLibrary.find_by_id("middle")
	var base := CardLibrary.find_by_id("sand")
	_assert.call(base != null and base.set_id.is_empty(), "sand is a base set card")
	_assert.call(CardOwnership.count_in({}, base) == 2, "base set cards are always held twice")
	_assert.call(CardOwnership.count_in({}, middle) == 0, "an unopened pack card is held zero")
	var bought := {"owned_card_sets": ["combo_five"]}
	_assert.call(CardOwnership.count_in(bought, middle) == 2, "a bought set counts as two")
	bought["card_counts"] = {"middle": 1}
	_assert.call(CardOwnership.count_in(bought, middle) == 2, "the larger of stored and migrated")
	_assert.call(
		CardOwnership.count_in({"card_counts": {"middle": 1}}, middle) == 1, "stored count"
	)
	_assert.call(
		CardOwnership.count_in({"owned_card_sets": ["combo_five"]}, _synthetic_legend()) == 0,
		"a bought set does not hand out its later legendary"
	)
	var fields := {"card_counts": {SYNTHETIC_LEGENDARY_ID: 2}}
	_assert.call(
		CardOwnership.deck_limit_in(fields, _synthetic_legend()) == 1,
		"legendaries are limited to one"
	)
	_assert.call(
		CardOwnership.deck_limit_in({"card_counts": {"middle": 1}}, middle) == 1,
		"limit follows holdings"
	)
	_assert.call(CardOwnership.deck_limit_in({}, middle) == 0, "unheld cards are not deck cards")

	AccountService.reset()
	AccountService.apply_local_fields(
		{"owned_card_sets": ["still_time"], "card_counts": {"phase": 1}}
	)
	_assert.call(AccountService.card_count("freeze") == 2, "AccountService migrates bought sets")
	_assert.call(AccountService.card_count("phase") == 1, "AccountService reads card_counts")
	_assert.call(AccountService.card_count("crest") == 0, "AccountService: unowned is zero")
	_assert.call(AccountService.card_count("__nothing") == 0, "AccountService: unknown id is zero")
	var collected_before := AccountService.collected_card_counts().x
	AccountService.apply_local_fields(
		{"owned_card_sets": ["still_time"], "card_counts": {"phase": 1, "crest": 1}}
	)
	_assert.call(
		AccountService.collected_card_counts().x == collected_before + 1,
		"a single pulled card counts as collected without owning its set"
	)
	AccountService.apply_local_fields(
		{"owned_card_sets": ["still_time"], "card_counts": {"phase": 1}}
	)
	_assert.call(not CardDeckSave.within_limit([middle]), "an unheld card is over the limit")
	var phase := CardLibrary.find_by_id("phase")
	_assert.call(
		CardDeckSave.shortage([phase, phase, middle]) == 2,
		"shortage counts every card over the limit"
	)
	var freeze := CardLibrary.find_by_id("freeze")
	_assert.call(CardDeckSave.within_limit([freeze, freeze]), "bought set cards go in twice")
	_assert.call(
		(
			CardDeckSave.within_limit([base, base])
			and not CardDeckSave.within_limit([base, base, base])
		),
		"the copy limit stays two"
	)
	AccountService.reset()


func _test_open_packs() -> void:
	_reset({"currency": BALANCE})
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var result: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, false, rng)
	_assert.call(result["ok"], "opening a pack should work")
	_assert.call(_client.commit_count == 1, "one pack is one commit")
	_assert.call(int(_fields()["currency"]) == BALANCE - 100, "a pack costs 100")
	var held := 0
	for id in _fields()["card_counts"]:
		held += int(_fields()["card_counts"][id])
	var dust := int(result["dust_gained"])
	_assert.call(held + _overflow_cards(result) == 5, "five cards were drawn")
	_assert.call(dust >= 0, "dust never goes negative")
	_assert.call(int(_fields()["pack_pity"][PACK_ID]) == 1, "pity advanced")
	_assert.call(AccountService.currency() == BALANCE - 100, "the cache follows the write")

	_client.commit_count = 0
	var bulk: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 10, false, rng)
	_assert.call(bulk["ok"] and (bulk["packs"] as Array).size() == 10, "ten packs open")
	_assert.call(_client.commit_count == 1, "ten packs are still one commit")
	_assert.call(int(_fields()["currency"]) == BALANCE - 1100, "ten packs cost 1000")
	_assert.call(int(_fields()["pack_pity"][PACK_ID]) == 11, "pity counts every pack")

	_reset({"currency": 99})
	var poor: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, false, rng)
	_assert.call(not poor["ok"] and _client.commit_count == 0, "short balance writes nothing")
	var bad: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 3, false, rng)
	_assert.call(not bad["ok"], "only 1 or 10 packs")
	_reset({"currency": BALANCE})
	_client.fail_reads = 1
	var offline: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, false, rng)
	_assert.call(not offline["ok"] and _client.commit_count == 0, "a failed read writes nothing")


func _overflow_cards(result: Dictionary) -> int:
	var over := 0
	for pack: Dictionary in result["packs"]:
		for flag: bool in pack["overflow"]:
			if flag:
				over += 1
	return over


func _test_free_pack() -> void:
	_reset({"currency": 0})
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_assert.call(AccountService.free_pack_available(), "the free pack is open at first")
	var first: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, true, rng)
	_assert.call(first["ok"], "the free pack opens with zero balance")
	_assert.call(int(_fields()["currency"]) == 0, "the free pack costs nothing")
	_assert.call(str(_fields()["free_pack_date"]) == DailyMissionService.today(), "date recorded")
	_assert.call(not AccountService.free_pack_available(), "only one free pack a day")
	var second: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, true, rng)
	_assert.call(not second["ok"], "a second free pack the same day fails")
	var bulk_free: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 10, true, rng)
	_assert.call(not bulk_free["ok"], "the free pack is a single pack")


func _test_overflow_dust() -> void:
	var counts := {}
	for set_id in _pack.set_ids:
		for id in CardSetLibrary.card_ids(set_id):
			counts[id] = 2
	_reset({"currency": BALANCE, "card_counts": counts, "sand_dust": 7})
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var result: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, false, rng)
	_assert.call(result["ok"], "overflow pack opens")
	var expected := 0
	var table := RarityTable.get_table()
	for id: String in result["packs"][0]["cards"]:
		expected += table.gain_of(CardLibrary.find_by_id(id).rarity)
	_assert.call(int(result["dust_gained"]) == expected and expected > 0, "dust matches rarity")
	_assert.call(int(_fields()["sand_dust"]) == 7 + expected, "dust is saved")
	for id in counts:
		_assert.call(int(_fields()["card_counts"][id]) == 2, "counts stay at the cap")
	_assert.call(AccountService.sand_dust() == 7 + expected, "dust cache follows")

	# 前にセットを買った人は所持数を書かなくても2枚持つ扱いなので、そのセットのカードは全部あふれる
	_reset({"currency": BALANCE, "owned_card_sets": BOUGHT_SETS.duplicate()})
	var migrated: Dictionary = await PackService.open_packs(_client, UID, PACK_ID, 1, false, rng)
	var every: Array = migrated["packs"][0]["overflow"]
	_assert.call(not every.has(false), "bought sets already hold two of every card")
	_assert.call((_fields()["card_counts"] as Dictionary).is_empty(), "migration writes no counts")


func _test_craft() -> void:
	_reset({"currency": 0, "sand_dust": 150})
	var result: Dictionary = await PackService.craft(_client, UID, "middle")
	_assert.call(result["ok"], "crafting a common costs 40")
	_assert.call(int(_fields()["sand_dust"]) == 110, "dust spent")
	_assert.call(int(_fields()["card_counts"]["middle"]) == 1, "count added")
	await PackService.craft(_client, UID, "middle")
	var capped: Dictionary = await PackService.craft(_client, UID, "middle")
	_assert.call(not capped["ok"], "no crafting past the cap")
	_assert.call(int(_fields()["sand_dust"]) == 70, "a refused craft keeps the dust")
	var rare: Dictionary = await PackService.craft(_client, UID, "phase")
	_assert.call(not rare["ok"] and int(_fields()["sand_dust"]) == 70, "short dust refuses a rare")
	var unreleased: Dictionary = await PackService.craft(_client, UID, "present")
	_assert.call(not unreleased["ok"], "cards outside the pack cannot be crafted")
	var missing: Dictionary = await PackService.craft(_client, UID, "__none")
	_assert.call(not missing["ok"], "unknown cards cannot be crafted")
