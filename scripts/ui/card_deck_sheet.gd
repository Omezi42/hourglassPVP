class_name CardDeckSheet
extends Control
## 共有用のデッキ表(GameDesign.md 9章)。デッキの中身を1枚の絵として書き出すための組み立て。
##
## **画面へ直接置かず、`SubViewport` の中だけで生きる。**書き出す画像と、共有パネルへ
## 映しているものが同じ実体になるため、見本と書き出しが食い違う経路そのものが無い。
##
## **中身は工房と同じ棚(`CardDeckShelf`)を横長にしたもの。**画面で見た形と貼られた画像が
## 一致していることを優先する(GameDesign.md 9章)ため、共有のためだけの並べ方は作らない。
## 横10×縦3にしているのは、貼られる先(X・Discord)で横長のほうが大きく表示されるため。
##
## マナカーブの棒グラフは持たない。並びがコスト順に固定されている以上、
## どのあたりまでが軽いカードかは棚の上での位置がそのまま示す。

## 貼られることを前提とした横長。**行数が固定になったため高さも固定**。
## 1280x720(16:9)に収めているのは、SNSのタイムラインで切り取られずに出る比のため。
const SHEET_SIZE := Vector2(1280.0, 720.0)
const MARGIN := 36.0
## 共有の表は横長にする。工房(6列×5段)と枠の総数は同じ。
const COLUMNS := 10
const RACK_TOP := 138.0
## 3段ぶん。**駒の高さは幅で決まる**(1208 / 10 列)ため、そこから逆算した値。
const RACK_HEIGHT := 510.0
const TITLE_FONT_SIZE := 38
const SUB_FONT_SIZE := 22
const FOOTER_FONT_SIZE := 18
const TITLE_NAME := "砂時計アリーナ"
const THEME_PATH := "res://resources/theme/main_theme.tres"

var _rack: CardDeckShelf
var _font: Font
var _deck_name := ""
var _count := 0
var _code := ""


func _ready() -> void:
	if theme == null and ResourceLoader.exists(THEME_PATH):
		theme = load(THEME_PATH)
	_font = get_theme_default_font()
	if _font == null or _font == ThemeDB.fallback_font:
		if theme != null and theme.default_font != null:
			_font = theme.default_font
		else:
			_font = TextGlyphs.ui_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SHEET_SIZE
	custom_minimum_size = SHEET_SIZE
	_rack = CardDeckShelf.new()
	_rack.columns = COLUMNS
	_rack.readonly = true
	_rack.position = Vector2(MARGIN, RACK_TOP)
	_rack.size = Vector2(SHEET_SIZE.x - MARGIN * 2.0, RACK_HEIGHT)
	add_child(_rack)


## 書き出す絵の大きさ。映す側・書き出す側はここを見る。
func sheet_size() -> Vector2:
	return SHEET_SIZE


## 表の中身を差し替える。`code` は発行済みのときだけ渡す(GameDesign.md 9章)。
func show_deck(deck: Array, deck_name: String, code: String) -> void:
	_deck_name = deck_name
	_count = deck.size()
	_code = code
	_rack.deck = deck.duplicate()
	queue_redraw()


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
		(SHEET_SIZE.x - MARGIN * 2.0) * 0.62,
		TITLE_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	draw_string(
		_font,
		Vector2(MARGIN, 116.0),
		"%d枚" % _count,
		HORIZONTAL_ALIGNMENT_LEFT,
		240.0,
		SUB_FONT_SIZE,
		UiPalette.GLOW_AMBER
	)
	if _code == "":
		return
	# 発行済みのコードだけを載せる。画像1枚で「見せる」と「渡す」を完結させるため。
	draw_string(
		_font,
		Vector2(SHEET_SIZE.x - MARGIN - 360.0, 78.0),
		"デッキコード %s" % _code,
		HORIZONTAL_ALIGNMENT_RIGHT,
		360.0,
		SUB_FONT_SIZE + 6,
		UiPalette.TEXT_OFFWHITE
	)
	draw_string(
		_font,
		Vector2(SHEET_SIZE.x - MARGIN - 360.0, 110.0),
		"デッキ編集の「共有」から読み込めます",
		HORIZONTAL_ALIGNMENT_RIGHT,
		360.0,
		FOOTER_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)


## 隅の作品名とバージョン。貼られた画像だけを見た人が、何のゲームのいつの構築か
## 追えるようにするため(GameDesign.md 9章)。
func _draw_footer() -> void:
	var y := RACK_TOP + RACK_HEIGHT + 34.0
	draw_string(
		_font,
		Vector2(MARGIN, y),
		TITLE_NAME,
		HORIZONTAL_ALIGNMENT_LEFT,
		400.0,
		FOOTER_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
	draw_string(
		_font,
		Vector2(SHEET_SIZE.x - MARGIN - 320.0, y),
		GameVersion.display(),
		HORIZONTAL_ALIGNMENT_RIGHT,
		320.0,
		FOOTER_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
