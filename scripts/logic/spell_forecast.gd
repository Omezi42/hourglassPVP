class_name SpellForecast
extends RefCounted
## 砂術を撃った後の盤面の予測(GameDesign.md 9章「撃った後の予測」)。
##
## カードごとに計算を書かず、対局の写し(`MatchState.fork()`)へ実際に撃って
## 撃つ前と比べる。効果が増えても予測の側は変えずに済む。


## 撃つと体力が変わる駒の一覧。[{"side", "slot", "health", "dead"}]。
## ランダムな効果を含む砂術は結果が定まらないため、空を返す。
static func compute(state: MatchState, side: int, hand_index: int, target := {}) -> Array:
	var card := CardEffectResolver.acting_card(state, side, state.hand[side][hand_index])
	if is_random(card):
		return []
	var after := fork(state)
	if not after.cast_spell(side, hand_index, target):
		return []
	var changes: Array = []
	for board_side in [MatchState.Side.A, MatchState.Side.B]:
		for slot in MatchState.BOARD_SIZE:
			var before: CardInstance = state.board[board_side][slot]
			if before == null:
				continue
			var now: CardInstance = after.board[board_side][slot]
			var dead := now == null or now.is_dead()
			if dead or now.health != before.health:
				(
					changes
					. append(
						{
							"side": board_side,
							"slot": slot,
							"health": 0 if dead else now.health,
							"dead": dead,
						}
					)
				)
	return changes


static func is_random(card: CardData) -> bool:
	for effect in card.effects:
		if effect.random_target:
			return true
	return false


## 対局の写し。写しへの変更は元へ届かない。シグナルの接続は写さない。
## 乱数の状態も写すため、ランダムな効果の結果は本物と一致する(`is_random()` で弾く)。
## `MatchState` は公開メソッドの上限に達しているため、ここに置く。
static func fork(state: MatchState) -> MatchState:
	var twin := MatchState.new()
	for property in state.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var name: String = property["name"]
		if name in ["_effects", "_rng"]:
			continue
		var value: Variant = state.get(name)
		twin.set(name, value.duplicate(true) if value is Dictionary or value is Array else value)
	for side in state.board:
		var slots: Array = []
		for unit in state.board[side]:
			slots.append((unit as CardInstance).copy() if unit != null else null)
		twin.board[side] = slots
	twin._rng.seed = state._rng.seed
	twin._rng.state = state._rng.state
	return twin
