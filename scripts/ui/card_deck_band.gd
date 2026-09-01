class_name CardDeckBand
extends Control
## 編成中のデッキ1枚ぶんの帯(GameDesign.md 9章)。
##
## 20枚をカードの絵で並べると画面に入らないが、文字だけの表では何のカードか読み取るのに
## 時間がかかる。**絵を右端へ薄く敷いた横長の帯**にして、その中間を取る。
## 帯からは1枚減らすだけでなく1枚足すこともできる(入れたカードをもう1枚足す操作が
## いちばん多いのに、それが一覧側にしか無いのは遠いため)。

signal add_pressed(card: CardData)
signal remove_pressed(card: CardData)
signal hovered(card: CardData)

const BAND_HEIGHT := 32.0
const CORNER := 5.0
const COST_CENTER_X := 19.0
const COST_RADIUS := 12.5
const NAME_LEFT := 39.0
const NAME_FONT_SIZE := 17
const BUTTON_SIZE := Vector2(28.0, 26.0)
const BUTTON_GAP := 4.0
const BADGE_SIZE := Vector2(30.0, 22.0)
const BADGE_GAP := 8.0
## 絵は元画像の縦中央あたりだけを切り出す。全体を帯の高さへ縮めると幅が25px程度になり、
## 何の絵なのか読めなくなるため。
const ART_SRC_TOP := 0.1
const ART_SRC_HEIGHT := 0.36
const ART_ALPHA := 0.55

var card: CardData
var count := 1

var _remove: Button
var _add: Button
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	custom_minimum_size.y = BAND_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(func() -> void: hovered.emit(card))
	_remove = CodedButton.make_icon("−", BUTTON_SIZE)
	_remove.pressed.connect(func() -> void: remove_pressed.emit(card))
	add_child(_remove)
	_add = CodedButton.make_icon("+", BUTTON_SIZE)
	_add.pressed.connect(func() -> void: add_pressed.emit(card))
	add_child(_add)
	resized.connect(_layout_buttons)
	_layout_buttons()
	queue_redraw()


func show_card(new_card: CardData, new_count: int, can_add: bool) -> void:
	card = new_card
	count = new_count
	if _add != null:
		_add.disabled = not can_add
	queue_redraw()


func _layout_buttons() -> void:
	if _add == null:
		return
	var y := (size.y - BUTTON_SIZE.y) * 0.5
	_add.position = Vector2(size.x - BUTTON_SIZE.x - BUTTON_GAP, y)
	_remove.position = Vector2(_add.position.x - BUTTON_SIZE.x - BUTTON_GAP, y)


## 絵を置ける範囲。ボタンとバッジの手前で切り、帯からはみ出させない。
func _art_rect() -> Rect2:
	var right := size.x - BUTTON_SIZE.x * 2.0 - BUTTON_GAP * 3.0
	if count >= 2:
		right -= BADGE_SIZE.x + BADGE_GAP
	return Rect2(NAME_LEFT, 0.0, maxf(right - NAME_LEFT, 0.0), size.y)


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER, 4)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[
			[0.0, Color(0.18, 0.16, 0.14, 0.96)],
			[0.55, Color(0.13, 0.115, 0.105, 0.96)],
			[1.0, Color(0.09, 0.08, 0.075, 0.96)]
		]
	)
	_draw_art()
	_draw_cost()
	draw_string(
		_font,
		Vector2(NAME_LEFT, size.y * 0.5 + 6.0),
		card.display_name if card != null else "",
		HORIZONTAL_ALIGNMENT_LEFT,
		_art_rect().size.x,
		NAME_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	if count >= 2:
		_draw_badge()
	draw_polyline(
		points + PackedVector2Array([points[0]]),
		Color(0.6, 0.48, 0.3, 0.75) if count >= 2 else Color(0.3, 0.28, 0.25, 0.75),
		1.5
	)


func _draw_art() -> void:
	if card == null or card.icon_upright == null:
		return
	var tex: Texture2D = card.icon_upright
	var src := Rect2(
		0.0, tex.get_height() * ART_SRC_TOP, tex.get_width(), tex.get_height() * ART_SRC_HEIGHT
	)
	var area := _art_rect()
	var width: float = src.size.x * (area.size.y / src.size.y)
	if width > area.size.x:
		return
	var dest := Rect2(area.end.x - width, area.position.y, width, area.size.y)
	draw_texture_rect_region(tex, dest, src, Color(1, 1, 1, ART_ALPHA))


func _draw_cost() -> void:
	if card == null:
		return
	var cy := size.y * 0.5
	var d := COST_RADIUS
	var diamond := PackedVector2Array(
		[
			Vector2(COST_CENTER_X, cy - d),
			Vector2(COST_CENTER_X + d, cy),
			Vector2(COST_CENTER_X, cy + d),
			Vector2(COST_CENTER_X - d, cy)
		]
	)
	draw_colored_polygon(diamond, Color(0.14, 0.26, 0.44, 0.95))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), CardView.MANA_BLUE, 2.0)
	draw_string(
		_font,
		Vector2(COST_CENTER_X - d, cy + 6.0),
		str(card.cost),
		HORIZONTAL_ALIGNMENT_CENTER,
		d * 2.0,
		16,
		Color(0.87, 0.93, 1.0)
	)


## 枚数は2枚積みのときだけ出す(1枚のものに「×1」を出しても情報にならない)。
func _draw_badge() -> void:
	var badge := Rect2(
		Vector2(
			size.x - BUTTON_SIZE.x * 2.0 - BUTTON_GAP * 3.0 - BADGE_SIZE.x - BADGE_GAP * 0.5,
			(size.y - BADGE_SIZE.y) * 0.5
		),
		BADGE_SIZE
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(badge, 4.0, 4),
		badge,
		[[0.0, Color(0.56, 0.43, 0.16)], [1.0, Color(0.29, 0.21, 0.08)]]
	)
	draw_string(
		_font,
		Vector2(badge.position.x, badge.position.y + BADGE_SIZE.y - 6.0),
		"×2",
		HORIZONTAL_ALIGNMENT_CENTER,
		BADGE_SIZE.x,
		15,
		UiPalette.TEXT_OFFWHITE
	)
