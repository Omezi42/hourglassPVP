class_name CardCpuSpellSearch
extends RefCounted
## 砂術の1手読み(GameDesign.md 13章・Architecture.md 8章)。対局の写し(`SpellForecast.fork()`)へ
## 対象の候補ごとに実際に撃ち、その手番の攻撃まで進めた盤面を、撃たずに攻撃した盤面と比べた差を
## 砂術の価値とする。除去で守護をどけて本体を殴る・削ってから仕留めるといった、
## 撃った後の攻撃で生きる価値まで拾うため。効果の種類ごとに見積もりを書かないため、
## 砂術が増えてもここは変えずに済む。

## 手札1枚の値打ち。ドロー1枚の見積もり(`CardCpuStrategy._on_play_value()` の DRAW)と揃える。
const HAND_CARD_VALUE := 3.0
## 反転権1回の値打ち。総量+1とほぼ同じに見る(`GAIN_FLIP_RIGHT` の見積もりと揃える)。
const FLIP_RIGHT_VALUE := 2.0
## 決着がつく手の値打ち。どんな盤面の差よりも大きければよい。
const WIN_VALUE := 1000.0
## ランダムな対象を取る砂術を見積もるときに撃ち直す回数。乱数の先を覗かないよう、写しの乱数を引き直す。
const RANDOM_SAMPLES := 4
## 写しの上で続ける攻撃の上限(1手番に攻撃できる駒の数を十分に上回ればよい)。
const ATTACK_ROLLOUT_LIMIT := 12
## 駒のキーワード1つの値打ち。`CardCpuStrategy._card_value()` が出すときに見る値と揃える。
const KEYWORD_VALUES := {
	CardEnums.Keyword.GUARD: 2.0,
	CardEnums.Keyword.LIFESTEAL: 2.0,
	CardEnums.Keyword.DOUBLE_STRIKE: 3.0,
	CardEnums.Keyword.POISON: 4.0,
	CardEnums.Keyword.PIERCE: 1.0,
}
const GLASS_VALUE := 2.0
## 場に残るあいだ繰り返し働くトリガー1つの値打ち(沈黙・除去で失うぶん)。
const TRIGGER_VALUE := 2.0
const REPEATING_TRIGGERS := [
	CardEnums.Trigger.ON_TURN_END,
	CardEnums.Trigger.ON_DAMAGED,
	CardEnums.Trigger.ON_ALLY_DEATH,
	CardEnums.Trigger.ON_ENEMY_FLIP,
	CardEnums.Trigger.ON_ENEMY_DRAW,
	CardEnums.Trigger.ON_OWN_SPELL,
	CardEnums.Trigger.ON_FLIP,
]


## 手札の砂術を撃ったときの最善の対象と、その評価の差。撃つ意味が無ければ value は 0 以下。
## `attack` はその手番の攻撃を1手ずつ返す思考(`CardCpuStrategy._choose_attack`)。
## 戻り値は {"value": float, "target": Dictionary}。
## `before` は撃たずに攻撃した場合の評価(`baseline()`)。
static func best_cast(
	state: MatchState,
	side: int,
	hand_index: int,
	before: float,
	face_weight: float,
	grave_hint: Dictionary,
	attack: Callable
) -> Dictionary:
	var card: CardData = state.hand[side][hand_index]
	var best := {"value": 0.0, "target": {}}
	var targets := candidate_targets(state, side, card)
	if targets.is_empty():
		return best
	var samples := RANDOM_SAMPLES if SpellForecast.is_random(card) else 1
	var first := true
	for target: Dictionary in targets:
		target.merge(grave_hint)
		var total := 0.0
		for i in samples:
			var after := SpellForecast.fork(state)
			if samples > 1:
				after._rng.seed = i + 1
			if not after.cast_spell(side, hand_index, target):
				return best
			_attack_out(after, side, attack)
			total += evaluate(after, side, face_weight)
		# 撃った砂術が手札から減るぶんは、出す駒と同じくカード1枚の代価として数えない。
		var gain := total / samples - before + HAND_CARD_VALUE
		if first or gain > best["value"]:
			best = {"value": gain, "target": target}
			first = false
	return best


## 砂術を撃たずに、その手番の攻撃だけを続けた盤面の評価。
static func baseline(state: MatchState, side: int, face_weight: float, attack: Callable) -> float:
	var unchanged := SpellForecast.fork(state)
	_attack_out(unchanged, side, attack)
	return evaluate(unchanged, side, face_weight)


## 写しの上で、その手番の攻撃を思考どおりに続ける。
static func _attack_out(state: MatchState, side: int, attack: Callable) -> void:
	for i in ATTACK_ROLLOUT_LIMIT:
		if state.is_match_over():
			return
		var action: Dictionary = attack.call(state, side)
		if action.is_empty() or not MatchAction.apply(state, action):
			return


## 対象を1体取る効果があれば、選べる対象をすべて並べる。取らなければ空の指定1つ。
## 取るのに候補が1体もいなければ空の配列(撃たない。自動選択の無駄撃ちを避ける)。
static func candidate_targets(state: MatchState, side: int, card: CardData) -> Array:
	var foe_side := MatchState.other_side(side)
	for effect in card.effects_for(CardEnums.Trigger.ON_PLAY):
		if effect.random_target:
			continue
		match effect.target:
			CardEnums.EffectTarget.ENEMY_UNIT:
				return _unit_targets(state, foe_side, effect)
			CardEnums.EffectTarget.ALLY_UNIT:
				return _unit_targets(state, side, effect)
			CardEnums.EffectTarget.ENEMY_UNIT_OR_PLAYER:
				var found := _unit_targets(state, foe_side, effect)
				found.append({"side": foe_side, "slot": -1})
				return found
	return [{}]


static func _unit_targets(state: MatchState, target_side: int, effect: CardEffectData) -> Array:
	var found: Array = []
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[target_side][slot]
		if unit != null and CardEffectResolver.eligible_target(unit, effect):
			found.append({"side": target_side, "slot": slot})
	return found


## `side` から見た盤面の評価。駒は生涯ダメージ(GameDesign.md 1章)、本体はHPの差を
## `face_weight` 倍、自分の手札と反転権はそれぞれの値打ちで数える。相手の手札は中身が分からないため数えない。
static func evaluate(state: MatchState, side: int, face_weight: float) -> float:
	var foe_side := MatchState.other_side(side)
	if state.is_match_over():
		if state.winner == side:
			return WIN_VALUE
		return -WIN_VALUE if state.winner == foe_side else 0.0
	var value := 0.0
	for unit in state.units(side):
		value += unit_value(unit)
	for unit in state.units(foe_side):
		value -= unit_value(unit)
	value += float(int(state.hp[side]) - int(state.hp[foe_side])) * face_weight
	value += float(state.hand[side].size()) * HAND_CARD_VALUE
	value += float(state.flip_right_remaining.get(side, 0)) * FLIP_RIGHT_VALUE
	return value


static func unit_value(unit: CardInstance) -> float:
	if unit.is_dead():
		return 0.0
	var value := float(unit.lifetime_damage())
	for keyword: int in KEYWORD_VALUES:
		if unit.has_keyword(keyword):
			value += KEYWORD_VALUES[keyword]
	if unit.glass_intact:
		value += GLASS_VALUE
	for trigger: int in REPEATING_TRIGGERS:
		value += unit.effects_for(trigger).size() * TRIGGER_VALUE
	return value
