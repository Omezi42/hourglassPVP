class_name CardMatchMenu
extends RefCounted
## 縦画面の「メニュー」(GameDesign.md 9章「縦の対局画面」/ Architecture.md 4.7節)。
## ログ・エモート・投了を、メニューのボタンの下へ開くパネルへ縦に並べる。
## **ボタンの実体は横の行動の列のものを付け替えて使い**、押したときの処理を二重に持たない。
## 横ではボタンもパネルも出さない。

const PANEL_PADDING := 12.0
const ITEM_GAP := 10.0
const PANEL_GAP := 8.0
const CORNER_RADIUS := 12.0
const FRAME_WIDTH := 3.0

var _screen: CardMatchScreen
var _button: RoundActionButton
## パネルの外を押したら閉じるための透明な幕。
var _blocker: Control
var _panel: MenuPanel
var _portrait := false
## 付け替える前の、対局画面の子としての並び順(横へ戻すときに重なり順を変えないため)。
var _homes: Dictionary = {}


class MenuPanel:
	extends Control

	func _draw() -> void:
		var ci := get_canvas_item()
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, CORNER_RADIUS, 5)
		UiPaint.fill_gradient_polygon(
			ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
		)
		UiPaint.apply_grain(ci, rect, 0.06)
		UiPaint.draw_bevel(
			ci, points, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK, FRAME_WIDTH, false
		)


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_button = CardMatchBuild.add_round_button(
		screen, "メニュー", ActionColumnLayout.SMALL_DIAMETER, false
	)
	_button.visible = false
	_button.pressed.connect(toggle)
	_blocker = Control.new()
	_blocker.anchor_right = 1.0
	_blocker.anchor_bottom = 1.0
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	_blocker.gui_input.connect(_on_blocker_input)
	screen.add_child(_blocker)
	_panel = MenuPanel.new()
	_panel.visible = false
	screen.add_child(_panel)
	for item in _items():
		_homes[item] = item.get_index()
	# ログと投了は押したら閉じる。エモートは選択肢がパネルの脇へ開くため閉じない。
	screen._log_button.pressed.connect(close)
	screen._surrender_button.pressed.connect(close)


func _items() -> Array[Control]:
	return [_screen._log_button, _screen._emote.button, _screen._surrender_button]


## 向きに合わせてボタンを付け替える(`CardMatchArrange`)。
func apply(layout: CardMatchLayout) -> void:
	_portrait = layout.portrait
	close()
	CardMatchBuild.center_on(_button, layout.menu_center)
	var items := _items()
	if not _portrait:
		for item in items:
			if item.get_parent() != _screen:
				item.reparent(_screen, false)
				_screen.move_child(item, _homes[item])
		refresh()
		return
	var diameter := ActionColumnLayout.SMALL_DIAMETER
	var panel_size := Vector2(
		diameter + PANEL_PADDING * 2.0,
		diameter * items.size() + ITEM_GAP * (items.size() - 1) + PANEL_PADDING * 2.0
	)
	_panel.size = panel_size
	_panel.position = Vector2(
		layout.menu_center.x + diameter * 0.5 - panel_size.x,
		layout.menu_center.y + diameter * 0.5 + PANEL_GAP
	)
	for i in items.size():
		var item := items[i]
		if item.get_parent() != _panel:
			item.reparent(_panel, false)
		item.position = Vector2(PANEL_PADDING, PANEL_PADDING + i * (diameter + ITEM_GAP))
	_screen._emote.anchor_popup(_panel.position + _screen._emote.button.position)
	refresh()


## 縦の対局中だけ出す(マリガンと決着の後は、上に重なる幕やパネルが自分の操作を持つ)。
func refresh() -> void:
	var state := _screen.state
	var live := state != null and not state.is_match_over() and not state.mulligan_pending
	_button.visible = _portrait and _screen.interactive and live
	if not _button.visible:
		close()


func toggle() -> void:
	if _panel.visible:
		close()
		return
	_panel.visible = true
	_blocker.visible = true


func close() -> void:
	_panel.visible = false
	_blocker.visible = false
	_screen._emote.close_popup()


func _on_blocker_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed:
		close()
