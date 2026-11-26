extends SignatureMove
## スタンピードの演出(GameDesign.md 9章):設置で、駒の頭上から蹄鉄が3つ、砂煙を上げて跳ねながら駆け、
## 先頭の蹄鉄が対象へ跳び込む(HPを払う打撃では自分のHPの器へ、手札から出す恵与では出た駒へ)。

const GALLOP := 0.56
## 蹄鉄の数・遅れ(進みの割合)、跳ねる回数と高さ、大きさと太さ、出だしの高さ(駒の中心から上へ)。
const SHOES := 3
const LAG := 0.14
const HOPS := 3
const HOP := 26.0
const SHOE := 9.0
const SHOE_WIDTH := 4.0
const LIFT := 30.0
## 着地ごとの砂煙の大きさ、蹄鉄の後ろの火の筋の長さと太さ。
const PUFF := 7.0
const COMET := 26.0
const COMET_WIDTH := 7.0


func impact_at() -> float:
	return GALLOP


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var start := from - Vector2(0.0, LIFT * zoom)
	var target := targets[0]
	var gallop := phase(t, 0.0, GALLOP)
	for i in range(SHOES - 1, -1, -1):
		var lag := LAG * float(i)
		var k := clampf((gallop - lag) / (1.0 - lag * 0.5), 0.0, 1.0)
		if k <= 0.0:
			continue
		var stop := 1.0 - 0.12 * float(i)
		var s := k * stop
		var hop := absf(sin(s * float(HOPS) * PI)) * HOP * zoom
		var at := start.lerp(target, s) - Vector2(0.0, hop)
		var ahead := start.lerp(target, minf(s + 0.04, 1.0))
		var shoe_alpha := alpha * (1.0 if i == 0 else 1.0 - phase(t, GALLOP, FADE))
		# 跳ねて降りた所に砂煙
		var cycle := fmod(s * float(HOPS), 1.0)
		if cycle < 0.3 and s > 0.05:
			var ground := start.lerp(target, s - cycle / float(HOPS))
			UiPaint.fill_ellipse(
				ci,
				ground + Vector2(-4.0, 2.0) * zoom,
				Vector2(PUFF * 1.4, PUFF) * zoom * (1.0 + cycle * 2.0),
				Color(UiPalette.DUST, shoe_alpha * (1.0 - cycle / 0.3) * 0.8),
				14
			)
		SignaturePaint.blaze_comet(
			item,
			at,
			ahead - start.lerp(target, s),
			COMET * zoom,
			COMET_WIDTH * zoom,
			shoe_alpha * 0.8
		)
		_shoe(ci, at, shoe_alpha)
	var land := phase(t, impact_at(), FADE)
	if style == CardEnums.EffectVisualStyle.STRIKE:
		SignaturePaint.sparks(item, target, land, alpha)
	else:
		SignaturePaint.boon_ring(item, target, land, alpha)


## 下へ開いた蹄鉄。
func _shoe(ci: RID, at: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var r := SHOE * zoom
	ShapePaint.arc(
		ci,
		at,
		r,
		PI * 0.72,
		PI * 2.28,
		18,
		Color(UiPalette.INK_950, alpha * 0.85),
		(SHOE_WIDTH + 2.4) * zoom,
		true
	)
	ShapePaint.arc(
		ci, at, r, PI * 0.72, PI * 2.28, 18, Color(UiPalette.STEEL, alpha), SHOE_WIDTH * zoom, true
	)
