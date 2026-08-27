extends Control
## v5.0 対局画面モックの描画本体(使い捨て)。確認後に削除すること。
## カードの数値配置は既存のDCGの慣習に合わせる(コスト=左上 / 攻撃力=左下 / 体力=右下)。

const BOARD_CARD := Vector2(128, 170)
const BOARD_GAP := 12.0
const HAND_CARD := Vector2(118, 158)
const HAND_GAP := 10.0
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const ATTACK_ORANGE := Color(0.95, 0.62, 0.2, 1.0)
const HEALTH_RED := Color(0.9, 0.3, 0.26, 1.0)

var _font: Font
var _own_board: Array = []
var _foe_board: Array = []
var _hand: Array = []


func _ready() -> void:
	_font = load("res://assets/fonts/ZenKakuGothicNew-Bold.ttf")
	_own_board = [
		_unit("wall", 7, 3),
		_unit("shield", 2, 2),
		_unit("glow", 4, 3),
		null,
		_unit("dash", 1, 3),
		null
	]
	_foe_board = [_unit("guard", 6, 2), null, _unit("poison", 3, 2), _unit("drill", 2, 4), null, null]
	_hand = [
		CardLibrary.find_by_id("sword"),
		CardLibrary.find_by_id("hammer"),
		CardLibrary.find_by_id("twin"),
		CardLibrary.find_by_id("sand"),
		CardLibrary.find_by_id("sweep"),
		CardLibrary.find_by_id("echo"),
	]
	queue_redraw()


func _unit(id: String, health: int, attack: int) -> CardInstance:
	var unit := CardInstance.new(CardLibrary.find_by_id(id))
	unit.health = health
	unit.attack = attack
	return unit


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.06, 0.08, 1.0))
	_draw_info_bar(Rect2(16, 10, 1248, 56), false)
	_draw_row(_foe_board, 78.0, true)
	draw_line(Vector2(120, 248), Vector2(1160, 248), Color(0.85, 0.62, 0.22, 0.25), 2.0)
	_draw_row(_own_board, 258.0, false)
	_draw_info_bar(Rect2(16, 440, 1060, 56), true)
	_draw_buttons()
	_draw_hand()


# --- 情報帯 -------------------------------------------------------------


func _draw_info_bar(rect: Rect2, own: bool) -> void:
	_panel(rect, UiPalette.BAR_FILL_TOP, UiPalette.BAR_FILL_BOTTOM)
	_text(Vector2(rect.position.x + 18, rect.position.y + 36), "あなた" if own else "相手", 20)
	var hp_rect := Rect2(rect.position.x + 96, rect.position.y + 16, 240, 24)
	var hp: int = 21 if own else 14
	_panel(hp_rect, Color(0.16, 0.12, 0.1, 1.0), Color(0.1, 0.08, 0.07, 1.0))
	var ratio := float(hp) / float(MatchState.INITIAL_HP)
	draw_rect(
		Rect2(hp_rect.position, Vector2(hp_rect.size.x * ratio, hp_rect.size.y)),
		UiPalette.GLOW_AMBER if ratio > 0.4 else UiPalette.WARNING_RED
	)
	_text(Vector2(hp_rect.position.x + 96, hp_rect.position.y + 19), "%d / 30" % hp, 17)
	var mana: int = 5 if own else 7
	var max_mana := 7
	_text(Vector2(rect.position.x + 356, rect.position.y + 36), "マナ %d/%d" % [mana, max_mana], 18)
	for i in max_mana:
		var center := Vector2(rect.position.x + 452 + i * 20, rect.position.y + 28)
		draw_circle(center, 7.0, MANA_BLUE if i < mana else Color(0.2, 0.22, 0.28, 1.0))
		draw_arc(center, 7.0, 0.0, TAU, 16, Color(0.75, 0.85, 1.0, 0.6), 1.5)
	_pile(Vector2(rect.position.x + 620, rect.position.y + 8), "山札", 12)
	_pile(Vector2(rect.position.x + 712, rect.position.y + 8), "墓地", 5)
	if not own:
		_pile(Vector2(rect.position.x + 804, rect.position.y + 8), "手札", 4)


func _pile(pos: Vector2, label: String, count: int) -> void:
	var rect := Rect2(pos, Vector2(74, 40))
	_panel(rect, Color(0.2, 0.16, 0.12, 1.0), Color(0.11, 0.09, 0.07, 1.0))
	_text(Vector2(pos.x + 8, pos.y + 26), label, 15)
	_text(Vector2(pos.x + 46, pos.y + 27), str(count), 19, UiPalette.GLOW_AMBER)


# --- 盤面 ---------------------------------------------------------------


func _draw_row(units: Array, top: float, foe: bool) -> void:
	var total := MatchState.BOARD_SIZE * BOARD_CARD.x + (MatchState.BOARD_SIZE - 1) * BOARD_GAP
	var start := (size.x - total) * 0.5
	for i in MatchState.BOARD_SIZE:
		var rect := Rect2(Vector2(start + i * (BOARD_CARD.x + BOARD_GAP), top), BOARD_CARD)
		if units[i] == null:
			_empty_slot(rect, not foe and i == 3)
			continue
		_draw_unit(rect, units[i])


func _empty_slot(rect: Rect2, highlighted: bool) -> void:
	var color := UiPalette.GLOW_AMBER if highlighted else Color(0.3, 0.28, 0.3, 0.5)
	_dashed_rect(rect, color)
	if highlighted:
		_text(rect.position + Vector2(20, rect.size.y * 0.5), "ここへ出す", 15, color)


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


