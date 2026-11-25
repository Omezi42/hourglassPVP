extends SignatureMove
## リブラの恵与(GameDesign.md 9章):設置で、駒の上に天秤が現れて左へ大きく傾き、ゆっくり水平へ戻る間に、
## 下がった皿から燠の色の砂が山なりに自分のHPの器へ流れ込み、届いたところで金色の輪が広がる(回復)。

const APPEAR := 0.12
const TIP := 0.18
const POUR := 0.5
const RING := 0.3
## 天秤の台の位置(駒の中心から上へ)と、傾ききる角度(正で左が下がる)。
const LIFT := 38.0
const TILT := 0.42
## 流れる砂粒の数、山なりの高さ、筋の長さ(進みの割合)、粒の大きさ。
const GRAINS := 18
const ARC := 44.0
const STREAM := 0.4
const GRAIN := 2.2
## 支柱の頂の玉のぶん。
const POST_CAP := 6.0


func impact_at() -> float:
	return APPEAR + TIP + POUR


func duration() -> float:
	return impact_at() + RING


func top_extent() -> float:
	return LIFT + SignaturePaint.SCALE_POST + POST_CAP


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var tip := back_out(phase(t, APPEAR, TIP))
	var pour := phase(t, APPEAR + TIP, POUR)
	var tilt := TILT * tip * (1.0 - ease(pour, 1.4))
	var base := from - Vector2(0.0, LIFT)
	var scale_alpha := alpha * intro * (1.0 - phase(t, impact_at(), RING))
	SignaturePaint.balance(item, base, tilt, scale_alpha)
	var top := base - Vector2(0.0, SignaturePaint.SCALE_POST)
	var arm := Vector2(SignaturePaint.SCALE_BEAM * 0.5, 0.0).rotated(-tilt)
	var pan := top - arm + Vector2(0.0, SignaturePaint.SCALE_CHAIN)
	if pour > 0.0 and t < impact_at() + FADE:
		var stream_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
		for i in range(GRAINS):
			var lag := SignaturePaint.jitter(i, 321) * STREAM
			var s := clampf(pour * (1.0 + STREAM) - lag, 0.0, 1.0)
			if s <= 0.0 or s >= 1.0:
				continue
			var at := pan.lerp(targets[0], ease(s, 0.8)) - Vector2(0.0, ARC * sin(s * PI))
			at.x += (SignaturePaint.jitter(i, 322) - 0.5) * 6.0
			var color := UiPalette.EMBER.lerp(SignaturePaint.BOON, ease(s, 0.6))
			ShapePaint.circle(ci, at, GRAIN, Color(color, stream_alpha))
		ShapePaint.circle(ci, pan, 6.0 * (1.0 - pour), Color(UiPalette.EMBER, stream_alpha * 0.8))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
