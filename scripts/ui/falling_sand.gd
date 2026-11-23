class_name FallingSand
extends Control
## 印の矩形へ砂の粒だけを毎コマ描く部品(GameDesign.md 9章「動き続けてよいのは砂だけ」)。
## 印そのものは描かない。毎コマ描き直す範囲を砂だけに絞るため、親(席など)とは別のノードにする。

var emblem_rect := Rect2()
var color := UiPalette.GOLD

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func start() -> void:
	_time = 0.0
	visible = true
	set_process(true)


func stop() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	EmptyState.draw_falling_sand(get_canvas_item(), emblem_rect, color, _time)
