class_name ScreenBackdrop
extends Control
## 背景イラストを持たない画面の下地。**画面ごとに「どんな場所か」を持たせる**
## (GameDesign.md 9章)。
##
## 以前はどの画面も同じ暗いグラデーション1枚だった。工房を板壁の作業場として描いたときに
## 効いたのは、そこが**場所として読めた**ためであり、同じ手当てを他の画面へも広げる。
## **ただし画面ごとに壁を描き起こさない。**部品は `RoomPaint` が持ち、ここは
## 場所ごとの組み合わせだけを決める。
##
## 色は `UiPalette`、描画は `UiPaint` / `RoomPaint` を経由する。

## 場所の種類。**画面の数だけ増やさない**——性格が同じ画面は同じ場所を使う。
enum Room {
	## 無地の暗がり(対局画面のように、盤面へ視線を集めたい画面)。
	PLAIN,
	## 書庫。読む・調べる画面(ルール・キーワード辞書・画面の見かた)。
	LIBRARY,
	## 記録室。積み上げたものを見る画面(戦績・リプレイ一覧・ミッション)。
	VAULT,
	## 控えの間。選ぶ・待つ画面(デッキ一覧・ルームマッチ・パズル選択)。
	HALL,
	## 帳場。買う画面(ショップ)。
	SHOP,
}

## 中央付近をわずかに持ち上げ、上下の端へ向かって沈める。
const STOPS := [
	[0.0, Color(0.09, 0.08, 0.11, 1.0)],
	[0.42, Color(0.13, 0.11, 0.15, 1.0)],
	[1.0, Color(0.05, 0.04, 0.06, 1.0)],
]
const GRAIN_ALPHA := 0.05
## 左右の暗がり。中央へ視線を集めるため、端を段階的に落とす。
const VIGNETTE_STEPS := 5
const VIGNETTE_WIDTH_RATIO := 0.22
const VIGNETTE_ALPHA := 0.1
## 壁の色味。場所ごとに振る(部品は同じでも、同じ部屋には見えないようにする)。
const WALL_TINTS := {
	Room.LIBRARY: Color(0.74, 0.84, 1.06),
	Room.VAULT: Color(0.86, 0.90, 1.02),
	Room.HALL: Color(1.10, 1.00, 0.86),
	Room.SHOP: Color(1.14, 0.94, 0.74),
}
## 中身を置く帯を落とす濃さ。**濃くしすぎると板目ごと消えて元の暗がりに戻る**ため、
## 「板目が見えていて、その上の文字も読める」ところで止める。
const HAZE_ALPHA := 0.26
const HAZE_TOP := 88.0

## どの場所として描くか。`add_child()` の前後どちらで変えてもよい。
var room: Room = Room.PLAIN:
	set(value):
		room = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	if room == Room.PLAIN:
		var points := PackedVector2Array(
			[rect.position, Vector2(rect.end.x, 0.0), rect.end, Vector2(0.0, rect.end.y)]
		)
		UiPaint.fill_gradient_polygon(ci, points, rect, STOPS)
		UiPaint.apply_grain(ci, rect, GRAIN_ALPHA)
		_draw_vignette()
		return
	RoomPaint.wall(self, rect, 913, WALL_TINTS.get(room, Color.WHITE))
	_draw_furniture(rect)
	# **中身を置く帯を暗く落とす。**壁をそのまま下地にすると、文字や一覧のカードが
	# 板目の上へ乗って読みにくい。壁は「奥にある」ものとして扱う。
	_draw_haze(rect)
	_draw_vignette()


## 場所ごとの造作。**壁へ据え付けるものだけ**にして、中身の邪魔をしない。
func _draw_furniture(rect: Rect2) -> void:
	match room:
		Room.LIBRARY:
			RoomPaint.bookshelf(self, Rect2(0, 96, 176, rect.size.y - 96), 4021)
			RoomPaint.bookshelf(self, Rect2(rect.size.x - 176, 96, 176, rect.size.y - 96), 4022)
			RoomPaint.lamp(self, Vector2(rect.size.x * 0.5, -60), rect.size.y, 520.0)
		Room.VAULT:
			RoomPaint.drawers(self, Rect2(0, 96, 150, rect.size.y - 96), 2, 6)
			RoomPaint.drawers(self, Rect2(rect.size.x - 150, 96, 150, rect.size.y - 96), 2, 6)
			RoomPaint.lamp(self, Vector2(rect.size.x * 0.5, -60), rect.size.y, 480.0)
		Room.HALL:
			RoomPaint.gear(self, Vector2(rect.size.x - 90, 108), 84.0, 14, 0.0, 0.13)
			RoomPaint.gear(self, Vector2(96, rect.size.y - 90), 64.0, 12, 0.2, 0.11)
			RoomPaint.lamp(self, Vector2(rect.size.x * 0.5, -80), rect.size.y, 560.0)
		Room.SHOP:
			RoomPaint.bookshelf(self, Rect2(0, 96, 132, rect.size.y - 96), 5510)
			RoomPaint.drawers(self, Rect2(rect.size.x - 132, 96, 132, rect.size.y - 96), 2, 5)
			RoomPaint.lamp(self, Vector2(rect.size.x * 0.5, -40), rect.size.y, 500.0)
		_:
			pass


## 中身の乗る中央を落として、板目が文字の背後で暴れないようにする。
## **上端は落とさない**——ヘッダーの手前は壁がいちばんよく見える帯であり、
## そこまで沈めると場所そのものが見えなくなる。
func _draw_haze(rect: Rect2) -> void:
	draw_rect(
		Rect2(rect.position.x, rect.position.y + HAZE_TOP, rect.size.x, rect.size.y - HAZE_TOP),
		Color(0.03, 0.024, 0.030, HAZE_ALPHA)
	)


## 端の落ち込み。半透明の細い帯を重ねて段階的に暗くする(1枚の矩形だと境目が線に見える)。
func _draw_vignette() -> void:
	var band := size.x * VIGNETTE_WIDTH_RATIO / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var alpha := VIGNETTE_ALPHA * float(VIGNETTE_STEPS - i) / float(VIGNETTE_STEPS)
		var shade := Color(0.0, 0.0, 0.0, alpha)
		draw_rect(Rect2(float(i) * band, 0.0, band, size.y), shade)
		draw_rect(Rect2(size.x - float(i + 1) * band, 0.0, band, size.y), shade)
