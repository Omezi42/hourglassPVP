class_name PaintedShape
extends Node2D
## 形を1度だけ描き、以後は位置・拡大・不透明度(`position` / `scale` / `modulate`)だけで動かす部品
## (Architecture.md 10.10.3節)。絶えず動く光や粒を毎フレーム `queue_redraw()` で描き直すと、
## Web版では描き直しのたびにGLのバッファ番号が使い捨てられ、メモリが際限なく積み上がる。
##
## `painter` は `func(shape: PaintedShape)` の形で、`shape` のローカル座標(原点が中心)へ描く。
## 形そのものが変わったときだけ `repaint()` を呼ぶ。

var _painter: Callable


func _init(painter: Callable) -> void:
	_painter = painter


func repaint() -> void:
	queue_redraw()


func _draw() -> void:
	_painter.call(self)
