class_name CardPlaceFx
extends Control
## 場に出すとき、札がほどけて器になる演出(GameDesign.md 9章「場に出すときは、札がほどけて器になる」)。
## 札の面が台座の上へ移り、そのカードの砂の色の粒にほどけてガラスへ流れ込み、粒の中から駒が現れて着地する。
## 相手が出した札は、先に卓の中央で開いて読ませてから台座へ向かう。
##
## 出した順に1枚ずつ見せる(`_jobs`)。見せている間は `busy()` が真になり、その駒の設置効果の紋章は
## `CardMatchEffectStrike` が持ち越して、`finished` で放つ(着地より先に効果が飛ばないため)。
## 駒の着地そのもの(固有の登場・重さ)は呼び出し側の `land` が持つ。

signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 相手の札を見せる
const REVEAL_FROM_SCALE := 0.5
const REVEAL_SCALE := 1.6
const REVEAL_POP := 0.18
const REVEAL_HOLD := 0.5
const REVEAL_TO_SLOT := 0.2
## 台座の上へ移る札の大きさ(駒の縮尺に対する割合)と、台座の上で止める高さ。
const SLOT_FACE_SCALE := 0.8
const SLOT_FACE_LIFT := 18.0
const TO_SLOT := 0.16
## ほどける
const UNRAVEL := 0.28
## 札が薄れきる割合・駒が現れ始める割合(ほどける尺に対して)。
const FACE_FADE_PART := 0.55
const UNIT_APPEAR_AT := 0.45
const UNIT_APPEAR_PART := 0.4
const FACE_SHRINK := 0.6
const GRAINS := 44
const GRAIN_RADIUS := 2.4
## 粒の出だしをずらす幅・ガラスの中で散る幅(x, y)・渦の膨らみ。
const GRAIN_DELAY := 0.35
const GRAIN_SPREAD := Vector2(18.0, 40.0)
const GRAIN_SWIRL := 14.0
const GRAIN_WHITEN_FROM := 0.15
const GRAIN_WHITEN_BY := 0.35
const GRAIN_FADE_FROM := 0.75
## 札の縁が粒へほどけていく線。ほどける前半だけ縮みながら消える。
const EDGE_PART := 0.5
const EDGE_SHRINK := 0.18
const EDGE_WIDTH := 2.0
const EDGE_LIGHTEN := 0.35
const EDGE_ALPHA := 0.9

## {view, card, from, reveal, face_scale, center, land}
var _jobs: Array[Dictionary] = []
var _playing := false
var _face: CardView
var _t := -1.0
var _face_rect := Rect2()
var _to := Vector2.ZERO
var _sand := Color.WHITE
var _zoom := 1.0
## `stop()` のたびに進める。待っている間に止められた進行を、再開させずに捨てるため。
var _gen := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	z_index = 24


func busy() -> bool:
	return _playing


## `from` / `center` は画面(この部品の親)の座標。`reveal` なら先に `center` で開いて読ませる。
## `land` は駒が現れ始める瞬間に呼ぶ(着地・登場の演出を始める)。
func play(
	view: CardView,
	card: CardData,
	from: Vector2,
	reveal: bool,
	face_scale: float,
	center: Vector2,
	land: Callable
) -> void:
	view.modulate.a = 0.0
	(
		_jobs
		. append(
			{
				"view": view,
				"card": card,
				"from": from,
				"reveal": reveal,
				"face_scale": face_scale,
				"center": center,
				"land": land,
			}
		)
	)
	if not _playing:
		_next()


## 対局を離れる・やり直すとき。駒を見える状態へ戻して止める。
func stop() -> void:
	for job in _jobs:
		job["view"].modulate.a = 1.0
	_jobs.clear()
	_gen += 1
	_clear_face()
	_playing = false
	_t = -1.0
	queue_redraw()


func _next() -> void:
	if _jobs.is_empty():
		_playing = false
		finished.emit()
		return
	_playing = true
	var job: Dictionary = _jobs.pop_front()
	var gen := _gen
	await _run(job, gen)
	if gen == _gen:
		_next()


