class_name StatusBadge
extends Control
## 文言の横へ添える丸い印(GameDesign.md 11章)。
##
## **押すものではなく、読むためのもの**として作る。募集をDiscordへ知らせたことのように
## 「起きたが、待っている人にできることは無い」出来事は、待機中の文言へ混ぜると
## 読ませる価値のない一文が居座る。印だけを置き、**知りたい人がカーソルを乗せた
## ときにだけ**説明を出す。
##
## 説明はGodotの標準のツールチップ(`tooltip_text`)へ委ねる。専用のパネルを作ると
## 画面ごとに出方が違うものが増えるため。
## タッチでは同じ見た目の説明を印の下へ出す(乗せる操作が無いため)。別の場所に触れたら消す。

const DIAMETER := 22.0
const MARK := "!"
const MARK_FONT_SIZE := UiPalette.T_BODY
## 円の中で「!」が上寄りに見えるため、視覚的な中心へ寄せる下駄。
const MARK_BASELINE_RATIO := 0.72
## 触れて反応する範囲を、描く円の外へ広げる幅。
const TOUCH_SLOP := 12.0
## 印の下端から説明の上端まで。
const NOTE_GAP := 8.0
## 説明を画面の左右端から離す幅。
const NOTE_SCREEN_MARGIN := 16.0
const NOTE_Z_INDEX := 1

var _hovered := false
var _note: PanelContainer
var _note_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	visibility_changed.connect(hide_touch_note)
	visible = false
	_note = PanelContainer.new()
	_note.top_level = true
	_note.visible = false
	_note.z_index = NOTE_Z_INDEX
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_theme_stylebox_override("panel", get_theme_stylebox("panel", "TooltipPanel"))
	_note_label = Label.new()
	_note_label.theme_type_variation = "TooltipLabel"
	_note_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_note.add_child(_note_label)
	add_child(_note)
	set_process_input(false)


## 印を出し、カーソルを乗せたときに出す説明を差し替える。
func show_note(note: String) -> void:
	tooltip_text = note
	visible = true


func clear_note() -> void:
	visible = false
	hide_touch_note()


## 触れて出した説明を消す(説明が出ていなければ何もしない)。
func hide_touch_note() -> void:
	if _note == null or not _note.visible:
		return
	_note.visible = false
	set_process_input(false)
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= DIAMETER * 0.5 + TOUCH_SLOP


func _gui_input(event: InputEvent) -> void:
	TouchInput.note(event)
	if TouchInput.active and _is_press(event):
		_show_touch_note()
		accept_event()


## 説明を出している間だけ、印の外への押下を見て消す。イベントは消費しない(触れたボタンも普通に押せる)。
func _input(event: InputEvent) -> void:
	if _is_press(event) and not _has_point(make_input_local(event).position):
		hide_touch_note()


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return false


func _show_touch_note() -> void:
	_note_label.text = tooltip_text
	_note_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_note_label.custom_minimum_size.x = 0.0
	var max_width := get_viewport_rect().size.x - NOTE_SCREEN_MARGIN * 2.0
	if _note.get_combined_minimum_size().x > max_width:
		_note_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_note_label.custom_minimum_size.x = max_width - _note_inset()
	_note.reset_size()
	var note_size := _note.get_combined_minimum_size()
	var center := get_global_rect().get_center()
	var left := clampf(
		center.x - note_size.x * 0.5,
		NOTE_SCREEN_MARGIN,
		maxf(NOTE_SCREEN_MARGIN, get_viewport_rect().size.x - NOTE_SCREEN_MARGIN - note_size.x)
	)
	_note.global_position = Vector2(left, get_global_rect().position.y + DIAMETER + NOTE_GAP)
	_note.modulate.a = 0.0
	_note.visible = true
	create_tween().tween_property(_note, "modulate:a", 1.0, UiPalette.DUR_SHOW)
	set_process_input(true)
	queue_redraw()


## パネルの余白(左右の合計)。折り返す幅からこれを引いて、パネル全体を上限に収める。
func _note_inset() -> float:
	var panel := _note.get_theme_stylebox("panel")
	return panel.get_minimum_size().x


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := DIAMETER * 0.5
	UiKit.round_face(
		get_canvas_item(),
		center,
		radius,
		UiKit.Role.SUB,
		0.0,
		1.0 if _hovered or (_note != null and _note.visible) else 0.0
	)
	var font := get_theme_default_font()
	if font == null:
		return
	var mark_size := font.get_string_size(MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE)
	var origin := Vector2(
		center.x - mark_size.x * 0.5, DIAMETER * MARK_BASELINE_RATIO + radius * 0.28
	)
	draw_string(font, origin, MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE, UiPalette.GOLD)
