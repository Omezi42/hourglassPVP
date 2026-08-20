class_name CodedPanelStyle
extends StyleBox
## 画像(StyleBoxTexture)や単色(StyleBoxFlat)を使わず、コード描画のみで
## 真鍮枠+凹んだ中央パネルの外観を再現するStyleBox。CodedButtonStyleと同じ
## 質感言語(UiPaint/UiPalette)を使い、ボタンと同じ製品群に見えるようにする
## (フェーズ12 Q-3)。ボタンと異なりhover/pressed/disabledの状態遷移は持たず、
## 常に単一の「静止した外枠」として描く。
##
## 用途の違いは、形(corner_radius/frame_thickness)と、上部中央の砂時計紋章
## バッジの有無(has_header_emblem)の2つの@exportだけで吸収する。質感
## (真鍮の反射カーブ・グレイン・面取り・落ち込み影)は他のコード描画UI
## (CodedButtonStyle/BoardTable/BarPanel)と共通のまま変更しない。
##
## 元画像(detail_panel_bg.png)にあった四隅の砂時計意匠は再現しない。
## Architecture.md 4章の「機能を伝えない純粋な飾りは置かない」方針により、
## 四隅の意匠はこれに該当すると判断した(上部中央の紋章は「このパネルが
## 砂時計の情報を表示している」ことを伝えるため残す)。
##
## `highlighted`/`dimmed`の2つの@exportは、LineEdit(テキスト入力欄)の背景として
## 使う際のフォーカス/読み取り専用状態を表す(フェーズ12 Q-5)。入力欄は文字を
## 読み書きする場所のため、CodedButtonStyleのhover(パネルを琥珀色へ)のような
## 中央パネルの色変更は可読性を損なう。そのため`highlighted`は枠(frame)の
## グラデーションを1段明るくするだけに留め、中央パネルの色は変えない。
## `dimmed`はCodedButtonStyleのDISABLED状態と同じ変換(UiPaint.disabled_tone)を
## 枠・パネル双方へ適用し、グレイン・落ち込み影も省略する。

const CORNER_SEGMENTS := 8
const OUTLINE_INSET := 2.0

## 真鍮グラデーションのストップ位置(CodedButtonStyleの通常状態と同じ配分)
const FRAME_HIGHLIGHT_STOP := 0.06
const FRAME_MID_STOP := 0.45
const FRAME_DARK_STOP := 0.85

const GRAIN_ALPHA_FRAME := 0.05
const GRAIN_ALPHA_PANEL := 0.045

const BEVEL_WIDTH_FRAME := 1.5
const BEVEL_WIDTH_PANEL := 1.0
const PANEL_LIGHTEN := 0.25
const PANEL_DARKEN := 0.35

const INNER_SHADOW_LAYERS := 5
const INNER_SHADOW_ALPHA := 0.4

## 上部中央の紋章バッジの見た目パラメータ(半径はrect幅に対する比率だが、
## 極端なサイズにならないよう絶対px上下限でクランプする)
const BADGE_RADIUS_RATIO := 0.1
const BADGE_RADIUS_MIN := 16.0
const BADGE_RADIUS_MAX := 30.0
const BADGE_INSET_RATIO := 0.55
const BADGE_BEVEL_INSET := 2.5
const BADGE_ICON_RATIO := 0.62

@export var corner_radius: float = 16.0
@export var frame_thickness: float = 8.0
@export var has_header_emblem: bool = false
@export var highlighted: bool = false
@export var dimmed: bool = false


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var radius := _effective_corner_radius(rect)

	var outline_color := UiPalette.OUTLINE_DARK
	if dimmed:
		outline_color = UiPaint.disabled_tone(outline_color)
	var outline_points := UiPaint.rounded_rect_points_uniform(rect, radius, CORNER_SEGMENTS)
	UiPaint.fill_gradient_polygon(
		to_canvas_item, outline_points, rect, [[0.0, outline_color], [1.0, outline_color]]
	)

	var frame_rect := rect.grow(-OUTLINE_INSET)
	var frame_radius: float = max(radius - OUTLINE_INSET, 0.0)
	var frame_points := UiPaint.rounded_rect_points_uniform(
		frame_rect, frame_radius, CORNER_SEGMENTS
	)
	_draw_frame(to_canvas_item, frame_points, frame_rect)

	var panel_rect := rect.grow(-frame_thickness)
	if panel_rect.size.x > 0.0 and panel_rect.size.y > 0.0:
		var panel_radius: float = max(radius - frame_thickness, 0.0)
		var panel_points := UiPaint.rounded_rect_points_uniform(
			panel_rect, panel_radius, CORNER_SEGMENTS
		)
		_draw_panel(to_canvas_item, panel_points, panel_rect, panel_radius)

	if has_header_emblem:
		_draw_header_badge(to_canvas_item, rect)


func _effective_corner_radius(rect: Rect2) -> float:
	return min(corner_radius, min(rect.size.x, rect.size.y) * 0.5)


