class_name NotchSparkFx
extends Control
## 刻み目の光が粒になり、反転権の粒へ飛ぶ(GameDesign.md 9章、Architecture.md 10.10.3節)。
## 画面へ全面で重ねる(`FlipRightGauge` と情報帯は別の場所にあるため、どちらの `_draw()` にも描けない)。

## 1回の飛行の尺と、弧の持ち上げ・粒の数と広がり・尾の長さ。
const FLIGHT_SECONDS := 0.6
const ARC_LIFT := 38.0
const GRAINS := 3
const GRAIN_SPREAD := 22.0
const TRAIL_STEPS := 5
const TRAIL_GAP := 0.045
const GRAIN_RADIUS := 3.6
const GLOW_RADIUS := 11.0
const GRAIN_COLOR := UiPalette.GOLD_HI
const GLOW_COLOR := Color(0.96, 0.68, 0.24, 0.55)

## 飛んでいる粒の群れ。{from, to, progress}。
var _flights: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


## `from_global` から `to_global` へ光の粒を飛ばす。着いたら `on_land` を1度だけ呼ぶ。
func launch(from_global: Vector2, to_global: Vector2, delay: float, on_land: Callable) -> void:
	var inverse := get_global_transform().affine_inverse()
	var flight := {"from": inverse * from_global, "to": inverse * to_global, "progress": -1.0}
	_flights.append(flight)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_method(_set_progress.bind(flight), 0.0, 1.0, FLIGHT_SECONDS)
	tween.tween_callback(_land.bind(flight, on_land))


func _set_progress(value: float, flight: Dictionary) -> void:
	flight["progress"] = value
	queue_redraw()


func _land(flight: Dictionary, on_land: Callable) -> void:
	_flights.erase(flight)
	queue_redraw()
	on_land.call()


func _draw() -> void:
	for flight in _flights:
		if float(flight["progress"]) < 0.0:
			continue
		for grain in GRAINS:
			_draw_grain(flight, grain)


## 弧を描いて飛ぶ1粒と尾。粒ごとに弧の高さと横ずれを変えて、1つの光が散って集まるように見せる。
func _draw_grain(flight: Dictionary, grain: int) -> void:
	var ci := get_canvas_item()
	var from: Vector2 = flight["from"]
	var to: Vector2 = flight["to"]
	var spread := (float(grain) - float(GRAINS - 1) * 0.5) / float(GRAINS - 1) * 2.0
	var control := from.lerp(to, 0.5) + Vector2(spread * GRAIN_SPREAD, -ARC_LIFT)
	var head: float = flight["progress"]
	for step in TRAIL_STEPS:
		var t := clampf(head - float(step) * TRAIL_GAP, 0.0, 1.0)
		var at := _bezier(from, control, to, t)
		var fade := 1.0 - float(step) / float(TRAIL_STEPS)
		if step == 0:
			ShapePaint.radial_glow(ci, at, Vector2(GLOW_RADIUS, GLOW_RADIUS), GLOW_COLOR)
		ShapePaint.circle(ci, at, GRAIN_RADIUS * fade, Color(GRAIN_COLOR, fade))


static func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)
