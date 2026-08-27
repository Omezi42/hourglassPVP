class_name CardFlipBeam
extends Control
## 反転の光の筋(GameDesign.md 9章)。**誰がその駒に手を出したのかが分かる演出にする。**
## 反転を行った側の情報帯から対象の駒へ筋が伸び、届いた瞬間に着弾の閃光を出す。
##
## 盤面の駒より手前へ重ねる必要があるため、対局画面の `_draw()` ではなく
## 独立したオーバーレイとして持つ(`Control._draw()` は自分の子より背面に描かれるため、
## 画面側で描くと卓と駒に隠れて筋がほとんど見えない)。

const DURATION := 0.2
const COLOR := Color(1.0, 0.86, 0.5, 1.0)
## 着弾の閃光を出し始める進捗。
const BURST_AT := 0.85

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _progress := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## 筋を伸ばし、対象へ届いたら返る。呼び出し側はこの後に駒の反転を始める。
func play(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	await tween.finished
	_progress = -1.0
	queue_redraw()


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	if _progress < 0.0:
		return
	var head: Vector2 = _from.lerp(_to, _progress)
	draw_line(_from, head, Color(COLOR, 0.3), 7.0)
	draw_line(_from, head, Color(COLOR, 0.95), 2.0)
	draw_circle(head, 7.0, Color(COLOR, 0.9))
	if _progress <= BURST_AT:
		return
	var burst := (_progress - BURST_AT) / (1.0 - BURST_AT)
	draw_circle(_to, 10.0 + 28.0 * burst, Color(COLOR, 0.5 * (1.0 - burst)))
