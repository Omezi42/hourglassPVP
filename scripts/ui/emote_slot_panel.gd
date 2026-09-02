class_name EmoteSlotPanel
extends Control
## 所有しているエモートから、対局中に出す4つを選ぶモーダル
## (GameDesign.md 9章、Architecture.md 10.8)。
## アカウント画面のヘッダーの主アクションから開く。左カラムは既に埋まっており、
## ここへ4つの枠を足すと下端の保存ボタンを押し出すため、別のモーダルにしている。

signal saved

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_SIZE := Vector2(520, 470)

var _slots: Array[String] = []
## いま差し替えようとしている枠。-1 なら未選択。
var _active_slot := -1
var _slot_buttons: Array[Button] = []
var _list: VBoxContainer
var _message: Label
var _busy := false


func _ready() -> void:
	visible = false
	_build()


func open() -> void:
	_slots = AccountService.emote_slots()
	_active_slot = 0
	_message.text = "枠を選んでから、入れたいエモートを押してください。"
	_refresh()
	visible = true


func _refresh() -> void:
	for i in _slot_buttons.size():
		var id: String = _slots[i] if i < _slots.size() else ""
		var button := _slot_buttons[i]
		button.text = "%d. %s" % [i + 1, EmoteLibrary.get_emote_text(id)]
		button.add_theme_color_override(
			"font_color", UiPalette.GLOW_AMBER if i == _active_slot else UiPalette.TEXT_OFFWHITE
		)
	for child in _list.get_children():
		child.queue_free()
	for id in AccountService.owned_emote_ids():
		var used := _slots.has(id)
		var row := Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(0, 32)
		row.text = "%s%s" % ["● " if used else "○ ", EmoteLibrary.get_emote_text(id)]
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override(
			"font_color", UiPalette.TEXT_MUTED if used else UiPalette.TEXT_OFFWHITE
		)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(func() -> void: _assign(id))
		_list.add_child(row)


## 選んでいる枠へ入れる。既に別の枠に入っているものを選んだ場合は、その2つを入れ替える
## (同じエモートが2つの枠に並ぶと、4つのうち1つが無駄になる)。
func _assign(id: String) -> void:
	if _active_slot < 0 or _active_slot >= _slots.size():
		return
	var existing := _slots.find(id)
	if existing >= 0:
		_slots[existing] = _slots[_active_slot]
	_slots[_active_slot] = id
	_active_slot = (_active_slot + 1) % _slots.size()
	_refresh()


func _on_save_pressed() -> void:
	if _busy:
		return
	_busy = true
	_message.text = "保存しています…"
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var ok: bool = await AccountService.save_emote_slots(NetSession.client, uid, _slots)
	_busy = false
	if ok:
		saved.emit()
		visible = false
	else:
		_message.text = "保存できませんでした。接続を確認してください。"


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 中身の高さは所有数で変わるため、座標で中央へ置かず `CenterContainer` に任せる。
	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_caption("対局中に出すエモート(4つ)", 20, UiPalette.BRASS_HIGHLIGHT))
	for i in EmoteLibrary.SLOT_COUNT:
		var slot := Button.new()
		slot.flat = true
		slot.custom_minimum_size = Vector2(0, 30)
		slot.add_theme_font_size_override("font_size", 15)
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.pressed.connect(
			func() -> void:
				_active_slot = i
				_refresh()
		)
		column.add_child(slot)
		_slot_buttons.append(slot)
	column.add_child(_caption("所有しているエモート", 16, UiPalette.TEXT_OFFWHITE))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_message = _caption("", 14, UiPalette.TEXT_MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var save_button := CodedButton.make("保存", Vector2(160, 44))
	save_button.pressed.connect(_on_save_pressed)
	row.add_child(save_button)
	var close_button := CodedButton.make("閉じる", Vector2(160, 44))
	close_button.pressed.connect(func() -> void: visible = false)
	row.add_child(close_button)


func _caption(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
