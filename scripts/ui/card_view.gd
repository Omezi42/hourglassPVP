class_name CardView
extends Control
## カード1枚の表示(GameDesign.md 9章「対局画面」)。盤面の砂時計と手札の両方に使う。
## 数値の配置は既存のDCGの慣習に合わせる:コスト=左上 / 攻撃力=左下 / 体力=右下。

signal pressed(view: CardView)

## 砂の動きの演出。**消える砂と落ちる砂は必ず描き分ける**(GameDesign.md 9章)。
## この2つを取り違えるとルールを誤解するため、演出上もっとも重要な区別として扱う。
enum Effect {
	NONE,
	## ダメージ。砂は消える(総量が減る)ので、砕けて外へ散る。
	SHATTER,
	## ターン終了の1粒。砂は落ちる(総量は変わらない)ので、下の部屋へ流れる。
	DROP,
}

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
## 選択中の枠。守護の真鍮色と取り違えないよう、別系統の色にする。
const SELECT_CYAN := Color(0.55, 0.9, 1.0, 1.0)
const SAND_AMBER := Color(0.93, 0.78, 0.42, 1.0)
const SHATTER_DURATION := 0.42
const DROP_DURATION := 0.45
const SHARD_COUNT := 9
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
## 右上へ出す小さな添え字(デッキ編集の「2/2」など)。空なら出さない。
var badge := ""

var _font: Font
var _hovering := false
var _tracker := PressTracker.new()
var _effect: int = Effect.NONE
var _effect_progress := 0.0
var _effect_amount := 0
var _effect_tween: Tween


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


## ダメージを受けた:砂が砕けて散る。
func play_shatter(amount: int) -> void:
	_effect_amount = amount
	_start_effect(Effect.SHATTER, SHATTER_DURATION)


## ターン終了の1粒:砂が下の部屋へ流れる。
func play_drop() -> void:
	_start_effect(Effect.DROP, DROP_DURATION)


func _start_effect(kind: int, duration: float) -> void:
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
	_effect = kind
	_effect_progress = 0.0
	_effect_tween = create_tween()
	_effect_tween.tween_method(_set_effect_progress, 0.0, 1.0, duration)
	_effect_tween.finished.connect(_on_effect_finished)


func _set_effect_progress(value: float) -> void:
	_effect_progress = value
	queue_redraw()


func _on_effect_finished() -> void:
	_effect = Effect.NONE
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
		border = SELECT_CYAN
	elif guard:
		border = UiPalette.BRASS_HIGHLIGHT
	draw_rect(rect, border, false, GUARD_BORDER if guard or selected else NORMAL_BORDER)
	_draw_art(rect, tint)
	if unit != null and unit.glass_intact:
		draw_rect(rect.grow(-4), Color(0.6, 0.85, 1.0, 0.13))
	_draw_labels(rect, tint)
	_draw_stats(rect)
	if _effect != Effect.NONE:
		_draw_effect(rect)
	if not badge.is_empty():
		_draw_badge(rect)
	if _hovering and enabled:
		draw_rect(rect, Color(1, 1, 1, 0.06))


func _draw_effect(rect: Rect2) -> void:
	if _effect == Effect.SHATTER:
		_draw_shatter(rect)
	else:
		_draw_drop(rect)


## 砕けて散る:カードの中心から破片が外へ飛び、赤みを帯びて消える。
func _draw_shatter(rect: Rect2) -> void:
	var center := rect.size * Vector2(0.5, 0.42)
	var fade := 1.0 - _effect_progress
	var reach := rect.size.x * (0.18 + 0.42 * _effect_progress)
	var shards: int = SHARD_COUNT + mini(_effect_amount, 6)
	for i in shards:
		var angle := TAU * float(i) / float(shards)
		var to := center + Vector2(cos(angle), sin(angle) * 0.8) * reach
		var shard_size := 4.0 * fade + 1.0
		draw_circle(to, shard_size, Color(0.95, 0.5, 0.4, fade * 0.9))
	draw_rect(rect, Color(1.0, 0.35, 0.3, fade * 0.18))


## 下の部屋へ流れる:カードの中央を細い砂の筋が下りていく。総量は変わらない。
func _draw_drop(rect: Rect2) -> void:
	var x := rect.size.x * 0.5
	var top := rect.size.y * 0.18
	var bottom := rect.size.y * 0.72
	var head: float = lerpf(top, bottom, _effect_progress)
	draw_line(Vector2(x, top), Vector2(x, head), Color(SAND_AMBER, 0.55), 3.0)
	for i in 3:
		var offset := float(i) * 6.0
		var y: float = head - offset
		if y < top:
			continue
		draw_circle(Vector2(x, y), 3.0 - i * 0.6, Color(SAND_AMBER, 0.9 - i * 0.25))
	if _effect_progress > 0.85:
		var glow := (_effect_progress - 0.85) / 0.15
		draw_circle(Vector2(x, bottom), 8.0 * glow, Color(SAND_AMBER, 0.35 * (1.0 - glow)))


func _draw_badge(rect: Rect2) -> void:
	var width := _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
	var chip := Rect2(rect.size.x - width - 4, 4, width, 22)
	draw_rect(chip, Color(0.08, 0.07, 0.06, 0.92))
	draw_rect(chip, UiPalette.BRASS_HIGHLIGHT, false, 1.0)
	draw_string(
		_font,
		chip.position + Vector2(6, 17),
		badge,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		UiPalette.BRASS_HIGHLIGHT
	)


func _draw_empty() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color := SELECT_CYAN if selected else Color(0.3, 0.28, 0.3, 0.5)
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
