class_name ScreenBackdrop
extends Control
## 背景イラストを持たない画面(対局・カード一覧・デッキ編集)の下地。
##
## 無地の `ColorRect` 1枚だとフラットベクターに見えてしまうため、他のコード描画UIと同じ
## 手当て(多段グラデーション + グレイン + 周囲の落ち込み)をここへ集約する。
## 色は `UiPalette`、描画は `UiPaint` を経由する(BoardTable/BarPanel と同じ流儀)。

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := PackedVector2Array(
		[rect.position, Vector2(rect.end.x, 0.0), rect.end, Vector2(0.0, rect.end.y)]
	)
	UiPaint.fill_gradient_polygon(ci, points, rect, STOPS)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA)
	_draw_vignette()


## 端の落ち込み。半透明の細い帯を重ねて段階的に暗くする(1枚の矩形だと境目が線に見える)。
func _draw_vignette() -> void:
	var band := size.x * VIGNETTE_WIDTH_RATIO / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var alpha := VIGNETTE_ALPHA * float(VIGNETTE_STEPS - i) / float(VIGNETTE_STEPS)
		var shade := Color(0.0, 0.0, 0.0, alpha)
		draw_rect(Rect2(float(i) * band, 0.0, band, size.y), shade)
		draw_rect(Rect2(size.x - float(i + 1) * band, 0.0, band, size.y), shade)
