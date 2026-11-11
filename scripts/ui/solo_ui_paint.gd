class_name SoloUiPaint
extends RefCounted
## 遠征(ソロモード)の画面で共有する描画・部品(GameDesign.md 27章「画面」)。
## 硝子の面のパネルを、出発の札・道の状態パネルなどの両方で使うため、ここへ集める。

## ホバー・押下で動かす見た目のノードを、当たり判定のボタンに持たせる名前(`choice_button()`)。
const HOVER_VISUAL_META := &"hover_visual"
const TRANSPARENT_BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]


## 硝子の面。選べる状態(または選ばれた状態)だけ縁を砂色にして、同じ強さで並べた札から区別する。
static func paint_panel(ci: RID, rect: Rect2, highlighted: bool) -> void:
	UiKit.glass(
		ci,
		rect,
		-1.0,
		1.0,
		UiKit.GLASS_ALPHA,
		UiKit.rim_color(UiPalette.SAND) if highlighted else []
	)


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
