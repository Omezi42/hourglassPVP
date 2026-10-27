extends SignatureMove
## リリーフの設置(GameDesign.md 9章):相手の駒の1体ずつから淡い砂の粒が立ちのぼり、順に
## 自分のHPの器へ流れ込む。筋の数が回復量になり、最後の筋が届いたところで金色の輪が広がる(恵与)。

const RISE := 0.2
const FLOW := 0.42
const RING := 0.32
## 筋ごとの遅れ。相手の駒が多くても尺の上限に収まるよう、遅れの合計を `LAG_TOTAL` で抑える。
const LAG := 0.08
const LAG_TOTAL := 0.24
## 粒が立ちのぼる高さ(駒の中心から上へ)、1本の筋の粒の数と間隔、粒の大きさ、筋の膨らみ。
const LIFT := 24.0
const GRAINS := 5
const SPACING := 0.06
const GRAIN := 2.2
const BULGE := 40.0
const GLOW := Color(0.86, 1.0, 0.82, 1.0)


func impact_at() -> float:
	return RISE + FLOW + _lag() * float(maxi(foes.size() - 1, 0))


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var lag := _lag()
	for i in range(foes.size()):
		_stream(item, foes[i], targets[0], t - lag * float(i), alpha)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


func _lag() -> float:
	if foes.size() <= 1:
		return LAG
	return minf(LAG, LAG_TOTAL / float(foes.size() - 1))


## 駒1体ぶんの筋。粒が駒の上へ立ちのぼってから、弧を描いて器へ流れ込む。
func _stream(item: CanvasItem, origin: Vector2, goal: Vector2, t: float, alpha: float) -> void:
	if t <= 0.0:
		return
	var ci := item.get_canvas_item()
	var top := origin - Vector2(0.0, LIFT)
	var bend := (top + goal) * 0.5 - Vector2(0.0, BULGE)
	var glow := ease(phase(t, 0.0, RISE), 0.5)
	ShapePaint.circle(
		ci, origin, GRAIN * 4.0, Color(GLOW, alpha * 0.25 * glow * (1.0 - phase(t, RISE, FLOW)))
	)
	for g in range(GRAINS):
		var q := phase(t, RISE + SPACING * float(g), FLOW - SPACING * float(GRAINS - 1))
		var at: Vector2
		var a := alpha
		if q <= 0.0:
			at = origin.lerp(top, glow)
			a *= glow * 0.6
		elif q >= 1.0:
			continue
		else:
			var s := ease(q, -1.6)
			at = top.lerp(bend, s).lerp(bend.lerp(goal, s), s)
		var size := GRAIN * (1.0 - 0.12 * float(g))
		ShapePaint.circle(ci, at, size * 2.0, Color(GLOW, a * 0.3))
		ShapePaint.circle(ci, at, size, Color(SignaturePaint.SAND.lerp(GLOW, 0.5), a))
