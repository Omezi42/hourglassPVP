extends SignatureMove
## マエストロの登場(GameDesign.md 9章):駒の頭上に指揮棒が現れて弧を描き、振り下ろした先から
## 五線が左右に広がって消える。

const SWING := 0.3
const SPREAD := 0.45
## 指揮棒の握りの高さ(台座の上面から上へ)と、振りはじめ・振りおろしの向き(ラジアン)。
const LIFT := 96.0
const RAISED := -2.3
const DOWNBEAT := 0.35
## 軌跡に残す光の点の数。
const TRAIL := 10
## 五線の本数・間隔と、広がりきったときの半幅。
const LINES := 5
const LINE_GAP := 5.0
const REACH := 120.0
const NOTE_SIZE := 4.5
## 五線の上に乗る音符の、中心からの位置(半幅に対する割合)。
const NOTE_AT := [-0.55, 0.55]


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + SWING + SPREAD


func sound() -> int:
	return SoundBank.Sfx.SIG_MAESTRO


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var alpha := fade_alpha(t)
	var grip := from - Vector2(0.0, LIFT * zoom)
	var swing := phase(t, impact_at(), SWING)
	var angle := lerpf(RAISED, DOWNBEAT, back_out(swing))
	var appear := minf(swing * 4.0, 1.0)
	_trail(item, grip, angle, alpha * appear)
	SignaturePaint.baton(item, grip, angle, zoom, alpha * appear)
	var spread := phase(t, impact_at() + SWING, SPREAD)
	if spread > 0.0:
		var tip := grip + Vector2.RIGHT.rotated(DOWNBEAT) * SignaturePaint.BATON_LENGTH * zoom
		_staff(item, tip, ease(spread, 0.35), alpha * (1.0 - ease(spread, 2.5)))


## 先が通った弧に残る光。振りはじめから今の向きまで。
func _trail(item: CanvasItem, grip: Vector2, angle: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var length := SignaturePaint.BATON_LENGTH * zoom
	for i in range(TRAIL):
		var k := float(i) / float(TRAIL)
		var at := grip + Vector2.RIGHT.rotated(lerpf(RAISED, angle, k)) * length
		ShapePaint.circle(ci, at, 2.4 * zoom * k, Color(SignaturePaint.MAESTRO, alpha * k * 0.6))


func _staff(item: CanvasItem, center: Vector2, progress: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var half := REACH * zoom * progress
	for line in range(LINES):
		var y := (float(line) - float(LINES - 1) * 0.5) * LINE_GAP * zoom
		var color := Color(SignaturePaint.MAESTRO, alpha * 0.8)
		item.draw_line(center + Vector2(-half, y), center + Vector2(half, y), color, 1.4, true)
	for at: float in NOTE_AT:
		var note := center + Vector2(at * half, -LINE_GAP * zoom)
		SignaturePaint.note(item, note, NOTE_SIZE * zoom, SignaturePaint.PAPER, alpha)
