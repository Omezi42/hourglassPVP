extends SignatureMove
## バスティオンの登場(GameDesign.md 9章):通常より高くから重く落ちて卓が揺れ、駒の左右に黒い石の
## 控え壁が斜めにせり上がって支え、壁のひびに赤い燠の光が走ったところへ鉄のかすがいが打ち込まれて光る
## (崩れかけてから築かれる最後の城壁)。

const RAISE := 0.24
const CRACK := 0.14
const CRAMP := 0.14
## 控え壁の位置(台座の上面の中心から左右へ)、裾と頂の半幅、高さ。
const OFFSET := 50.0
const FOOT := 16.0
const HEAD := 8.0
const HEIGHT := 78.0
## ひびの折れ数と振れ幅、かすがいの大きさと打ち込む前の拡大。
const ZIGS := 5
const ZIG := 4.0
const CRAMP_SIZE := Vector2(16.0, 7.0)
const CRAMP_DROP := 1.8


func impact_at() -> float:
	return CardUnitFx.HEAVY_LAND_DURATION


func duration() -> float:
	return impact_at() + RAISE + CRACK + CRAMP + FADE


func heavy_land() -> bool:
	return true


func sound() -> int:
	return SoundBank.Sfx.SIG_BASTION


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var raise := back_out(phase(t, impact_at(), RAISE))
	var crack := phase(t, impact_at() + RAISE, CRACK)
	var cramp := phase(t, impact_at() + RAISE + CRACK, CRAMP)
	for side: float in [-1.0, 1.0]:
		var foot := from + Vector2(side * OFFSET, 0.0)
		var top := foot + Vector2(-side * (FOOT - HEAD), -HEIGHT * raise)
		var shape := PackedVector2Array(
			[
				foot + Vector2(-FOOT, 0.0),
				foot + Vector2(FOOT, 0.0),
				top + Vector2(HEAD, 0.0),
				top + Vector2(-HEAD, 0.0),
			]
		)
		var closed := shape.duplicate()
		closed.append(shape[0])
		var wall_alpha := alpha * minf(raise * 3.0, 1.0)
		(
			ShapePaint
			. polygon(
				ci,
				shape,
				PackedColorArray(
					[
						Color(UiPalette.BASALT.darkened(0.3), wall_alpha),
						Color(UiPalette.BASALT.darkened(0.3), wall_alpha),
						Color(UiPalette.BASALT.lightened(0.2), wall_alpha),
						Color(UiPalette.BASALT.lightened(0.2), wall_alpha),
					]
				)
			)
		)
		ShapePaint.polyline(ci, closed, Color(UiPalette.INK_950, wall_alpha * 0.9), 2.4, true)
		for k in range(1, 3):
			var y := float(k) / 3.0
			item.draw_line(
				foot.lerp(top, y) + Vector2(-FOOT * 0.8, 0.0),
				foot.lerp(top, y) + Vector2(FOOT * 0.8, 0.0),
				Color(UiPalette.INK_950, wall_alpha * 0.5),
				1.4,
				true
			)
		if crack > 0.0:
			var points := PackedVector2Array()
			var mid := foot.lerp(top, 0.5)
			var reach := ease(crack, 0.6)
			for i in range(ZIGS + 1):
				var s := float(i) / float(ZIGS) * reach
				points.append(
					foot.lerp(top, 0.15 + 0.7 * s) + Vector2(ZIG if i % 2 == 0 else -ZIG, 0.0)
				)
			ShapePaint.polyline(ci, points, Color(UiPalette.EMBER, wall_alpha * 0.4), 5.0, true)
			ShapePaint.polyline(ci, points, Color(SignaturePaint.SPARK_HOT, wall_alpha), 1.8, true)
			if cramp > 0.0:
				var grow := lerpf(CRAMP_DROP, 1.0, ease(cramp, 2.0))
				_cramp(item, mid, CRAMP_SIZE * grow, wall_alpha * minf(cramp * 3.0, 1.0), cramp)


## 鉄のかすがい(コの字の留め金)。打ち込んだ瞬間に白く光る。
func _cramp(item: CanvasItem, at: Vector2, size: Vector2, alpha: float, landed: float) -> void:
	var a := at + Vector2(-size.x, size.y)
	var b := at + Vector2(-size.x, 0.0)
	var c := at + Vector2(size.x, 0.0)
	var d := at + Vector2(size.x, size.y)
	var staple := PackedVector2Array([a, b, c, d])
	ShapePaint.polyline(item.get_canvas_item(), staple, Color(UiPalette.INK_950, alpha), 5.0, true)
	var shine := UiPalette.STEEL.lerp(Color.WHITE, 1.0 - landed)
	ShapePaint.polyline(item.get_canvas_item(), staple, Color(shine, alpha), 2.8, true)
