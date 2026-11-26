extends SignatureMove
## チェイサーの登場(GameDesign.md 9章):着地の直前に、炎の尾を引く火矢が台座の左から右へ駆け抜け、
## 着地した足元に駆ける火の筋が前(右)へ残って消える(弱った獲物を追う)。

const FLY := 0.3
const TRAIL := 0.36
## 矢の高さ(台座の上面から上へ)・走り抜ける幅・長さ・太さ、鏃と矢羽の大きさ。
const HEIGHT := 40.0
const SWEEP := 170.0
const SHAFT := 46.0
const SHAFT_WIDTH := 3.0
const HEAD := Vector2(10.0, 6.0)
const FLETCH := Vector2(12.0, 7.0)
## 足元に残る火の筋の長さ・太さ・伸びる距離。
const COMET := 60.0
const COMET_WIDTH := 9.0
const REACH := 40.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + TRAIL + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_CHASER


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var start := impact_at() - FLY * 0.6
	var fly := phase(t, start, FLY)
	if fly > 0.0 and fly < 1.0:
		var tip := from + Vector2(-SWEEP * 0.5 + SWEEP * fly, -HEIGHT)
		var nock := tip - Vector2(SHAFT, 0.0)
		SignaturePaint.blaze_comet(
			item, tip - Vector2(HEAD.x, -2.0), Vector2.RIGHT, SHAFT * 1.4, 12.0, alpha
		)
		ShapePaint.polyline(
			ci,
			PackedVector2Array([nock, tip]),
			Color(UiPalette.INK_950, alpha * 0.8),
			SHAFT_WIDTH + 2.0,
			true
		)
		ShapePaint.polyline(
			ci, PackedVector2Array([nock, tip]), Color(UiPalette.BIRCH, alpha), SHAFT_WIDTH, true
		)
		var head := PackedVector2Array(
			[
				tip + Vector2(HEAD.x, 0.0),
				tip + Vector2(0.0, -HEAD.y),
				tip + Vector2(-HEAD.x * 0.3, 0.0),
				tip + Vector2(0.0, HEAD.y)
			]
		)
		ShapePaint.convex_polygon(ci, head, Color(UiPalette.STEEL, alpha))
		for side: float in [-1.0, 1.0]:
			var vane := PackedVector2Array(
				[
					nock + Vector2(FLETCH.x, 0.0),
					nock + Vector2(FLETCH.x * 0.2, side * FLETCH.y),
					nock + Vector2(-FLETCH.x * 0.2, side * FLETCH.y),
					nock
				]
			)
			ShapePaint.convex_polygon(ci, vane, Color(UiPalette.FEATHER_RED, alpha))
	var trail := phase(t, impact_at(), TRAIL)
	if trail > 0.0 and trail < 1.0:
		var head := from + Vector2(COMET * 0.3 + REACH * ease(trail, 0.4), -4.0)
		SignaturePaint.blaze_comet(
			item, head, Vector2.RIGHT, COMET, COMET_WIDTH, alpha * (1.0 - trail)
		)
