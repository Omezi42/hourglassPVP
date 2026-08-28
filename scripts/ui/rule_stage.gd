class_name RuleStage
extends Control
## ルール画面の1ページ分の盤面(GameDesign.md 16章)。
##
## **ルール画面専用の描画は1つも書かない。**`CardView` / `BoardTable` / `PlayerInfoBar` を
## `CardInstance` / `MatchState` で駆動し、対局画面とまったく同じ絵を出す。教材用の絵を
## 別に持つと、対局画面と食い違った時点で誤った予習になるため。演出も
## `CardView.play_drop()` / `play_shatter()` / `play_flip()` をそのまま呼ぶ。
##
## 中身は「自然なサイズで組み立ててから、ステージの矩形へ収まる倍率で拡縮する」。
## ページごとに必要な広さが違うため、置き方をページごとに決め打ちしない。

## 拡大しすぎると輪郭が粗く見えるため、上限を設ける。
const MAX_SCALE := 2.0
## 演出を始めるまでの間。ページが切り替わった直後に動くと目が追いつかない。
const LEAD_IN := 0.55
## 砂が1粒落ちる演出どうしの間隔。
const STEP_INTERVAL := 0.75

const CARD_GAP := 40.0
const HAND_GAP := 24.0
const CAPTION_HEIGHT := 30.0
const CAPTION_FONT_SIZE := 17
## 「場に出す」の手札と場のあいだに置く矢印。
const ARROW_WIDTH := 76.0
const ARROW_FONT_SIZE := 34

## 第7章で見せる盤面の組み立て。情報帯を上下に挟むため、卓より広い幅が要る。
const BOARD_TABLE_SIZE := Vector2(880, 380)
const BOARD_SLOT_GAP := 12.0
const BOARD_ROW_INSET := 22.0
const DEMO_HP := [24, 17]
const DEMO_MANA := [6, 6]
const DEMO_UNITS_SELF: Array = [
	{"id": "shield", "health": 2, "attack": 2},
	{"id": "drill", "health": 4, "attack": 3},
	{"id": "sand", "health": 5, "attack": 0},
]
const DEMO_UNITS_FOE: Array = [
	{"id": "glass", "health": 3, "attack": 3},
	{"id": "wall", "health": 7, "attack": 2},
]

var _content: Control
var _page: Dictionary = {}
var _units: Array[CardInstance] = []
var _views: Array[CardView] = []
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func show_page(page: Dictionary) -> void:
	_page = page
	_rebuild()
	play()


## そのページの演出をもう一度はじめから見せる。
func play() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_reset_units()
	match _kind():
		RulePages.STAGE_DROP:
			_play_drop()
		RulePages.STAGE_FLIP:
			_play_flip()
		RulePages.STAGE_COMBAT:
			_play_combat()
		RulePages.STAGE_SAND_DIFF:
			_play_sand_diff()
		RulePages.STAGE_PLAY:
			_play_summon()


## そのページに演出があるか(「もう一度見る」を出すかどうかの判断に使う)。
func has_animation() -> bool:
	return (
		_kind()
		in [
			RulePages.STAGE_DROP,
			RulePages.STAGE_FLIP,
			RulePages.STAGE_COMBAT,
			RulePages.STAGE_SAND_DIFF,
			RulePages.STAGE_PLAY,
		]
	)


func _kind() -> String:
	var stage: Dictionary = _page.get("stage", {})
	return str(stage.get("kind", ""))


func _cards() -> Array:
	var stage: Dictionary = _page.get("stage", {})
	return stage.get("cards", [])


# --- 組み立て -----------------------------------------------------------


func _rebuild() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _content != null:
		_content.queue_free()
	_units.clear()
	_views.clear()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var natural := Vector2.ZERO
	match _kind():
		RulePages.STAGE_HAND:
			natural = _build_hand(_cards())
		RulePages.STAGE_PLAY:
			natural = _build_summon(_cards())
		RulePages.STAGE_BOARD:
			natural = _build_board()
		_:
			natural = _build_units(_cards())
	_fit(natural)


## 場の砂時計を横に並べる(single / drop / flip / combat / sand_diff で共通)。
func _build_units(cards: Array) -> Vector2:
	var has_caption := false
	for card: Dictionary in cards:
		if not str(card.get("caption", "")).is_empty():
			has_caption = true
	var height: float = CardView.BOARD_SIZE_PX.y + (CAPTION_HEIGHT if has_caption else 0.0)
	var x := 0.0
	for card: Dictionary in cards:
		var view := _make_unit_view(card)
		if view == null:
			continue
		view.position = Vector2(x, 0.0)
		var caption := str(card.get("caption", ""))
		if not caption.is_empty():
			var rect := Rect2(x, CardView.BOARD_SIZE_PX.y, CardView.BOARD_SIZE_PX.x, CAPTION_HEIGHT)
			_add_caption(caption, rect)
		x += CardView.BOARD_SIZE_PX.x + CARD_GAP
	return Vector2(maxf(x - CARD_GAP, 0.0), height)


