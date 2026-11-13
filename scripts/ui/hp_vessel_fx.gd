class_name HpVesselFx
extends Control
## HPの器に重ねる演出(GameDesign.md 9章「演出」、Architecture.md 10.10.3節)。
## HPが少なくなると縁にひびが入り、現在値の丸が鼓動のように脈打つ。決着でHPが0になった側は
## ひびが走って器が砕け、中の赤い砂がこぼれ落ちる。
##
## `PlayerInfoBar` の子として同じ矩形に重ねる(`Control._draw()` は子より背面に描かれるため、
## 器の上へ出すものは子に持たせる)。ひびの本数はHPから毎回決め、状態として持たない。

## ひびが1本入るHPと、2本に増えるHP(初期値24の1/4と1/8)。
const CRACK_ONE_AT := 6
const CRACK_TWO_AT := 3
## 砕ける演出の尺。前半でひびが走り、`BURST_AT` で割れて破片と砂が散る。
const SHATTER_DURATION := 0.8
const BURST_AT := 0.4
## 鼓動の周期(秒)。HPが少ないほど速くする。
const BEAT_PERIOD := 1.0
const BEAT_PERIOD_CRITICAL := 0.72
## 1拍の中の2つ目の打ち(どっ・くん)の位置と、打ちの鋭さ。
const BEAT_SECOND_AT := 0.2
const BEAT_SHARPNESS := 90.0
const HALO_REACH := 7.0
const SHARDS := 12
## 破片(三角形の一辺・飛距離・回転量・消え始める進み)。
const SHARD_SIDE_MIN := 6.0
const SHARD_SIDE_MAX := 11.0
const SHARD_REACH_MIN := 34.0
const SHARD_REACH_MAX := 64.0
const SHARD_SPIN := 1.2
const SHARD_FADE_AT := 0.6
const SHARD_COLOR := Color(0.86, 0.92, 1.0)
const SAND_GRAINS := 22
## こぼれる赤い砂(粒の半径・落下・横の流れ・消え始める進み)。
const SAND_RADIUS_MIN := 2.0
const SAND_RADIUS_MAX := 3.5
const SAND_FALL_MIN := 70.0
const SAND_FALL_MAX := 130.0
const SAND_DRIFT := 18.0
const SAND_FADE_AT := 0.75
const SAND_BRIGHT_EVERY := 3
const SPILL_RED := Color(0.95, 0.24, 0.18)
const SAND_BRIGHT := Color(1.0, 0.56, 0.42)
## 破裂の瞬間に器へ重ねる白い面。
const BURST_FLASH_ALPHA := 0.5
const BURST_FLASH_SECONDS := 0.12
const CRACK_DARK := Color(0.06, 0.03, 0.03, 0.9)
const CRACK_LIGHT := Color(1.0, 0.95, 0.9, 0.45)
const SAND_RED := Color(0.86, 0.24, 0.19, 1.0)
const GLASS := Color(0.95, 0.9, 0.86, 1.0)
## ひびの道筋(器の矩形に対する0〜1の座標)。先の2本がHPの少なさで順に入り、残りは砕けるときだけ走る。
const CRACK_PATHS := [
	[Vector2(0.64, 0.0), Vector2(0.6, 0.35), Vector2(0.67, 0.6), Vector2(0.62, 1.0)],
	[Vector2(0.28, 1.0), Vector2(0.33, 0.62), Vector2(0.27, 0.34), Vector2(0.34, 0.0)],
	[Vector2(0.6, 0.35), Vector2(0.48, 0.45), Vector2(0.4, 0.3)],
	[Vector2(0.67, 0.6), Vector2(0.8, 0.52), Vector2(0.9, 0.7)],
	[Vector2(0.12, 0.0), Vector2(0.16, 0.5), Vector2(0.1, 1.0)],
	[Vector2(0.33, 0.62), Vector2(0.46, 0.8), Vector2(0.52, 1.0)],
]

## 器の矩形・現在値の丸。親(`PlayerInfoBar`)の座標系で受け取る。
var vessel_rect := Rect2()
var badge_center := Vector2.ZERO
var badge_radius := 0.0
var hp := MatchState.INITIAL_HP:
	set(value):
		hp = value
		set_process(_beating())
		queue_redraw()

var _time := 0.0
## 砕けの進捗。負なら砕けていない。1で砕けきった状態のまま残る。
var _shatter := -1.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func play_shatter() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_shatter, 0.0, 1.0, SHATTER_DURATION)


func reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_shatter = -1.0
	hp = MatchState.INITIAL_HP


func _set_shatter(value: float) -> void:
	_shatter = value
	queue_redraw()


func _beating() -> bool:
	return hp > 0 and hp <= CRACK_ONE_AT


func _draw() -> void:
	if _beating() and _shatter < 0.0:
		_draw_heartbeat()
	if _shatter < 0.0:
		for i in _crack_count():
			_draw_crack(CRACK_PATHS[i], 1.0)
		return
	var grow: float = clampf(_shatter / BURST_AT, 0.0, 1.0)
	for i in CRACK_PATHS.size():
		# 入っていたひびは最初から全長で、新しいひびは前半で伸びきる。
		_draw_crack(CRACK_PATHS[i], 1.0 if i < _crack_count() else grow)
	if _shatter < BURST_AT:
		# 割れる直前、ひびの走る器が白く張り詰める。
		var tension := Color(GLASS, 0.25 * grow)
		UiPaint.fill_ellipse(
			get_canvas_item(), vessel_rect.get_center(), vessel_rect.size * 0.5, tension, 24
		)
		return
	var burst := (_shatter - BURST_AT) / (1.0 - BURST_AT)
	_draw_burst_flash(burst)
	_draw_shards(burst)
	_draw_spill(burst)


