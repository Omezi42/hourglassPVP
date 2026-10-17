class_name BoardDust
extends Control
## 卓の上に漂う砂埃(GameDesign.md 9章「空気感」)。`BoardTable`の手前(前面)へ重ね、
## 静止画では伝わらない「時が流れている」空気を添える。
##
## 駒や数値の読みやすさを損なわないことを最優先し(9章「盤面の読みやすさを損なわない
## 範囲でしか作らない」と同じ考え方)、粒はごく小さく・薄く・ゆっくりにする。
## クリックは奪わない(`MOUSE_FILTER_IGNORE`)。粒の形は `PaintedShape` に1度だけ描き、
## 漂いと明滅は位置と不透明度だけで動かす(Architecture.md 10.10.3節)。

const MOTE_COUNT := 10
const RADIUS_RANGE := Vector2(1.2, 2.6)
## 見た目の「呼吸」の速さと、横に流れる速さ。どちらも遅いほど埃らしい。
const DRIFT_SPEED := Vector2(6.0, 3.0)
const FLICKER_SPEED := 0.5
const PEAK_ALPHA := 0.16

var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 42
	for i in MOTE_COUNT:
		var radius := _rng.randf_range(RADIUS_RANGE.x, RADIUS_RANGE.y)
		var shape := PaintedShape.new(_paint_mote.bind(radius))
		add_child(shape)
		(
			_motes
			. append(
				{
					"pos": Vector2(_rng.randf_range(0.0, 1.0), _rng.randf_range(0.0, 1.0)),
					"drift": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3)),
					"phase": _rng.randf_range(0.0, TAU),
					"shape": shape,
				}
			)
		)


func _process(delta: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for mote in _motes:
		var pos: Vector2 = mote["pos"]
		var drift: Vector2 = mote["drift"]
		pos += drift * DRIFT_SPEED * delta / Vector2(size.x, size.y)
		# 端まで流れたら反対側へ回す(埃は同じ器の中を漂い続ける)。
		pos.x = fposmod(pos.x, 1.0)
		pos.y = fposmod(pos.y, 1.0)
		mote["pos"] = pos
		mote["phase"] += delta * FLICKER_SPEED
		var flicker := (sin(float(mote["phase"])) + 1.0) * 0.5
		var shape: PaintedShape = mote["shape"]
		shape.position = pos * size
		shape.modulate.a = PEAK_ALPHA * (0.35 + flicker * 0.65)


func _paint_mote(shape: PaintedShape, radius: float) -> void:
	var glow := UiPalette.GLOW_AMBER
	UiPaint.fill_gradient_polygon(
		shape.get_canvas_item(),
		UiPaint.circle_points(Vector2.ZERO, radius, 8),
		Rect2(-Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		[[0.0, Color(glow.r, glow.g, glow.b, 1.0)], [1.0, Color(glow.r, glow.g, glow.b, 0.0)]]
	)
