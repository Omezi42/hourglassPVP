class_name AccountLooksTabs
extends VBoxContainer
## アカウント画面の右カラム(GameDesign.md 14章)。「アイコン / 称号 / プレイマット / エモート」の4つのタブ。
## 所有しているものだけを並べ、選ばれたら通知する。保存は画面側が持つ(エモートだけは枠を自分で保存する)。

signal icon_selected(icon_id: String)
signal title_selected(title_id: String)
signal playmat_selected(mat_id: String)
signal emote_saved(ok: bool)

enum Tab { ICON, TITLE, PLAYMAT, EMOTE }

const TAB_LABELS: Array[String] = ["アイコン", "称号", "プレイマット", "エモート"]
const TAB_SIZE := Vector2(140, 46)
const TAB_GAP := 10
const ICON_COLUMNS := 6
const MAT_COLUMNS := 3
const GRID_GAP := 14
const TITLE_GAP := 8

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _icon_grid: GridContainer
var _title_list: VBoxContainer
var _mat_grid: GridContainer
var _emote_page: EmoteSlotPage


func _ready() -> void:
	add_theme_constant_override("separation", GRID_GAP)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", TAB_GAP)
	add_child(tab_row)
	for i in TAB_LABELS.size():
		var button := CodedButton.make(TAB_LABELS[i], TAB_SIZE)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: select_tab(i))
		tab_row.add_child(button)
		_tab_buttons.append(button)

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_icon_grid = _grid(ICON_COLUMNS)
	_title_list = VBoxContainer.new()
	_title_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_list.add_theme_constant_override("separation", TITLE_GAP)
	_mat_grid = _grid(MAT_COLUMNS)
	_emote_page = EmoteSlotPage.new()
	_emote_page.saved.connect(func(ok: bool) -> void: emote_saved.emit(ok))
	_pages = [_scroll(_icon_grid), _scroll(_title_list), _scroll(_mat_grid), _emote_page]
	for page in _pages:
		page.anchor_right = 1.0
		page.anchor_bottom = 1.0
		body.add_child(page)
	select_tab(Tab.ICON)


func select_tab(index: int) -> void:
	for i in _tab_buttons.size():
		var active := i == index
		_tab_buttons[i].set_pressed_no_signal(active)
		var color := UiPalette.GLOW_AMBER if active else UiPalette.TEXT_OFFWHITE
		for slot in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			_tab_buttons[i].add_theme_color_override(slot, color)
		_pages[i].visible = active


## 所有しているものを並べ直す。画面を開くたび・アカウントが変わるたびに呼ぶ。
func reload(icon_id: String, title_id: String, mat_id: String) -> void:
	_clear(_icon_grid)
	for id in AccountService.owned_icon_ids():
		var tile := IconTile.new(id)
		tile.pressed.connect(func() -> void: icon_selected.emit(id))
		_icon_grid.add_child(tile)
	_clear(_title_list)
	for id in _owned_title_ids():
		var row := TitleRow.new(id)
		row.pressed.connect(func() -> void: title_selected.emit(id))
		_title_list.add_child(row)
	_clear(_mat_grid)
	for id in AccountService.owned_playmat_ids():
		var tile := MatTile.new(id)
		tile.pressed.connect(func() -> void: playmat_selected.emit(id))
		_mat_grid.add_child(tile)
	_emote_page.reload()
	mark_selected(icon_id, title_id, mat_id)


func mark_selected(icon_id: String, title_id: String, mat_id: String) -> void:
	for tile in _icon_grid.get_children():
		_mark(tile, tile.get("icon_id") == icon_id)
	for row in _title_list.get_children():
		_mark(row, row.get("title_id") == title_id)
	for tile in _mat_grid.get_children():
		_mark(tile, tile.get("mat_id") == mat_id)


## 誰でも選べる初期の2つ + 所有を絞る称号(掲示板〈ラボ〉採用の「発案者」など)。
func _owned_title_ids() -> Array:
	var ids: Array = UserProfileLibrary.get_available_title_ids().duplicate()
	for id in AccountService.owned_titles():
		if not ids.has(id):
			ids.append(id)
	return ids


func _mark(node: Node, selected: bool) -> void:
	if node.is_queued_for_deletion():
		return
	node.set("is_selected", selected)
	(node as CanvasItem).queue_redraw()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	return grid


func _scroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	scroll.add_child(content)
	return scroll