## 真鍮の額縁。CodedButtonStyleの通常状態(hover/pressedなし)と同じグラデーション・
## 面取り・グレインで、ボタンと同じ質感に揃える。highlighted時は明るい2ストップの
## グラデーションへ差し替え、dimmed時はUiPaint.disabled_toneで彩度・明度を落とす。
func _draw_frame(ci: RID, points: PackedVector2Array, rect: Rect2) -> void:
	var stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT],
		[FRAME_HIGHLIGHT_STOP, UiPalette.BRASS_LIGHT],
		[FRAME_MID_STOP, UiPalette.BRASS_MID],
		[FRAME_DARK_STOP, UiPalette.BRASS_DARK],
		[1.0, UiPalette.BRASS_BOUNCE],
	]
	if highlighted:
		stops = [
			[0.0, UiPalette.BRASS_HIGHLIGHT],
			[FRAME_MID_STOP, UiPalette.BRASS_LIGHT],
			[1.0, UiPalette.BRASS_MID]
		]
	if dimmed:
		stops = UiPaint.dim_gradient_stops(stops)

	UiPaint.fill_gradient_polygon(ci, points, rect, stops)

	var light := UiPalette.BRASS_HIGHLIGHT
	var dark := UiPalette.BRASS_DARK
	if dimmed:
		light = UiPaint.disabled_tone(light)
		dark = UiPaint.disabled_tone(dark)
	UiPaint.draw_bevel(ci, points, light, dark, BEVEL_WIDTH_FRAME, false)
	if not dimmed:
		UiPaint.apply_grain(ci, rect, GRAIN_ALPHA_FRAME)


## 中央の凹んだパネル。枠とは逆向き(上が暗く下が明るい)のグラデーションで凹みを表現し、
## 内側の落ち込み影・グレインを重ねる(CodedButtonStyleの通常状態と同じ配色)。dimmed時は
## disabled_toneを適用し、落ち込み影・グレインは省略する(CodedButtonStyleのDISABLEDと同じ)。
## highlightedはここでは扱わない(_draw_frame参照。中央パネルの色は可読性のため変えない)。
func _draw_panel(ci: RID, points: PackedVector2Array, rect: Rect2, shadow_radius: float) -> void:
	var top_color := UiPalette.PANEL_SLATE_TOP
	var bottom_color := UiPalette.PANEL_SLATE_BOTTOM
	if dimmed:
		top_color = UiPaint.disabled_tone(top_color)
		bottom_color = UiPaint.disabled_tone(bottom_color)

	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top_color], [1.0, bottom_color]])
	if not dimmed:
		UiPaint.draw_inner_shadow(
			ci,
			rect,
			shadow_radius,
			CORNER_SEGMENTS,
			INNER_SHADOW_LAYERS,
			Color.BLACK,
			INNER_SHADOW_ALPHA
		)
		UiPaint.apply_grain(ci, rect, GRAIN_ALPHA_PANEL)

	var bevel_light := top_color.lightened(PANEL_LIGHTEN)
	var bevel_dark := bottom_color.darkened(PANEL_DARKEN)
	UiPaint.draw_bevel(ci, points, bevel_light, bevel_dark, BEVEL_WIDTH_PANEL, false)


## 上部中央に、外枠の上端へ半分重なる円形バッジを描き、砂時計紋章を収める。
## detail_panel_bg(砂時計の情報パネル)向けの唯一の識別要素。「このパネルが
## 何の情報を表示するか」を伝えるため、四隅の純粋な装飾とは区別して残す。
func _draw_header_badge(ci: RID, rect: Rect2) -> void:
	var radius: float = clampf(rect.size.x * BADGE_RADIUS_RATIO, BADGE_RADIUS_MIN, BADGE_RADIUS_MAX)
	var center := Vector2(
		rect.position.x + rect.size.x * 0.5, rect.position.y + radius * BADGE_INSET_RATIO
	)
	var badge_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

	var outline_points := UiPaint.rounded_rect_points_uniform(badge_rect, radius, CORNER_SEGMENTS)
	UiPaint.fill_gradient_polygon(
		ci,
		outline_points,
		badge_rect,
		[[0.0, UiPalette.OUTLINE_DARK], [1.0, UiPalette.OUTLINE_DARK]]
	)

	var inner_rect := badge_rect.grow(-BADGE_BEVEL_INSET)
	var inner_radius: float = radius - BADGE_BEVEL_INSET
	var inner_points := UiPaint.rounded_rect_points_uniform(
		inner_rect, inner_radius, CORNER_SEGMENTS
	)
	var stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT],
		[FRAME_MID_STOP, UiPalette.BRASS_MID],
		[1.0, UiPalette.BRASS_DARK]
	]
	UiPaint.fill_gradient_polygon(ci, inner_points, inner_rect, stops)
	UiPaint.draw_bevel(
		ci, inner_points, UiPalette.BRASS_HIGHLIGHT, UiPalette.BRASS_DARK, BEVEL_WIDTH_FRAME, false
	)

	UiPaint.draw_emblem(ci, UiPaint.Emblem.HOURGLASS, center, radius * BADGE_ICON_RATIO)