func _draw_unit(rect: Rect2, unit: CardInstance) -> void:
	var guard := unit.has_keyword(CardEnums.Keyword.GUARD)
	_panel(rect, Color(0.19, 0.16, 0.14, 1.0), Color(0.1, 0.09, 0.08, 1.0))
	draw_rect(
		rect, UiPalette.BRASS_HIGHLIGHT if guard else UiPalette.BRASS_MID, false, 4.0 if guard else 2.0
	)
	var texture := _icon_for(unit)
	if texture != null:
		draw_texture_rect(
			texture, Rect2(rect.position + Vector2(24, 10), Vector2(80, 80)), false
		)
	if unit.glass_intact:
		draw_rect(rect.grow(-4), Color(0.6, 0.85, 1.0, 0.13))
	_text(_centered(rect, unit.data.display_name, 15, 108.0), unit.data.display_name, 15)
	var words: PackedStringArray = []
	for keyword in unit.data.keywords:
		words.append(CardEnums.keyword_name(keyword))
	if not words.is_empty():
		var text := " ".join(words)
		_text(_centered(rect, text, 14, 128.0), text, 14, UiPalette.BRASS_HIGHLIGHT)
	# 既存のDCGの慣習に合わせ、攻撃力=左下 / 体力=右下。
	_stat(Vector2(rect.position.x + 4, rect.end.y - 32), unit.attack, ATTACK_ORANGE)
	_stat(Vector2(rect.end.x - 32, rect.end.y - 32), unit.health, HEALTH_RED)


func _centered(rect: Rect2, text: String, font_size: int, top: float) -> Vector2:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + top)


func _icon_for(unit: CardInstance) -> Texture2D:
	if unit.attack > unit.health:
		return unit.data.icon_fallen
	if unit.attack >= unit.health - 1:
		return unit.data.icon_falling
	return unit.data.icon_upright


func _stat(pos: Vector2, value: int, color: Color) -> void:
	var center := pos + Vector2(14, 14)
	draw_circle(center, 15.0, Color(0.08, 0.07, 0.06, 0.95))
	draw_arc(center, 15.0, 0.0, TAU, 24, color, 2.5)
	var text := str(value)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_text(center + Vector2(-width * 0.5, 7), text, 20, color)


# --- 手札・ボタン -------------------------------------------------------


func _draw_hand() -> void:
	var total := _hand.size() * HAND_CARD.x + (_hand.size() - 1) * HAND_GAP
	var start := 190.0 + (900.0 - total) * 0.5
	for i in _hand.size():
		var card: CardData = _hand[i]
		var rect := Rect2(Vector2(start + i * (HAND_CARD.x + HAND_GAP), 512), HAND_CARD)
		var playable: bool = card.cost <= 5
		_panel(
			rect,
			Color(0.21, 0.18, 0.15, 1.0) if playable else Color(0.13, 0.13, 0.14, 1.0),
			Color(0.11, 0.1, 0.09, 1.0)
		)
		draw_rect(rect, UiPalette.BRASS_MID if playable else Color(0.25, 0.25, 0.27, 1.0), false, 2.0)
		var tint := Color(1, 1, 1, 1) if playable else Color(0.5, 0.5, 0.55, 1)
		if card.icon_upright != null:
			draw_texture_rect(
				card.icon_upright, Rect2(rect.position + Vector2(31, 22), Vector2(56, 56)), false, tint
			)
		draw_circle(
			rect.position + Vector2(18, 18), 15.0, MANA_BLUE if playable else Color(0.3, 0.3, 0.35)
		)
		_text(rect.position + Vector2(12, 25), str(card.cost), 19)
		_text(_centered(rect, card.display_name, 15, 96.0), card.display_name, 15, tint)
		var short := _short(card)
		_text(_centered(rect, short, 13, 116.0), short, 13, UiPalette.BRASS_HIGHLIGHT)
		# 手札では総量が場に出たときの体力になるため、体力の位置に総量を出す。
		_stat(Vector2(rect.end.x - 32, rect.end.y - 32), card.total_sand, HEALTH_RED)


func _short(card: CardData) -> String:
	var words: PackedStringArray = []
	for keyword in card.keywords:
		words.append(CardEnums.keyword_name(keyword))
	if not words.is_empty():
		return " ".join(words)
	if card.rules_text.is_empty():
		return "──"
	return "設置" if card.rules_text.begins_with("設置") else "反転"


func _draw_buttons() -> void:
	var end_turn := Rect2(1096, 440, 168, 64)
	_panel(end_turn, UiPalette.PANEL_AMBER_TOP, UiPalette.PANEL_AMBER_BOTTOM)
	draw_rect(end_turn, UiPalette.BRASS_HIGHLIGHT, false, 2.0)
	_text(end_turn.position + Vector2(30, 40), "ターン終了", 21, Color(0.1, 0.07, 0.03, 1))
	for i in 2:
		var rect := Rect2(1096 + i * 88, 520, 80, 40)
		_panel(rect, Color(0.2, 0.17, 0.15, 1.0), Color(0.11, 0.09, 0.08, 1.0))
		draw_rect(rect, UiPalette.BRASS_MID, false, 2.0)
		_text(rect.position + Vector2(20, 26), "ログ" if i == 0 else "投了", 16)


# --- 下地 ---------------------------------------------------------------


func _panel(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _text(pos: Vector2, value: String, font_size: int, color: Color = UiPalette.TEXT_OFFWHITE) -> void:
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
