extends SignatureMove
## 追い風の恵与(GameDesign.md 9章):撃った位置から砂まじりの風が3筋、うねりながら対象の駒へ吹き寄せ、
## 届いた瞬間に駒の足元から駆ける火の筋が3本、前(右)へ走り抜けて金色の輪が広がる(疾走を与え、砂が1粒落ちる)。

const GUST := 0.4
const RUN := 0.3
## 風の筋の数・横のずれ・うねりの幅と回数・太さ・尾の長さ(進みの割合)、運ぶ砂粒の数。
const LANES := 3
const LANE_GAP := 14.0
const SWAY := 10.0
const WAVES := 2.0
const WIND_WIDTH := 2.6
const TAIL := 0.35
const TRAIL_STEPS := 12
const GRAINS := 3
## 足元の火の筋の高さ(駒の中心から下へ)・間隔・走る距離・長さ・太さ。
const FEET := 22.0
const STREAK_GAP := 12.0
const RUN_REACH := 70.0
const COMET := 40.0
const COMET_WIDTH := 8.0


func impact_at() -> float:
	return GUST


func duration() -> float:
	return impact_at() + RUN + FADE * 0.5


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var target := targets[0]
	var gust := phase(t, 0.0, GUST)
	var along := (target - from).normalized()
	var side := along.orthogonal()
	if gust > 0.0 and gust < 1.0:
		for lane in range(LANES):
			var offset := (float(lane) - float(LANES - 1) * 0.5) * LANE_GAP
			var head := ease(clampf(gust * 1.15 - float(lane) * 0.05, 0.0, 1.0), 0.6)
			var points := PackedVector2Array()
			for i in range(TRAIL_STEPS + 1):
				var s := maxf(head - TAIL * float(TRAIL_STEPS - i) / float(TRAIL_STEPS), 0.0)
				var wave := sin((s * WAVES + float(lane) * 0.3) * TAU) * SWAY * (1.0 - s)
				points.append(from.lerp(target, s) + side * (offset * (1.0 - s) + wave))
			ShapePaint.polyline(ci, points, Color(UiPalette.WIND, alpha * 0.8), WIND_WIDTH, true)
			for g in range(GRAINS):
				var p := points[int(float(TRAIL_STEPS) * (0.4 + 0.2 * float(g)))]
				ShapePaint.circle(
					ci,
					p + side * (SignaturePaint.jitter(lane * GRAINS + g, 503) - 0.5) * 6.0,
					1.7,
					Color(SignaturePaint.SAND, alpha)
				)
	var run := phase(t, impact_at(), RUN)
	if run > 0.0 and run < 1.0:
		for i in range(LANES):
			var y := FEET + (float(i) - 1.0) * STREAK_GAP * 0.6
			var lag := float(i % 2) * 0.12
			var k := clampf((run - lag) / (1.0 - lag), 0.0, 1.0)
			var head := target + Vector2(-COMET * 0.5 + RUN_REACH * ease(k, 0.5), y) * zoom
			SignaturePaint.blaze_comet(
				item, head, Vector2.RIGHT, COMET * zoom, COMET_WIDTH * zoom, alpha * (1.0 - k)
			)
	SignaturePaint.boon_ring(item, target, run, alpha)
