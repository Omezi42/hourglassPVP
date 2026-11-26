extends SignatureMove
## ミーティアの登場(GameDesign.md 9章):右上の空から燃える岩が火の尾を引いて斜めに落ちてきて台座へ突き刺さり、
## 通常より重く着地して卓が揺れ、足元で黒色火薬のように爆ぜて煤の輪と火の粉が広がる(空から落ちてくる砂は止まらない)。

const FALL := 0.3
const SETTLE := 0.42
## 落ち始める位置(台座の上面から)、岩の半径、尾の長さと太さ、足元の爆ぜの大きさ、火の粉の広がり。
const SKY := Vector2(150.0, -170.0)
const ROCK := 15.0
const TAIL := 84.0
const TAIL_WIDTH := 26.0
const BURST := 62.0
const MOTES := 70.0


func impact_at() -> float:
	return CardUnitFx.HEAVY_LAND_DURATION


func duration() -> float:
	return impact_at() + SETTLE + FADE


func heavy_land() -> bool:
	return true


func sound() -> int:
	return SoundBank.Sfx.SIG_METEOR


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var fall := phase(t, impact_at() - FALL, FALL)
	if fall > 0.0 and fall < 1.0:
		var dir := (-SKY).normalized()
		var head := from + SKY * (1.0 - fall * fall)
		SignaturePaint.blaze_comet(item, head, dir, TAIL, TAIL_WIDTH, alpha)
		ShapePaint.circle(ci, head, ROCK + 1.8, Color(UiPalette.INK_950, alpha * 0.85))
		ShapePaint.circle(ci, head, ROCK, Color(UiPalette.METEOR_ROCK, alpha))
		ShapePaint.circle(
			ci, head + dir * ROCK * 0.35, ROCK * 0.6, Color(UiPalette.FLAME, alpha * 0.9)
		)
		ShapePaint.circle(
			ci,
			head - dir * ROCK * 0.3 + dir.orthogonal() * 3.0,
			ROCK * 0.28,
			Color(UiPalette.INK_950, alpha * 0.4)
		)
	var land := phase(t, impact_at(), SETTLE)
	SignaturePaint.powder_burst(item, from, land, BURST, alpha)
	SignaturePaint.sparks(item, from, land, alpha)
	SignaturePaint.ember_motes(item, from, land, alpha, MOTES, MOTES)
