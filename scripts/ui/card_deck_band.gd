class_name CardDeckBand
extends Control
## 編成中のデッキ1枚ぶんの帯(GameDesign.md 9章)。
##
## 30枚をカードの絵で並べると画面に入らないが、文字だけの表では何のカードか読み取るのに
## 時間がかかる。**絵を右端へ薄く敷いた横長の帯**にして、その中間を取る。
## 帯からは1枚減らすだけでなく1枚足すこともできる(入れたカードをもう1枚足す操作が
## いちばん多いのに、それが一覧側にしか無いのは遠いため)。

signal add_pressed(card: CardData)
signal remove_pressed(card: CardData)
signal pressed(card: CardData)

const BAND_HEIGHT := 46.0
const CORNER := 6.0
const COST_CENTER_X := 24.0
const COST_RADIUS := 14.0
const NAME_LEFT := 46.0
const NAME_FONT_SIZE := 18
## 総量は名前の右へ添える(GameDesign.md 9章)。30枚を上から見たときに、コストだけでなく
## 規模も読めるようにするため。**砂術は総量を持たないため「砂術」と出す**
## (空欄にすると総量0のカードと見分けが付かない)。
const TOTAL_FONT_SIZE := 15
const TOTAL_GAP := 10.0
const BUTTON_SIZE := Vector2(36.0, 36.0)
const BUTTON_GAP := 5.0
const BADGE_SIZE := Vector2(36.0, 26.0)
const BADGE_GAP := 8.0
## 絵は元画像の縦中央あたりだけを切り出す。全体を帯の高さへ縮めると幅が25px程度になり、
## 何の絵なのか読めなくなるため。
const ART_SRC_TOP := 0.05
const ART_SRC_HEIGHT := 0.50
const ART_ALPHA := 0.60

var card: CardData
var count := 1
## 共有用のデッキ表(GameDesign.md 9章)では「−」「+」を出さない。押せる先が無いためで、
## 空いたぶんは絵の幅へ回す。
var readonly := false

var _remove: Button
var _add: Button
var _font: Font
var _tracker := PressTracker.new()


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null or _font == ThemeDB.fallback_font:
		_font = TextGlyphs.ui_font()
	custom_minimum_size.y = BAND_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not readonly:
		_remove = CodedButton.make_icon("−", BUTTON_SIZE)
		_remove.pressed.connect(func() -> void: remove_pressed.emit(card))
		add_child(_remove)
		_add = CodedButton.make_icon("+", BUTTON_SIZE)
		_add.pressed.connect(func() -> void: add_pressed.emit(card))
		add_child(_add)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	resized.connect(_layout_buttons)
	_layout_buttons()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	if _tracker.feed(event, size) == PressTracker.Result.CONFIRMED:
		pressed.emit(card)


func show_card(new_card: CardData, new_count: int, can_add: bool) -> void:
	card = new_card
	count = new_count
	if _add != null:
		_add.disabled = not can_add
	queue_redraw()


## 右端でボタンが占める幅。`readonly` のときは余白だけを残す。
func _buttons_width() -> float:
	if readonly:
		return BUTTON_GAP * 2.0
	return BUTTON_SIZE.x * 2.0 + BUTTON_GAP * 3.0


func _layout_buttons() -> void:
	if _add == null:
		return
	var y := (size.y - BUTTON_SIZE.y) * 0.5
	_add.position = Vector2(size.x - BUTTON_SIZE.x - BUTTON_GAP, y)
	_remove.position = Vector2(_add.position.x - BUTTON_SIZE.x - BUTTON_GAP, y)


## 絵を置ける範囲。ボタンとバッジの手前で切り、帯からはみ出させない。
func _art_rect() -> Rect2:
	var right := size.x - _buttons_width()
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
	var name_text: String = card.display_name if card != null else ""
	draw_string(
		_font,
		Vector2(NAME_LEFT, size.y * 0.5 + 6.0),
		name_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		_art_rect().size.x,
		NAME_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	_draw_total(name_text)
	if count >= 2:
		_draw_badge()
	draw_polyline(
		points + PackedVector2Array([points[0]]),
		Color(0.6, 0.48, 0.3, 0.75) if count >= 2 else Color(0.3, 0.28, 0.25, 0.75),
		1.5
	)


func _draw_art() -> void:
	if card == null:
		return
	# 砂術は砂時計の絵を持たない(GameDesign.md 9章)。紋章を同じ場所へ敷く。
	if card.is_spell:
		_draw_emblem_art()
		return
	if card.icon_upright == null:
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


## 砂術の帯へ敷く紋章。絵と同じく右端で、帯からはみ出さない大きさに収める。
func _draw_emblem_art() -> void:
	if card.emblem == null:
		return
	var area := _art_rect()
	var side: float = area.size.y * 0.82
	if side > area.size.x:
		return
	var dest := Rect2(area.end.x - side, area.position.y + (area.size.y - side) * 0.5, side, side)
	draw_texture_rect(card.emblem, dest, false, Color(1, 1, 1, ART_ALPHA))


## 総量を名前のすぐ右へ置く。名前の実寸を測ってから並べるため、長さの違うカードでも
## 間隔が揃う。
func _draw_total(name_text: String) -> void:
	if card == null:
		return
	var text: String = "砂術" if card.is_spell else "総量 %d" % card.total_sand
	var name_width: float = (
		_font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
	)
	var left := NAME_LEFT + name_width + TOTAL_GAP
	var area := _art_rect()
	draw_string(
		_font,
		Vector2(left, size.y * 0.5 + 5.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(area.end.x - left, 0.0),
		TOTAL_FONT_SIZE,
		UiPalette.GLOW_AMBER
	)


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
		17,
		Color(0.87, 0.93, 1.0)
	)


## 枚数は2枚積みのときだけ出す(1枚のものに「×1」を出しても情報にならない)。
func _draw_badge() -> void:
	var badge := Rect2(
		Vector2(
			size.x - _buttons_width() - BADGE_SIZE.x - BADGE_GAP * 0.5,
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
		Vector2(badge.position.x, badge.position.y + BADGE_SIZE.y - 7.0),
		"×2",
		HORIZONTAL_ALIGNMENT_CENTER,
		BADGE_SIZE.x,
		16,
		UiPalette.TEXT_OFFWHITE
	)
