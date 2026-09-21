class_name ActionColumnPanel
extends Control
## 対局画面右端「行動の列」の地(GameDesign.md 9章「対局画面の再構築」)。
## 濃紺の縦グラデーション + グレイン + 左辺の真鍮の細線 + 内側の落ち込み影。
##
## `CardMatchScreen` の定数を実行時に読んで矩形を決める(Architecture.md 11章
## 「class_nameを持つ2つのスクリプトが、互いのconstをconstから参照してはいけない」)。
## ボタンより先に `add_child()` して背面へ置く。

const EDGE_WIDTH := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x: float = CardMatchScreen.ACTION_COLUMN_X - 8.0
	position = Vector2(x, 0.0)
	size = Vector2(1280.0 - x, 720.0)


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, 0.06)
	UiPaint.draw_inner_shadow(ci, rect, -1.0, 4, 5, Color(0, 0, 0), 0.3)
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), UiPalette.BRASS_MID, EDGE_WIDTH)
