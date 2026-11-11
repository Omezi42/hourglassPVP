class_name CardDeckCase
extends ClickArea
## デッキ一覧の札1枚(GameDesign.md 9章「デッキ一覧」)。左に棚板へ立てた砂時計、右にデッキ名と要約。
## `new_slot` を立てると、一覧の最後に置く点線の「新しいデッキを作る」の枠として描く
## (並びの大きさと押し心地を札とそろえるため、同じクラスで持つ)。
## 絵と文字は `VisualRoot`(`ClickArea` がホバーで浮かせる子)へ描き、ボタンもそこへ置く。

signal list_pressed
signal delete_pressed
signal move_pressed(offset: int)

## 砂術を除き、コストの高い順に並べる本数。先頭の1本だけを大きく描く。
const HERO_COUNT := 4
## 縦は文字を大きくするぶん、本数を減らして名前と要約の幅を空ける。
const PORTRAIT_HERO_COUNT := 3
## 棚の幅と、札の背丈から引いて砂時計の背丈を決める量(大きい1本 / 残り)。
const SHOWCASE_WIDTH := 236.0
const PORTRAIT_SHOWCASE_WIDTH := 210.0
const HERO_INSET := 34.0
const SIDE_INSET := 56.0
## 縦は札が高いぶん、3本が狭い棚へ収まるよう大きく引く。
const PORTRAIT_HERO_INSET := 86.0
const PORTRAIT_SIDE_INSET := 120.0
## 次の砂時計を置く間隔(手前の絵の幅に対する比)。少し重ねて棚に詰める。
const HERO_STEP := 0.86
const SIDE_STEP := 0.78
const PLANK_HEIGHT := 16.0
const FLOOR_MARGIN := 18.0
const EDGE := 18.0
const TEXT_GAP := 22.0
const NAME_FONT := UiPalette.T_HEAD
const SUMMARY_FONT := UiPalette.T_SMALL
const NAME_RISE := 18.0
const SUMMARY_DROP := 10.0
## 縦は文字を24px以上にし、名前と要約を札の上半分へ置いて下の右にボタンを空ける。
const PORTRAIT_NAME_FONT := 32
const PORTRAIT_SUMMARY_FONT := 24
const PORTRAIT_NAME_BASELINE := 66.0
const PORTRAIT_SUMMARY_BASELINE := 108.0
const SHADOW_COLOR := Color(0, 0, 0, 0.45)
const SHELF_FEET_DROP := 3.0
const SHADOW_HEIGHT := 4.0
const SHADOW_SPREAD := 0.36
## 先頭の1本の砂の色で、砂時計の後ろへ敷く淡い光。
const GLOW_ALPHA := 0.25
const GLOW_RADII_RATIO := Vector2(0.9, 0.62)
## 面の影が札の外へはみ出して切れないよう、面を札の縁から内へ寄せる量。
const FACE_INSET := 4.0
const BUTTON_HEIGHT := 40.0
const BUTTON_GAP := 8.0
const LIST_BUTTON_WIDTH := 84.0
const DELETE_BUTTON_WIDTH := 72.0
const MOVE_BUTTON_WIDTH := 52.0
## 縦は指で押せる高さ(72px以上)と、その高さに見合う幅・文字にする。
const PORTRAIT_BUTTON_HEIGHT := 72.0
const PORTRAIT_LIST_BUTTON_WIDTH := 124.0
const PORTRAIT_DELETE_BUTTON_WIDTH := 112.0
const PORTRAIT_MOVE_BUTTON_WIDTH := 72.0
const PORTRAIT_BUTTON_FONT := 24
## 「前回」の札。
const TAG_FONT := 15
const TAG_HEIGHT := 26.0
const TAG_PAD := 20.0
const PORTRAIT_TAG_FONT := 24
const PORTRAIT_TAG_HEIGHT := 38.0
const PORTRAIT_TAG_PAD := 30.0
const TAG_GAP := 12.0
## 新規作成の枠。
const SLOT_FILL_ALPHA := 0.45
const SLOT_LINE_ALPHA := 0.55
const SLOT_DASH := 10.0
const SLOT_RADIUS := 12.0
const SLOT_INSET := 3.0
const SLOT_FONT := 22
const PORTRAIT_SLOT_FONT := 26
const PLUS_RADIUS := 15.0
const PLUS_ARM := 7.0
const PLUS_LINE_WIDTH := 3.0
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
		_add_button("↑", _move_width(), not can_up, true).pressed.connect(
			func() -> void: move_pressed.emit(-1)
		)
		_add_button("↓", _move_width(), not can_down, true).pressed.connect(
			func() -> void: move_pressed.emit(1)
		)
	else:
		_add_button("一覧", _list_width()).pressed.connect(func() -> void: list_pressed.emit())
		if show_delete:
			_add_button("削除", _delete_width(), false, false, true).pressed.connect(
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


func _add_button(
	label: String, width: float, disabled := false, icon := false, danger := false
) -> Button:
	var button_size := Vector2(width, _button_height())
	var button: Button
	if icon:
		button = CodedButton.make_icon(label, button_size)
	elif danger:
		button = CodedButton.make_in_group(label, button_size, CodedButton.DANGER_GROUP)
	else:
		button = CodedButton.make(label, button_size)
	if portrait:
		button.add_theme_font_size_override("font_size", PORTRAIT_BUTTON_FONT)
	button.disabled = disabled
	_buttons.add_child(button)
	return button


func _button_height() -> float:
	return PORTRAIT_BUTTON_HEIGHT if portrait else BUTTON_HEIGHT


func _list_width() -> float:
	return PORTRAIT_LIST_BUTTON_WIDTH if portrait else LIST_BUTTON_WIDTH


func _delete_width() -> float:
	return PORTRAIT_DELETE_BUTTON_WIDTH if portrait else DELETE_BUTTON_WIDTH


func _move_width() -> float:
	return PORTRAIT_MOVE_BUTTON_WIDTH if portrait else MOVE_BUTTON_WIDTH


func _zoom() -> float:
	return PORTRAIT_ZOOM if portrait else 1.0


# --- 描画 ---------------------------------------------------------------


func _paint() -> void:
	if new_slot:
		_paint_new_slot()
		return
	var k := _zoom()
	var ci := _visual.get_canvas_item()
	UiKit.glass(ci, Rect2(Vector2.ONE * FACE_INSET, size - Vector2.ONE * FACE_INSET * 2.0))
	var shelf_width := PORTRAIT_SHOWCASE_WIDTH if portrait else SHOWCASE_WIDTH
	var shelf := Rect2(
		EDGE * k, size.y - FLOOR_MARGIN * k - PLANK_HEIGHT * k * 0.4, shelf_width, PLANK_HEIGHT * k
	)
	var heroes := heroes_of(cards).slice(0, PORTRAIT_HERO_COUNT if portrait else HERO_COUNT)
	_paint_glow(shelf, k, heroes)
	_paint_plank(shelf)
	_paint_heroes(shelf, k, heroes)
	# 字は棚と砂時計の並びのどちらか右の端から始める(砂時計が棚からはみ出しても重ならないように)。
	var right := shelf.end.x
	for box: Rect2 in _hero_boxes(shelf, k, heroes):
		right = maxf(right, box.end.x)
	var text_x := right + TEXT_GAP * k
	var text_w := size.x - text_x - EDGE * k
	var name_w := text_w
	var tag_rect := Rect2()
	if last_used:
		tag_rect = _tag_rect(Vector2(size.x - EDGE * k, EDGE * k))
		name_w = minf(text_w, tag_rect.position.x - text_x - TAG_GAP)
	var name_y := PORTRAIT_NAME_BASELINE if portrait else size.y * 0.5 - NAME_RISE
	var summary_y := PORTRAIT_SUMMARY_BASELINE if portrait else size.y * 0.5 + SUMMARY_DROP
	_visual.draw_string(
		_font,
		Vector2(text_x, name_y),
		deck_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		name_w,
		PORTRAIT_NAME_FONT if portrait else NAME_FONT,
		UiPalette.IVORY
	)
	_visual.draw_string(
		_font,
		Vector2(text_x, summary_y),
		summary_of(cards),
		HORIZONTAL_ALIGNMENT_LEFT,
		text_w,
		PORTRAIT_SUMMARY_FONT if portrait else SUMMARY_FONT,
		UiPalette.MUTED
	)
	if last_used:
		UiKit.tag(ci, _font, tag_rect, "前回", PORTRAIT_TAG_FONT if portrait else TAG_FONT)


## 先頭の1本の砂の色の光を、その砂時計の後ろへ淡く敷く(デッキごとの色で見分けるため)。
func _paint_glow(shelf: Rect2, k: float, heroes: Array) -> void:
	if heroes.is_empty():
		return
	var hero: CardData = heroes[0]
	var tex: Texture2D = hero.icon_upright
	if tex == null:
		return
	var h := size.y - _hero_inset(0, k)
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var center := Vector2(
		shelf.position.x + EDGE * 0.5 * k + w * 0.5, shelf.position.y + SHELF_FEET_DROP - h * 0.5
	)
	UiKit.glow(
		_visual.get_canvas_item(),
		center,
		Vector2(w, h) * GLOW_RADII_RATIO,
		Color(CardSkins.accent_color(hero), GLOW_ALPHA)
	)


## i本目の砂時計の背丈を札の背丈から引く量。
func _hero_inset(i: int, k: float) -> float:
	if portrait:
		return PORTRAIT_HERO_INSET if i == 0 else PORTRAIT_SIDE_INSET
	return (HERO_INSET if i == 0 else SIDE_INSET) * k


func _paint_heroes(shelf: Rect2, k: float, heroes: Array) -> void:
	var feet := shelf.position.y + SHELF_FEET_DROP
	for box: Rect2 in _hero_boxes(shelf, k, heroes):
		UiPaint.fill_ellipse(
			_visual.get_canvas_item(),
			Vector2(box.get_center().x, feet),
			Vector2(box.size.x * SHADOW_SPREAD, SHADOW_HEIGHT),
			SHADOW_COLOR,
			18
		)
	for i in heroes.size():
		var tex: Texture2D = heroes[i].icon_upright
		if tex != null:
			_visual.draw_texture_rect(tex, _hero_boxes(shelf, k, heroes)[i], false)


## 砂時計を立てる矩形(棚の左から、先頭を大きく並べる)。絵の無いものは幅0。
func _hero_boxes(shelf: Rect2, k: float, heroes: Array) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	var x := shelf.position.x + EDGE * 0.5 * k
	var feet := shelf.position.y + SHELF_FEET_DROP
	for i in heroes.size():
		var tex: Texture2D = heroes[i].icon_upright
		var h := size.y - _hero_inset(i, k)
		var w := 0.0 if tex == null else h * float(tex.get_width()) / float(tex.get_height())
		boxes.append(Rect2(x, feet - h, w, h))
		x += w * (HERO_STEP if i == 0 else SIDE_STEP)
	return boxes


## 棚板は `ShelfPlank` と同じ3層(天板・真鍮の縁・木口)を、藍の板と真鍮の帯で札の中へ小さく描く。
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
	_slab(ci, top, UiPalette.INK_500, UiPalette.INK_700)
	_slab(ci, trim, UiPalette.GOLD, UiPalette.BRASS_DEEP)
	_slab(ci, lip, UiPalette.INK_700, UiPalette.INK_900)


static func _slab(ci: RID, rect: Rect2, top_color: Color, bottom_color: Color) -> void:
	UiKit.vgrad(ci, UiKit.rr(rect, 0.0), [[0.0, top_color], [1.0, bottom_color]])


func _tag_rect(top_right: Vector2) -> Rect2:
	var font_size := PORTRAIT_TAG_FONT if portrait else TAG_FONT
	var pad := PORTRAIT_TAG_PAD if portrait else TAG_PAD
	var w := _font.get_string_size("前回", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + pad
	var h := PORTRAIT_TAG_HEIGHT if portrait else TAG_HEIGHT
	return Rect2(top_right - Vector2(w, 0), Vector2(w, h))


func _paint_new_slot() -> void:
	var k := _zoom()
	var ci := _visual.get_canvas_item()
	var rect := Rect2(Vector2(SLOT_INSET, SLOT_INSET), size - Vector2(SLOT_INSET, SLOT_INSET) * 2.0)
	var points := UiPaint.rounded_rect_points_uniform(rect, SLOT_RADIUS, 6)
	ShapePaint.colored_polygon(ci, points, Color(UiPalette.INK_900, SLOT_FILL_ALPHA))
	var line := Color(UiPalette.GOLD, SLOT_LINE_ALPHA)
	for i in points.size():
		ShapePaint.dashed_line(ci, points[i], points[(i + 1) % points.size()], line, 2.0, SLOT_DASH)
	var center := size * 0.5
	var label := "新しいデッキを作る"
	var font_size := PORTRAIT_SLOT_FONT if portrait else SLOT_FONT
	var text_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plus := Vector2(center.x - text_w * 0.5 - PLUS_GAP * k, center.y)
	UiKit.round_face(ci, plus, PLUS_RADIUS * k)
	var arm := PLUS_ARM * k
	_visual.draw_line(
		plus - Vector2(arm, 0), plus + Vector2(arm, 0), UiPalette.GOLD_HI, PLUS_LINE_WIDTH
	)
	_visual.draw_line(
		plus - Vector2(0, arm), plus + Vector2(0, arm), UiPalette.GOLD_HI, PLUS_LINE_WIDTH
	)
	_visual.draw_string(
		_font,
		Vector2(center.x - text_w * 0.5 + PLUS_TEXT_SHIFT * k, center.y + PLUS_TEXT_DROP * k),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		UiPalette.IVORY
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
