class_name CardDeckCase
extends ClickArea
## デッキ一覧の札1枚(GameDesign.md 9章「デッキ一覧」)。左に棚板へ立てた砂時計、右にデッキ名と要約。
## `new_slot` を立てると、一覧の最後に置く点線の「新しいデッキを作る」の枠として描く
## (並びの大きさと押し心地を札とそろえるため、同じクラスで持つ)。
## 絵と文字は `VisualRoot`(`ClickArea` がホバーで浮かせる子)へ描き、ボタンもそこへ置く。

signal list_pressed
signal delete_pressed
signal move_pressed(offset: int)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## 砂術を除き、コストの高い順に並べる本数。先頭の1本だけを大きく描く。
const HERO_COUNT := 4
## 縦は文字を大きくするぶん、本数を減らして名前と要約の幅を空ける。
const PORTRAIT_HERO_COUNT := 3
## 棚の幅と、札の背丈から引いて砂時計の背丈を決める量(大きい1本 / 残り)。
const SHOWCASE_WIDTH := 236.0
const HERO_INSET := 34.0
const SIDE_INSET := 56.0
## 次の砂時計を置く間隔(手前の絵の幅に対する比)。少し重ねて棚に詰める。
const HERO_STEP := 0.86
const SIDE_STEP := 0.78
const PLANK_HEIGHT := 16.0
const FLOOR_MARGIN := 18.0
const EDGE := 18.0
const TEXT_GAP := 22.0
const NAME_FONT := 28
const SUMMARY_FONT := 17
const NAME_RISE := 18.0
const SUMMARY_DROP := 10.0
const SHADOW_COLOR := Color(0, 0, 0, 0.45)
const SHADOW_HEIGHT := 4.0
const SHADOW_SPREAD := 0.36
const BUTTON_HEIGHT := 40.0
const BUTTON_GAP := 8.0
const LIST_BUTTON_WIDTH := 84.0
const DELETE_BUTTON_WIDTH := 72.0
const MOVE_BUTTON_WIDTH := 52.0
## 「前回」の札。
const TAG_FONT := 15
const TAG_HEIGHT := 26.0
const TAG_PAD := 20.0
const TAG_TOP := Color(0.95, 0.80, 0.45)
const TAG_BOTTOM := Color(0.70, 0.52, 0.22)
const TAG_TEXT := Color(0.25, 0.15, 0.05)
const TAG_TEXT_DROP := 7.0
## 新規作成の枠。
const SLOT_FILL := Color(0.05, 0.03, 0.02, 0.45)
const SLOT_LINE := Color(0.78, 0.64, 0.40, 0.7)
const SLOT_DASH := 10.0
const SLOT_RADIUS := 12.0
const SLOT_INSET := 3.0
const SLOT_FONT := 22
const SLOT_TEXT := Color(0.92, 0.84, 0.68)
const PLUS_RADIUS := 16.0
const PLUS_ARM := 8.0
const PLUS_FILL := Color(0.78, 0.64, 0.40, 0.25)
const PLUS_LINE := Color(0.95, 0.82, 0.55)
const PLUS_GAP := 22.0
const PLUS_TEXT_SHIFT := 6.0
const PLUS_TEXT_DROP := 8.0
## 縦画面では中身ごと大きく描く(GameDesign.md 9章「縦画面」)。
const PORTRAIT_ZOOM := 1.25

var deck_name := ""
var cards: Array = []
var last_used := false
var new_slot := false
var portrait := false

var _visual: Control
var _font: Font
var _buttons: HBoxContainer


## 札の下に置くボタン。`show_delete` は管理のときだけ。並び替え中は ↑ ↓ に替え、札は押せなくする。
func set_actions(show_delete: bool, reorder: bool, can_up := true, can_down := true) -> void:
	_ensure_visual()
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if reorder:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_add_button("↑", MOVE_BUTTON_WIDTH, not can_up).pressed.connect(
			func() -> void: move_pressed.emit(-1)
		)
		_add_button("↓", MOVE_BUTTON_WIDTH, not can_down).pressed.connect(
			func() -> void: move_pressed.emit(1)
		)
	else:
		_add_button("一覧", LIST_BUTTON_WIDTH).pressed.connect(func() -> void: list_pressed.emit())
		if show_delete:
			_add_button("削除", DELETE_BUTTON_WIDTH).pressed.connect(
				func() -> void: delete_pressed.emit()
			)


