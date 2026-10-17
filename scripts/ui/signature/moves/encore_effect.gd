extends SignatureMove
## アンコールの設置(GameDesign.md 9章):駒の周りで手拍子の光が3回弾み、最後の1拍で金の音符が
## 自分のHPの器へ跳ねて光の輪になる(反転権を1回得る)。

const CLAPS := 3
## 手拍子の光が弾む向き(左上・右上・真上の順)。
const CLAP_ANGLES := [-PI * 0.5 - 0.9, -PI * 0.5 + 0.9, -PI * 0.5]
const BEAT := 0.14
const FLIGHT := 0.34
const RING := 0.3
## 手拍子の光が弾む位置(駒の中心から)と大きさ。
const CLAP_RADIUS := 40.0
const CLAP_REACH := 18.0
const NOTE_SIZE := 6.0
const ARC := 70.0
## 静止の型(`EmblemStrikeFx` の PULSE)と同じ金色。
const PULSE := Color(1.0, 0.86, 0.42, 1.0)


func impact_at() -> float:
	return BEAT * CLAPS + FLIGHT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	for i in range(CLAPS):
		var clap := phase(t, BEAT * i, BEAT * 1.6)
		if clap <= 0.0 or clap >= 1.0:
			continue
		var angle: float = CLAP_ANGLES[i]
		_clap(item, from + Vector2.from_angle(angle) * CLAP_RADIUS, clap, alpha)
	var flight := phase(t, BEAT * CLAPS, FLIGHT)
	if flight > 0.0 and flight < 1.0:
		var start := from - Vector2(0.0, CLAP_RADIUS)
		var at := start.lerp(targets[0], ease(flight, 0.7)) - Vector2(0.0, ARC * sin(flight * PI))
		SignaturePaint.note(item, at, NOTE_SIZE, PULSE, alpha)
	var ring := phase(t, impact_at(), RING)
	if ring > 0.0 and ring < 1.0:
		var color := Color(PULSE, alpha * 0.7 * (1.0 - ring))
		ShapePaint.arc(
			item.get_canvas_item(),
			targets[0],
			46.0 * ease(ring, 0.4),
			0.0,
			TAU,
			40,
			color,
			2.4,
			true
		)


## 手を打った瞬間の光。短い光条が放射状に伸びて消える。
func _clap(item: CanvasItem, at: Vector2, k: float, alpha: float) -> void:
	const RAYS := 6
	var color := Color(PULSE, alpha * (1.0 - k))
	for i in range(RAYS):
		var dir := Vector2.from_angle(TAU * float(i) / float(RAYS))
		item.draw_line(at + dir * CLAP_REACH * k * 0.4, at + dir * CLAP_REACH * k, color, 2.0, true)
