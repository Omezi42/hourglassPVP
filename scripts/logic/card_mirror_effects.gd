class_name CardMirrorEffects
extends RefCounted
## 第3弾「写し身の刻」の固有効果(GameDesign.md 6章「写しを出す効果・変える効果」)。
## 写しを出す・他のカードに化ける・語と効果を写し取る・別のトークンへ置き換える。
## 写しは `CardInstance.copy_of` が写し元のカードを持ち、`data` は総量だけ違うトークン(`token_card()`)になる。
## トークンなので墓地に積もっても蘇生・回収の対象にならず、手札へ戻すと消える。

const TYPES := [
	CardEnums.EffectType.COPY_UNIT,
	CardEnums.EffectType.COPY_UNIT_HALF,
	CardEnums.EffectType.MIMIC_UNIT,
	CardEnums.EffectType.COPY_FOE_TRAITS,
	CardEnums.EffectType.REPLACE_WITH_TOKEN,
]
## 写し取った効果を札の文の末尾へ足すときの見出し。
const COPIED_NOTE := "写し取った効果:%s"
## CPUの見積もり。写し・化けた駒を、生涯ダメージの何倍で数えるか。砕けたときに働く写しは起きるとは限らないため割り引く。
const COPY_FACTOR := 1.0
const DEATH_FACTOR := 0.6
## 写し取った語・効果1つの値打ち。
const TRAIT_VALUE := 2.0
## 砕けたときに出る写しの総量の見込み(値が決まっていない写し元の総量を見るときは使わない)。
const DEFAULT_COPY_TOTAL := 1

## 写し元ごとの総量違いのトークン。データは変わらないので対局をまたいで持つ。
static var _tokens: Dictionary = {}

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 駒が何のカードの写しか・何のカードか(写しなら写し元、そうでなければ見た目のカード)。写される・化けられる元。
static func source_card(unit: CardInstance) -> CardData:
	return unit.data if unit.copy_of == null else unit.copy_of


## 砕けたとき墓地へ、手札へ戻すとき手札へ行くカード(ミミックは化ける前の本当のカード)。
static func card_of(unit: CardInstance) -> CardData:
	return unit.data if unit.origin_card == null else unit.origin_card


## source と同じカードで、総量が total・砂がすべて上のトークン。
static func token_card(source: CardData, total: int) -> CardData:
	var key := "%s:%d" % [source.id, total]
	if not _tokens.has(key):
		var token: CardData = source.duplicate()
		token.is_token = true
		token.total_sand = total
		token.initial_attack = 0
		_tokens[key] = token
	return _tokens[key]


## 撃てる砂術か。写し砂・パラレルは自分の駒と空き枠が要り、砂人形は相手の駒が要る。
static func castable(state: MatchState, side: int, effect: CardEffectData) -> bool:
	match effect.effect_type:
		CardEnums.EffectType.COPY_UNIT, CardEnums.EffectType.COPY_UNIT_HALF:
			if effect.target == CardEnums.EffectTarget.SELF:
				return true
			return not state.units(side).is_empty() and not state.empty_slots(side).is_empty()
		CardEnums.EffectType.REPLACE_WITH_TOKEN:
			return not state.units(MatchState.other_side(side)).is_empty()
	return true


## 写しを自分の空き枠の左へ出す。出せたら枠を返す(空き枠が無い・写せないなら -1)。設置効果は働かないが、出た駒としては数える。
## total が0以下なら写し元のカードの総量。
func place_copy(side: int, source: CardData, total: int, by_doppel := false) -> int:
	if source == null or source.is_spell:
		return -1
	var slot := _resolver._first_empty_slot(side)
	if slot < 0:
		return -1
	var copy := CardInstance.new(token_card(source, total if total > 0 else source.total_sand))
	copy.copy_of = source
	copy.doppel_made = by_doppel
	_state.board[side][slot] = copy
	_state.board_changed.emit(side)
	CardPourSandEffects.fire_entered(_state, side, slot)
	return slot