func _ready() -> void:
	_ensure_visual()
	super._ready()
	_font = get_theme_default_font()


func _ensure_visual() -> void:
	if _visual != null:
		return
	_visual = Control.new()
	_visual.name = "VisualRoot"
	_visual.anchor_right = 1.0
	_visual.anchor_bottom = 1.0
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.draw.connect(_paint)
	add_child(_visual)
	# 右下へ寄せる。札の大きさはグリッドが後から決めるため、位置は計算せずアンカーで張る。
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", BUTTON_GAP)
	_buttons.anchor_left = 1.0
	_buttons.anchor_top = 1.0
	_buttons.anchor_right = 1.0
	_buttons.anchor_bottom = 1.0
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var inset := (EDGE - 2.0) * _zoom()
	_buttons.offset_right = -inset
	_buttons.offset_bottom = -inset
	_visual.add_child(_buttons)


func _add_button(label: String, width: float, disabled := false) -> Button:
	var zoom := _zoom()
	var button := (
		CodedButton.make_icon(label, Vector2(width, BUTTON_HEIGHT) * zoom)
		if width == MOVE_BUTTON_WIDTH
		else CodedButton.make(label, Vector2(width, BUTTON_HEIGHT) * zoom)
	)
	button.disabled = disabled
	_buttons.add_child(button)
	return button


func _zoom() -> float:
	return PORTRAIT_ZOOM if portrait else 1.0


# --- 描画 ---------------------------------------------------------------


func _paint() -> void:
	if new_slot:
		_paint_new_slot()
		return
	var k := _zoom()
	_visual.draw_style_box(load(PANEL_STYLE), Rect2(Vector2.ZERO, size))
	var shelf := Rect2(
		EDGE * k,
		size.y - FLOOR_MARGIN * k - PLANK_HEIGHT * k * 0.4,
		SHOWCASE_WIDTH,
		PLANK_HEIGHT * k
	)
	_paint_plank(shelf)
	_paint_heroes(shelf, k)
	var text_x := shelf.end.x + TEXT_GAP * k
	var text_w := size.x - text_x - EDGE * k
	_visual.draw_string(
		_font,
		Vector2(text_x, size.y * 0.5 - NAME_RISE * k),
		deck_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		text_w,
		roundi(NAME_FONT * k),
		UiPalette.TEXT_OFFWHITE
	)
	_visual.draw_string(
		_font,
		Vector2(text_x, size.y * 0.5 + SUMMARY_DROP * k),
		summary_of(cards),
		HORIZONTAL_ALIGNMENT_LEFT,
		text_w,
		roundi(SUMMARY_FONT * k),
		UiPalette.BRASS_HIGHLIGHT
	)
	if last_used:
		_paint_tag(Vector2(size.x - EDGE * k, EDGE * k), "前回", k)


func _paint_heroes(shelf: Rect2, k: float) -> void:
	var x := shelf.position.x + EDGE * 0.5 * k
	var feet := shelf.position.y + 3.0
	var heroes := heroes_of(cards).slice(0, PORTRAIT_HERO_COUNT if portrait else HERO_COUNT)
	for i in heroes.size():
		var tex: Texture2D = heroes[i].icon_upright
		if tex == null:
			continue
		var h := size.y - (HERO_INSET if i == 0 else SIDE_INSET) * k
		var w := h * float(tex.get_width()) / float(tex.get_height())
		UiPaint.fill_ellipse(
			_visual.get_canvas_item(),
			Vector2(x + w * 0.5, feet),
			Vector2(w * SHADOW_SPREAD, SHADOW_HEIGHT),
			SHADOW_COLOR,
			18
		)
		_visual.draw_texture_rect(tex, Rect2(x, feet - h, w, h), false)
		x += w * (HERO_STEP if i == 0 else SIDE_STEP)


