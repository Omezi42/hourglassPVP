class_name CardSpectateListScreen
extends Control
## ランクマッチの観戦一覧(GameDesign.md 12章、Architecture.md 7.2節)。入口はたたかうタブの「観戦」。
## 開いたときと「更新」を押したときに読み直す。

signal back_pressed
signal spectate_requested(match_id: String)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_RECT := Rect2(140, ScreenHeader.CONTENT_TOP, 1000, ScreenHeader.CONTENT_HEIGHT)
const PAD := Vector2(24, 20)
const ROW_GAP := 8
const REFRESH_SIZE := Vector2(140, 44)

var _scroll: ScrollContainer
var _rows: VBoxContainer
var _empty: EmptyState
var _refresh_button: Button
var _fetching := false


func _ready() -> void:
	_build()


func open() -> void:
	_fetch()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("観戦")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	_refresh_button = CodedButton.make("更新", REFRESH_SIZE)
	_refresh_button.pressed.connect(_fetch)
	header.add_action(_refresh_button)

	var panel := Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	add_child(panel)

	var inner := Rect2(PANEL_RECT.position + PAD, PANEL_RECT.size - PAD * 2.0)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = inner.position
	_scroll.size = inner.size
	TouchScroll.enable(_scroll)
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(_rows)

	_empty = EmptyState.new()
	_empty.position = inner.position
	_empty.size = inner.size
	_empty.visible = false
	add_child(_empty)


func _fetch() -> void:
	if _fetching:
		return
	for child in _rows.get_children():
		child.queue_free()
	_empty.visible = true
	if NetSession.client == null or not await NetSession.sign_in():
		_empty.show_message("対局を取得できませんでした", "通信状況を確認してください")
		return
	_fetching = true
	_refresh_button.disabled = true
	_empty.show_message("対局を探しています", "", true)
	var entries: Array[Dictionary] = await LiveMatchService.list_live(NetSession.client)
	_fetching = false
	_refresh_button.disabled = false
	if entries.is_empty():
		_empty.show_message("いま行われている対局はありません", "")
		return
	_empty.visible = false
	for entry in entries:
		var row := SpectateMatchRow.new()
		row.match_id = entry["match_id"]
		row.turn = entry["turn"]
		row.player_a = entry["a"]
		row.player_b = entry["b"]
		row.pressed.connect(func() -> void: spectate_requested.emit(row.match_id))
		_rows.add_child(row)
	ListRevealFx.stagger(_rows.get_children())
