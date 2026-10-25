extends SignatureMove
## チャイムの反転(GameDesign.md 9章):駒の上に小さなハンドベルが現れて2度鳴り、音符が光の札になって
## 自分の情報帯へ跳ねていく(ドロー)。

const APPEAR := 0.1
const RING_TIME := 0.3
const FLY := 0.32
## ベルの支点(駒の中心から上へ)と柄の長さ、振れ幅・回数、音の輪の広がり、音符と札の大きさ、届いた所の輪。
const LIFT := 74.0
const HANDLE := 14.0
const SWING := 0.45
const STRIKES := 2.0
const RIPPLE := 22.0
const NOTE := 5.0
const CARD := 7.0
const GLOW := 30.0


func impact_at() -> float:
	return APPEAR + RING_TIME + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var pivot := from - Vector2(0.0, LIFT)
	var ring := phase(t, APPEAR, RING_TIME)
	var swing := SWING * sin(ring * TAU * STRIKES) * (1.0 - ring * 0.4) if ring < 1.0 else 0.0
	item.draw_line(
		pivot,
		pivot + Vector2(0.0, -HANDLE).rotated(swing),
		Color(UiPalette.WOOD_TOP.lightened(0.25), a),
		4.0,
		true
	)
	SignaturePaint.bell(item, pivot, swing, a)
	for k in range(int(STRIKES)):
		var q := phase(t, APPEAR + RING_TIME * (float(k) + 0.25) / STRIKES, RING_TIME * 0.5)
		if q > 0.0 and q < 1.0:
			var mouth := pivot + Vector2(0.0, SignaturePaint.BELL_HEIGHT)
			ShapePaint.arc(
				ci,
				mouth,
				RIPPLE * ease(q, 0.5) + 6.0,
				PI * 0.1,
				PI * 0.9,
				14,
				Color(SignaturePaint.BOON, alpha * (1.0 - q)),
				2.0,
				true
			)
	var fly := phase(t, APPEAR + RING_TIME, FLY)
	if fly > 0.0 and fly < 1.0:
		var start := (
			pivot + Vector2(SignaturePaint.BELL_WIDTH * 0.6, SignaturePaint.BELL_HEIGHT * 0.5)
		)
		var s := ease(fly, 1.2)
		var at := (
			start.lerp(targets[0], s) - Vector2(0.0, 40.0 * absf(sin(s * PI * 1.5)) * (1.0 - s))
		)
		if fly < 0.45:
			SignaturePaint.note(item, at, NOTE, SignaturePaint.BOON, alpha)
		else:
			SignaturePaint.card_glint(
				item, at, CARD * minf((fly - 0.45) * 6.0, 1.0), fly * 2.0, alpha
			)
	var glow := phase(t, impact_at(), FADE)
	if glow > 0.0:
		ShapePaint.arc(
			ci,
			targets[0],
			GLOW * ease(glow, 0.4),
			0.0,
			TAU,
			32,
			Color(SignaturePaint.BOON, 1.0 - glow),
			2.0,
			true
		)