## 手札のカードを横に並べる(キーワードの一覧)。
func _build_hand(cards: Array) -> Vector2:
	var x := 0.0
	for card: Dictionary in cards:
		var data := CardLibrary.find_by_id(str(card.get("id", "")))
		if data == null:
			continue
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.position = Vector2(x, 0.0)
		_content.add_child(view)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.show_card(data, true)
		view.size = CardView.HAND_SIZE_PX
		x += CardView.HAND_SIZE_PX.x + HAND_GAP
	return Vector2(maxf(x - HAND_GAP, 0.0), CardView.HAND_SIZE_PX.y)


## 手札の1枚が台座の上の砂時計になるまで。手札=カード / 場=物体という二層構成を見せる。
func _build_summon(cards: Array) -> Vector2:
	if cards.is_empty():
		return Vector2.ZERO
	var first: Dictionary = cards[0]
	var data := CardLibrary.find_by_id(str(first.get("id", "")))
	if data == null:
		return Vector2.ZERO
	var height: float = maxf(CardView.HAND_SIZE_PX.y, CardView.BOARD_SIZE_PX.y)

	var hand_view := CardView.new()
	hand_view.mode = CardView.Mode.HAND
	_content.add_child(hand_view)
	hand_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_view.show_card(data, true)
	hand_view.size = CardView.HAND_SIZE_PX
	hand_view.position = Vector2(0.0, (height - CardView.HAND_SIZE_PX.y) * 0.5)

	var arrow_x: float = CardView.HAND_SIZE_PX.x + HAND_GAP
	var arrow := Label.new()
	arrow.text = "▶"
	arrow.add_theme_font_size_override("font_size", ARROW_FONT_SIZE)
	arrow.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.position = Vector2(arrow_x, 0.0)
	arrow.size = Vector2(ARROW_WIDTH, height)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(arrow)

	var unit := CardInstance.new(data)
	_units.append(unit)
	var board_view := CardView.new()
	board_view.position = Vector2(arrow_x + ARROW_WIDTH + HAND_GAP, 0.0)
	_content.add_child(board_view)
	board_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_view.size = CardView.BOARD_SIZE_PX
	board_view.clear()
	_views.append(board_view)
	return Vector2(board_view.position.x + CardView.BOARD_SIZE_PX.x, height)


## 6枠ずつの盤面と情報帯。`MatchState` を実際に作ってから、盤面とHPだけ教材用の局面へ
## 差し替える(`PlayerInfoBar.show_state()` が `MatchState` を要るため)。
func _build_board() -> Vector2:
	var state := _demo_state()
	var slot_pitch: float = CardView.BOARD_SIZE_PX.x + BOARD_SLOT_GAP
	var row_width: float = slot_pitch * MatchState.BOARD_SIZE - BOARD_SLOT_GAP
	var width: float = maxf(row_width + BOARD_ROW_INSET * 2.0, BOARD_TABLE_SIZE.x)
	var bar_width: float = maxf(width, PlayerInfoBar.CLOCK_X)
	var table_x: float = (bar_width - BOARD_TABLE_SIZE.x) * 0.5
	var row_x: float = (bar_width - row_width) * 0.5

	var foe_bar := _make_info_bar(state, MatchState.Side.B, true, bar_width, 0.0)
	var table := BoardTable.new()
	table.position = Vector2(table_x, foe_bar.size.y)
	table.size = BOARD_TABLE_SIZE
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(table)

	var row_gap: float = (BOARD_TABLE_SIZE.y - CardView.BOARD_SIZE_PX.y * 2.0) / 3.0
	for side in [MatchState.Side.B, MatchState.Side.A]:
		var row: float = 0.0 if side == MatchState.Side.B else 1.0
		var y: float = foe_bar.size.y + row_gap + (CardView.BOARD_SIZE_PX.y + row_gap) * row
		var slots: Array = state.board[side]
		for i in MatchState.BOARD_SIZE:
			var view := CardView.new()
			view.position = Vector2(row_x + slot_pitch * float(i), y)
			_content.add_child(view)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			view.size = CardView.BOARD_SIZE_PX
			if slots[i] == null:
				view.clear()
			else:
				view.show_unit(slots[i])

	var bottom: float = foe_bar.size.y + BOARD_TABLE_SIZE.y
	var own_bar := _make_info_bar(state, MatchState.Side.A, false, bar_width, bottom)
	return Vector2(bar_width, bottom + own_bar.size.y)


func _make_info_bar(
	state: MatchState, side: int, is_opponent: bool, width: float, y: float
) -> PlayerInfoBar:
	var bar := PlayerInfoBar.new()
	bar.is_opponent = is_opponent
	bar.display_name = "相手" if is_opponent else "自分"
	bar.position = Vector2(0.0, y)
	_content.add_child(bar)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size = Vector2(width, PlayerInfoBar.BAR_HEIGHT)
	bar.show_state(state, side)
	return bar


