class_name ResultSandFall
extends Control
## 結果パネルの背後で舞い落ちる粒。勝ち(bright)は琥珀の砂、負けはくすんだ灰。
## GameDesign.md 9章の「消える砂と落ちる砂を演出で分ける」思想を結果パネルへも及ぼし、
## 砂時計モチーフの延長として見せる。対局・リーサルパズル・ソロモードで共有する。

const PARTICLE_COUNT := 40
const SPEED_RANGE := Vector2(40.0, 110.0)
## 負けの灰は砂よりゆっくり落とす。
const ASH_SPEED_SCALE := 0.6
const DRIFT := 12.0
const SIZE_RANGE := Vector2(1.2, 2.6)
const SAND_ALPHA := 0.55
const ASH_COLOR := Color(0.55, 0.53, 0.5, 0.35)

var _bright := false
## 各粒 {"pos":Vector2, "speed":float, "drift":float, "phase":float, "size":float}
var _particles: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func start(bright: bool) -> void:
	_bright = bright
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in PARTICLE_COUNT:
		(
			_particles
			. append(
				{
					"pos": Vector2(rng.randf() * size.x, rng.randf() * size.y - size.y),
					"speed":
					(
						rng.randf_range(SPEED_RANGE.x, SPEED_RANGE.y)
						* (1.0 if bright else ASH_SPEED_SCALE)
					),
					"drift": rng.randf_range(-DRIFT, DRIFT),
					"phase": rng.randf() * TAU,
					"size": rng.randf_range(SIZE_RANGE.x, SIZE_RANGE.y),
				}
			)
		)
	set_process(true)


func stop() -> void:
	set_process(false)


func _process(delta: float) -> void:
	# パネルを閉じたら止める(次の `start()` で再開する)。
	if not is_visible_in_tree():
		set_process(false)
		return
	for p in _particles:
		p["pos"].y += p["speed"] * delta
		p["phase"] += delta * 1.4
		p["pos"].x += sin(p["phase"]) * p["drift"] * delta
		if p["pos"].y > size.y + 12.0:
			p["pos"].y = -randf() * 60.0
			p["pos"].x = randf() * size.x
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var color := Color(UiPalette.GLOW_AMBER, SAND_ALPHA) if _bright else ASH_COLOR
	for p in _particles:
		UiPaint.fill_circle(ci, p["pos"], p["size"], color, 8)
