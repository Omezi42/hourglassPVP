class_name RoundActionButton
extends Button
## 対局画面「行動の列」の丸いボタン(GameDesign.md 9章「対局画面の再構築」)。
##
## `CodedButton`/`CodedButtonStyle`は文字の幅に合わせて矩形が伸びる仕組みのため、
## 直径だけが決まっているこの用途には合わない(実際に「反転権」のオーバルが
## 丸に収まらなかった)。`Button`を継承するのはホバー・押下・`disabled`・
## `pressed`シグナル・`SoundBank.wire_buttons()`の配線をそのまま使うためで、
## **`text`は空のままにし、文言は`label`として自前で描く**。

const MIN_FONT_SIZE := 11
## 紋章の下へ添える文言の大きさ(紋章に主役を譲るため、通常のフィット計算より
## 小さく固定する)。
const EMBLEM_LABEL_FONT_SIZE := 12
const RIM_SEGMENTS := 28
const BADGE_SEGMENTS := 16
const SHADOW_SEGMENTS := 22
const STYLE_STATES := ["normal", "hover", "pressed", "disabled", "focus"]
## アイコンの半辺(直径に対する比)。取り込みアイコンは正方形いっぱいに描かれているため、
## 手描き紋章(0.30)より小さく取って面の余白を残す。
const ICON_HALF_RATIO := 0.21

## 丸の中の語。
var label: String = "":
	set(value):
		label = value
		queue_redraw()
## 丸の直径。
var diameter: float = 56.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(diameter, diameter)
		size = Vector2(diameter, diameter)
		queue_redraw()
## 真鍮を塗りつぶした主役の面か(GameDesign.md 9章「主要な操作は塗りつぶした
## 真鍮、副次的な操作は凹んだパネル」)。
var filled: bool = false:
	set(value):
		filled = value
		queue_redraw()
## 右下に添える小さな数字(エモートの残り秒)。空なら出さない。
var badge: String = "":
	set(value):
		badge = value
		queue_redraw()
## 面の中央(文言があれば少し上)に描く紋章。反転権のように文言だけでは
## 伝わりにくい操作に添える(GameDesign.md 9章「対局画面の再構築」)。
var emblem: UiPaint.Emblem = UiPaint.Emblem.NONE:
	set(value):
		emblem = value
		queue_redraw()
## `emblem`の代わりに描く取り込みアイコン(`assets/ui/icons/`の白いシルエット)。
var emblem_texture: Texture2D:
	set(value):
		emblem_texture = value
		queue_redraw()

var _font: Font


func _init(p_label: String = "", p_diameter: float = 56.0, p_filled: bool = false) -> void:
	label = p_label
	diameter = p_diameter
	filled = p_filled
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	var empty := StyleBoxEmpty.new()
	for state in STYLE_STATES:
		add_theme_stylebox_override(state, empty)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _get_minimum_size() -> Vector2:
	return Vector2(diameter, diameter)


func _draw() -> void:
	var mode := get_draw_mode()
	var is_disabled := mode == BaseButton.DRAW_DISABLED
	var is_pressed_now := mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	var is_hovered_now := mode == BaseButton.DRAW_HOVER or mode == BaseButton.DRAW_HOVER_PRESSED
	var radius := diameter * 0.5
	var shadow_center := Vector2(radius, radius + 2.0)
	var center := Vector2(radius, radius)
	if is_pressed_now:
		center.y += 1.0
	var ci := get_canvas_item()
	UiPaint.fill_circle(ci, shadow_center, radius, Color(0, 0, 0, 0.45), SHADOW_SEGMENTS)
	var outline := UiPalette.OUTLINE_DARK
	if is_disabled:
		outline = UiPaint.disabled_tone(outline)
	UiPaint.draw_ring(ci, center, radius - 1.0, outline, 2.0, RIM_SEGMENTS)
	var rim_width: float = maxf(diameter * 0.09, 5.0)
	var inner_radius: float = radius - rim_width
	_draw_rim(ci, center, radius - 2.0, inner_radius, is_hovered_now, is_pressed_now, is_disabled)
	if filled:
		_draw_filled_face(ci, center, inner_radius, is_hovered_now, is_pressed_now, is_disabled)
	else:
		_draw_hollow_face(ci, center, inner_radius, is_hovered_now, is_pressed_now, is_disabled)
	_draw_top_highlight(ci, center, inner_radius, is_disabled)
	if emblem_texture != null or emblem != UiPaint.Emblem.NONE:
		# 紋章は面の中央よりわずかに上、文言は紋章の下寄りへ小さく描く
		# (反転権:紋章だけでは「何回できるか」が伝わらないため語も添える)。
		var emblem_center := center + Vector2(0.0, -diameter * 0.06)
		if emblem_texture != null:
			UiPaint.draw_icon(
				ci, emblem_texture, emblem_center, diameter * ICON_HALF_RATIO, is_disabled
			)
		else:
			UiPaint.draw_emblem(ci, emblem, emblem_center, diameter * 0.30)
		_draw_label(center + Vector2(0.0, diameter * 0.30), is_disabled, EMBLEM_LABEL_FONT_SIZE)
	else:
		# バッジがある間は、右下へ添える数字と文字が重ならないよう語を少し上へ寄せる
		# (「反転権」のように3字ある語は、中央のままだと右下のバッジへ食い込む)。
		var label_center := (
			center + Vector2(0.0, -diameter * 0.12) if not badge.is_empty() else center
		)
		_draw_label(label_center, is_disabled)
	if not badge.is_empty():
		_draw_badge(ci, center, radius, is_disabled)
	if is_hovered_now and not is_disabled and not is_pressed_now:
		UiPaint.draw_ring(
			ci, center, radius + 3.0, Color(UiPalette.GLOW_AMBER, 0.18), 3.0, RIM_SEGMENTS
		)


