class_name SoloUiPaint
extends RefCounted
## 遠征(ソロモード)の画面で共有する描画・部品(GameDesign.md 27章「画面」)。
## 額縁つきの凹んだパネル(真鍮の縁+濃紺の面+落ち込み影+グレイン)を、出発の札・
## 道の状態パネルの両方で使うため、ここへ集める。

const PANEL_RADIUS := 20.0
const PANEL_INNER_RADIUS := 15.0
const PANEL_SEGMENTS := 14
const PANEL_INSET := 6.0
const PANEL_GRAIN := 0.05
const GLOW_INSET := 4.0
const GLOW_RADIUS := 22.0
const GLOW_WIDTH := 3.0

const TRANSPARENT_BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]


## 選ばれる前提の札を同じ強さで並べ、選べる状態(または選ばれた状態)だけを光らせる。
static func paint_panel(ci: RID, rect: Rect2, highlighted: bool) -> void:
	var outer := UiPaint.rounded_rect_points_uniform(rect, PANEL_RADIUS, PANEL_SEGMENTS)
	UiPaint.fill_gradient_polygon(
		ci, outer, rect, [[0.0, UiPalette.BRASS_HIGHLIGHT], [1.0, UiPalette.BRASS_DARK]]
	)
	var inner_rect := rect.grow(-PANEL_INSET)
	var inner := UiPaint.rounded_rect_points_uniform(inner_rect, PANEL_INNER_RADIUS, PANEL_SEGMENTS)
	UiPaint.fill_gradient_polygon(
		ci, inner, inner_rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.FELT_NAVY_TOP]]
	)
	UiPaint.draw_bevel(ci, inner, UiPalette.BRASS_RIM_LIGHT, Color(0, 0, 0, 0.5), 2.0, false)
	UiPaint.draw_inner_shadow(
		ci, inner_rect, PANEL_INNER_RADIUS, PANEL_SEGMENTS, 5, Color(0, 0, 0, 1), 0.28
	)
	UiPaint.apply_grain(ci, inner_rect, PANEL_GRAIN)
	if highlighted:
		var glow := UiPaint.rounded_rect_points_uniform(
			rect.grow(GLOW_INSET), GLOW_RADIUS, PANEL_SEGMENTS
		)
		UiPaint.draw_bevel(ci, glow, UiPalette.GLOW_AMBER, UiPalette.GLOW_AMBER, GLOW_WIDTH, false)


static func fill_colors(points: PackedVector2Array, color: Color) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	return colors


## 見た目を持たず当たり判定だけのボタン(額縁の絵の上に重ねる、道の駒・出発の札用)。
static func transparent_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state in TRANSPARENT_BUTTON_STATES:
		button.add_theme_stylebox_override(state, empty)
	return button
