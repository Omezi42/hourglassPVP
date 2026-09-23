class_name MulliganStageLight
extends Control
## マリガンの暗幕の上で、初期手札の列の後ろにだけ敷く淡い光だまり(GameDesign.md 9章)。
## 一様な暗幕の上へ札を直に並べると、札が暗がりに浮いたまま沈んで見えるため、
## 卓の背後の光(`BoardGlow`)と同じ琥珀色で列の奥を照らす。

## 外側の楕円ほど薄く重ねて、縁のない光として見せる。
const LAYER_COUNT := 7
const PEAK_ALPHA := 0.035
const SEGMENTS := 48


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ci := get_canvas_item()
	var center := size * 0.5
	var radius := size * 0.5
	for i in LAYER_COUNT:
		var t := float(i) / float(LAYER_COUNT)
		var color := UiPalette.GLOW_AMBER
		color.a = PEAK_ALPHA
		UiPaint.fill_ellipse(ci, center, radius * (1.0 - t * 0.85), color, SEGMENTS)
