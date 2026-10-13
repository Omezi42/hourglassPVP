extends SignatureMove
## クロノスの登場(GameDesign.md 9章):高くから重く落ち、台座の周りを歯車の輪が一回転して
## 噛み合い止まる(反転できない印)。卓の揺れは進行役が着弾で出す。

const GROW := 0.1
const SPIN := 0.5
const TURN := TAU / float(SignaturePaint.GEAR_TEETH) * 6.0
const RING_SCALE := 1.3


func impact_at() -> float:
	return CardUnitFx.HEAVY_LAND_DURATION


func duration() -> float:
	return impact_at() + GROW + SPIN + FADE


func heavy_land() -> bool:
	return true


func sound() -> int:
	return SoundBank.Sfx.SIG_CHRONOS


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var grow := ease(phase(t, impact_at(), GROW), 0.5)
	var turn := TURN * back_out(phase(t, impact_at() + GROW, SPIN))
	var radius := CardView.PEDESTAL_RADIUS * RING_SCALE * grow
	if radius.x > 0.0:
		SignaturePaint.gear_ring(item, from, radius, turn, fade_alpha(t))
