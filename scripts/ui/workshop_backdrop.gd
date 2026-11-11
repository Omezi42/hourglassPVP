class_name WorkshopBackdrop
extends Control
## 時計工房(デッキ編集画面)の下地(GameDesign.md 9章)。板壁の作業場に夜の藍の幕を掛け、
## 左=在庫棚 / 右=組立台 の硝子の面を据える。
##
## **一覧と棚はこの上へ子として重ねる**(`Control._draw()` は自分の子より背面に描かれる)。
## 看板・面・小見出しまでをここが描き、画面側は中身だけを置く。
##
## **板壁・歯車・作業灯は `RoomPaint` が持つ**。他の画面の下地でも使うため、ここへ描き起こさない。

const SCREEN_SIZE := Vector2(1280, 720)
## 在庫棚と組立台。**左を狭め右を広く取る**——右は横6枠を並べるため、
## 一覧と同じ幅では1枠が狭くなる。
const SHELF_RECT := Rect2(26, 112, 566, 586)
const BENCH_RECT := Rect2(610, 112, 644, 586)
## 面の上端の小見出しの帯。ラベルはこの帯の左へ置き、下へ細い線を引く。
const BAND_HEIGHT := 48.0
## 吊り看板。
const SIGN_RECT := Rect2(464, 22, 352, 62)
## 縦画面(GameDesign.md 9章「縦画面」)。在庫棚と組立台は同じ1つの面に切り替えて出す。
const PORTRAIT_SIGN_RECT := Rect2(184, 22, 352, 62)
const PORTRAIT_BOX_RECT := Rect2(24, 280, 672, 976)
const SHELF_LABEL := "在庫棚"
const SIGN_LABEL := "時計工房"
const WALL_SEED := 913
const LABEL_INSET := 24.0
const LABEL_FONT := UiPalette.T_LEAD
const PORTRAIT_LABEL_FONT := UiPalette.T_HEAD
const SIGN_FONT := UiPalette.T_TITLE
## 看板を吊る鎖の、看板の端からの内寄せと、鎖の太さ・色の濃さ。
const CHAIN_INSET := 44.0
const CHAIN_WIDTH := 3.0
const CHAIN_ALPHA := 0.7
const CHAIN_RISE := 22.0

## 縦の配置で描くか。
var portrait := false:
	set(value):
		portrait = value
		size = Vector2(ScreenOrientation.base_size())
		queue_redraw()
## 縦で在庫棚(true)と組立台(false)のどちらの面を出すか。
var show_shelf := true:
	set(value):
		show_shelf = value
		queue_redraw()

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。
	size = SCREEN_SIZE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _draw() -> void:
	var screen := Vector2(ScreenOrientation.PORTRAIT_SIZE) if portrait else SCREEN_SIZE
	var rect := Rect2(Vector2.ZERO, screen)
	RoomPaint.wall(self, rect, WALL_SEED)
	if portrait:
		RoomPaint.gear(self, Vector2(640, 196), 78.0, 14, 0.0, 0.16)
		RoomPaint.gear(self, Vector2(70, 1236), 62.0, 12, 0.1, 0.12)
		RoomPaint.lamp(self, Vector2(520, -40), screen.y, 460.0)
	else:
		RoomPaint.gear(self, Vector2(1180, 92), 78.0, 14, 0.0, 0.16)
		RoomPaint.gear(self, Vector2(1258, 196), 46.0, 9, 0.22, 0.13)
		RoomPaint.gear(self, Vector2(86, 636), 62.0, 12, 0.1, 0.12)
		RoomPaint.lamp(self, Vector2(1010, -40), screen.y, 460.0)
	ShapePaint.gradient_convex(
		get_canvas_item(),
		PackedVector2Array(
			[rect.position, Vector2(rect.end.x, 0.0), rect.end, Vector2(0.0, rect.end.y)]
		),
		ScreenBackdrop.VEIL_STOPS
	)
	_draw_sign(PORTRAIT_SIGN_RECT if portrait else SIGN_RECT)
	if portrait:
		_draw_box(PORTRAIT_BOX_RECT, SHELF_LABEL if show_shelf else "")
	else:
		_draw_box(SHELF_RECT, SHELF_LABEL)
		_draw_box(BENCH_RECT, "")


## 吊り看板。2本の鎖で下げた硝子の札へ画面名を載せる。
func _draw_sign(rect: Rect2) -> void:
	var ci := get_canvas_item()
	var chain := Color(UiPalette.BRASS, CHAIN_ALPHA)
	for cx in [rect.position.x + CHAIN_INSET, rect.end.x - CHAIN_INSET]:
		draw_line(
			Vector2(cx, rect.position.y - CHAIN_RISE),
			Vector2(cx, rect.position.y),
			chain,
			CHAIN_WIDTH
		)
	UiKit.glass(ci, rect)
	UiKit.text_in(
		ci,
		UiFonts.display_font_for(SIGN_LABEL, _font),
		SIGN_LABEL,
		rect,
		SIGN_FONT,
		UiPalette.IVORY
	)


## 硝子の面。`label` があれば上端の帯へ小見出しを置き、その下へ細い線を引く。
func _draw_box(rect: Rect2, label: String) -> void:
	var ci := get_canvas_item()
	UiKit.glass(ci, rect)
	if label.is_empty():
		return
	var band := Rect2(rect.position + Vector2(LABEL_INSET, 0.0), Vector2(rect.size.x, BAND_HEIGHT))
	var px := PORTRAIT_LABEL_FONT if portrait else LABEL_FONT
	draw_string(
		_font,
		Vector2(band.position.x, band.get_center().y + _font.get_ascent(px) * 0.4),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		px,
		UiPalette.GOLD
	)
	UiKit.hairline(
		ci,
		Vector2(rect.position.x + LABEL_INSET, rect.position.y + BAND_HEIGHT),
		Vector2(rect.end.x - LABEL_INSET, rect.position.y + BAND_HEIGHT)
	)
