class_name CodedNameplateStyle
extends StyleBox
## 名札(デッキ名・砂時計名)の背景。画像(shelf_nameplate.png)を使わず、CodedButtonStyle/
## CodedPanelStyleと同じ質感(真鍮グラデーション・面取り・グレイン)で描くStyleBox
## (フェーズ12 Q-4)。左右の端を中央へ向けて欠き込んだ「タグ札」の六角形シルエット
## (UiPaint.banner_points、back_navボタンのchevron_left_pointsと同じ「尖端+肩」の考え方)
## にし、画像にあった留め具は、BarPanelの四隅リベットと同じ意匠で左右に1個ずつ残す
## (「プレートが固定されている」ことを伝える機能的な要素のため、CodedPanelStyleで
## 四隅の砂時計意匠を「純粋な飾り」として省いた判断基準とは区別している)。
##
## 中央の凹み(テキストを乗せる面)は、他のCodedスタイルが使うスレート系(PANEL_SLATE_*)
## ではなく、木材・真鍮と揃う暖色の焦げ茶(NAMEPLATE_PANEL_*)にしている。
##
## 名札はコンテナの都合で横幅だけが大きく伸びる使われ方をする(DeckListCardでは
## LeftColumnのEXPAND_FILLにより数百pxまで伸びる)。尖端の欠き込み幅・リベットの
## 位置をrect幅に比例させると、伸びるほど尖端が不自然に長く/リベットが中央寄りに
## 流れてしまうため、いずれも高さ基準の絶対pxで決める(元画像の9-slice運用が
## 「両端は一定幅を保ち、中央だけが伸びる」ようにしていたのと同じ考え方)。

const CORNER_SEGMENTS := 8
const OUTLINE_INSET := 2.0

const FRAME_THICKNESS_RATIO := 0.18
const FRAME_THICKNESS_MIN := 3.0
const FRAME_THICKNESS_MAX := 10.0

const NOTCH_HEIGHT_RATIO := 0.6
const NOTCH_MIN := 10.0
const NOTCH_MAX := 34.0

const FRAME_HIGHLIGHT_STOP := 0.06
const FRAME_MID_STOP := 0.45
const FRAME_DARK_STOP := 0.85

const GRAIN_ALPHA_FRAME := 0.05
const GRAIN_ALPHA_PANEL := 0.04
const BEVEL_WIDTH_FRAME := 1.3
const BEVEL_WIDTH_PANEL := 1.0
const PANEL_LIGHTEN := 0.2
const PANEL_DARKEN := 0.3

const RIVET_RADIUS_RATIO := 0.09
const RIVET_MARGIN_BEYOND_NOTCH := 6.0
const RIVET_HEAD_RATIO := 0.62
const RIVET_SEGMENTS := 10


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var notch := _notch(rect)
	var outline_points := UiPaint.banner_points(rect, notch)
	UiPaint.fill_gradient_polygon(
		to_canvas_item,
		outline_points,
		rect,
		[[0.0, UiPalette.OUTLINE_DARK], [1.0, UiPalette.OUTLINE_DARK]]
	)

	var frame_rect := rect.grow(-OUTLINE_INSET)
	var frame_points := UiPaint.banner_points(frame_rect, notch)
	_draw_frame(to_canvas_item, frame_points, frame_rect)

	var thickness := _frame_thickness(rect)
	var panel_rect := rect.grow(-thickness)
	if panel_rect.size.x > 0.0 and panel_rect.size.y > 0.0:
		var panel_points := UiPaint.banner_points(panel_rect, notch)
		_draw_panel(to_canvas_item, panel_points, panel_rect)

	_draw_rivets(to_canvas_item, rect, notch)


func _frame_thickness(rect: Rect2) -> float:
	return clampf(rect.size.y * FRAME_THICKNESS_RATIO, FRAME_THICKNESS_MIN, FRAME_THICKNESS_MAX)


func _notch(rect: Rect2) -> float:
	return clampf(rect.size.y * NOTCH_HEIGHT_RATIO, NOTCH_MIN, NOTCH_MAX)


## 真鍮の額縁。CodedButtonStyle/CodedPanelStyleの通常状態と同じグラデーション・
## 面取り・グレインで揃える。
func _draw_frame(ci: RID, points: PackedVector2Array, rect: Rect2) -> void:
	var stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT],
		[FRAME_HIGHLIGHT_STOP, UiPalette.BRASS_LIGHT],
		[FRAME_MID_STOP, UiPalette.BRASS_MID],
		[FRAME_DARK_STOP, UiPalette.BRASS_DARK],
		[1.0, UiPalette.BRASS_BOUNCE],
	]
	UiPaint.fill_gradient_polygon(ci, points, rect, stops)
	UiPaint.draw_bevel(
		ci, points, UiPalette.BRASS_HIGHLIGHT, UiPalette.BRASS_DARK, BEVEL_WIDTH_FRAME, false
	)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA_FRAME)


## 中央の凹んだテキスト面。木材・真鍮と揃う暖色の焦げ茶で塗り、内側の落ち込みを
## 面取りで表現する(CodedPanelStyleの落ち込み影レイヤーは、名札程度の薄さでは
## 潰れて見えなくなるため使わず、面取りのみに留める)。
func _draw_panel(ci: RID, points: PackedVector2Array, rect: Rect2) -> void:
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, UiPalette.NAMEPLATE_PANEL_TOP], [1.0, UiPalette.NAMEPLATE_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA_PANEL)
	var bevel_light := UiPalette.NAMEPLATE_PANEL_TOP.lightened(PANEL_LIGHTEN)
	var bevel_dark := UiPalette.NAMEPLATE_PANEL_BOTTOM.darkened(PANEL_DARKEN)
	UiPaint.draw_bevel(ci, points, bevel_light, bevel_dark, BEVEL_WIDTH_PANEL, false)


## BarPanelの四隅リベットと同じ「小さな鋲」を、六角形の肩の内側(欠き込みより
## 少し内側)に1個ずつ置く。暗い縁取り+真鍮の頭の2層で、沈んだ金属鋲に見せる。
func _draw_rivets(ci: RID, rect: Rect2, notch: float) -> void:
	var radius: float = rect.size.y * RIVET_RADIUS_RATIO
	var inset: float = notch + radius + RIVET_MARGIN_BEYOND_NOTCH
	var y: float = rect.position.y + rect.size.y * 0.5
	_draw_rivet(ci, Vector2(rect.position.x + inset, y), radius)
	_draw_rivet(ci, Vector2(rect.end.x - inset, y), radius)


func _draw_rivet(ci: RID, center: Vector2, radius: float) -> void:
	UiPaint.fill_circle(ci, center, radius, UiPalette.OUTLINE_DARK, RIVET_SEGMENTS)
	UiPaint.fill_circle(ci, center, radius * RIVET_HEAD_RATIO, UiPalette.BRASS_MID, RIVET_SEGMENTS)
