class_name CardPuzzlePickerScreen
extends Control
## リーサルパズルのステージ選択(GameDesign.md 24章)。
## 共通のレイアウト規約(GameDesign.md 9章)に従い、`ScreenHeader` と横2列のグリッドで組む。

signal back_pressed
signal stage_selected(stage: PuzzleStageData)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const GRID_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const COLUMNS := 2
const CARD_SIZE := Vector2(596, 108)

var _grid: GridContainer
var _empty: Label


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _build() -> void:
	add_child(ScreenBackdrop.new())
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("リーサルパズル")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	var scroll := ScrollContainer.new()
	scroll.position = GRID_RECT.position
	scroll.size = GRID_RECT.size
	scroll.custom_minimum_size = GRID_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)

	_empty = Label.new()
	_empty.text = "まだ問題がありません"
	_empty.position = GRID_RECT.position + Vector2(0, 40)
	_empty.visible = false
	add_child(_empty)


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var stages := PuzzleLibrary.all_stages()
	_empty.visible = stages.is_empty()
	var uid := _uid()
	for stage in stages:
		_grid.add_child(_make_card(stage, PuzzleProgress.is_cleared(uid, stage.id)))


## 1問ぶんの横長カード。**クリア済みは印だけで示す**——解けた問題を暗くして
## 選びにくくすると、解き直して確かめることができなくなる。
func _make_card(stage: PuzzleStageData, cleared: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title := Label.new()
	title.text = "%s%s" % [stage.title, "  ★" if cleared else ""]
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var hint := Label.new()
	hint.text = stage.hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(hint)

	var button := CodedButton.make("挑戦", Vector2(132, 52))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: stage_selected.emit(stage))
	row.add_child(button)
	return panel


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
