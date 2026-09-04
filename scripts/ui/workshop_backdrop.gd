class_name WorkshopBackdrop
extends Control
## 時計工房(デッキ編集画面)の下地(GameDesign.md 9章)。板壁の作業場に、
## 左=在庫棚 / 右=組立台 の木箱を据える。
##
## **一覧と棚はこの上へ子として重ねる**(`Control._draw()` は自分の子より背面に描かれる)。
## 看板・棚板・枠までをここが描き、画面側は中身だけを置く。
##
## **部品そのものは `RoomPaint` が持つ。**板壁・歯車・作業灯・吊り看板・木箱は
## 他の画面の下地でも使うため、ここへ描き起こさない。

const SCREEN_SIZE := Vector2(1280, 720)
## 在庫棚と組立台。**左を狭め右を広く取る**——右は横6枠を並べるため、
## 一覧と同じ幅では1枠が狭くなる。
const SHELF_RECT := Rect2(26, 112, 566, 586)
const BENCH_RECT := Rect2(610, 112, 644, 586)
## 木箱の上端へ渡す帯。ラベルはこの木の上へ焼く。
const BAND_HEIGHT := 48.0
## 吊り看板。
const SIGN_RECT := Rect2(464, 22, 352, 62)

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。
	size = SCREEN_SIZE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, SCREEN_SIZE)
	RoomPaint.wall(self, rect, 913)
	RoomPaint.gear(self, Vector2(1180, 92), 78.0, 14, 0.0, 0.16)
	RoomPaint.gear(self, Vector2(1258, 196), 46.0, 9, 0.22, 0.13)
	RoomPaint.gear(self, Vector2(86, 636), 62.0, 12, 0.1, 0.12)
	RoomPaint.lamp(self, Vector2(1010, -40), SCREEN_SIZE.y, 460.0)
	RoomPaint.sign(self, SIGN_RECT, _font, "時計工房", 30)
	_draw_box(SHELF_RECT, "在  庫  棚", true)
	_draw_box(BENCH_RECT, "", false)


func _draw_box(rect: Rect2, label: String, hollow: bool) -> void:
	RoomPaint.wood_box(self, rect, hollow)
	RoomPaint.box_band(self, rect, BAND_HEIGHT, _font, label)
	RoomPaint.box_frame(self, rect)
