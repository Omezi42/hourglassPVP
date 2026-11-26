extends SignatureMove
## ブレイズの恵与(GameDesign.md 9章):落砂で、駒の足元の左右から炎が駒の縁を駆け上がり、頭上で合わさって
## 一度大きく燃え立ち、金色の輪が広がる(砂がもう1粒落ちる)。

const RACE := 0.34
const FLARE := 0.3
## 炎が駆ける楕円の半径、炎の舌の高さと幅、頭上で燃え立つ高さ、火の粉の広がり。
const OUTLINE := Vector2(42.0, 56.0)
const TONGUE := 18.0
const TONGUE_WIDTH := 12.0
const CROWN := 40.0
const CROWN_WIDTH := 26.0


func impact_at() -> float:
	return RACE


func duration() -> float:
	return impact_at() + FLARE


func top_extent() -> float:
	return (OUTLINE.y + CROWN) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var race := ease(phase(t, 0.0, RACE), 0.7)
	var radius := OUTLINE * zoom
	if t < impact_at() + FADE:
		var trail_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
		for side: float in [-1.0, 1.0]:
			# 真下(PI/2)から真上(-PI/2)へ、左右それぞれ半周を駆け上がる
			for i in range(4):
				var k := maxf(race - float(i) * 0.08, 0.0)
				var a := PI * 0.5 + side * PI * k
				var at := from + Vector2(cos(a) * radius.x, sin(a) * radius.y)
				SignaturePaint.flame_tongue(
					item,
					at,
					TONGUE * zoom * (1.0 - float(i) * 0.2),
					TONGUE_WIDTH * zoom * (1.0 - float(i) * 0.2),
					side * 3.0 * zoom,
					trail_alpha * (1.0 - float(i) * 0.22)
				)
	var flare := phase(t, impact_at(), FLARE)
	if flare > 0.0 and flare < 1.0:
		var top := from - Vector2(0.0, radius.y)
		var h := CROWN * zoom * sin(minf(flare * 1.8, 1.0) * PI * 0.5)
		var fa := alpha * (1.0 - flare)
		SignaturePaint.flame_tongue(
			item,
			top + Vector2(-9.0, 4.0) * zoom,
			h * 0.7,
			CROWN_WIDTH * 0.6 * zoom,
			-8.0 * zoom,
			fa
		)
		SignaturePaint.flame_tongue(
			item, top + Vector2(9.0, 4.0) * zoom, h * 0.7, CROWN_WIDTH * 0.6 * zoom, -4.0 * zoom, fa
		)
		SignaturePaint.flame_tongue(
			item, top + Vector2(0.0, 4.0) * zoom, h, CROWN_WIDTH * zoom, -6.0 * zoom, fa
		)
		SignaturePaint.ember_motes(item, top, flare, alpha, 40.0 * zoom, 46.0 * zoom)
	SignaturePaint.boon_ring(item, targets[0], flare, alpha)
