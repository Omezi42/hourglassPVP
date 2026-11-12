extends RefCounted
## カードセット「詠砂の刻」の検証。Architecture.md 10.8.7節に対応する。

const SET_ID := "chant_sand"

var _assert: Callable


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_test_scribe_grows_on_own_spell()
	_test_scribe_ignores_foe_spell()
	_test_scribe_ignores_unit_play()
	_test_scribe_broken_by_spell_does_not_react()
	_test_cpu_values_own_spell_trigger()
	_test_divine_takes_spell_from_deck()
	_test_divine_without_spells_does_nothing()
	_test_divine_is_not_a_draw()
	_test_chant_hits_foe_on_own_spell()
	_test_chant_ignores_foe_spell()
	_test_archive_recovers_chosen_spell()
	_test_archive_skips_units()
	_test_cpu_picks_spell_for_archive()
	_test_warden_raises_sand_on_own_spell()
	_test_recite_recasts_newest_spell()
	_test_recite_uses_target()
	_test_recite_needs_castable_source()
	_test_recite_counts_as_one_spell()
	_test_recite_rules_text_names_source()
	_test_cpu_aims_recite_like_source()
	_test_set_is_registered()


func _new_match(hand_ids: Array) -> MatchState:
	var deck: Array = []
	for i in MatchState.DECK_SIZE:
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 12345)
	state.current_turn = MatchState.Side.A
	var hand: Array = []
	for id in hand_ids:
		hand.append(CardLibrary.find_by_id(id))
	state.hand[MatchState.Side.A] = hand
	state.mana[MatchState.Side.A] = MatchState.MAX_MANA
	return state


func _place(state: MatchState, side: int, id: String, slot: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.summoned_this_turn = false
	state.board[side][slot] = unit
	return unit


func _test_scribe_grows_on_own_spell() -> void:
	var state := _new_match(["shot", "shot"])
	var scribe := _place(state, MatchState.Side.A, "scribe", 0)
	var before := scribe.health + scribe.attack
	state.cast_spell(MatchState.Side.A, 0)
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(scribe.health + scribe.attack == before + 2, "スクライブは自分が砂術を使うたび総量+1")


func _test_scribe_ignores_foe_spell() -> void:
	var state := _new_match([])
	var scribe := _place(state, MatchState.Side.B, "scribe", 0)
	var before := scribe.health + scribe.attack
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("shot")]
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(scribe.health + scribe.attack == before, "スクライブは相手の砂術に反応しない")


func _test_scribe_ignores_unit_play() -> void:
	var state := _new_match(["sand"])
	var scribe := _place(state, MatchState.Side.A, "scribe", 0)
	var before := scribe.health + scribe.attack
	state.play_card(MatchState.Side.A, 0, 1)
	_assert.call(scribe.health + scribe.attack == before, "スクライブは砂時計を出しても育たない")


## 自分の駒を払う砂術で払われたスクライブは、解決の後に場にいないので反応しない。
func _test_scribe_broken_by_spell_does_not_react() -> void:
	var state := _new_match(["burial"])
	_place(state, MatchState.Side.A, "scribe", 0)
	state.cast_spell(MatchState.Side.A, 0, {"side": MatchState.Side.A, "slot": 0})
	_assert.call(state.board[MatchState.Side.A][0] == null, "砂葬で払ったスクライブは場に残らない")
	var grave: Array = state.graveyard[MatchState.Side.A]
	_assert.call(
		grave.any(func(card: CardData) -> bool: return card.id == "scribe"), "払われたスクライブは墓地へ行く"
	)


func _test_cpu_values_own_spell_trigger() -> void:
	var state := _new_match([])
	var cpu := CardCpuStrategy.new()
	var scribe := CardLibrary.find_by_id("scribe")
	_assert.call(
		cpu._repeating_value(state, MatchState.Side.A, scribe) > 0.0, "CPUは自分の砂術に反応する効果に価値を見る"
	)


func _test_divine_takes_spell_from_deck() -> void:
	var state := _new_match(["divine"])
	state.deck[MatchState.Side.A][7] = CardLibrary.find_by_id("shot")
	var deck_before: int = state.deck[MatchState.Side.A].size()
	state.cast_spell(MatchState.Side.A, 0)
	var hand: Array = state.hand[MatchState.Side.A]
	_assert.call(hand.size() == 1 and hand[0].id == "shot", "砂占いは山札の砂術を手札に加える")
	_assert.call(state.deck[MatchState.Side.A].size() == deck_before - 1, "砂占いで加えた砂術は山札から抜ける")


