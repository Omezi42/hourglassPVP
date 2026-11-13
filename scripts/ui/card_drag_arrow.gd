class_name CardDragArrow
extends Control
## 攻撃をドラッグしている間、駒の中心から指先へ引く矢印(GameDesign.md 9章
## 「対局画面の手触り」)。手札のドラッグは札そのものが動くので分かるが、攻撃の
## ドラッグには出どころと行き先の線が無かった。手札のドラッグ(設置)では出さない
## (自分の場の駒をドラッグしたときだけ呼ばれる)。
##
## `CardFlipBeam` と同じく盤面より手前の独立したオーバーレイとして持つ
## (`Control._draw()` は自分の子より背面に描かれるため、画面側で描くと駒に隠れる)。

const SCREEN_SIZE := Vector2(1280, 720)
const COLOR := Color(UiPalette.GOLD, 0.6)
const LOCKED_COLOR := Color(UiPalette.GOLD, 1.0)
## 紺の卓と金の台座の上で金の線が沈まないよう、線と矢尻の下へ敷く影。
const UNDERLAY_COLOR := Color(0.0, 0.0, 0.0, 0.4)
const UNDERLAY_GROW := 3.0
const LINE_WIDTH := 3.0
const HEAD_LENGTH := 16.0
const HEAD_WIDTH := 9.0
## 狙える相手の上では太く大きくなり、先端が相手へ吸い付く。切り替えは即時(カチッと入るのが返事になる)。
const LOCKED_LINE_WIDTH := 5.0
const LOCKED_HEAD_LENGTH := 22.0
const LOCKED_HEAD_WIDTH := 13.0
## 成立せずに放したときだけ、矢印を短く落としてから消す。
const CANCEL_FADE := 0.1

var _from := Vector2.ZERO
var _active := false
var _locked := false
var _snap := Vector2.INF
var _release_to := Vector2.ZERO
var _fading := false
var _fade_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。コードで生成した
	# 直後(サイズ0)のノードへ使うと0のまま固定され、何も描かれない。
	size = SCREEN_SIZE
	set_process(false)


func is_active() -> bool:
	return _active


## ドラッグを開始した駒の中心から矢印を引き始める。`from` は `CardFlipBeam` と同じ
## 座標系(このノードの親と同じ `Control` の local 座標)で渡す。
func begin(from: Vector2) -> void:
	_kill_fade()
	_from = from
	_active = true
	_locked = false
	_snap = Vector2.INF
	set_process(true)
	queue_redraw()


## 狙える相手の上にいるか。`snap` が有限なら先端をそこへ吸い付かせる(相手のHP帯は指のまま)。
func set_aim(locked: bool, snap := Vector2.INF) -> void:
	if not _active:
		return
	_locked = locked
	_snap = snap if locked else Vector2.INF
	queue_redraw()


## 放された/取り消された。攻撃が成立したときは即時に消し、成立しなかったときだけ短く落とす。
func end(hit := false) -> void:
	if not _active:
		return
	_release_to = _end_point()
	_active = false
	set_process(false)
	if hit:
		queue_redraw()
		return
	_fading = true
	modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, CANCEL_FADE)
	_fade_tween.tween_callback(_on_faded)


func _on_faded() -> void:
	_fading = false
	modulate.a = 1.0
	queue_redraw()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fading = false
	modulate.a = 1.0


func _process(_delta: float) -> void:
	queue_redraw()


func _end_point() -> Vector2:
	if not _active:
		return _release_to
	if _locked and _snap != Vector2.INF:
		return _snap
	return get_local_mouse_position()


func _draw() -> void:
	if not _active and not _fading:
		return
	var to := _end_point()
	var head_length := LOCKED_HEAD_LENGTH if _locked else HEAD_LENGTH
	var head_width := LOCKED_HEAD_WIDTH if _locked else HEAD_WIDTH
	var line_width := LOCKED_LINE_WIDTH if _locked else LINE_WIDTH
	var color := LOCKED_COLOR if _locked else COLOR
	var dir := to - _from
	if dir.length() < head_length:
		return
	var normal := dir.normalized()
	var shaft_end := to - normal * head_length
	_draw_arrow(
		to,
		shaft_end,
		normal,
		line_width + UNDERLAY_GROW,
		head_width + UNDERLAY_GROW,
		UNDERLAY_COLOR
	)
	_draw_arrow(to, shaft_end, normal, line_width, head_width, color)


func _draw_arrow(
	to: Vector2,
	shaft_end: Vector2,
	normal: Vector2,
	line_width: float,
	head_width: float,
	color: Color
) -> void:
	draw_line(_from, shaft_end, color, line_width)
	var side := Vector2(-normal.y, normal.x) * head_width * 0.5
	ShapePaint.colored_polygon(
		get_canvas_item(), PackedVector2Array([to, shaft_end + side, shaft_end - side]), color
	)
