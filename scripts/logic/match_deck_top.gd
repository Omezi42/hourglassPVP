class_name MatchDeckTop
extends RefCounted
## 山札の上を扱う処理(GameDesign.md 6章「山札の上を扱う効果」。先触の刻)。
## `MatchState` の公開メソッドが上限に達しているため、山札の一番上を手札のように使う・山札を墓地へ置くための関数をここへ置く。


## 山札の一番上を手札のように使えるか(シビルが場にいて、山札が残っているとき)。
static func top_playable(state: MatchState, side: int) -> bool:
	if state.deck[side].is_empty():
		return false
	return state.units(side).any(func(unit: CardInstance) -> bool: return unit.plays_deck_top())


## 手札と、使えるなら山札の一番上を右端に1枚足した並び。手札の枚数には数えない。
## 手の `hand_index` はこの並びの位置で、手札の枚数と同じ位置が山札の一番上を指す。
static func playable_hand(state: MatchState, side: int) -> Array:
	if not top_playable(state, side):
		return state.hand[side]
	return state.hand[side] + [state.deck[side][0]]


## `playable_hand()` の位置にある札。無ければ null。
static func card_at(state: MatchState, side: int, index: int) -> CardData:
	var cards: Array = state.hand[side]
	if index >= 0 and index < cards.size():
		return cards[index]
	if index == cards.size() and top_playable(state, side):
		return state.deck[side][0]
	return null


## 山札の一番上を1枚抜いて返す(手札・場・墓地へ動かすとき)。空なら null。空になったら `draw()` と同じく疲労の印を立てる。
static func take_top(state: MatchState, side: int) -> CardData:
	if state.deck[side].is_empty():
		return null
	var card: CardData = state.deck[side].pop_front()
	if state.deck[side].is_empty():
		state._deck_exhausted[side] = true
	return card


## 山札の上から count 枚を墓地へ置き、置いた札を返す。引くではないため、相手のドローに反応する効果は働かない。
## 山札が足りなければある分だけ置く(疲労は起きない)。
static func mill(state: MatchState, side: int, count: int) -> Array[CardData]:
	var milled: Array[CardData] = []
	for i in count:
		var card := take_top(state, side)
		if card == null:
			break
		state.graveyard[side].append(card)
		milled.append(card)
	if not milled.is_empty():
		state.deck_milled.emit(side, milled.size())
	return milled
