extends SignatureMove
## 砂つぶて(GameDesign.md 9章):自分の情報帯の上で砂粒がひとつかみに寄り集まり、ばらけながら
## 山なりに対象へ投げつけられ、ぱらぱらと当たって火花が散る(打撃)。続くドロー(PULSE)では、
## 情報帯の上で砂粒が1つ跳ねて手札の側へ落ちる。

const GATHER := 0.2
const THROW := 0.3
## 寄り集まる高さ(情報帯の中心から上へ)と、集まる前に散らばっている広さ。
const LIFT := 40.0
const SCATTER := 26.0
const GRAINS := 7
const GRAIN := 2.6
## 飛ぶ間に粒がばらける幅と、粒ごとの着弾のずれ(投げる区間に対する割合)。
const SPREAD := 9.0
const STAGGER := 0.18
## 弧の膨らみ(2点間の距離に対する割合)。
const ARC := 0.25
const DRAW_TIME := 0.36
const DRAW_HOP := 26.0
const DRAW_FALL := 40.0


func impact_at() -> float:
	return DRAW_TIME if _drawing() else GATHER + THROW


func draw(item: CanvasItem, t: float) -> void:
	if _drawing():
		_draw_hop(item, t)
		return
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var hub := from - Vector2(0.0, LIFT)
	var target: Vector2 = targets[0]
	var gather := ease(phase(t, 0.0, GATHER), 0.5)
	for i in range(GRAINS):
		var offset := (
			Vector2(SignaturePaint.jitter(i, 41) - 0.5, SignaturePaint.jitter(i, 42) - 0.5) * 2.0
		)
		var at := hub + offset * SCATTER * (1.0 - gather) + offset * GRAIN
		if t >= GATHER:
			var late := SignaturePaint.jitter(i, 43) * STAGGER
			var q := clampf((phase(t, GATHER, THROW) - late) / (1.0 - STAGGER), 0.0, 1.0)
			if q >= 1.0:
				continue
			at = _arc_point(hub, target, q) + offset * SPREAD * q
		ShapePaint.circle(ci, at, GRAIN, Color(SignaturePaint.SAND_DARK, alpha))
		ShapePaint.circle(ci, at, GRAIN * 0.6, Color(SignaturePaint.SAND, alpha))
	SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)


## 出どころから対象へ、上へ膨らむ弧の上の1点。
func _arc_point(start: Vector2, end: Vector2, progress: float) -> Vector2:
	var lift := start.distance_to(end) * ARC * 4.0 * progress * (1.0 - progress)
	return start.lerp(end, progress) - Vector2(0.0, lift)


func _draw_hop(item: CanvasItem, t: float) -> void:
	var q := phase(t, 0.0, DRAW_TIME + FADE)
	var toward := 1.0 if from.y > CardMatchLayout.current().table_rect.get_center().y else -1.0
	var rise := -DRAW_HOP * sin(minf(q * 2.0, 1.0) * PI * 0.5)
	var fall := toward * DRAW_FALL * maxf(q * 2.0 - 1.0, 0.0) ** 2
	var at := from + Vector2(0.0, rise + fall)
	ShapePaint.circle(
		item.get_canvas_item(), at, GRAIN, Color(SignaturePaint.SAND, fade_alpha(t) * (1.0 - q))
	)


func _drawing() -> bool:
	return style == CardEnums.EffectVisualStyle.PULSE
