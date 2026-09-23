class_name CardMatchDamageAssist
extends Control
## 盤面総攻撃力(打点アシスト)表示(GameDesign.md 9章)。
## 自陣の即時攻撃可能な総打点を算出し、相手の守護の有無やリーサル(トドメ)の
## 機会をひと目で把握できるように支援する。
##
## **相手の情報帯のHPの器の右隣へ、枠を持たない文字として置く**(GameDesign.md 9章
## 「対局画面の見た目」)。枠で囲うとボタンに見えるため、山の札と同じ「見出し + 数字」の語彙で彫る。

const AREA_SIZE := Vector2(150, PlayerInfoBar.BAR_HEIGHT)
## HPの器のバッジの右端からの余白。
const HP_GAP := 14.0
const LABEL_BASELINE := 22.0
const VALUE_BASELINE := 46.0
const LABEL_FONT_SIZE := 11
const VALUE_FONT_SIZE := 21
const NOTE_FONT_SIZE := 13
const NOTE_GAP := 8.0
const LETHAL_PULSE_SPEED := 0.01

var _screen: CardMatchScreen
var _font: Font
var _total_attack := 0
var _has_guard := false
var _is_lethal := false
var _ready_count := 0


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = TextGlyphs.ui_font()
	custom_minimum_size = AREA_SIZE
	size = AREA_SIZE
	var bar := _screen.foe_bar
	var hp := bar.hp_bar_rect()
	position = bar.position + Vector2(hp.end.x + PlayerInfoBar.HP_BADGE_RADIUS + HP_GAP, 0.0)


func _process(_delta: float) -> void:
	if visible and _is_lethal:
		queue_redraw()


func sync() -> void:
	var state := _screen.state
	if state == null or state.is_match_over() or not _screen.is_interactive():
		visible = false
		return

	if state.current_turn != _screen.my_side:
		visible = false
		return

	_total_attack = 0
	_ready_count = 0
	var my_side := _screen.my_side
	var foe_side := MatchState.other_side(my_side)

	for i in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[my_side][i]
		if unit != null and unit.can_attack():
			# 連撃は1ターンに2回殴れるため、残りの回数ぶんを数える。
			var swings: int = maxi(unit.max_attacks() - unit.attacks_this_turn, 0)
			_total_attack += unit.attack * swings
			_ready_count += 1

	_has_guard = false
	for i in MatchState.BOARD_SIZE:
		var foe_unit: CardInstance = state.board[foe_side][i]
		if foe_unit != null and foe_unit.has_keyword(CardEnums.Keyword.GUARD):
			_has_guard = true
			break

	var foe_hp: int = state.hp[foe_side]
	_is_lethal = not _has_guard and _total_attack >= foe_hp and foe_hp > 0

	visible = _ready_count > 0 or _total_attack > 0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var label := "総打点" if _has_guard else "直接打点"
	_text(Vector2(0, LABEL_BASELINE), label, LABEL_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	var value := str(_total_attack)
	var value_color := UiPalette.GLOW_AMBER
	if _has_guard:
		value_color = UiPalette.TEXT_MUTED
	_text(Vector2(0, VALUE_BASELINE), value, VALUE_FONT_SIZE, value_color)
	var note_x := (
		_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE).x + NOTE_GAP
	)
	if _is_lethal:
		var pulse := (sin(Time.get_ticks_msec() * LETHAL_PULSE_SPEED) + 1.0) * 0.5
		var color := UiPalette.GLOW_AMBER.lerp(UiPalette.BRASS_HIGHLIGHT, pulse)
		_text(Vector2(note_x, VALUE_BASELINE - 2.0), "決着可能", NOTE_FONT_SIZE, color)
	elif _has_guard:
		_text(Vector2(note_x, VALUE_BASELINE - 2.0), "守護あり", NOTE_FONT_SIZE, UiPalette.TEXT_MUTED)


## 砂の上でも床の上でも読めるよう、暗い影を1pxずらして敷く(情報帯の数字と同じ)。
func _text(pos: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(
		_font,
		pos + Vector2.ONE,
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		PlayerInfoBar.TEXT_SHADOW
	)
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