## アイコン1つ。対局の肖像のメダルと同じく、暗い円にアイコンを嵌めて真鍮の輪で囲む。
class IconTile:
	extends Button

	const TILE := 88.0
	const RING_INSET := 4.0
	const ICON_INSET := 8.0
	const RING_WIDTH := 2.0
	const SELECTED_RING_WIDTH := 3.0
	const HALO_GAP := 3.0
	const HALO_COLOR := Color(1.0, 0.84, 0.4, 0.4)
	const SEGMENTS := 40

	var icon_id: String
	var is_selected := false

	func _init(p_icon_id: String) -> void:
		icon_id = p_icon_id
		flat = true
		custom_minimum_size = Vector2(TILE, TILE)
		tooltip_text = UserProfileLibrary.get_icon_name(p_icon_id)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var ci := get_canvas_item()
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - RING_INSET
		UiPaint.fill_circle(ci, center, radius, Color(0.05, 0.04, 0.03, 1.0), SEGMENTS)
		var tex := UserProfileLibrary.get_icon_texture(icon_id)
		if tex != null:
			var r := radius - ICON_INSET
			draw_texture_rect(tex, Rect2(center - Vector2.ONE * r, Vector2.ONE * r * 2.0), false)
		if is_selected:
			UiPaint.draw_ring(
				ci, center, radius, UiPalette.GLOW_AMBER, SELECTED_RING_WIDTH, SEGMENTS
			)
			UiPaint.draw_ring(ci, center, radius + HALO_GAP, HALO_COLOR, 1.2, SEGMENTS)
		else:
			var ring := UiPalette.BRASS_LIGHT if is_hovered() else UiPalette.BRASS_MID
			UiPaint.draw_ring(ci, center, radius, ring, RING_WIDTH, SEGMENTS)


## 称号1行。
class TitleRow:
	extends Button

	const HEIGHT := 46
	const RADIUS := 5.0
	const TEXT_X := 18.0
	const FONT_SIZE := 17
	const BASELINE_OFFSET := 6.0

	var title_id: String
	var is_selected := false

	func _init(p_title_id: String) -> void:
		title_id = p_title_id
		flat = true
		custom_minimum_size = Vector2(0, HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, RADIUS, 4)
		var top := Color(0.18, 0.15, 0.12, 0.92) if is_selected else Color(0.1, 0.08, 0.07, 0.8)
		var bottom := Color(0.12, 0.1, 0.08, 0.92) if is_selected else Color(0.06, 0.05, 0.04, 0.8)
		UiPaint.fill_gradient_polygon(get_canvas_item(), points, rect, [[0.0, top], [1.0, bottom]])
		var outline := points.duplicate()
		outline.append(points[0])
		var border := UiPalette.BRASS_DARK
		if is_selected:
			border = UiPalette.GLOW_AMBER
		elif is_hovered():
			border = UiPalette.BRASS_LIGHT
		draw_polyline(outline, border, 1.5 if is_selected else 1.0, true)
		var font := get_theme_default_font()
		var text := ("◆ " if is_selected else "    ") + UserProfileLibrary.get_title_name(title_id)
		var color := UiPalette.GLOW_AMBER if is_selected else UiPalette.TEXT_OFFWHITE
		draw_string(
			font,
			Vector2(TEXT_X, size.y * 0.5 + BASELINE_OFFSET),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SIZE,
			color
		)


## プレイマット1枚。見本は盤面と同じ `PlaymatPaint` を通す(選ぶ絵と敷かれる絵を食い違わせない)。
class MatTile:
	extends Button

	const TILE := Vector2(196, 140)
	const LABEL_HEIGHT := 28.0
	const SWATCH_INSET := 5.0
	const FONT_SIZE := 16
	const LABEL_BASELINE := 6.0

	var mat_id: String
	var is_selected := false

	func _init(p_mat_id: String) -> void:
		mat_id = p_mat_id
		flat = true
		# 模様は矩形の外まで伸びる。見本でも必ず切り抜く(BoardTable と同じ理由)。
		clip_contents = true
		custom_minimum_size = TILE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var swatch := Rect2(0, 0, size.x, size.y - LABEL_HEIGHT)
		draw_rect(swatch, UiPalette.BOARD_TABLE_FILL)
		PlaymatPaint.draw_mat(self, swatch.grow(-SWATCH_INSET), mat_id)
		var border := UiPalette.BRASS_DARK
		if is_selected:
			border = UiPalette.GLOW_AMBER
		elif is_hovered():
			border = UiPalette.BRASS_LIGHT
		draw_rect(swatch, border, false, 3.0 if is_selected else 1.4)
		var color := UiPalette.GLOW_AMBER if is_selected else UiPalette.TEXT_OFFWHITE
		draw_string(
			get_theme_default_font(),
			Vector2(0, size.y - LABEL_BASELINE),
			PlaymatLibrary.display_name(mat_id),
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			FONT_SIZE,
			color
		)