func _run(job: Dictionary, gen: int) -> void:
	var view: CardView = job["view"]
	var card: CardData = job["card"]
	var face_scale: float = job["face_scale"]
	_face = _make_face(
		card, job["from"], REVEAL_FROM_SCALE * face_scale if job["reveal"] else face_scale
	)
	if job["reveal"]:
		_face.modulate.a = 0.0
		var pop := _face.create_tween().set_parallel()
		(
			pop
			. tween_property(_face, "position", job["center"] - _face.size * 0.5, REVEAL_POP)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		(
			pop
			. tween_property(_face, "scale", Vector2.ONE * REVEAL_SCALE * face_scale, REVEAL_POP)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		pop.tween_property(_face, "modulate:a", 1.0, REVEAL_POP * 0.6)
		await _wait(REVEAL_POP + REVEAL_HOLD)
		if gen != _gen:
			return
	var zoom := view.get_global_transform().get_scale().x
	var art_center := _art_center(view)
	var duration := REVEAL_TO_SLOT if job["reveal"] else TO_SLOT
	var lift := Vector2(0.0, 0.0 if job["reveal"] else SLOT_FACE_LIFT * zoom)
	var move := _face.create_tween().set_parallel()
	(
		move
		. tween_property(_face, "position", art_center - lift - _face.size * 0.5, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT if job["reveal"] else Tween.EASE_OUT)
	)
	move.tween_property(_face, "scale", Vector2.ONE * SLOT_FACE_SCALE * zoom, duration).set_trans(
		Tween.TRANS_CUBIC
	)
	await _wait(duration)
	if gen != _gen:
		return
	await _unravel(view, card, art_center, zoom, job["land"], gen)


func _unravel(
	view: CardView, card: CardData, art_center: Vector2, zoom: float, land: Callable, gen: int
) -> void:
	_sand = HourglassArt.accent_color(card.art_key())
	_face_rect = Rect2(
		_face.position + _face.size * (Vector2.ONE - _face.scale) * 0.5, _face.size * _face.scale
	)
	_to = art_center
	_zoom = zoom
	var fade := _face.create_tween().set_parallel().set_ease(Tween.EASE_IN)
	fade.tween_property(_face, "modulate:a", 0.0, UNRAVEL * FACE_FADE_PART)
	fade.tween_property(_face, "scale", _face.scale * FACE_SHRINK, UNRAVEL * FACE_FADE_PART)
	var grains := create_tween()
	grains.tween_method(_set_t, 0.0, 1.0, UNRAVEL)
	await _wait(UNRAVEL * UNIT_APPEAR_AT)
	if gen != _gen:
		return
	if is_instance_valid(view):
		view.create_tween().tween_property(view, "modulate:a", 1.0, UNRAVEL * UNIT_APPEAR_PART)
		land.call()
	await _wait(UNRAVEL * (1.0 - UNIT_APPEAR_AT))
	if gen != _gen:
		return
	_t = -1.0
	queue_redraw()
	_clear_face()


func _set_t(value: float) -> void:
	_t = value
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var ci := get_canvas_item()
	var edge := clampf(1.0 - _t / EDGE_PART, 0.0, 1.0)
	if edge > 0.0:
		var shrunk := _face_rect.grow(-_face_rect.size.x * EDGE_SHRINK * (1.0 - edge))
		draw_rect(
			shrunk, Color(_sand.lightened(EDGE_LIGHTEN), edge * EDGE_ALPHA), false, EDGE_WIDTH
		)
	for i in GRAINS:
		var delay := SignaturePaint.jitter(i, 7) * GRAIN_DELAY
		var local := clampf((_t - delay) / (1.0 - delay), 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var start := (
			_face_rect.position
			+ Vector2(SignaturePaint.jitter(i, 3), SignaturePaint.jitter(i, 5)) * _face_rect.size
		)
		var end := (
			_to
			+ (
				Vector2(SignaturePaint.jitter(i, 11) - 0.5, SignaturePaint.jitter(i, 13) - 0.5)
				* GRAIN_SPREAD
				* _zoom
			)
		)
		var eased := local * local * (3.0 - 2.0 * local)
		var side := Vector2(-(end - start).y, (end - start).x).normalized()
		var swirl := (
			side * sin(local * PI) * GRAIN_SWIRL * (SignaturePaint.jitter(i, 17) - 0.5) * 2.0
		)
		var color := _sand.lerp(Color.WHITE, GRAIN_WHITEN_FROM + GRAIN_WHITEN_BY * local)
		color.a = 1.0 - smoothstep(GRAIN_FADE_FROM, 1.0, local)
		ShapePaint.circle(
			ci, start.lerp(end, eased) + swirl, GRAIN_RADIUS * _zoom * (1.0 - 0.4 * local), color
		)


func _make_face(card: CardData, center: Vector2, start_scale: float) -> CardView:
	var face := CardView.new()
	face.mode = CardView.Mode.HAND
	face.card = card
	face.size = CardView.HAND_SIZE_PX
	face.pivot_offset = face.size * 0.5
	face.scale = Vector2.ONE * start_scale
	face.position = center - face.size * 0.5
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face)
	return face


func _clear_face() -> void:
	if _face != null and is_instance_valid(_face):
		_face.queue_free()
	_face = null


## 駒の絵の中心(台座の上、絵の高さの半分)をこの部品の座標で。
func _art_center(view: CardView) -> Vector2:
	var local := Vector2(
		view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - CardView.BOARD_ART_SIDE * 0.5
	)
	return get_global_transform().affine_inverse() * (view.get_global_transform() * local)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
