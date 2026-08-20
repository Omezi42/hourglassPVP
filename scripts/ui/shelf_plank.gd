class_name ShelfPlank
extends Control
## 砂時計一覧の棚板。画像(shelf_plank.png)を使わず、BoardTable/BarPanelと同じ
## 「無地でもコード描画で質感を出す」方針で描く(フェーズ12 Q-4)。棚板は行の幅いっぱいに
## 敷く可変幅の土台のため、StyleBoxではなくControl._draw()で都度サイズに合わせて再構築する。
## 上面(木目)+真鍮の縁取り+前面木口(濃い影)の3層で立体感を出し、UiPaint/UiPaletteを使って
## 他のCoded系UIと同じ質感言語(グラデーション・グレイン)で仕上げる。

const TOP_FACE_RATIO := 0.6
const TRIM_RATIO := 0.08
const TOP_EDGE_HIGHLIGHT_ALPHA := 0.22
const NOISE_GRAIN_ALPHA := 0.05

const GRAIN_LINE_COUNT := 6
const GRAIN_LINE_ALPHA := 0.28
const GRAIN_LINE_WIDTH := 1.2
const GRAIN_WOBBLE := 2.0
const GRAIN_SEED := 20240819


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var ci := get_canvas_item()

	var top_h: float = size.y * TOP_FACE_RATIO
	var trim_h: float = size.y * TRIM_RATIO
	var top_rect := Rect2(rect.position, Vector2(size.x, top_h))
	var trim_rect := Rect2(Vector2(0.0, top_h), Vector2(size.x, trim_h))
	var lip_rect := Rect2(Vector2(0.0, top_h + trim_h), Vector2(size.x, size.y - top_h - trim_h))

	_fill_rect(ci, top_rect, UiPalette.WOOD_TOP, UiPalette.WOOD_MID)
	_draw_grain(top_rect)
	_fill_rect(ci, trim_rect, UiPalette.BRASS_HIGHLIGHT, UiPalette.BRASS_DARK)
	_fill_rect(ci, lip_rect, UiPalette.WOOD_MID, UiPalette.WOOD_DARK)

	draw_line(
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Color(1.0, 1.0, 1.0, TOP_EDGE_HIGHLIGHT_ALPHA),
		1.5
	)

	UiPaint.apply_grain(ci, rect, NOISE_GRAIN_ALPHA)


func _fill_rect(ci: RID, rect: Rect2, top_color: Color, bottom_color: Color) -> void:
	if rect.size.y <= 0.0:
		return
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)
	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top_color], [1.0, bottom_color]])


## 木目を表現する、緩やかに波打つ暗色の水平ストローク。固定シードの疑似乱数で波形を
## 決めつつ、始点・終点をrectの幅へ追従させることで、行の幅が変わっても破綻しない。
func _draw_grain(rect: Rect2) -> void:
	if rect.size.y <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAIN_SEED
	var color := Color(
		UiPalette.WOOD_DARK.r, UiPalette.WOOD_DARK.g, UiPalette.WOOD_DARK.b, GRAIN_LINE_ALPHA
	)
	for i in range(GRAIN_LINE_COUNT):
		var t: float = (float(i) + 0.5) / float(GRAIN_LINE_COUNT)
		var y: float = rect.position.y + rect.size.y * t
		var wobble_a: float = rng.randf_range(-GRAIN_WOBBLE, GRAIN_WOBBLE)
		var wobble_b: float = rng.randf_range(-GRAIN_WOBBLE, GRAIN_WOBBLE)
		var points := PackedVector2Array(
			[
				Vector2(rect.position.x, y + wobble_a),
				Vector2(rect.position.x + rect.size.x * 0.5, y - wobble_a),
				Vector2(rect.end.x, y + wobble_b),
			]
		)
		draw_polyline(points, color, GRAIN_LINE_WIDTH, true)
