extends SignatureMove
## ダッシュの登場(GameDesign.md 9章):着地の直前に台座の左から右へ風の筋が3本走り抜け、着地した
## 足元から砂埃が後ろ(左)へ流れる(速落=出たターンから殴れる印)。

const STREAK_LATE := 0.1
const DUST := 0.42
## 風の筋の高さ(台座の上面から上へ)と長さ、走り抜ける幅、筋ごとの遅れ。
const LANES := [30.0, 62.0, 94.0]
const LAGS := [0.0, 0.05, 0.025]
const STREAK := 70.0
const SWEEP := 150.0
## 砂埃の粒の数と、後ろへ流れる距離・舞い上がる高さ。
const GRAINS := 12
const DRIFT := 64.0
const RISE := 20.0
const WIND := Color(0.9, 0.96, 1.0, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + DUST + FADE


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var span := impact_at() + STREAK_LATE
	for i in range(LANES.size()):
		var lag: float = LAGS[i]
		var q := phase(t, lag, span - lag)
		if q <= 0.0 or q >= 1.0:
			continue
		var y: float = from.y - LANES[i]
		var head := from.x - SWEEP + SWEEP * 2.0 * ease(q, 0.7)
		var tail := head - STREAK * (1.0 - q * 0.5)
		var fade := alpha * sin(q * PI)
		item.draw_line(Vector2(tail, y), Vector2(head, y), Color(WIND, fade * 0.35), 5.0, true)
		item.draw_line(Vector2(tail, y), Vector2(head, y), Color(WIND, fade), 1.8, true)
	var dust := phase(t, impact_at(), DUST)
	if dust <= 0.0 or dust >= 1.0:
		return
	for i in range(GRAINS):
		var delay := SignaturePaint.jitter(i, 61) * 0.3
		var q := clampf((dust - delay) / (1.0 - delay), 0.0, 1.0)
		if q <= 0.0:
			continue
		var reach := DRIFT * (0.5 + 0.5 * SignaturePaint.jitter(i, 62)) * ease(q, 0.5)
		var rise := RISE * SignaturePaint.jitter(i, 63) * ease(q, 0.6)
		var at := from + Vector2(-reach - 10.0, -rise)
		var color := SignaturePaint.SAND.lerp(
			SignaturePaint.SAND_DARK, SignaturePaint.jitter(i, 64)
		)
		ShapePaint.circle(ci, at, 1.6 + q * 1.8, Color(color, alpha * (1.0 - q) * 0.8))
