extends SignatureMove
## カウントダウンの余砂(GameDesign.md 9章):砕けた台座に黒い丸爆弾が据わり、胴の三つの灯が一つずつ消えて秒を読み、
## 短い導火線が燃え尽きた瞬間に大きく爆ぜて、煤の輪が卓じゅうへ広がり、場の駒それぞれが爆ぜて火花が散る(打撃。盤面を揺らす)。

const COUNT := 0.42
const BOOM := 0.12
const SPREAD := 0.18
## 爆弾の高さ(台座から上へ)と半径、灯の間隔・半径、導火線の長さ、爆ぜと煤の輪の大きさ、届いた所の爆ぜの大きさ。
const LIFT := 24.0
const BOMB := 17.0
const LAMP_GAP := 8.0
const LAMP := 3.0
const FUSE := 16.0
const BIG_BURST := 90.0
const SHOCK := 260.0
const BURST := 30.0


func impact_at() -> float:
	return COUNT + BOOM + SPREAD


func top_extent() -> float:
	return (LIFT + BOMB + FUSE + 10.0) * zoom


func reaches(index: int, t: float) -> bool:
	return t >= _arrive(index)


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from - Vector2(0.0, LIFT * zoom)
	var count := phase(t, 0.0, COUNT)
	if t < COUNT + BOOM * 0.3:
		_bomb(item, center, count, alpha * minf(count * 6.0, 1.0))
	var boom := phase(t, COUNT, BOOM + SPREAD + FADE)
	SignaturePaint.powder_burst(item, center, boom, BIG_BURST * zoom, alpha)
	var shock := phase(t, COUNT, BOOM + SPREAD)
	if shock > 0.0 and shock < 1.0:
		ShapePaint.arc(
			ci,
			center,
			SHOCK * ease(shock, 0.6),
			0.0,
			TAU,
			64,
			Color(UiPalette.POWDER_SOOT, alpha * 0.6 * (1.0 - shock)),
			10.0 * (1.0 - shock) + 2.0,
			true
		)
	for i in range(targets.size()):
		var land := phase(t, _arrive(i), FADE)
		SignaturePaint.powder_burst(item, targets[i], land, BURST, alpha)
		SignaturePaint.sparks(item, targets[i], land, alpha)


## 黒い丸爆弾。`count` は秒読みの進み(0→1)で、灯が右から一つずつ消え、導火線が口金まで燃え進む。
func _bomb(item: CanvasItem, center: Vector2, count: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var r := BOMB * zoom
	var neck := center + Vector2(0.45, -0.9).normalized() * r
	var tip := neck + Vector2(0.4, -1.0).normalized() * FUSE * zoom
	SignaturePaint.fuse_cord(item, tip, neck, 1.0, ease(count, 1.4), alpha, 3.0)
	ShapePaint.circle(ci, center, r + 2.0, Color(UiPalette.INK_950, alpha))
	ShapePaint.circle(ci, center, r, Color(UiPalette.POWDER_SOOT, alpha))
	ShapePaint.circle(
		ci, center + Vector2(-0.35, -0.4) * r, r * 0.28, Color(UiPalette.FLINT, alpha * 0.6)
	)
	ShapePaint.circle(ci, neck, r * 0.26, Color(UiPalette.TOLL_BRASS, alpha))
	for i in range(3):
		var on := count < float(3 - i) / 3.0
		var at := center + Vector2(LAMP_GAP * float(i - 1), r * 0.2 / zoom) * zoom
		if on:
			ShapePaint.circle(ci, at, LAMP * 2.2 * zoom, Color(UiPalette.DYNAMITE, alpha * 0.35))
		ShapePaint.circle(
			ci, at, LAMP * zoom, Color(UiPalette.DYNAMITE if on else UiPalette.INK_950, alpha)
		)


## 煤の輪が対象 `index` へ届く時刻。爆心から遠い駒ほど遅れて爆ぜる。
func _arrive(index: int) -> float:
	var reach := clampf(from.distance_to(targets[index]) / SHOCK, 0.0, 1.0)
	return COUNT + BOOM * 0.5 + (BOOM * 0.5 + SPREAD) * reach