func apply(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	match effect.effect_type:
		CardEnums.EffectType.COPY_UNIT, CardEnums.EffectType.COPY_UNIT_HALF:
			_copy(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.MIMIC_UNIT:
			_mimic(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.COPY_FOE_TRAITS:
			_copy_traits(side, unit, effect, hint, from_slot, origin)
		CardEnums.EffectType.REPLACE_WITH_TOKEN:
			_replace(side, unit, effect, hint, from_slot, origin)


## 写す駒のカード。全体なら左から、単体なら1枚。
func _sources(
	side: int, unit: CardInstance, effect: CardEffectData, hint: Dictionary
) -> Array[CardData]:
	var found: Array[CardData] = []
	match effect.target:
		CardEnums.EffectTarget.SELF:
			found.append(source_card(unit))
		CardEnums.EffectTarget.SLAYER:
			if unit.slain_by != null:
				found.append(unit.slain_by)
		CardEnums.EffectTarget.ENTERING_FOE_UNIT:
			var entered := _entered_foe(hint)
			if entered != null and not entered.is_dead() and not entered.doppel_made:
				found.append(source_card(entered))
		_:
			for entry in _live_entries(_resolver._targets(side, unit, effect, hint)):
				found.append(source_card(_resolver._unit_at(entry)))
				if effect.target != CardEnums.EffectTarget.ALL_ALLY_UNITS:
					break
	return found


func _entered_foe(hint: Dictionary) -> CardInstance:
	var entered_side: int = hint.get("entered_side", -1)
	var entered_slot: int = hint.get("entered_slot", -1)
	if entered_side < 0 or entered_slot < 0:
		return null
	return _state.board[entered_side][entered_slot]


func _live_entries(entries: Array) -> Array:
	return entries.filter(
		func(entry: Dictionary) -> bool: return not _resolver._unit_at(entry).is_dead()
	)


func _copy(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var half := effect.effect_type == CardEnums.EffectType.COPY_UNIT_HALF
	var by_doppel := effect.target == CardEnums.EffectTarget.ENTERING_FOE_UNIT
	for source in _sources(side, unit, effect, hint):
		var slot := _resolver._first_empty_slot(side)
		if slot < 0:
			return
		_resolver._strike(side, from_slot, side, slot, CardEnums.EffectVisualStyle.DESCEND, origin)
		var total := ceili(source.total_sand / 2.0) if half else effect.value
		place_copy(side, source, total, by_doppel)


## 選んだ相手の駒のカードの総量・語・効果になる。砂はすべて上から。化ける前のカードは墓地・手札へ行くために持っておく。
func _mimic(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _live_entries(_resolver._targets(side, unit, effect, hint))
	if entries.is_empty() or unit.is_dead():
		return
	var foe_entry: Dictionary = entries[0]
	var source := source_card(_resolver._unit_at(foe_entry))
	_resolver._strike(
		side,
		from_slot,
		foe_entry["side"],
		foe_entry["slot"],
		CardEnums.EffectVisualStyle.SPIN,
		origin
	)
	if unit.origin_card == null:
		unit.origin_card = unit.data
	unit.data = source
	unit.health = source.total_sand
	unit.attack = 0
	unit.glass_intact = source.has_keyword(CardEnums.Keyword.GLASS)
	_state.board_changed.emit(side)


## 相手の駒の語と効果(設置を除く)を、与えられたものとして足す。沈黙で消える。
func _copy_traits(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _live_entries(_resolver._targets(side, unit, effect, hint))
	if entries.is_empty() or unit.is_dead():
		return
	var foe_entry: Dictionary = entries[0]
	var foe := _resolver._unit_at(foe_entry)
	_resolver._strike(
		side,
		from_slot,
		foe_entry["side"],
		foe_entry["slot"],
		CardEnums.EffectVisualStyle.DRAIN,
		origin
	)
	for keyword in foe.keywords():
		unit.grant_keyword(keyword)
	var noted := false
	for trigger in CardEnums.Trigger.values():
		if trigger == CardEnums.Trigger.ON_PLAY:
			continue
		for copied in foe.effects_for(trigger):
			var granted: CardEffectData = copied.duplicate()
			if granted.shown_text.is_empty() and not noted:
				granted.shown_text = COPIED_NOTE % source_card(foe).rules_text
				noted = true
			unit.grant_effect(granted)
	_state.board_changed.emit(side)


## 相手の駒を card_id のカードの総量 value のトークンに置き換える。破壊ではないため余砂は働かず、墓地にも積もらない。
func _replace(
	side: int,
	unit: CardInstance,
	effect: CardEffectData,
	hint: Dictionary,
	from_slot: int,
	origin: int
) -> void:
	var entries := _live_entries(_resolver._targets(side, unit, effect, hint))
	var source := CardLibrary.find_by_id(effect.card_id)
	if entries.is_empty() or source == null:
		return
	var entry: Dictionary = entries[0]
	_resolver._strike(
		side, from_slot, entry["side"], entry["slot"], CardEnums.EffectVisualStyle.SPIN, origin
	)
	_state.board[entry["side"]][entry["slot"]] = CardInstance.new(
		token_card(source, maxi(effect.value, 1))
	)
	_state.board_changed.emit(entry["side"])
	_state.board_changed.emit(MatchState.other_side(entry["side"]))


## 戦闘で砕かれたほうが、砕いた駒のカードを覚える(シェードが余砂で写す)。
static func note_slayers(attacker: CardInstance, defender: CardInstance) -> void:
	if defender.is_dead():
		defender.slain_by = source_card(attacker)
	if attacker.is_dead():
		attacker.slain_by = source_card(defender)


## 写しを出す生涯ダメージの見込み。砂がすべて上から始まる総量 total の駒。
static func copy_lifetime(total: int) -> float:
	return CardCpuStrategy.lifetime_of(total, 0)


## 砕けたときに写しを出す効果(ポートレイト・ドール・シェード)と、出たときに自分の写しを出す効果(ツインズ)の、CPUの見積もり。
## 設置の効果は `cpu_value()` では写し元のカードが分からないため、カードごと見る。
static func cpu_card_value(state: MatchState, side: int, card: CardData) -> float:
	var value := 0.0
	if state.empty_slots(side).size() > 1:
		for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
			if _is_copy(effect) and effect.target == CardEnums.EffectTarget.SELF:
				value += copy_lifetime(_copy_total(effect, card.total_sand)) * COPY_FACTOR
	for effect in card.effects_for(CardEnums.Trigger.ON_DEATH):
		if _is_copy(effect):
			value += copy_lifetime(_copy_total(effect, card.total_sand)) * DEATH_FACTOR
	return value


static func _is_copy(effect: CardEffectData) -> bool:
	return (
		effect.effect_type in [CardEnums.EffectType.COPY_UNIT, CardEnums.EffectType.COPY_UNIT_HALF]
	)


static func _copy_total(effect: CardEffectData, source_total: int) -> int:
	if effect.effect_type == CardEnums.EffectType.COPY_UNIT_HALF:
		return ceili(source_total / 2.0)
	return effect.value if effect.value > 0 else source_total


## CPUの見積もり(`CardCpuStrategy._themed_value()` から)。対象の写し元が分かる効果だけをここで見る。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var foe_side := MatchState.other_side(side)
	var room := state.empty_slots(side).size()
	match effect.effect_type:
		CardEnums.EffectType.COPY_UNIT, CardEnums.EffectType.COPY_UNIT_HALF:
			if effect.target == CardEnums.EffectTarget.ENTERING_FOE_UNIT and room > 0:
				return copy_lifetime(maxi(effect.value, DEFAULT_COPY_TOTAL)) * COPY_FACTOR
			return 0.0
		CardEnums.EffectType.MIMIC_UNIT:
			var biggest := 0.0
			for foe: CardInstance in state.units(foe_side):
				biggest = maxf(biggest, copy_lifetime(source_card(foe).total_sand))
			return biggest * COPY_FACTOR
		CardEnums.EffectType.COPY_FOE_TRAITS:
			var best := 0.0
			for foe: CardInstance in state.units(foe_side):
				var count := foe.keywords().size()
				for trigger in CardEnums.Trigger.values():
					if trigger != CardEnums.Trigger.ON_PLAY:
						count += foe.effects_for(trigger).size()
				best = maxf(best, float(count))
			return best * TRAIT_VALUE
		CardEnums.EffectType.REPLACE_WITH_TOKEN:
			var strongest := 0.0
			for foe: CardInstance in state.units(foe_side):
				strongest = maxf(strongest, float(foe.lifetime_damage()))
			return strongest
	return 0.0
