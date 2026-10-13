extends SignatureMove
## クロックタワーの落砂(GameDesign.md 9章):駒の上に鐘が現れて揺れ、音の波紋が相手の列を
## 横切る。波紋が触れた駒から順に砂が散る。

const BELL := 0.32
const RIPPLE := 0.45
const SWING := 0.32
const LIFT := 64.0
## 波紋が最後の対象を越えてから消えるまでの余り。
const MARGIN := 24.0


func impact_at() -> float:
	return BELL + RIPPLE


func sound() -> int:
	return SoundBank.Sfx.SIG_CLOCKTOWER


func reaches(index: int, t: float) -> bool:
	return _radius(t) >= _pivot().distance_to(targets[index])


func draw(item: CanvasItem, t: float) -> void:
	var intro := phase(t, 0.0, BELL)
	var main := phase(t, BELL, RIPPLE)
	var alpha := fade_alpha(t)
	# 鐘は現れながら大きく1度振れ、波紋の間は余韻で小さく揺れ続ける。
	var swing := sin(intro * PI * 1.5) * SWING * (1.0 - 0.6 * main)
	SignaturePaint.bell(item, _pivot(), swing, minf(intro * 3.0, 1.0) * alpha)
	if intro >= 1.0:
		var mouth := _pivot() + Vector2(0.0, SignaturePaint.BELL_HEIGHT)
		SignaturePaint.ripple(item, mouth, _radius(t), alpha)


func _pivot() -> Vector2:
	return from - Vector2(0.0, LIFT)


func _radius(t: float) -> float:
	var reach := 0.0
	for target in targets:
		reach = maxf(reach, _pivot().distance_to(target))
	return (reach + MARGIN) * phase(t, BELL, RIPPLE)
