class_name HomeScrim
extends Control
## ホーム画面で、背景の絵の上へ敷く夜の藍の幕(GameDesign.md 9章)。
## 背景の絵は奥にあるものとして扱い、絵が見えていてその上の字も読めるところまで落とす。
## 画面の端へ向かって濃くし、絵の見えている中央をそのまま奥行きにする。

## 上端(ヘッダー)と下端(下段の札)を濃く、絵の見えている中ほどを薄くする。
const STOPS := [
	[0.0, Color(0.035, 0.045, 0.085, 0.78)],
	[0.18, Color(0.035, 0.045, 0.085, 0.38)],
	[0.60, Color(0.035, 0.045, 0.085, 0.30)],
	[1.0, Color(0.035, 0.045, 0.085, 0.80)],
]


static func make() -> HomeScrim:
	var scrim := HomeScrim.new()
	# **`set_anchors_preset()` は使わない。**生成直後(サイズ0)へ掛けると
	# 「いまの矩形を保つように」offset を計算し直し、0サイズのまま固定される(Pitfalls.md)。
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return scrim


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var full := PackedVector2Array(
		[Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	)
	ShapePaint.gradient_convex(get_canvas_item(), full, STOPS)