## 棚板は `ShelfPlank` と同じ3層(木目の天板・真鍮の縁・暗い木口)を、札の中へ小さく描く。
func _paint_plank(rect: Rect2) -> void:
	var ci := _visual.get_canvas_item()
	var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ShelfPlank.TOP_FACE_RATIO))
	var trim := Rect2(
		Vector2(rect.position.x, top.end.y),
		Vector2(rect.size.x, rect.size.y * ShelfPlank.TRIM_RATIO)
	)
	var lip := Rect2(
		Vector2(rect.position.x, trim.end.y), Vector2(rect.size.x, rect.end.y - trim.end.y)
	)
	_slab(ci, top, UiPalette.WOOD_TOP, UiPalette.WOOD_MID)
	_slab(ci, trim, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK)
	_slab(ci, lip, UiPalette.WOOD_MID, UiPalette.WOOD_DARK)


static func _slab(ci: RID, rect: Rect2, top_color: Color, bottom_color: Color) -> void:
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top_color], [1.0, bottom_color]])


func _paint_tag(top_right: Vector2, text: String, k: float) -> void:
	var font_size := roundi(TAG_FONT * k)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + TAG_PAD * k
	var rect := Rect2(top_right - Vector2(w, 0), Vector2(w, TAG_HEIGHT * k))
	var points := UiPaint.rounded_rect_points_uniform(rect, 6.0 * k, 4)
	UiPaint.fill_gradient_polygon(
		_visual.get_canvas_item(), points, rect, [[0.0, TAG_TOP], [1.0, TAG_BOTTOM]]
	)
	_visual.draw_string(
		_font,
		Vector2(rect.position.x, rect.end.y - TAG_TEXT_DROP * k),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		font_size,
		TAG_TEXT
	)


func _paint_new_slot() -> void:
	var k := _zoom()
	var ci := _visual.get_canvas_item()
	var rect := Rect2(Vector2(SLOT_INSET, SLOT_INSET), size - Vector2(SLOT_INSET, SLOT_INSET) * 2.0)
	var points := UiPaint.rounded_rect_points_uniform(rect, SLOT_RADIUS, 6)
	ShapePaint.colored_polygon(ci, points, SLOT_FILL)
	for i in points.size():
		ShapePaint.dashed_line(
			ci, points[i], points[(i + 1) % points.size()], SLOT_LINE, 2.0, SLOT_DASH
		)
	var center := size * 0.5
	var label := "新しいデッキを作る"
	var font_size := roundi(SLOT_FONT * k)
	var text_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plus := Vector2(center.x - text_w * 0.5 - PLUS_GAP * k, center.y)
	UiPaint.fill_circle(ci, plus, PLUS_RADIUS * k, PLUS_FILL, 24)
	var arm := PLUS_ARM * k
	_visual.draw_line(plus - Vector2(arm, 0), plus + Vector2(arm, 0), PLUS_LINE, 3.0)
	_visual.draw_line(plus - Vector2(0, arm), plus + Vector2(0, arm), PLUS_LINE, 3.0)
	_visual.draw_string(
		_font,
		Vector2(center.x - text_w * 0.5 + PLUS_TEXT_SHIFT * k, center.y + PLUS_TEXT_DROP * k),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		SLOT_TEXT
	)


# --- 中身の要約 ---------------------------------------------------------


## 札に立てる砂時計。**砂術は絵を持たないため除き、コストの高い順**(そのデッキの主役が並ぶため)。
static func heroes_of(deck: Array) -> Array:
	var distinct: Array = []
	for card in deck:
		if not card.is_spell and not distinct.has(card):
			distinct.append(card)
	distinct.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost > b.cost)
	return distinct.slice(0, HERO_COUNT)


## 「平均コスト 3.4 ・ 砂術 6枚」。枚数は全デッキ30枚で同じため出さない。
static func summary_of(deck: Array) -> String:
	if deck.is_empty():
		return ""
	var total := 0
	var spells := 0
	for card in deck:
		total += card.cost
		if card.is_spell:
			spells += 1
	var text := "平均コスト %.1f" % (float(total) / float(deck.size()))
	if spells > 0:
		text += " ・ 砂術 %d枚" % spells
	return text
