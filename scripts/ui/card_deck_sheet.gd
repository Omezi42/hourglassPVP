class_name CardDeckSheet
extends Control
## 共有用のデッキ表(GameDesign.md 9章)。デッキの中身を1枚の絵として書き出すための組み立て。
##
## **画面へ直接置かず、`SubViewport` の中だけで生きる。**書き出す画像と、共有パネルへ
## 映しているものが同じ実体になるため、見本と書き出しが食い違う経路そのものが無い。
##
## 帯は `CardDeckBand` を `readonly` で使い回す(共有のためだけに似た帯をもう1つ書くと、
## 片方だけが古くなるため)。並びも `CardLibrary.compare_by_cost` を通し、画面ごとに
## 並べ方を決めない。

## 貼られることを前提とした横長。幅は固定で、**高さだけが種類数で変わる**。
## 常に最大(30種)ぶんの高さで書き出すと、15種のデッキでは右下が大きく空いた絵になる。
const SHEET_WIDTH := 1280.0
const MARGIN := 36.0
const COLUMNS := 3
const BAND_GAP := Vector2(16.0, 8.0)
const LIST_TOP := 150.0
const CURVE_HEIGHT := 140.0
const CURVE_GAP := 24.0
const FOOTER_GAP := 18.0
const TITLE_FONT_SIZE := 38
const SUB_FONT_SIZE := 22
const FOOTER_FONT_SIZE := 18
const TITLE_NAME := "砂時計アリーナ"

var _bands: Array[CardDeckBand] = []
var _curve: CardManaCurve
var _font: Font
var _deck_name := ""
var _count := 0
var _code := ""
## 1列あたりの行数。種類数から決める(3列に均す)。
var _rows := 1


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curve = CardManaCurve.new()
	_curve.compact = true
	_curve.size = Vector2(_content_width(), CURVE_HEIGHT)
	add_child(_curve)
	_apply_size()


## 書き出す絵の大きさ。行数で変わるため、映す側・書き出す側はここを見る。
func sheet_size() -> Vector2:
	return Vector2(SHEET_WIDTH, _footer_baseline() + MARGIN * 0.6)


## 表の中身を差し替える。`code` は発行済みのときだけ渡す(GameDesign.md 9章)。
func show_deck(deck: Array, deck_name: String, code: String) -> void:
	_deck_name = deck_name
	_count = deck.size()
	_code = code
	var distinct := _distinct_sorted(deck)
	_rows = maxi(1, ceili(float(distinct.size()) / float(COLUMNS)))
	_apply_size()
	while _bands.size() < distinct.size():
		var band := CardDeckBand.new()
		band.readonly = true
		add_child(band)
		_bands.append(band)
	for i in _bands.size():
		var band := _bands[i]
		band.visible = i < distinct.size()
		if not band.visible:
			continue
		var card: CardData = distinct[i]
		band.position = _band_position(i)
		band.size = Vector2(_band_width(), CardDeckBand.BAND_HEIGHT)
		band.show_card(card, _count_of(deck, card), false)
	_curve.show_deck(deck)
	queue_redraw()


## 行数が変わると全体の高さも変わる。曲線の位置もここで揃える。
func _apply_size() -> void:
	var sheet := sheet_size()
	size = sheet
	custom_minimum_size = sheet
	if _curve != null:
		_curve.position = Vector2(MARGIN, _curve_top())


func _content_width() -> float:
	return SHEET_WIDTH - MARGIN * 2.0


func _band_width() -> float:
	return (_content_width() - BAND_GAP.x * float(COLUMNS - 1)) / float(COLUMNS)


## 左の列から縦に詰める(上から下へ読む並びを、列を跨いでも保つため)。
func _band_position(index: int) -> Vector2:
	var column := index / _rows
	var row := index % _rows
	return Vector2(
		MARGIN + float(column) * (_band_width() + BAND_GAP.x),
		LIST_TOP + float(row) * (CardDeckBand.BAND_HEIGHT + BAND_GAP.y)
	)


func _curve_top() -> float:
	var list_height := CardDeckBand.BAND_HEIGHT * _rows + BAND_GAP.y * float(_rows - 1)
	return LIST_TOP + list_height + CURVE_GAP


func _footer_baseline() -> float:
	return _curve_top() + CURVE_HEIGHT + FOOTER_GAP + float(FOOTER_FONT_SIZE)


func _distinct_sorted(deck: Array) -> Array:
	var seen: Array = []
	for card in deck:
		if not seen.has(card):
			seen.append(card)
	seen.sort_custom(CardLibrary.compare_by_cost)
	return seen


func _count_of(deck: Array, card: CardData) -> int:
	var found := 0
	for entry in deck:
		if entry == card:
			found += 1
	return found


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	UiPaint.fill_gradient_polygon(
		ci,
		PackedVector2Array(
			[rect.position, Vector2(rect.end.x, 0.0), rect.end, Vector2(0.0, rect.end.y)]
		),
		rect,
		ScreenBackdrop.STOPS
	)
	UiPaint.apply_grain(ci, rect, ScreenBackdrop.GRAIN_ALPHA)
	draw_rect(rect.grow(-10.0), UiPalette.GLOW_AMBER, false, 2.0)
	_draw_header()
	_draw_footer()


func _draw_header() -> void:
	draw_string(
		_font,
		Vector2(MARGIN, 78.0),
		_deck_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		_content_width() * 0.62,
		TITLE_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	draw_string(
		_font,
		Vector2(MARGIN, 116.0),
		"%d枚" % _count,
		HORIZONTAL_ALIGNMENT_LEFT,
		_content_width() * 0.4,
		SUB_FONT_SIZE,
		UiPalette.GLOW_AMBER
	)
	if _code == "":
		return
	# 発行済みのコードだけを載せる。画像1枚で「見せる」と「渡す」を完結させるため。
	draw_string(
		_font,
		Vector2(SHEET_WIDTH - MARGIN - 360.0, 78.0),
		"デッキコード %s" % _code,
		HORIZONTAL_ALIGNMENT_RIGHT,
		360.0,
		SUB_FONT_SIZE + 6,
		UiPalette.TEXT_OFFWHITE
	)
	draw_string(
		_font,
		Vector2(SHEET_WIDTH - MARGIN - 360.0, 110.0),
		"デッキ編集の「共有」から読み込めます",
		HORIZONTAL_ALIGNMENT_RIGHT,
		360.0,
		FOOTER_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)


## 隅の作品名とバージョン。貼られた画像だけを見た人が、何のゲームのいつの構築か
## 追えるようにするため(GameDesign.md 9章)。
func _draw_footer() -> void:
	var y := _footer_baseline()
	draw_string(
		_font,
		Vector2(MARGIN, y),
		TITLE_NAME,
		HORIZONTAL_ALIGNMENT_LEFT,
		_content_width() * 0.5,
		FOOTER_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
	draw_string(
		_font,
		Vector2(SHEET_WIDTH - MARGIN - 320.0, y),
		GameVersion.display(),
		HORIZONTAL_ALIGNMENT_RIGHT,
		320.0,
		FOOTER_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
