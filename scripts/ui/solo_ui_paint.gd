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

## ホバー・押下で動かす見た目のノードを、当たり判定のボタンに持たせる名前(`choice_button()`)。
const HOVER_VISUAL_META := &"hover_visual"
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


## 札・駒の絵の上に重ねる当たり判定のボタン。押せる要素の共通の挙動(指カーソル)を持たせ、
## ホバー・押下で何を動かすかを`visual`として覚えておく(GameDesign.md 9章「操作」)。
static func hit_button(visual: Control) -> Button:
	var button := transparent_button()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta(HOVER_VISUAL_META, visual)
	return button


## 札の見た目(`visual`)をホバーで明るく浮かせ、押し込みで縮める。ボタン自身は動かさない
## (浮いた縁でカーソルが外れて明滅しないため)。`pivot`は`visual`の中の札の中心。
static func choice_button(visual: Control, pivot: Vector2) -> Button:
	var button := hit_button(visual)
	visual.pivot_offset = pivot
	var rest := visual.position
	button.mouse_entered.connect(func() -> void: ClickArea.animate_hover(visual, true, rest))
	button.mouse_exited.connect(
		func() -> void:
			ClickArea.animate_hover(visual, false, rest)
			ClickArea.animate_press(visual, false)
	)
	button.button_down.connect(func() -> void: ClickArea.animate_press(visual, true))
	button.button_up.connect(func() -> void: ClickArea.animate_press(visual, false))
	return button


## 札の見た目をまとめる箱。ホバー・押下で札の部品を一緒に動かすため、部品はここへ足す。
static func card_root(parent_size: Vector2) -> Control:
	var root := Control.new()
	root.size = parent_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root


static func transparent_button() -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state in TRANSPARENT_BUTTON_STATES:
		button.add_theme_stylebox_override(state, empty)
	return button