func _crack_count() -> int:
	if hp > CRACK_ONE_AT:
		return 0
	return 1 if hp > CRACK_TWO_AT else 2


## ひび。暗い筋の脇へ明るい筋を1px ずらして重ね、硝子の割れ目に見せる。
## `length` は道筋の何割まで描くか(0〜1)。
func _draw_crack(path: Array, length: float) -> void:
	if length <= 0.0:
		return
	var points := PackedVector2Array()
	for p in path:
		points.append(vessel_rect.position + vessel_rect.size * (p as Vector2))
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	var left := total * length
	var drawn := PackedVector2Array([points[0]])
	for i in range(1, points.size()):
		var step := points[i].distance_to(points[i - 1])
		if step >= left:
			drawn.append(points[i - 1].lerp(points[i], left / step))
			break
		drawn.append(points[i])
		left -= step
	if drawn.size() < 2:
		return
	ShapePaint.polyline(get_canvas_item(), drawn, CRACK_DARK, 1.6, true)
	var lit := PackedVector2Array()
	for p in drawn:
		lit.append(p + Vector2(1.0, 0.0))
	ShapePaint.polyline(get_canvas_item(), lit, CRACK_LIGHT, 0.8, true)


## 現在値の丸の外へ、どっ・くんと2回ずつ広がる赤い輪。
func _draw_heartbeat() -> void:
	var period := BEAT_PERIOD_CRITICAL if hp <= CRACK_TWO_AT else BEAT_PERIOD
	var phase := fmod(_time, period) / period
	var beat := maxf(
		exp(-BEAT_SHARPNESS * phase * phase),
		0.7 * exp(-BEAT_SHARPNESS * pow(phase - BEAT_SECOND_AT, 2.0))
	)
	if beat < 0.02:
		return
	var ci := get_canvas_item()
	UiPaint.draw_ring(
		ci,
		badge_center,
		badge_radius + 3.0 + HALO_REACH * beat,
		Color(SAND_RED, 0.7 * beat),
		2.0,
		32
	)
	UiPaint.fill_circle(ci, badge_center, badge_radius, Color(SAND_RED, 0.28 * beat), 32)


## 割れた器の破片。器の中心から外へ飛びながら回り、終わりへ向けて消える(駒の破壊と同じ語彙)。
func _draw_shards(t: float) -> void:
	var alpha := 1.0 - smoothstep(SHARD_FADE_AT, 1.0, t)
	var travel := 1.0 - (1.0 - t) * (1.0 - t)
	var center := vessel_rect.get_center()
	for i in SHARDS:
		var seed_size := fmod(float(i) * 0.618, 1.0)
		var seed_reach := fmod(float(i) * 0.377 + 0.2, 1.0)
		var seed_spin := fmod(float(i) * 0.731 + 0.1, 1.0)
		var angle := TAU * (float(i) + 0.5) / float(SHARDS)
		var at := (
			center
			+ (
				Vector2.from_angle(angle)
				* lerpf(SHARD_REACH_MIN, SHARD_REACH_MAX, seed_reach)
				* travel
			)
		)
		var turn := angle + lerpf(-SHARD_SPIN, SHARD_SPIN, seed_spin) * t
		var radius := lerpf(SHARD_SIDE_MIN, SHARD_SIDE_MAX, seed_size) / sqrt(3.0)
		var points := PackedVector2Array()
		for corner in 3:
			points.append(at + Vector2.from_angle(turn + TAU * float(corner) / 3.0) * radius)
		ShapePaint.colored_polygon(get_canvas_item(), points, Color(SHARD_COLOR, alpha))


## 破裂の瞬間、器が白く光って引く。
func _draw_burst_flash(t: float) -> void:
	var seconds := t * SHATTER_DURATION * (1.0 - BURST_AT)
	var alpha := BURST_FLASH_ALPHA * (1.0 - clampf(seconds / BURST_FLASH_SECONDS, 0.0, 1.0))
	if alpha <= 0.0:
		return
	var radius := vessel_rect.size.y * 0.5
	UiKit.fill(get_canvas_item(), UiKit.rr(vessel_rect, radius), Color(1.0, 1.0, 1.0, alpha))


## こぼれ落ちる赤い砂。器の底から粒をずらしながら落とし、下で消える。
func _draw_spill(t: float) -> void:
	for i in SAND_GRAINS:
		var delay := float(i % 7) / 7.0 * 0.4
		var local := clampf((t - delay) / (1.0 - delay), 0.0, 1.0)
		if local <= 0.0:
			continue
		var seed_fall := fmod(float(i) * 0.618, 1.0)
		var seed_drift := fmod(float(i) * 0.377 + 0.2, 1.0)
		var seed_size := fmod(float(i) * 0.731 + 0.1, 1.0)
		var x := vessel_rect.position.x + vessel_rect.size.x * (float(i) + 0.5) / float(SAND_GRAINS)
		var fall := lerpf(SAND_FALL_MIN, SAND_FALL_MAX, seed_fall) * local * local
		var drift := lerpf(-SAND_DRIFT, SAND_DRIFT, seed_drift) * local
		var alpha := 1.0 - smoothstep(SAND_FADE_AT, 1.0, local)
		var color := SAND_BRIGHT if i % SAND_BRIGHT_EVERY == 0 else SPILL_RED
		ShapePaint.circle(
			get_canvas_item(),
			Vector2(x + drift, vessel_rect.end.y - 2.0 + fall),
			lerpf(SAND_RADIUS_MIN, SAND_RADIUS_MAX, seed_size),
			Color(color, alpha)
		)