func _test_divine_without_spells_does_nothing() -> void:
	var state := _new_match(["divine"])
	var deck_before: int = state.deck[MatchState.Side.A].size()
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(
		(
			state.hand[MatchState.Side.A].is_empty()
			and state.deck[MatchState.Side.A].size() == deck_before
		),
		"山札に砂術が無ければ砂占いは何もしない"
	)


## 「引く」ではないため、相手のドローに反応する駒(ハウンド)は働かない。
func _test_divine_is_not_a_draw() -> void:
	var state := _new_match(["divine"])
	state.deck[MatchState.Side.A][3] = CardLibrary.find_by_id("shot")
	_place(state, MatchState.Side.B, "hound", 0)
	var mine := _place(state, MatchState.Side.A, "sand", 0)
	var health_before := mine.health
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(mine.health == health_before, "砂占いは相手のドローに反応する効果(ハウンド)を起こさない")


## 何もしない砂術(山札に砂術が無いときの砂占い)を撃てば、HPの差はチャントのぶんだけになる。
func _test_chant_hits_foe_on_own_spell() -> void:
	var state := _new_match(["divine", "divine"])
	_place(state, MatchState.Side.A, "chant", 0)
	var foe_before: int = state.hp[MatchState.Side.B]
	state.cast_spell(MatchState.Side.A, 0)
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(state.hp[MatchState.Side.B] == foe_before - 2, "チャントは自分が砂術を使うたび相手に1ダメージ")


func _test_chant_ignores_foe_spell() -> void:
	var state := _new_match([])
	_place(state, MatchState.Side.B, "chant", 0)
	state.hand[MatchState.Side.A] = [CardLibrary.find_by_id("divine")]
	var hp_before: int = state.hp[MatchState.Side.A]
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(state.hp[MatchState.Side.A] == hp_before, "チャントは相手の砂術に反応しない")


func _test_archive_recovers_chosen_spell() -> void:
	var state := _new_match(["archive"])
	state.graveyard[MatchState.Side.A] = [
		CardLibrary.find_by_id("shot"),
		CardLibrary.find_by_id("sand"),
		CardLibrary.find_by_id("divine")
	]
	state.play_card(MatchState.Side.A, 0, 0, {"grave_index": 0})
	var hand: Array = state.hand[MatchState.Side.A]
	_assert.call(hand.size() == 1 and hand[0].id == "shot", "アーカイブは選んだ墓地の砂術を手札に戻す")
	_assert.call(state.graveyard[MatchState.Side.A].size() == 2, "戻した砂術は墓地から抜ける")


## 砂時計を指しても選べないので、選べる砂術(コストの高いほう)へ向け直す。
func _test_archive_skips_units() -> void:
	var state := _new_match(["archive"])
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("sand")]
	state.play_card(MatchState.Side.A, 0, 0, {"grave_index": 0})
	_assert.call(state.hand[MatchState.Side.A].is_empty(), "墓地に砂術が無ければアーカイブは何も戻さない")
	_assert.call(
		CardEffectResolver.grave_choices(state, MatchState.Side.A, true).is_empty(),
		"墓地の砂時計は砂術の選択肢に入らない"
	)


func _test_cpu_picks_spell_for_archive() -> void:
	var state := _new_match(["archive"])
	state.graveyard[MatchState.Side.A] = [
		CardLibrary.find_by_id("sand"), CardLibrary.find_by_id("divine")
	]
	var cpu := CardCpuStrategy.new()
	var hint: Dictionary = cpu._effect_target(
		state, MatchState.Side.A, CardLibrary.find_by_id("archive")
	)
	_assert.call(int(hint.get("grave_index", -1)) == 1, "CPUはアーカイブで墓地の砂術を選ぶ")


func _test_warden_raises_sand_on_own_spell() -> void:
	var state := _new_match(["shot"])
	var warden := _place(state, MatchState.Side.A, "warden", 0)
	warden.health = 3
	warden.attack = 2
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(warden.health == 4 and warden.attack == 1, "ウォーデンは自分が砂術を使うたび砂が1粒上へ戻る")
	_assert.call(warden.has_keyword(CardEnums.Keyword.GUARD), "ウォーデンは守護を持つ")