## 真鍮のリム。外周点列と内周点列を同じ分割数で作り、対応する点どうしを結んで
## 帯を1周ぶん敷き詰める(`BoardTable._draw_frame_ring()`と同じやり方。円の輪は
## 単純な単一ポリゴンでは正しく塗れないため)。
func _draw_rim(
	ci: RID,
	center: Vector2,
	outer_r: float,
	inner_r: float,
	hovered: bool,
	pressed: bool,
	disabled_now: bool
) -> void:
	var rect := Rect2(center - Vector2(outer_r, outer_r), Vector2.ONE * outer_r * 2.0)
	var stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT],
		[0.4, UiPalette.BRASS_MID],
		[0.85, UiPalette.BRASS_DARK],
		[1.0, UiPalette.BRASS_BOUNCE],
	]
	if pressed:
		stops = [
			[0.0, UiPalette.BRASS_PRESSED_MID],
			[1.0, UiPalette.BRASS_PRESSED_DARK],
		]
	elif hovered:
		stops = _lightened_stops(stops, 0.08)
	if disabled_now:
		stops = UiPaint.dim_gradient_stops(stops)
	var outer_points := UiPaint.circle_points(center, outer_r, RIM_SEGMENTS)
	var inner_points := UiPaint.circle_points(center, inner_r, RIM_SEGMENTS)
	var count := outer_points.size()
	for i in count:
		var j := (i + 1) % count
		var quad := PackedVector2Array(
			[outer_points[i], outer_points[j], inner_points[j], inner_points[i]]
		)
		UiPaint.fill_gradient_polygon(ci, quad, rect, stops)


## 塗りつぶした主役の面。暖色の縦グラデーション(上端が明るい)+ 中心へ寄せた
## やわらかい放射のハイライトを2段重ねる。
func _draw_filled_face(
	ci: RID, center: Vector2, r: float, hovered: bool, pressed: bool, disabled_now: bool
) -> void:
	var rect := Rect2(center - Vector2(r, r), Vector2.ONE * r * 2.0)
	var top := UiPalette.ROUND_FILLED_TOP
	var bottom := UiPalette.ROUND_FILLED_BOTTOM
	if pressed:
		top = top.darkened(0.28)
		bottom = bottom.darkened(0.2)
	elif hovered:
		top = top.lightened(0.08)
		bottom = bottom.lightened(0.08)
	var stops := [[0.0, top], [1.0, bottom]]
	if disabled_now:
		stops = UiPaint.dim_gradient_stops(stops)
	UiPaint.fill_gradient_polygon(ci, UiPaint.circle_points(center, r, RIM_SEGMENTS), rect, stops)
	if disabled_now:
		return
	UiPaint.fill_circle(
		ci, center - Vector2(0.0, r * 0.15), r * 0.85, Color(1.0, 0.92, 0.75, 0.10), 20
	)
	UiPaint.fill_circle(
		ci, center - Vector2(0.0, r * 0.35), r * 0.35, Color(1.0, 0.95, 0.82, 0.16), 18
	)


## 凹んだ面(反転権・ログ・投了・エモート等)。濃紺の縦グラデーション +
## 上端の内側へ寄せた落ち込み影(暗い弧を2〜3段)。
func _draw_hollow_face(
	ci: RID, center: Vector2, r: float, hovered: bool, pressed: bool, disabled_now: bool
) -> void:
	var rect := Rect2(center - Vector2(r, r), Vector2.ONE * r * 2.0)
	var top := UiPalette.NAVY_PANEL_TOP
	var bottom := UiPalette.NAVY_PANEL_BOTTOM
	if hovered:
		top = top.lightened(0.1)
		bottom = bottom.lightened(0.1)
	if pressed:
		top = top.darkened(0.12)
		bottom = bottom.darkened(0.12)
	var stops := [[0.0, top], [1.0, bottom]]
	if disabled_now:
		stops = UiPaint.dim_gradient_stops(stops)
	UiPaint.fill_gradient_polygon(ci, UiPaint.circle_points(center, r, RIM_SEGMENTS), rect, stops)
	if not disabled_now:
		_draw_top_shadow_arcs(ci, center, r)


