class_name CardSoloMapScreen
extends Control
## ソロモードのステージ一覧(GameDesign.md 27章)。
##
## **v1は分岐しない1本道**のため、`CardPuzzlePickerScreen`と同じ「縦に並ぶ横長カード」の
## 形をそのまま使う(GameDesign.md 9章の一覧の規約に沿う)。見た目をツリー状の道に
## 作り込むのは、分岐を持たない間は優先度が低い将来の見た目の作り込みとして残す。

signal back_pressed
signal stage_selected(stage: SoloStageData)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const CARD_SIZE := Vector2(1232, 108)
const ACTION_SIZE := Vector2(132, 52)

var _list: VBoxContainer


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ソロモード")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	var scroll := ScrollContainer.new()
	scroll.position = LIST_RECT.position
	scroll.size = LIST_RECT.size
	scroll.custom_minimum_size = LIST_RECT.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.custom_minimum_size.x = LIST_RECT.size.x
	scroll.add_child(_list)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	var stages := SoloLibrary.all_stages()
	if stages.is_empty():
		var empty := EmptyState.new()
		empty.custom_minimum_size = LIST_RECT.size
		_list.add_child(empty)
		empty.show_message("まだステージがありません", "近日公開")
		return
	var uid := _uid()
	for stage in stages:
		_list.add_child(_make_card(stage, uid))


func _make_card(stage: SoloStageData, uid: String) -> Control:
	var cleared := SoloProgress.is_cleared(uid, stage.id)
	var unlocked := SoloLibrary.is_unlocked(stage, uid)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	panel.modulate = Color(1, 1, 1, 1) if unlocked else Color(1, 1, 1, 0.5)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(column)
	var title := Label.new()
	title.text = "%d. %s%s" % [stage.order, stage.display_name, "  ★" if cleared else ""]
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var detail := Label.new()
	if unlocked:
		detail.text = (
			"%s / %s%s" % [stage.kind_label(), stage.description, _reward_hint(stage, cleared)]
		)
	else:
		detail.text = "前のステージをクリアすると挑戦できます"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(detail)

	var button := CodedButton.make("挑戦", ACTION_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not unlocked
	button.pressed.connect(func() -> void: stage_selected.emit(stage))
	row.add_child(button)
	return panel


## 初回クリアの報酬を1行で添える。**クリア済みなら出さない**——解き直しでは
## 報酬が出ないため(GameDesign.md 27章)、二度と手に入らない額を見せ続けない。
func _reward_hint(stage: SoloStageData, cleared: bool) -> String:
	if cleared:
		return ""
	var parts: Array[String] = []
	if stage.reward_gold > 0:
		parts.append("+%d砂金" % stage.reward_gold)
	if not stage.reward_card_set_id.is_empty():
		parts.append(CardSetLibrary.display_name(stage.reward_card_set_id))
	if parts.is_empty():
		return ""
	return "(初回クリア: %s)" % ", ".join(parts)


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
