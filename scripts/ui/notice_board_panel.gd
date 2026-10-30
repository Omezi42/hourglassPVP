class_name NoticeBoardPanel
extends Control
## お知らせとプレゼント(GameDesign.md 33章 / Architecture.md 10.22節)。ホームへ重ねる「暗幕+中央パネル」のモーダル
## (`DailyMissionPanel` と同じ作り)。上に2つのタブ、お知らせは左に回の一覧・右に本文、プレゼントは `NoticeGiftList`。
## 開いた時点でお知らせは全部読んだことにする。

signal closed
signal reward_claimed(from_rect: Rect2, amount: int)

enum Tab { NOTICES, GIFTS }

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(980, 620)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const TAB_SIZE := Vector2(200, 48)
const CLOSE_SIZE := Vector2(180, 48)
const LIST_WIDTH := 210.0
const ENTRY_SIZE := Vector2(190, 44)
const BODY_FONT := 18
const HEADING_FONT := 22
## 縦(GameDesign.md 9章「縦画面」)。`PortraitModal` の論理幅で組み、回の一覧は本文の上へ積む。
const PORTRAIT_PANEL_SIZE := Vector2(PortraitModal.WIDTH, 880)
const PORTRAIT_TAB_SIZE := Vector2(190, 56)
const PORTRAIT_CLOSE_SIZE := Vector2(180, 56)
const PORTRAIT_LIST_HEIGHT := 150.0
const PORTRAIT_BODY_FONT := 17
const PORTRAIT_HEADING_FONT := 20
const UNREAD_MARK := "● "
const EMPTY_TEXT := "まだお知らせはありません"

var _dim: ColorRect
var _panel: PanelContainer
var _tabs: Array[Button] = []
var _notices: BoxContainer
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _body: RichTextLabel
var _gifts: NoticeGiftList
var _close: Button
var _tab := Tab.NOTICES
var _selected: AnnouncementData
## 開いた時点の未読(開くと既読にするため、印は開く前の状態で描く)。
var _unread: Array[AnnouncementData] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(self, _layout)


## 受け取っていないプレゼントがあれば「プレゼント」、無ければ「お知らせ」を選んで開く。
func open() -> void:
	_unread.clear()
	for entry in AnnouncementLibrary.all():
		if AnnouncementLibrary.is_unread(entry):
			_unread.append(entry)
	AnnouncementLibrary.mark_all_read()
	var entries := AnnouncementLibrary.all()
	_selected = entries[0] if not entries.is_empty() else null
	var has_gift := GiftLibrary.unclaimed_count(DailyMissionService.today()) > 0
	_tab = Tab.GIFTS if has_gift else Tab.NOTICES
	_layout()
	_refresh()
	visible = true


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_panel = PanelContainer.new()
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 12)
	box.add_child(tab_row)
	for tab in [Tab.NOTICES, Tab.GIFTS]:
		var button := CodedButton.make("お知らせ" if tab == Tab.NOTICES else "プレゼント", TAB_SIZE)
		button.pressed.connect(func() -> void: _select_tab(tab))
		tab_row.add_child(button)
		_tabs.append(button)

	_notices = BoxContainer.new()
	_notices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notices.add_theme_constant_override("separation", 16)
	box.add_child(_notices)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_notices.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list_scroll.add_child(_list)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", UiPalette.TEXT_OFFWHITE)
	_notices.add_child(_body)

	_gifts = NoticeGiftList.new()
	_gifts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gifts.reward_claimed.connect(
		func(rect: Rect2, amount: int) -> void: reward_claimed.emit(rect, amount)
	)
	_gifts.claimed.connect(_refresh_tabs)
	box.add_child(_gifts)

	_close = CodedButton.make("とじる", CLOSE_SIZE)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(_on_close)
	box.add_child(_close)


func _layout() -> void:
	var portrait := ScreenOrientation.is_portrait()
	var panel_size := PORTRAIT_PANEL_SIZE if portrait else PANEL_SIZE
	size = PortraitModal.screen_size()
	_dim.size = size
	_notices.vertical = portrait
	_list_scroll.custom_minimum_size = (
		Vector2(0, PORTRAIT_LIST_HEIGHT) if portrait else Vector2(LIST_WIDTH, 0)
	)
	for button in _tabs:
		button.custom_minimum_size = PORTRAIT_TAB_SIZE if portrait else TAB_SIZE
	_close.custom_minimum_size = PORTRAIT_CLOSE_SIZE if portrait else CLOSE_SIZE
	_body.add_theme_font_size_override("normal_font_size", _body_font())
	_panel.size = panel_size
	_panel.position = (size - panel_size) * 0.5
	PortraitModal.fit(_panel)


func _refresh() -> void:
	_notices.visible = _tab == Tab.NOTICES
	_gifts.visible = _tab == Tab.GIFTS
	_refresh_tabs()
	if _tab == Tab.GIFTS:
		_gifts.refresh()
		return
	for child in _list.get_children():
		child.queue_free()
	for entry in AnnouncementLibrary.all():
		_list.add_child(_make_entry(entry))
	_show_body()


## 選んでいるタブを真鍮の面、もう一方を凹んだ面にする(GameDesign.md 9章「入口の強弱」)。
## プレゼントのタブには受け取っていない件数を添える。
func _refresh_tabs() -> void:
	var count := GiftLibrary.unclaimed_count(DailyMissionService.today())
	_tabs[Tab.GIFTS].text = "プレゼント(%d)" % count if count > 0 else "プレゼント"
	for tab in _tabs.size():
		CodedButton.apply_styles(
			_tabs[tab], CodedButton.PRIMARY_ACTION_GROUP if tab == _tab else CodedButton.WIDE_GROUP
		)


func _make_entry(entry: AnnouncementData) -> Button:
	var mark := UNREAD_MARK if _unread.has(entry) else ""
	var button := CodedButton.make(mark + entry.version, ENTRY_SIZE)
	if entry == _selected:
		CodedButton.apply_styles(button, CodedButton.PRIMARY_ACTION_GROUP)
	button.pressed.connect(
		func() -> void:
			_selected = entry
			_refresh()
	)
	return button


func _show_body() -> void:
	if _selected == null:
		_body.text = EMPTY_TEXT
		return
	var heading := PORTRAIT_HEADING_FONT if ScreenOrientation.is_portrait() else HEADING_FONT
	_body.text = AnnouncementText.to_bbcode(_selected.body, heading, UiPalette.BRASS_HIGHLIGHT)
	_body.scroll_to_line(0)


func _select_tab(tab: Tab) -> void:
	_tab = tab
	_refresh()


func _body_font() -> int:
	return PORTRAIT_BODY_FONT if ScreenOrientation.is_portrait() else BODY_FONT


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_close()


func _on_close() -> void:
	visible = false
	closed.emit()
