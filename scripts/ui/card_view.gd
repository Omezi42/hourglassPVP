class_name CardView
extends Control
## カード1枚の表示(GameDesign.md 9章「対局画面」)。盤面の砂時計と手札の両方に使う。
## 数値の配置は既存のDCGの慣習に合わせる:コスト=左上 / 攻撃力=左下 / 体力=右下。

signal pressed(view: CardView)

enum Mode {
	## 場に出ている砂時計。攻撃力と体力を出す。
	BOARD,
	## 手札。コストと総量(=場に出たときの体力)を出す。
	HAND,
}

const BOARD_SIZE_PX := Vector2(128, 170)
const HAND_SIZE_PX := Vector2(118, 158)
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const ATTACK_ORANGE := Color(0.95, 0.62, 0.2, 1.0)
const HEALTH_RED := Color(0.9, 0.3, 0.26, 1.0)
const STAT_RADIUS := 15.0
const GUARD_BORDER := 4.0
const NORMAL_BORDER := 2.0

var mode: int = Mode.BOARD
## 表示するカード。手札はこれだけ、盤面は unit も併せて持つ。
var card: CardData
var unit: CardInstance
## 出せる/選べる状態か。false なら暗く表示する。
var enabled := true
## 選択中(枠を強調する)。
var selected := false
## このターンに行動を終えている(彩度を落とす)。
var exhausted := false

var _font: Font
var _hovering := false
var _tracker := PressTracker.new()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var theme_font := get_theme_default_font()
	if theme_font != null:
		_font = theme_font
	custom_minimum_size = HAND_SIZE_PX if mode == Mode.HAND else BOARD_SIZE_PX
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## 場の砂時計として表示する。
func show_unit(p_unit: CardInstance) -> void:
	mode = Mode.BOARD
	unit = p_unit
	card = null if p_unit == null else p_unit.data
	custom_minimum_size = BOARD_SIZE_PX
	queue_redraw()


## 手札のカードとして表示する。
func show_card(p_card: CardData, p_enabled: bool) -> void:
	mode = Mode.HAND
	unit = null
	card = p_card
	enabled = p_enabled
	custom_minimum_size = HAND_SIZE_PX
	queue_redraw()


func clear() -> void:
	card = null
	unit = null
	queue_redraw()


func is_empty() -> bool:
	return card == null


func _on_mouse_entered() -> void:
	_hovering = true
	if enabled:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovering = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	var result := _tracker.feed(event, size)
	if result == PressTracker.Result.CONFIRMED:
		pressed.emit(self)


func _draw() -> void:
	if card == null:
		_draw_empty()
		return
	var rect := Rect2(Vector2.ZERO, size)
	var guard := card.has_keyword(CardEnums.Keyword.GUARD)
	var tint := Color(1, 1, 1, 1)
	if not enabled or exhausted:
		tint = Color(0.55, 0.55, 0.6, 1)
	_fill(rect, Color(0.21, 0.18, 0.15, 1.0) * tint, Color(0.11, 0.1, 0.09, 1.0))
	var border := UiPalette.BRASS_MID
	if selected:
		border = UiPalette.GLOW_AMBER
	elif guard:
		border = UiPalette.BRASS_HIGHLIGHT
	draw_rect(rect, border, false, GUARD_BORDER if guard or selected else NORMAL_BORDER)
	_draw_art(rect, tint)
	if unit != null and unit.glass_intact:
		draw_rect(rect.grow(-4), Color(0.6, 0.85, 1.0, 0.13))
	_draw_labels(rect, tint)
	_draw_stats(rect)
	if _hovering and enabled:
		draw_rect(rect, Color(1, 1, 1, 0.06))


func _draw_empty() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color := UiPalette.GLOW_AMBER if selected else Color(0.3, 0.28, 0.3, 0.5)
	_dashed_rect(rect, color)


func _draw_art(rect: Rect2, tint: Color) -> void:
	var texture := _icon()
	if texture == null:
		return
	var side := rect.size.x * 0.62
	var pos := Vector2((rect.size.x - side) * 0.5, rect.size.y * 0.06)
	draw_texture_rect(texture, Rect2(pos, Vector2(side, side)), false, tint)


## 体力と攻撃力の比で3枚を切り替える(GameDesign.md 9章)。手札は常に上向き。
func _icon() -> Texture2D:
	if unit == null:
		return card.icon_upright
	if unit.attack > unit.health:
		return card.icon_fallen
	if unit.attack >= unit.health - 1:
		return card.icon_falling
	return card.icon_upright


func _draw_labels(rect: Rect2, tint: Color) -> void:
	var name_size := 15
	_centered_text(rect, card.display_name, name_size, rect.size.y - 62.0, tint)
	var words: PackedStringArray = []
	for keyword in card.keywords:
		words.append(CardEnums.keyword_name(keyword))
	var note := " ".join(words)
	if note.is_empty() and not card.rules_text.is_empty():
		note = CardEnums.trigger_name(card.effects[0].trigger)
	if not note.is_empty():
		_centered_text(rect, note, 13, rect.size.y - 42.0, UiPalette.BRASS_HIGHLIGHT * tint)


func _draw_stats(rect: Rect2) -> void:
	if mode == Mode.HAND:
		_stat(Vector2(STAT_RADIUS + 3, STAT_RADIUS + 3), card.cost, MANA_BLUE)
		_stat(
			Vector2(rect.size.x - STAT_RADIUS - 3, rect.size.y - STAT_RADIUS - 3),
			card.total_sand,
			HEALTH_RED
		)
		return
	_stat(Vector2(STAT_RADIUS + 3, rect.size.y - STAT_RADIUS - 3), unit.attack, ATTACK_ORANGE)
	_stat(
		Vector2(rect.size.x - STAT_RADIUS - 3, rect.size.y - STAT_RADIUS - 3),
		unit.health,
		HEALTH_RED
	)


func _stat(center: Vector2, value: int, color: Color) -> void:
	draw_circle(center, STAT_RADIUS, Color(0.08, 0.07, 0.06, 0.95))
	draw_arc(center, STAT_RADIUS, 0.0, TAU, 24, color, 2.5)
	var text := str(value)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(
		_font, center + Vector2(-width * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color
	)


func _centered_text(rect: Rect2, text: String, font_size: int, top: float, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		_font,
		Vector2((rect.size.x - width) * 0.5, top),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func _fill(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var x := rect.position.x
	while x < rect.end.x:
		var to := minf(x + 5, rect.end.x)
		draw_line(Vector2(x, rect.position.y), Vector2(to, rect.position.y), color, 2.0)
		draw_line(Vector2(x, rect.end.y), Vector2(to, rect.end.y), color, 2.0)
		x += 10.0
	var y := rect.position.y
	while y < rect.end.y:
		var to := minf(y + 5, rect.end.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, to), color, 2.0)
		draw_line(Vector2(rect.end.x, y), Vector2(rect.end.x, to), color, 2.0)
		y += 10.0
