class_name UnitWindupFx
extends Control
## 駒から出る効果の溜め(GameDesign.md 9章「駒から出る効果は、飛ぶ前に溜めを置く」)。
## 駒の絵がそのカードの砂の色に染まって少し膨らみ、外の輪が駒へ縮む。続けて発動するとき、
## どの駒から出たかを読ませるため。駒の子として重ね、終わったら自分で消える。
##
## 染めは止め絵を砂の色で重ねたもの、縁の光は焼いた枠の層(10.19節)を砂の色で加算したもの。
## 新しい絵は描かない。

const DURATION := 0.18
const FADE_OUT := 0.22
## 染めの濃さ・枠の光の濃さ・枠の光を暗くする量。
const TINT_ALPHA := 0.6
const RIM_ALPHA := 0.55
const RIM_DARKEN := 0.2
const SWELL := 1.06
## 縮む輪の半径(駒の座標)・明るさ・太さ・分割数。
const RING_FROM := 58.0
const RING_TO := 16.0
const RING_LIGHTEN := 0.3
const RING_ALPHA := 0.85
const RING_WIDTH := 2.5
const RING_POINTS := 40

var _t := 0.0
var _center := Vector2.ZERO
var _sand := Color.WHITE


## 溜めを始める。`time_rate` はカードの演出の短縮版の割合。溜めが終わる秒を返す。
static func play(view: CardView, time_rate := 1.0) -> float:
	var duration := DURATION * time_rate
	if view == null or view.card == null:
		return 0.0
	var fx := UnitWindupFx.new()
	view.add_child(fx)
	fx._start(view, duration)
	return duration


func _start(view: CardView, duration: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = view.size
	_sand = HourglassArt.accent_color(view.card.art_key())
	_center = Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - CardView.BOARD_ART_SIDE * 0.5)
	var still := view._icon()
	if still == null:
		queue_free()
		return
	var rect := view._fit_art(still, view.board_art_box())
	var tint := _layer(still, rect, null, Color(_sand, 0.0))
	var frame_tex := HourglassLive.load_layer(view.card.art_key(), view._icon_state(), "frame")
	var rim: TextureRect = null
	if frame_tex != null:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rim = _layer(frame_tex, rect, add, Color(_sand.darkened(RIM_DARKEN), 0.0))
	var swell := create_tween().set_parallel()
	swell.tween_method(_set_t, 0.0, 1.0, duration).set_ease(Tween.EASE_IN)
	swell.tween_property(tint, "modulate:a", TINT_ALPHA, duration).set_ease(Tween.EASE_IN)
	swell.tween_property(tint, "scale", Vector2.ONE * SWELL, duration).set_trans(Tween.TRANS_SINE)
	if rim != null:
		swell.tween_property(rim, "modulate:a", RIM_ALPHA, duration).set_ease(Tween.EASE_IN)
		swell.tween_property(rim, "scale", Vector2.ONE * SWELL, duration).set_trans(
			Tween.TRANS_SINE
		)
	swell.chain().tween_callback(func() -> void: _t = -1.0)
	swell.chain().tween_property(self, "modulate:a", 0.0, FADE_OUT)
	swell.chain().tween_callback(queue_free)


func _layer(texture: Texture2D, rect: Rect2, blend: Material, color: Color) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.material = blend
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.position = rect.position
	layer.size = rect.size
	layer.pivot_offset = rect.size * 0.5
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.modulate = color
	add_child(layer)
	return layer


func _set_t(value: float) -> void:
	_t = value
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var radius := lerpf(RING_FROM, RING_TO, _t * _t)
	var color := Color(_sand.lightened(RING_LIGHTEN), RING_ALPHA * sin(_t * PI * 0.5))
	ShapePaint.arc(
		get_canvas_item(), _center, radius, 0.0, TAU, RING_POINTS, color, RING_WIDTH, true
	)
