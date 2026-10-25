extends SignatureMove
## クラックの被弾(GameDesign.md 9章):駒の表面にひびが走り、割れ目から光の札が1枚こぼれ出て自分の
## 情報帯へ飛ぶ(ドロー)。

const CRACK := 0.2
const EMERGE := 0.14
const FLY := 0.3
## ひびの起点(駒の中心から)と本数・長さ・折れ曲がり、札の大きさと出てくる高さ、届いた所の輪。
const ORIGIN := Vector2(6.0, -8.0)
const RAYS := 5
const REACH := 26.0
const KINKS := 3
const JAG := 5.0
const CARD := 7.0
const POP := 26.0
const GLOW := 30.0
const LIGHT := Color(1.0, 0.95, 0.75, 1.0)


func impact_at() -> float:
	return CRACK + EMERGE + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var root := from + ORIGIN
	var crack := ease(phase(t, 0.0, CRACK), 0.5)
	for i in range(RAYS):
		var dir := Vector2.from_angle(
			TAU * (float(i) + SignaturePaint.jitter(i, 161) * 0.6) / float(RAYS)
		)
		var points := PackedVector2Array([root])
		for k in range(1, KINKS + 1):
			var s := float(k) / float(KINKS)
			var side := dir.orthogonal() * (SignaturePaint.jitter(i * 5 + k, 162) - 0.5) * JAG
			points.append(root + dir * REACH * crack * s + side)
		ShapePaint.polyline(ci, points, Color(LIGHT, alpha * 0.4), 4.0, true)
		ShapePaint.polyline(ci, points, Color(UiPalette.OUTLINE_DARK, alpha * 0.9), 1.4, true)
	var emerge := ease(phase(t, CRACK, EMERGE), 0.6)
	var fly := phase(t, CRACK + EMERGE, FLY)
	if emerge > 0.0 and fly < 1.0:
		var lifted := root - Vector2(0.0, POP * emerge)
		var s := ease(fly, 1.3)
		var at := lifted.lerp(targets[0], s) - Vector2(0.0, 26.0 * sin(s * PI))
		SignaturePaint.card_glint(item, at, CARD * emerge, -0.3 + fly * 2.0, alpha)
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
