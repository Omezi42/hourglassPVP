class_name CardSpellAim
extends Control
## 対象を取る砂術を構えた姿(GameDesign.md 9章「砂術」)。手札の上端より上へ運ぶと、札が
## 卓の左(縦では卓の左端)へ移って大きく構え、そこから指先へ矢印を伸ばす。狙えない所では矢印を灰色にする。
##
## `CardDragArrow` と同じく盤面より手前の独立したオーバーレイとして持つ
## (`Control._draw()` は子より背面に描かれるため、画面側で描くと駒に隠れる)。

## 構えた札の大きさ(手札の札に対する倍率)。
const AIM_SCALE := 1.3
## 指先から構えの位置まで札が滑る時間。
const SLIDE_DURATION := 0.14
## 縦画面で札を卓の左端から離す幅。
const PORTRAIT_INSET := 8.0
## 矢印の根元を札の縁から内側へ寄せる幅(縁と矢印の間に隙間を作らない)。
const ROOT_INSET := 8.0
const INVALID_COLOR := Color(0.6, 0.6, 0.62, 0.7)

var _card_view: CardView
var _portrait := false
var _valid := false
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Pitfalls.md)。コードで生成した直後はサイズ0のため。
	size = CardDragArrow.SCREEN_SIZE
	_card_view = CardView.new()
	_card_view.mode = CardView.Mode.HAND
	_card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_view.selected = true
	_card_view.visible = false
	add_child(_card_view)
	set_process(false)


func apply_layout(layout: CardMatchLayout) -> void:
	size = layout.screen_size
	_portrait = layout.portrait
	_card_view.scale = Vector2.ONE * AIM_SCALE * (layout.hand_scale if _portrait else 1.0)
	_card_view.position = _rest_position(layout)


## 構える。`from` は札が滑り出す位置(指先。このノードのlocal座標)。
func show_card(card: CardData, from: Vector2, layout: CardMatchLayout) -> void:
	_card_view.card = card
	_card_view.size = CardView.HAND_SIZE_PX
	_card_view.visible = true
	var rest := _rest_position(layout)
	_card_view.position = from - _shown_size() * 0.5
	var tween := _card_view.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card_view, "position", rest, SLIDE_DURATION)
	_active = true
	set_process(true)
	queue_redraw()


func hide_card() -> void:
	_active = false
	_card_view.visible = false
	set_process(false)
	queue_redraw()


func is_showing() -> bool:
	return _active


## 指している所が狙える対象か。矢印の色を変える。
func set_valid(valid: bool) -> void:
	if _valid != valid:
		_valid = valid
		queue_redraw()


## 構えた札の中心(このノードのlocal座標)。撃った紋章はここから飛ぶ。
func card_center() -> Vector2:
	return _card_view.position + _shown_size() * 0.5


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var from := _arrow_root()
	var to := get_local_mouse_position()
	var dir := to - from
	if dir.length() < CardDragArrow.HEAD_LENGTH:
		return
	var color := CardDragArrow.COLOR if _valid else INVALID_COLOR
	var normal := dir.normalized()
	var shaft_end := to - normal * CardDragArrow.HEAD_LENGTH
	draw_line(from, shaft_end, color, CardDragArrow.LINE_WIDTH)
	var side := Vector2(-normal.y, normal.x) * CardDragArrow.HEAD_WIDTH * 0.5
	ShapePaint.colored_polygon(
		get_canvas_item(), PackedVector2Array([to, shaft_end + side, shaft_end - side]), color
	)


## 矢印の根元。横は札の右の縁(相手の駒は右上にある)、縦は札の上の縁から出す。
func _arrow_root() -> Vector2:
	var rect := Rect2(_card_view.position, _shown_size())
	if _portrait:
		return Vector2(rect.get_center().x, rect.position.y + ROOT_INSET)
	return Vector2(rect.end.x - ROOT_INSET, rect.get_center().y)


func _shown_size() -> Vector2:
	return CardView.HAND_SIZE_PX * _card_view.scale


## 構えの位置。横は「直前の手」の列の上端、縦は卓の左端の中ほど(相手の駒・自分の情報帯を隠さない所)。
func _rest_position(layout: CardMatchLayout) -> Vector2:
	var shown := _shown_size()
	if _portrait:
		return Vector2(
			layout.table_rect.position.x + PORTRAIT_INSET,
			layout.table_rect.get_center().y - shown.y * 0.5
		)
	return Vector2((layout.table_rect.position.x - shown.x) * 0.5, layout.history_position.y)