## 教材用の局面。ランダムなデッキから引いた盤面をそのまま見せると、説明したい形が
## 毎回変わってしまうため、生成した `MatchState` の盤面とHPを差し替えて固定する。
func _demo_state() -> MatchState:
	var state := MatchState.new()
	var deck: Array = []
	for card in CardLibrary.all_cards():
		deck.append(card)
		deck.append(card)
		if deck.size() >= MatchState.DECK_SIZE:
			break
	state.start_match(deck.duplicate(), deck.duplicate(), MatchState.Side.A, 1)
	for entry in [[MatchState.Side.A, DEMO_UNITS_SELF], [MatchState.Side.B, DEMO_UNITS_FOE]]:
		var side: int = entry[0]
		var slots: Array = state.board[side]
		var specs: Array = entry[1]
		for i in specs.size():
			slots[i] = _make_unit(specs[i])
	state.hp[MatchState.Side.A] = DEMO_HP[0]
	state.hp[MatchState.Side.B] = DEMO_HP[1]
	for i in 2:
		var side: int = MatchState.Side.A if i == 0 else MatchState.Side.B
		state.mana[side] = DEMO_MANA[i]
		state.max_mana[side] = DEMO_MANA[i]
	return state


func _make_unit(spec: Dictionary) -> CardInstance:
	var data := CardLibrary.find_by_id(str(spec.get("id", "")))
	if data == null:
		return null
	var unit := CardInstance.new(data)
	unit.health = int(spec.get("health", unit.health))
	unit.attack = int(spec.get("attack", 0))
	unit.summoned_this_turn = false
	return unit


func _make_unit_view(spec: Dictionary) -> CardView:
	var unit := _make_unit(spec)
	if unit == null:
		return null
	_units.append(unit)
	var view := CardView.new()
	_content.add_child(view)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.size = CardView.BOARD_SIZE_PX
	view.show_unit(unit)
	_views.append(view)
	return view


func _add_caption(text: String, rect: Rect2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(label)


## 組み上がった中身を、ステージの矩形の中央へ収まる倍率で拡縮する。
func _fit(natural: Vector2) -> void:
	if natural.x <= 0.0 or natural.y <= 0.0:
		return
	_content.size = natural
	var factor: float = minf(minf(size.x / natural.x, size.y / natural.y), MAX_SCALE)
	_content.scale = Vector2(factor, factor)
	_content.position = (size - natural * factor) * 0.5


# --- 演出 ---------------------------------------------------------------


## 演出は状態を進めるため、再生のたびにページの初期値へ戻す。
func _reset_units() -> void:
	var cards := _cards()
	if _kind() == RulePages.STAGE_PLAY:
		for view in _views:
			view.clear()
		return
	for i in mini(_units.size(), cards.size()):
		var spec: Dictionary = cards[i]
		_units[i].health = int(spec.get("health", _units[i].health))
		_units[i].attack = int(spec.get("attack", 0))
		_units[i].glass_intact = _units[i].has_keyword(CardEnums.Keyword.GLASS)
	for view in _views:
		view.queue_redraw()


func _play_drop() -> void:
	if _units.is_empty():
		return
	_tween = create_tween()
	for step in _units[0].health:
		_tween.tween_interval(LEAD_IN if step == 0 else STEP_INTERVAL)
		_tween.tween_callback(_drop_step)


func _drop_step() -> void:
	var unit := _units[0]
	var view := _views[0]
	unit.tick()
	view.play_drop()
	view.queue_redraw()
	if unit.is_dead():
		# 体力0で破壊される。砕けて散る演出をそのまま使う。
		view.play_shatter(0)


func _play_flip() -> void:
	_tween = create_tween()
	_tween.tween_interval(LEAD_IN)
	_tween.tween_callback(_flip_step)


func _flip_step() -> void:
	_units[0].flip()
	_views[0].play_flip()
	_views[0].queue_redraw()


func _play_combat() -> void:
	if _units.size() < 2:
		return
	_tween = create_tween()
	_tween.tween_interval(LEAD_IN)
	_tween.tween_callback(_combat_step)


func _combat_step() -> void:
	# 同時攻撃であり、片方の減少がもう片方の値へ影響してはならないため先に控える。
	var attack_a := _units[0].attack
	var attack_b := _units[1].attack
	_units[0].take_damage(attack_b)
	_units[1].take_damage(attack_a)
	_views[0].play_shatter(attack_b)
	_views[1].play_shatter(attack_a)
	_views[0].queue_redraw()
	_views[1].queue_redraw()


func _play_sand_diff() -> void:
	if _units.size() < 2:
		return
	_tween = create_tween()
	_tween.tween_interval(LEAD_IN)
	_tween.tween_callback(_sand_diff_step)


func _sand_diff_step() -> void:
	_units[0].tick()
	_views[0].play_drop()
	_views[0].queue_redraw()
	var amount := 2
	_units[1].take_damage(amount)
	_views[1].play_shatter(amount)
	_views[1].queue_redraw()


func _play_summon() -> void:
	_tween = create_tween()
	_tween.tween_interval(LEAD_IN)
	_tween.tween_callback(_summon_step)


func _summon_step() -> void:
	if _units.is_empty() or _views.is_empty():
		return
	_views[0].show_unit(_units[0])
	_views[0].play_drop()