func _test_recite_recasts_newest_spell() -> void:
	var state := _new_match(["recite"])
	state.graveyard[MatchState.Side.A] = [
		CardLibrary.find_by_id("shot"),
		CardLibrary.find_by_id("divine"),
		CardLibrary.find_by_id("sand")
	]
	state.deck[MatchState.Side.A].append(CardLibrary.find_by_id("pelt"))
	var mana_before: int = state.mana[MatchState.Side.A]
	_assert.call(state.cast_spell(MatchState.Side.A, 0), "写し詠みは墓地に砂術があれば撃てる")
	var hand: Array = state.hand[MatchState.Side.A]
	_assert.call(hand.size() == 1 and hand[0].id == "pelt", "写し詠みは墓地でいちばん新しい砂術(砂占い)を撃ち直す")
	_assert.call(state.mana[MatchState.Side.A] == mana_before - 2, "撃ち直す砂術のコストは払わない")
	var grave: Array = state.graveyard[MatchState.Side.A]
	_assert.call(grave.size() == 4 and grave[1].id == "divine", "撃ち直した砂術は墓地に残ったまま")


func _test_recite_uses_target() -> void:
	var state := _new_match(["recite", "recite"])
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("shatter")]
	var foe := _place(state, MatchState.Side.B, "sand", 1)
	var before := foe.health
	state.cast_spell(MatchState.Side.A, 0, {"side": MatchState.Side.B, "slot": 1})
	_assert.call(foe.health == before - 4 or foe.is_dead(), "写し詠みは選んだ対象へ撃ち直す")
	_assert.call(state.can_cast(MatchState.Side.A, 0), "墓地の写し詠みは飛ばして、その前の砂術を撃ち直せる")


func _test_recite_needs_castable_source() -> void:
	var state := _new_match(["recite"])
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("sand")]
	_assert.call(not state.can_cast(MatchState.Side.A, 0), "墓地に砂術が無ければ写し詠みは撃てない")
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("burial")]
	_assert.call(not state.can_cast(MatchState.Side.A, 0), "撃ち直す砂術の撃つ条件を満たさなければ写し詠みは撃てない")
	_place(state, MatchState.Side.A, "sand", 0)
	_assert.call(state.can_cast(MatchState.Side.A, 0), "撃ち直す砂術の条件を満たせば撃てる")


func _test_recite_counts_as_one_spell() -> void:
	var state := _new_match(["recite"])
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("divine")]
	_place(state, MatchState.Side.A, "chant", 0)
	var foe_before: int = state.hp[MatchState.Side.B]
	state.cast_spell(MatchState.Side.A, 0)
	_assert.call(state.hp[MatchState.Side.B] == foe_before - 1, "撃ち直しは「砂術を使う」に数えない")


func _test_recite_rules_text_names_source() -> void:
	var state := _new_match(["recite"])
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("shot")]
	var text := CardEffectResolver.live_rules_text(
		state, MatchState.Side.A, CardLibrary.find_by_id("recite")
	)
	_assert.call(text.ends_with("(いま撃ち直すのはサンドショット)"), "写し詠みの文はいま撃ち直す砂術を添える")


func _test_cpu_aims_recite_like_source() -> void:
	var state := _new_match(["recite"])
	state.graveyard[MatchState.Side.A] = [CardLibrary.find_by_id("shatter")]
	_place(state, MatchState.Side.B, "sand", 2)
	var cpu := CardCpuStrategy.new()
	var hint: Dictionary = cpu._effect_target(
		state, MatchState.Side.A, CardLibrary.find_by_id("recite")
	)
	_assert.call(int(hint.get("slot", -1)) == 2, "CPUは写し詠みを撃ち直す砂術と同じく狙う")


func _test_set_is_registered() -> void:
	_assert.call(CardSetLibrary.has_set(SET_ID), "詠砂の刻が登録されている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("scribe"), "スクライブが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("divine"), "砂占いが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("chant"), "チャントが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("archive"), "アーカイブが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.card_ids(SET_ID).has("recite"), "写し詠みが詠砂の刻に入っている")
	_assert.call(CardSetLibrary.planned_count(SET_ID) == 8, "詠砂の刻は予定8枚")
	_assert.call(CardEnums.trigger_name(CardEnums.Trigger.ON_OWN_SPELL) == "常在", "砂術への反応は「常在」と出す")
