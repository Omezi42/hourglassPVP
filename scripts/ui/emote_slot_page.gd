class_name EmoteSlotPage
extends VBoxContainer
## アカウント画面の「エモート」タブの中身(GameDesign.md 9章・14章)。
## 上に対局で出す4つの枠、下に所有しているエモートの一覧。入れ替えるたびに保存する。

## 保存の成否を画面の足元の1行へ伝える。
signal saved(ok: bool)

const SLOT_COLUMNS := 2
const SLOT_SIZE := Vector2(300, 46)
const SLOT_GAP := 12
const SLOT_FONT_SIZE := 15
const ROW_HEIGHT := 32
const ROW_FONT_SIZE := 15
const CAPTION_FONT_SIZE := 14

var _slots: Array[String] = []
## いま差し替えようとしている枠。
var _active_slot := 0
var _slot_buttons: Array[Button] = []
var _list: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(_caption("対局で出せる4つ(枠を選んでから、下の一覧で入れ替える)"))
	var grid := GridContainer.new()
	grid.columns = SLOT_COLUMNS
	grid.add_theme_constant_override("h_separation", SLOT_GAP)
	grid.add_theme_constant_override("v_separation", SLOT_GAP)
	add_child(grid)
	for i in EmoteLibrary.SLOT_COUNT:
		var slot := CodedButton.make("", SLOT_SIZE)
		slot.clip_text = true
		slot.add_theme_font_size_override("font_size", SLOT_FONT_SIZE)
		slot.pressed.connect(
			func() -> void:
				_active_slot = i
				_refresh()
		)
		grid.add_child(slot)
		_slot_buttons.append(slot)
	add_child(_caption("持っているエモート"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


## 画面を開くたび・アカウントが変わるたびに呼ぶ。
func reload() -> void:
	_slots = AccountService.emote_slots()
	_active_slot = 0
	_refresh()


func _refresh() -> void:
	for i in _slot_buttons.size():
		var id: String = _slots[i] if i < _slots.size() else ""
		var button := _slot_buttons[i]
		button.text = "%d. %s" % [i + 1, EmoteLibrary.get_emote_text(id)]
		var color := UiPalette.GLOW_AMBER if i == _active_slot else UiPalette.TEXT_OFFWHITE
		for slot in ["font_color", "font_hover_color"]:
			button.add_theme_color_override(slot, color)
	for child in _list.get_children():
		child.queue_free()
	for id in AccountService.owned_emote_ids():
		var used := _slots.has(id)
		var row := Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		row.text = "%s%s" % ["● " if used else "○ ", EmoteLibrary.get_emote_text(id)]
		row.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
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
	if _slots[_active_slot] == id:
		return
	var existing := _slots.find(id)
	if existing >= 0:
		_slots[existing] = _slots[_active_slot]
	_slots[_active_slot] = id
	_active_slot = (_active_slot + 1) % _slots.size()
	_refresh()
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var ok: bool = await AccountService.save_emote_slots(NetSession.client, uid, _slots)
	saved.emit(ok)


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	label.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	return label
