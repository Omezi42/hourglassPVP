class_name CardBlazeSandEffects
extends RefCounted
## 第2弾「烈砂の刻」の固有効果(GameDesign.md 6章「手札から砂時計を出す効果」)。
## `CardEffectResolver` が1000行の上限に近いため、手札から出す効果の解決・CPUの見積もり・疾走を与える効果の見積もりをここへ切り出す。
## 紋章を知らせる処理は `CardEffectResolver` のものを使う(`CardBackWaterEffects` と同じ作り)。

const TYPES := [CardEnums.EffectType.PLAY_RANDOM_FROM_HAND]

var _state: MatchState
var _resolver: CardEffectResolver


func _init(state: MatchState, resolver: CardEffectResolver) -> void:
	_state = state
	_resolver = resolver


static func handles(effect_type: int) -> bool:
	return TYPES.has(effect_type)


## 効果が出せる手札の位置。砂時計(砂術・トークンは除く)で、札のコストが condition_total 以下のもの。
static func eligible_hand_indices(
	state: MatchState, side: int, effect: CardEffectData
) -> Array[int]:
	var found: Array[int] = []
	for index in state.hand[side].size():
		var card: CardData = state.hand[side][index]
		if not card.is_spell and not card.is_token and card.cost <= effect.condition_total:
			found.append(index)
	return found


func apply(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	match effect.effect_type:
		CardEnums.EffectType.PLAY_RANDOM_FROM_HAND:
			_play_from_hand(side, effect, from_slot, origin)


## 手札からランダムに、value 体まで空き枠へ出す。乱数は対局の乱数から引く(リプレイ・オンラインで一致させるため)。
## 出した駒は設置効果を解決する(手で出したのと同じ)。対象を選ぶ設置効果は選び方の指定が無いため自動で選ぶ。
func _play_from_hand(side: int, effect: CardEffectData, from_slot: int, origin: int) -> void:
	for i in effect.value:
		if _state.is_match_over():
			return
		var slot := _resolver._first_empty_slot(side)
		var picks := eligible_hand_indices(_state, side, effect)
		if slot < 0 or picks.is_empty():
			return
		var index: int = picks[_state._rng.randi_range(0, picks.size() - 1)]
		var card: CardData = _state.hand[side][index]
		_state.hand[side].remove_at(index)
		_resolver._strike(side, from_slot, side, slot, CardEnums.EffectVisualStyle.DESCEND, origin)
		var played := CardInstance.new(card)
		if effect.keyword >= 0:
			played.grant_keyword(effect.keyword)
		_state.board[side][slot] = played
		_state.hand_changed.emit(side)
		_state.board_changed.emit(side)
		_state._fire(side, played, CardEnums.Trigger.ON_PLAY, {})


## CPUの見積もり(`CardCpuStrategy._on_play_value()`)。出せる砂時計の平均の生涯ダメージを、出せる数だけ。
static func cpu_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var picks := eligible_hand_indices(state, side, effect)
	var count := mini(mini(effect.value, picks.size()), state.empty_slots(side).size())
	if count <= 0:
		return 0.0
	var total := 0.0
	for index in picks:
		var card: CardData = state.hand[side][index]
		total += CardCpuStrategy.lifetime_of(card.initial_health(), card.initial_attack)
	return total / picks.size() * count


## 疾走を与える効果(追い風・フレア)の見積もり。出したばかりで殴れない駒がすぐ殴れるぶんだけ、その攻撃力を本体へ。
static func quick_grant_value(state: MatchState, side: int, effect: CardEffectData) -> float:
	var fresh: Array[float] = []
	for unit: CardInstance in state.units(side):
		if unit.is_fresh() and not unit.data.cannot_attack:
			fresh.append(float(unit.attack))
	if fresh.is_empty():
		return 0.0
	if effect.target == CardEnums.EffectTarget.ALLY_UNIT:
		return fresh.max() * CardCpuStrategy.FACE_WEIGHT
	var total := 0.0
	for attack in fresh:
		total += attack
	return total * CardCpuStrategy.FACE_WEIGHT
