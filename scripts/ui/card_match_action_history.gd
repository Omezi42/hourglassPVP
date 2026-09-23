class_name CardMatchActionHistory
extends Control
## 直前の手の列(GameDesign.md 9章)。卓の左の余白へ、直近の手を上から新しい順に積む。
## 1件は濃紺の板に真鍮の縁(名札・山の札と同じ語彙)で、左端の色が誰の手か、
## 紋章と名前がどのカードかを示す。
##
## **手は `MatchState` の信号から拾う**。自分の操作・CPU・オンラインの相手のどの経路で
## 適用されても同じ信号が出るため、経路ごとに積む処理を書かずに済む。

const TILE_SIZE := Vector2(156, 50)
const TILE_GAP := 8.0
const MAX_TILES := 4
const TILE_RADIUS := 7.0
const ORIGIN := Vector2(18.0, 96.0)
const SIDE_STRIPE_WIDTH := 4.0
const EMBLEM_RADIUS := 15.0
const EMBLEM_X := 26.0
const TEXT_X := 48.0
const VERB_BASELINE := 20.0
const NAME_BASELINE := 39.0
const VERB_FONT_SIZE := 11
const NAME_FONT_SIZE := 14
const RIM_WIDTH := 1.5
const GRAIN_ALPHA := 0.06
## 新しい1件が左から滑り込む量と時間。古い件は1段ぶん下へ滑る。
const APPEAR_SHIFT := 24.0
const APPEAR_DURATION := 0.22
## 相手の手は板をわずかに赤へ寄せる(左端の帯と合わせて誰の手かを二重に示す)。
const FOE_TINT := Color(0.30, 0.08, 0.08, 0.35)

var _screen: CardMatchScreen
var _font: Font
var _items: Array[Dictionary] = []
var _state: MatchState
var _appear := 1.0
var _appear_tween: Tween


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = TextGlyphs.ui_font()
	position = ORIGIN
	size = Vector2(TILE_SIZE.x, (TILE_SIZE.y + TILE_GAP) * MAX_TILES)


## 新しい対局の状態へつなぎ直す。前の対局の状態は解放済みのため切らなくてよい。
func watch(state: MatchState) -> void:
	clear()
	_state = state
	state.unit_played.connect(
		func(side: int, slot: int) -> void: _push(side, "設置", _unit_card(side, slot))
	)
	state.spell_cast.connect(func(side: int, card: CardData) -> void: _push(side, "砂術", card))
	state.unit_flipped.connect(
		func(side: int, slot: int) -> void: _push(side, "反転", _unit_card(side, slot))
	)
	state.flip_right_used.connect(
		func(actor: int, target_side: int, slot: int) -> void:
			_push(actor, "反転権", _unit_card(target_side, slot))
	)
	state.attack_performed.connect(_on_attack)


func clear() -> void:
	_items.clear()
	queue_redraw()


func _on_attack(side: int, slot: int, target_slot: int) -> void:
	var verb := "攻撃 → 本体"
	if target_slot >= 0:
		var target := _unit_card(MatchState.other_side(side), target_slot)
		if target != null:
			verb = "攻撃 → %s" % target.display_name
	_push(side, verb, _unit_card(side, slot))


func _unit_card(side: int, slot: int) -> CardData:
	var unit: CardInstance = _state.board[side][slot]
	return unit.data if unit != null else null


func _push(side: int, verb: String, card: CardData) -> void:
	if card == null:
		return
	_items.push_front({"side": side, "verb": verb, "card": card})
	if _items.size() > MAX_TILES:
		_items.pop_back()
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	_appear_tween = create_tween()
	_appear_tween.tween_method(_set_appear, 0.0, 1.0, APPEAR_DURATION).set_ease(Tween.EASE_OUT)


func _set_appear(value: float) -> void:
	_appear = value
	queue_redraw()


func _draw() -> void:
	if _items.is_empty() or _screen.state == null:
		return
	var slide := (1.0 - _appear) * (TILE_SIZE.y + TILE_GAP)
	for i in _items.size():
		var y := i * (TILE_SIZE.y + TILE_GAP) - slide
		var x := 0.0
		var alpha := 1.0
		if i == 0:
			y = 0.0
			x = -APPEAR_SHIFT * (1.0 - _appear)
			alpha = _appear
		_draw_tile(Rect2(Vector2(x, y), TILE_SIZE), _items[i], alpha)


func _draw_tile(rect: Rect2, item: Dictionary, alpha: float) -> void:
	var ci := get_canvas_item()
	var own: bool = item["side"] == _screen.my_side
	var points := UiPaint.rounded_rect_points_uniform(rect, TILE_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[
			[0.0, Color(UiPalette.NAVY_PANEL_TOP, alpha)],
			[1.0, Color(UiPalette.NAVY_PANEL_BOTTOM, alpha)]
		]
	)
	if not own:
		var tint := Color(FOE_TINT, FOE_TINT.a * alpha)
		UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, tint], [1.0, tint]])
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA * alpha)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(UiPalette.OUTLINE_DARK, alpha), 1.0, true)
	UiPaint.draw_bevel(
		ci,
		points,
		Color(UiPalette.BRASS_RIM_LIGHT, alpha),
		Color(UiPalette.BRASS_DARK, alpha),
		RIM_WIDTH,
		false
	)
	var stripe_color := UiPalette.GLOW_AMBER if own else UiPalette.WARNING_RED
	var stripe := Rect2(
		rect.position + Vector2(RIM_WIDTH + 1.0, TILE_RADIUS),
		Vector2(SIDE_STRIPE_WIDTH, rect.size.y - TILE_RADIUS * 2.0)
	)
	draw_rect(stripe, Color(stripe_color, alpha))
	var card: CardData = item["card"]
	var emblem_center := rect.position + Vector2(EMBLEM_X, rect.size.y * 0.5)
	EmblemSeal.brass(self, emblem_center, card.emblem, EMBLEM_RADIUS)
	var who := "自分" if own else "相手"
	var who_color := UiPalette.GLOW_AMBER if own else UiPalette.WARNING_RED
	var text_x := rect.position.x + TEXT_X
	var max_width := rect.end.x - text_x - RIM_WIDTH * 3.0
	var verb_pos := Vector2(text_x, rect.position.y + VERB_BASELINE)
	_text(verb_pos, who, VERB_FONT_SIZE, Color(who_color, alpha), max_width)
	var who_width := _font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, VERB_FONT_SIZE).x
	var verb_x := who_width + VERB_FONT_SIZE * 0.5
	_text(
		verb_pos + Vector2(verb_x, 0.0),
		String(item["verb"]),
		VERB_FONT_SIZE,
		Color(UiPalette.BRASS_HIGHLIGHT, alpha),
		max_width - verb_x
	)
	_text(
		Vector2(text_x, rect.position.y + NAME_BASELINE),
		card.display_name,
		NAME_FONT_SIZE,
		Color(UiPalette.TEXT_OFFWHITE, alpha),
		max_width
	)


## 幅を超える文字は `…` で切る(`draw_string` の幅指定は切らずに縮めないため)。
func _text(pos: Vector2, value: String, font_size: int, color: Color, max_width: float) -> void:
	var shown := value
	while (
		shown.length() > 1
		and _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width
	):
		shown = shown.left(shown.length() - 2) + "…"
	draw_string(
		_font,
		pos + Vector2.ONE,
		shown,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		PlayerInfoBar.TEXT_SHADOW
	)
	draw_string(_font, pos, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
