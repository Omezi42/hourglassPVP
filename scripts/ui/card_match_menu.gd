class_name CardMatchMenu
extends RefCounted
## 縦画面の「メニュー」(GameDesign.md 9章「縦の対局画面」/ Architecture.md 4.7節)。
## ログ・エモート・投了(誘導対局ではスキップ)を、メニューのボタンの下へ開くパネルへ大きな横長のボタンで縦に並べる。
## **押したときの処理は横の行動の列のボタンと同じ関数を呼ぶだけ**にし、出す・押せるかも元のボタンから写す。
## 横ではボタンもパネルも出さない。

const PANEL_PADDING := 14.0
const ITEM_GAP := 12.0
const PANEL_GAP := 8.0
const CORNER_RADIUS := 12.0
const FRAME_WIDTH := 3.0
const ITEM_SIZE := Vector2(260, 68)
const ITEM_FONT_SIZE := 28

var _screen: CardMatchScreen
var _button: RoundActionButton
## パネルの外を押したら閉じるための透明な幕。
var _blocker: Control
var _panel: MenuPanel
var _portrait := false
var _log_item: Button
var _emote_item: Button
var _surrender_item: Button
var _skip_item: Button


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
	_button.emblem = UiPaint.Emblem.MENU
	_button.visible = false
	_button.pressed.connect(toggle)
	# ボタンだけはマリガン・結果パネル・ログの暗幕より背面へ(直前の手の列の直後)。
	screen.move_child(_button, screen._history.get_index() + 1)
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
	_log_item = _add_item("ログ", func() -> void: screen._log.set_open(true))
	_emote_item = _add_item("エモート", func() -> void: screen._emote.toggle_popup())
	_surrender_item = _add_item("投了", screen._on_surrender_pressed)
	_skip_item = _add_item("スキップ", func() -> void: screen._tutorial.request_skip())


## 押したら閉じる(エモートは選択肢がパネルの脇へ開くため閉じない)。
func _add_item(label: String, action: Callable) -> Button:
	var item := CodedButton.make(label, ITEM_SIZE)
	item.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	item.pressed.connect(
		func() -> void:
			if item != _emote_item:
				close()
			action.call()
	)
	_panel.add_child(item)
	return item


## 向きに合わせて置く(`CardMatchArrange`)。
func apply(layout: CardMatchLayout) -> void:
	_portrait = layout.portrait
	close()
	_button.scale = Vector2.ONE * layout.button_scale
	CardMatchBuild.center_on(_button, layout.menu_center)
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
	_sync_items()
	_panel.visible = true
	_blocker.visible = true


## 出す項目と押せるかを元のボタンから写し、出す項目だけを詰めて並べる。
func _sync_items() -> void:
	var emote := _screen._emote.button
	_log_item.visible = _screen._log_button.visible
	_emote_item.visible = emote.visible
	_emote_item.disabled = emote.disabled
	_emote_item.text = "エモート" if emote.badge.is_empty() else "エモート(%s)" % emote.badge
	_surrender_item.visible = _screen._surrender_button.visible
	_skip_item.visible = _screen._tutorial.visible
	var y := PANEL_PADDING
	for item: Button in [_log_item, _emote_item, _surrender_item, _skip_item]:
		item.size = ITEM_SIZE
		if not item.visible:
			continue
		item.position = Vector2(PANEL_PADDING, y)
		y += ITEM_SIZE.y + ITEM_GAP
	_panel.size = Vector2(ITEM_SIZE.x + PANEL_PADDING * 2.0, y - ITEM_GAP + PANEL_PADDING)
	var button_rect := Rect2(_button.position, _button.size * _button.scale)
	_panel.position = Vector2(button_rect.end.x - _panel.size.x, button_rect.end.y + PANEL_GAP)
	_screen._emote.anchor_popup(_panel.position + _emote_item.position)
	_panel.queue_redraw()


func close() -> void:
	_panel.visible = false
	_blocker.visible = false
	_screen._emote.close_popup()


func _on_blocker_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed:
		close()
