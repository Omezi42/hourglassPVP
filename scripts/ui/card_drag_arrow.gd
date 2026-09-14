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
const COLOR := Color(UiPalette.BRASS_HIGHLIGHT, 0.85)
const LINE_WIDTH := 3.0
const HEAD_LENGTH := 16.0
const HEAD_WIDTH := 9.0

var _from := Vector2.ZERO
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。コードで生成した
	# 直後(サイズ0)のノードへ使うと0のまま固定され、何も描かれない。
	size = SCREEN_SIZE
	set_process(false)


## ドラッグを開始した駒の中心から矢印を引き始める。`from` は `CardFlipBeam` と同じ
## 座標系(このノードの親と同じ `Control` の local 座標)で渡す。
func begin(from: Vector2) -> void:
	_from = from
	_active = true
	set_process(true)
	queue_redraw()


## 放された/取り消された。
func end() -> void:
	_active = false
	set_process(false)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var to := get_local_mouse_position()
	var dir := to - _from
	if dir.length() < HEAD_LENGTH:
		return
	var normal := dir.normalized()
	var shaft_end := to - normal * HEAD_LENGTH
	draw_line(_from, shaft_end, COLOR, LINE_WIDTH)
	var side := Vector2(-normal.y, normal.x) * HEAD_WIDTH * 0.5
	draw_colored_polygon(PackedVector2Array([to, shaft_end + side, shaft_end - side]), COLOR)
