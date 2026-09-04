class_name BoardGlow
extends Control
## 卓(`BoardTable`)の背後にだけ淡い光を置く(GameDesign.md 9章)。暗がりへ卓を直に置くと
## 卓が背景へ沈んで見えるため、卓と同じ矩形へ配置してその外周をわずかに光らせる。
##
## `BoardTable` より先に(=背面へ)`add_child()` すること。輪は自分の矩形(=卓の矩形)から
## 外側へ広がるだけで、`clip_contents` は立てていないため矩形の外まで描ける
## (CodedButtonStyleのホバーグローと同じ描き方)。

## 光が届く距離。GameDesign.md「卓の後ろにだけ淡い光」の"わずかに"を保つため、
## 盤面の読みやすさを損なわない範囲(24〜40px)に収める。
const RING_COUNT := 4
const RING_STEP := 9.0
## 卓の額の角丸(`BoardTable.FRAME_WIDTH` ではなく `_draw_frame()` の角丸半径18.0)に合わせる。
const CORNER_RADIUS := 18.0
const CORNER_SEGMENTS := 8
## 最も内側の輪の不透明度。卓の額に隠れて実際に見えるのは外側のにじみだけのため、
## ボタンのホバーグロー(0.14)よりやや低く抑える。
const PEAK_ALPHA := 0.10


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ci := get_canvas_item()
	var inner_rect := Rect2(Vector2.ZERO, size)
	for i in range(RING_COUNT):
		var grow_amount: float = float(i + 1) * RING_STEP
		var ring_rect: Rect2 = inner_rect.grow(grow_amount)
		var radius: float = CORNER_RADIUS + grow_amount
		var alpha: float = PEAK_ALPHA * (1.0 - float(i) / float(RING_COUNT))
		var color := Color(
			UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, alpha
		)
		var points := UiPaint.rounded_rect_points_uniform(ring_rect, radius, CORNER_SEGMENTS)
		UiPaint.fill_gradient_polygon(ci, points, ring_rect, [[0.0, color], [1.0, color]])
