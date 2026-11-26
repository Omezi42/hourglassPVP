extends SignatureMove
## クロックワークの登場(GameDesign.md 9章):着地すると、駒の頭上に大小三つの歯車が現れて噛み合って回り、
## 最後に小さな歯車が一つ早く回ってカチリと止まり、噛み合わせから音の輪が広がる(歯車が噛み合うと一つ早く回る)。

const APPEAR := 0.12
const TURN := 0.42
const CLICK := 0.16
## 大きい歯車の中心(台座の上面から上へ)と半径、歯の数と高さ、小さい歯車の半径・歯の数、
## 回る量(大きい歯車の周回)、最後に小さい歯車だけが余分に進む歯の数、音の輪の広がり。
const LIFT := 130.0
const BIG := 19.0
const BIG_TEETH := 12
const TOOTH := 4.0
const SMALL := 12.0
const SMALL_TEETH := 8
const TURNS := 0.35
const EXTRA_TEETH := 1.0
const RING_REACH := 26.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + APPEAR + TURN + CLICK + FADE


func sound() -> int:
	return SoundBank.Sfx.SIG_CLOCKWORK


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * minf(phase(t, impact_at(), APPEAR) * 1.5, 1.0)
	var big_at := from - Vector2(0.0, LIFT)
	var mesh := BIG + SMALL + TOOTH * 0.6
	var left_at := big_at + Vector2.from_angle(PI * 0.86) * mesh
	var right_at := big_at + Vector2.from_angle(PI * 0.12) * mesh
	var turn := ease(phase(t, impact_at() + APPEAR, TURN), 1.6) * TAU * TURNS
	var click := phase(t, impact_at() + APPEAR + TURN - 0.05, CLICK * 0.6)
	var ratio := float(BIG_TEETH) / float(SMALL_TEETH)
	var extra := back_out(click) * TAU / float(SMALL_TEETH) * EXTRA_TEETH
	_gear(ci, left_at, SMALL, SMALL_TEETH, -turn * ratio + 0.2, UiPalette.STEEL, alpha)
	_gear(ci, right_at, SMALL, SMALL_TEETH, -turn * ratio - extra + 0.5, UiPalette.STEEL, alpha)
	_gear(ci, big_at, BIG, BIG_TEETH, turn, UiPalette.TOLL_BRASS, alpha)
	var ring := phase(t, impact_at() + APPEAR + TURN + CLICK * 0.4, CLICK + FADE * 0.6)
	if ring > 0.0 and ring < 1.0:
		var bite := big_at.lerp(right_at, BIG / mesh)
		ShapePaint.circle(
			ci, bite, 6.0 * (1.0 - ring), Color(SignaturePaint.SPARK_HOT, alpha * (1.0 - ring))
		)
		SignaturePaint.toll_arcs(
			item, bite, Vector2.ZERO, RING_REACH * ease(ring, 0.5), alpha * (1.0 - ring)
		)


## 歯車1つ。外周に歯を並べた多角形と、肉抜きの暗い輪、軸。
static func _gear(
	ci: RID, at: Vector2, radius: float, teeth: int, turn: float, color: Color, alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var rim := PackedVector2Array()
	var face := PackedVector2Array()
	for i in range(teeth * 4):
		var a := turn + TAU * float(i) / float(teeth * 4)
		var r := radius + (TOOTH if i % 4 < 2 else 0.0)
		rim.append(at + Vector2.from_angle(a) * (r + 1.4))
		face.append(at + Vector2.from_angle(a) * r)
	ShapePaint.colored_polygon(ci, rim, Color(UiPalette.INK_950, alpha * 0.85))
	ShapePaint.colored_polygon(ci, face, Color(color, alpha))
	ShapePaint.arc(
		ci,
		at,
		radius * 0.6,
		0.0,
		TAU,
		24,
		Color(UiPalette.INK_950, alpha * 0.35),
		radius * 0.28,
		true
	)
	ShapePaint.circle(ci, at, radius * 0.22, Color(UiPalette.BRASS_DEEP, alpha))