## `UiPaint.draw_inner_shadow()`は角丸矩形向けのため、円では上端に寄せた
## 弧を数段重ねて同じ「上から差し込む影」を作る。
func _draw_top_shadow_arcs(ci: RID, center: Vector2, r: float) -> void:
	var layers := 3
	for i in layers:
		var inset: float = r * (0.1 + i * 0.16)
		var arc_r: float = r - inset
		if arc_r <= 1.0:
			continue
		var alpha: float = 0.30 * (1.0 - float(i) / float(layers))
		_draw_top_arc(ci, center, arc_r, Color(0, 0, 0, alpha), 2.0)


## 面の上端に沿う光の弧。真鍮のリムの内側で、金属が上から光を受けている印象を足す。
func _draw_top_highlight(ci: RID, center: Vector2, r: float, disabled_now: bool) -> void:
	if disabled_now:
		return
	_draw_top_arc(ci, center, r - 2.0, Color(UiPalette.BRASS_HIGHLIGHT, 0.45), 1.4)


## 上端を中心にした弧を、両端でアルファが薄まるポリラインとして描く。
func _draw_top_arc(ci: RID, center: Vector2, r: float, color: Color, width: float) -> void:
	var segments := 18
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for s in range(segments + 1):
		var t: float = float(s) / float(segments)
		var angle: float = lerpf(-PI * 0.82, -PI * 0.18, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
		colors.append(Color(color.r, color.g, color.b, color.a * sin(t * PI)))
	RenderingServer.canvas_item_add_polyline(ci, points, colors, width, true)


func _draw_label(center: Vector2, disabled_now: bool, forced_font_size: int = 0) -> void:
	if _font == null or label.is_empty():
		return
	var font_size := forced_font_size if forced_font_size > 0 else _fit_font_size()
	var text_color: Color
	var shadow_color: Color
	if filled:
		text_color = UiPalette.OUTLINE_DARK
		shadow_color = Color(1.0, 1.0, 1.0, 0.35)
	else:
		text_color = UiPalette.TEXT_OFFWHITE
		shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	if disabled_now:
		text_color = UiPaint.disabled_tone(text_color)
		shadow_color.a *= 0.5
	var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := center + Vector2(-text_size.x * 0.5, 0.0)
	origin.y += (float(_font.get_ascent(font_size)) - float(_font.get_descent(font_size))) * 0.5
	draw_string(
		_font, origin + Vector2(0, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color
	)
	draw_string(_font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


## `diameter*0.78`へ収まるまで1pxずつ縮める(`MIN_FONT_SIZE`が下限)。
func _fit_font_size() -> int:
	var base: float = 13.0 + (diameter - 48.0) * ((22.0 - 13.0) / (110.0 - 48.0))
	var current: int = int(round(clampf(base, float(MIN_FONT_SIZE), 26.0)))
	if _font == null or label.is_empty():
		return current
	var max_width: float = diameter * 0.78
	while current > MIN_FONT_SIZE:
		var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, current).x
		if width <= max_width:
			break
		current -= 1
	return current


## 右下の小さな真鍮の丸(反転権の残り回数・エモートの残り秒)。
func _draw_badge(ci: RID, center: Vector2, radius: float, disabled_now: bool) -> void:
	var badge_r: float = diameter * 0.16
	var badge_center := center + Vector2(1.0, 1.0).normalized() * (radius - badge_r * 0.3)
	var rect := Rect2(badge_center - Vector2(badge_r, badge_r), Vector2.ONE * badge_r * 2.0)
	var fill := UiPalette.BRASS_LIGHT
	var outline := UiPalette.OUTLINE_DARK
	if disabled_now:
		fill = UiPaint.disabled_tone(fill)
		outline = UiPaint.disabled_tone(outline)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(badge_center, badge_r, BADGE_SEGMENTS),
		rect,
		[[0.0, fill.lightened(0.18)], [1.0, fill.darkened(0.1)]]
	)
	UiPaint.draw_ring(ci, badge_center, badge_r, outline, 1.6, BADGE_SEGMENTS)
	if _font == null:
		return
	var font_size := 12
	var width: float = _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width > badge_r * 1.5 and font_size > 9:
		font_size -= 1
		width = _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := badge_center + Vector2(-width * 0.5, 0.0)
	origin.y += (float(_font.get_ascent(font_size)) - float(_font.get_descent(font_size))) * 0.5
	draw_string(_font, origin, badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline)


static func _lightened_stops(stops: Array, amount: float) -> Array:
	var result := []
	for stop in stops:
		var color: Color = stop[1]
		result.append([stop[0], color.lightened(amount)])
	return result
