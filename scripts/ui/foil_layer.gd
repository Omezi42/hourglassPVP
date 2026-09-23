class_name FoilLayer
extends Control
## 白で描いた図形へ金箔の縦グラデーションを掛ける描画層(TitleLogo)。
##
## グラデーションは層ごとに`top_y`〜`bottom_y`の帯で決まる。紋章・題字・罫のように
## 高さの違う部品へそれぞれ同じ箔を掛けるため、部品ごとに1層ずつ持つ。

const SHADER := preload("res://resources/shaders/foil_gradient.gdshader")
const TOP_COLOR := Color(1.0, 0.96, 0.8, 1.0)
const MID_COLOR := Color(0.96, 0.78, 0.38, 1.0)
const BOTTOM_COLOR := Color(0.66, 0.43, 0.14, 1.0)
const SHEEN_COLOR := Color(0.25, 0.2, 0.1, 1.0)

## 白で描く処理。引数にこの層(`CanvasItem`)を受ける。
var painter: Callable


func _init(paint: Callable, top_y: float, bottom_y: float) -> void:
	painter = paint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("top_y", top_y)
	shader_material.set_shader_parameter("bottom_y", bottom_y)
	shader_material.set_shader_parameter("top_color", TOP_COLOR)
	shader_material.set_shader_parameter("mid_color", MID_COLOR)
	shader_material.set_shader_parameter("bottom_color", BOTTOM_COLOR)
	shader_material.set_shader_parameter("sheen_color", SHEEN_COLOR)
	material = shader_material


func _draw() -> void:
	painter.call(self)
