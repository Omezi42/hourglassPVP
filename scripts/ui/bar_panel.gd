class_name BarPanel
extends Control
## ランクマッチ待機の帯(`RankedWaitBanner`)の背景。硝子の面(UiKit.glass)を全面へ張る。


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	UiKit.glass(get_canvas_item(), Rect2(Vector2.ZERO, size))
