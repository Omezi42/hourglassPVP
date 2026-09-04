class_name CodedButtonStyle
extends StyleBox
## 画像シート(ボタン画像)を使わず、コード描画のみで真鍮の額縁+凹んだ中央パネルの
## ボタン外観を再現するStyleBox。元画像(assets/buttons/processed/{グループ}/*.png)の
## 構成を、UiPaint(RID経由描画)とUiPalette(色の単一情報源)を使って再構築する。
## StyleBoxの_draw()はCanvasItemのdraw_*系ではなくRenderingServerのRID経由描画APIしか
## 使えないため、角丸矩形はコーナーごとに円弧点を積んだポリゴンとして自前で構築する
## (BoardTable/BarPanelと同じ「無地でもコード描画で質感を出す」方針)。
##
## グループごとの個性は「形(shape)」と「紋章(emblem)」の2つだけで表現し、質感
## (真鍮のグラデーション・グレイン・ベベル・内側の落ち込み影)は全グループで共通のまま
## 変更しない(「多く使われているデザインと調和させる」という方針のため)。

enum State { NORMAL, HOVER, PRESSED, DISABLED }
enum Shape { ROUNDED_RECT, CIRCLE, PILL, CHEVRON_LEFT }
## 紋章の配置。UPPER=円の上半分(下半分にテキスト)、RIGHT_INSET=右寄せ小さめ、
## TOP_BADGE=上端中央に飛び出す円形徽章の中、CENTER=中央(将来用)。
enum EmblemPlacement { CENTER, UPPER, RIGHT_INSET, TOP_BADGE }

const CORNER_RADIUS := 32.0
## 角丸半径はボタンの高さに対する比率で上限を掛ける(高さの低い小さなボタンで
## 角丸だけが元画像より不自然に大きくならないようにする)
const CORNER_RADIUS_HEIGHT_RATIO := 0.25
const CORNER_SEGMENTS := 8
## 真鍮の額縁の太さ。**固定値ではなくボタンの短辺に比例させる**。小さなボタン
## (帯の「−」「+」など高さ26px)へ大きなボタンと同じ12pxを掛けると、枠だけで
## 面積の半分近くを占めて線が太すぎる印象になるため(`CodedNameplateStyle` と同じ流儀)。
const FRAME_THICKNESS := 12.0
## 短辺に対して単純な比例にすると、小さなボタンでもまだ太い(高さ34pxで7px)。
## 「大きなボタン(高さ56px)で12px / 小さなボタン(高さ34px)で5px」の2点を通る直線として
## 求め、下限で止める。**小さくなるほど急に細くする**のが狙いで、比例では届かない。
const FRAME_REFERENCE_SIZE := 56.0
const FRAME_SMALL_SIZE := 34.0
const FRAME_SMALL_THICKNESS := 5.0
const FRAME_THICKNESS_MIN := 3.0
## 額縁の外側に置く暗い輪郭と面取りも、額縁の太さに合わせて細くする
## (額縁だけ細くすると、今度は輪郭線が目立って同じ印象になる)。
const OUTLINE_WIDTH := 2.0
const OUTLINE_WIDTH_MIN := 1.0

## 真鍮グラデーションのストップ位置。ハイライトは元画像実測で上端のごく細い帯にしか
## 出ていないため、0.0→FRAME_HIGHLIGHT_STOPの区間を狭く取る
const FRAME_HIGHLIGHT_STOP := 0.06
const FRAME_MID_STOP := 0.45
const FRAME_DARK_STOP := 0.85

const GRAIN_ALPHA_FRAME := 0.05
const GRAIN_ALPHA_PANEL := 0.045

const BEVEL_WIDTH_FRAME := 1.5
const BEVEL_WIDTH_PANEL := 1.0
const BEVEL_WIDTH_MIN := 0.75
const INNER_SHADOW_LAYERS := 5
const INNER_SHADOW_ALPHA := 0.4
const INNER_SHADOW_PRESSED_SCALE := 1.6
## 内側の落ち込み影を描かない(角丸半径を一意に決められない形状向け)ことを示す番兵値
const NO_INNER_SHADOW := -1.0

const GLOW_RING_COUNT := 3
const GLOW_RING_STEP := 5.0
const GLOW_BASE_ALPHA := 0.14

const PANEL_PRESSED_SINK := 2.0
const PANEL_LIGHTEN := 0.25
const PANEL_DARKEN := 0.35

## CHEVRON_LEFTの肩(shoulder、尖端から斜辺で繋がる直線区間の終点)のx位置を
## rect幅に対する比率で指定する
const CHEVRON_SHOULDER_RATIO := 0.34

## TOP_BADGE(nav_tab等、上端中央に飛び出す円形徽章)の見た目パラメータ
const TOP_BADGE_RADIUS := 20.0
## 徽章がピル本体の上端へどれだけ重なり込むか(継ぎ目を自然に見せるための重なり量)
const TOP_BADGE_OVERLAP := 10.0
const TOP_BADGE_ICON_RATIO := 0.6
const TOP_BADGE_BEVEL_INSET := 2.5

## 紋章配置ごとのサイズ・位置パラメータ(いずれもボタン矩形に対する比率、
## RIGHT_INSETのみ絶対pxの余白を併用する)
const EMBLEM_CENTER_SIZE_RATIO := 0.42
const EMBLEM_RIGHT_INSET_MARGIN := 26.0
const EMBLEM_RIGHT_INSET_SIZE_RATIO := 0.28

## UPPER配置(円形パネルの上半分に紋章、下半分にテキスト)専用のパラメータ。
## marginはパネル外周(フレーム内側の円弧)とテキスト境界の両方から確保する共通の
## 余白で、パネルの短辺に対する比率。bound_ratioは、UPPERで使われる全紋章
## (HOURGLASS/SWAP_ARROWS/BENCH)の単位図形が原点からどれだけ外側まで広がるかの
## 実測上限(ui_paint.gdの各_*_points参照、最大でBENCHの0.85〜0.9)に安全マージンを
## 足した値で、「利用可能な半径px」を`UiPaint.draw_emblem`のsize引数へ変換する際に使う
## (size * bound_ratio ≒ 図形の外接半径になるよう、常にこの比率で除算する)。
const EMBLEM_UPPER_MARGIN_RATIO := 0.08
const EMBLEM_UPPER_BOUND_RATIO := 0.92
## 逆算した半径がこれを下回るボタンでは紋章を描かない(潰れて見えるくらいなら
## 何も描かない方がまし、という安全弁)
const EMBLEM_UPPER_MIN_HALF_EXTENT := 6.0

@export var variant: State = State.NORMAL
@export var shape: Shape = Shape.ROUNDED_RECT
@export var emblem: UiPaint.Emblem = UiPaint.Emblem.NONE
@export var emblem_placement: EmblemPlacement = EmblemPlacement.CENTER


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var disabled := variant == State.DISABLED
	var hover := variant == State.HOVER
	var pressed := variant == State.PRESSED

	var body_rect := rect
	if _uses_top_badge():
		body_rect = _badge_body_rect(rect)

	if shape == Shape.CHEVRON_LEFT:
		_draw_chevron_layers(to_canvas_item, body_rect, disabled, hover, pressed)
	else:
		_draw_rounded_layers(to_canvas_item, body_rect, disabled, hover, pressed)

	if emblem != UiPaint.Emblem.NONE:
		_draw_emblem_layer(to_canvas_item, rect, body_rect, disabled)


func _uses_top_badge() -> bool:
	return (
		shape == Shape.PILL
		and emblem_placement == EmblemPlacement.TOP_BADGE
		and emblem != UiPaint.Emblem.NONE
	)


## PILL+TOP_BADGE時、ピル本体が占める矩形(上端を徽章の分だけ空ける)を返す。
func _badge_body_rect(rect: Rect2) -> Rect2:
	var top_inset: float = TOP_BADGE_RADIUS * 2.0 - TOP_BADGE_OVERLAP
	return Rect2(rect.position.x, rect.position.y + top_inset, rect.size.x, rect.size.y - top_inset)


## ROUNDED_RECT/CIRCLE/PILL共通の描画(角丸ポリゴン+額縁+パネル)。
func _draw_rounded_layers(ci: RID, rect: Rect2, disabled: bool, hover: bool, pressed: bool) -> void:
	var radii := _corner_radii(rect)

	if hover:
		_draw_hover_glow(ci, rect, radii)

	var outline_color := UiPalette.OUTLINE_DARK
	if disabled:
		outline_color = UiPaint.disabled_tone(outline_color)
	var outline_points := UiPaint.rounded_rect_points(
		rect, radii[0], radii[1], radii[2], radii[3], CORNER_SEGMENTS
	)
	UiPaint.fill_gradient_polygon(
		ci, outline_points, rect, [[0.0, outline_color], [1.0, outline_color]]
	)

	var thickness := _frame_thickness(rect)
	var outline := _outline_width(thickness)
	var frame_rect := rect.grow(-outline)
	var frame_radii := _shrink_radii(radii, outline)
	var frame_points := UiPaint.rounded_rect_points(
		frame_rect, frame_radii[0], frame_radii[1], frame_radii[2], frame_radii[3], CORNER_SEGMENTS
	)
	_draw_frame(ci, frame_points, frame_rect, disabled, pressed, thickness)

	var panel_rect := rect.grow(-thickness)
	if pressed:
		panel_rect.position.y += PANEL_PRESSED_SINK
		panel_rect.size.y -= PANEL_PRESSED_SINK
	var panel_radii := _shrink_radii(radii, thickness)
	var panel_points := UiPaint.rounded_rect_points(
		panel_rect, panel_radii[0], panel_radii[1], panel_radii[2], panel_radii[3], CORNER_SEGMENTS
	)
	_draw_panel(ci, panel_points, panel_rect, disabled, hover, pressed, panel_radii[0], thickness)


## CHEVRON_LEFT(back_nav、左向き矢印型)専用の描画。角丸ポリゴンではなく
## UiPaint.chevron_left_pointsで生成した五角形の点列を使う点だけが異なり、
## 額縁・パネルの塗り自体は_draw_frame/_draw_panelを共用する。
func _draw_chevron_layers(ci: RID, rect: Rect2, disabled: bool, hover: bool, pressed: bool) -> void:
	var base_radius := _effective_corner_radius(rect)

	var outline_points := UiPaint.chevron_left_points(
		rect, base_radius, CORNER_SEGMENTS, CHEVRON_SHOULDER_RATIO
	)
	if hover:
		_draw_hover_glow_chevron(ci, rect, base_radius)

	var outline_color := UiPalette.OUTLINE_DARK
	if disabled:
		outline_color = UiPaint.disabled_tone(outline_color)
	UiPaint.fill_gradient_polygon(
		ci, outline_points, rect, [[0.0, outline_color], [1.0, outline_color]]
	)

	var thickness := _frame_thickness(rect)
	var outline := _outline_width(thickness)
	var frame_rect := rect.grow(-outline)
	var frame_radius: float = maxf(base_radius - outline, 0.0)
	var frame_points := UiPaint.chevron_left_points(
		frame_rect, frame_radius, CORNER_SEGMENTS, CHEVRON_SHOULDER_RATIO
	)
	_draw_frame(ci, frame_points, frame_rect, disabled, pressed, thickness)

	var panel_rect := rect.grow(-thickness)
	if pressed:
		panel_rect.position.y += PANEL_PRESSED_SINK
		panel_rect.size.y -= PANEL_PRESSED_SINK
	var panel_radius: float = maxf(base_radius - thickness, 0.0)
	var panel_points := UiPaint.chevron_left_points(
		panel_rect, panel_radius, CORNER_SEGMENTS, CHEVRON_SHOULDER_RATIO
	)
	_draw_panel(ci, panel_points, panel_rect, disabled, hover, pressed, NO_INNER_SHADOW, thickness)


## 形状(角丸/円/ピル)に応じた4隅[左上, 右上, 右下, 左下]の半径を返す。
func _corner_radii(rect: Rect2) -> PackedFloat32Array:
	match shape:
		Shape.CIRCLE:
			var r: float = min(rect.size.x, rect.size.y) * 0.5
			return PackedFloat32Array([r, r, r, r])
		Shape.PILL:
			var r: float = rect.size.y * 0.5
			return PackedFloat32Array([r, r, r, r])
		_:
			var radius := _effective_corner_radius(rect)
			return PackedFloat32Array([radius, radius, radius, radius])


func _effective_corner_radius(rect: Rect2) -> float:
	return min(CORNER_RADIUS, rect.size.y * CORNER_RADIUS_HEIGHT_RATIO)


## 額縁の太さ。短辺に比例させ、既定の大きさ(高さ56px前後)ではこれまでどおり
## FRAME_THICKNESS になるよう比率を選んである。
static func frame_thickness(rect: Rect2) -> float:
	var short_side: float = min(rect.size.x, rect.size.y)
	var thickness := remap(
		short_side, FRAME_SMALL_SIZE, FRAME_REFERENCE_SIZE, FRAME_SMALL_THICKNESS, FRAME_THICKNESS
	)
	return clampf(thickness, FRAME_THICKNESS_MIN, FRAME_THICKNESS)


## **ボタンの中身を描いてよい範囲**(額縁の内側の、暗く凹んだパネル)。
## 紋章や透かしをボタンの矩形いっぱいに描くと**額縁へ載り上がってはみ出す**。
## 内側の矩形を各所で計算し直すと必ずどこかがずれるため、ここが唯一の出どころになる。
static func inner_rect(rect: Rect2) -> Rect2:
	return rect.grow(-frame_thickness(rect))


func _frame_thickness(rect: Rect2) -> float:
	return frame_thickness(rect)


## 暗い輪郭の太さ。額縁と同じ比率で細くする。
func _outline_width(frame: float) -> float:
	return maxf(OUTLINE_WIDTH * frame / FRAME_THICKNESS, OUTLINE_WIDTH_MIN)


func _bevel_width(base: float, frame: float) -> float:
	return maxf(base * frame / FRAME_THICKNESS, BEVEL_WIDTH_MIN)


static func _shrink_radii(radii: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for r in radii:
		result.append(max(r - amount, 0.0))
	return result


## 真鍮の額縁。実測(assets/buttons/processed/wide_text/normal.png)に基づく、彩度低めの
## 「褪せた真鍮」グラデーションで金属らしさを出し、面取り・グレインを重ねる。
## pointsは呼び出し側(角丸/CHEVRON)で生成済みの外周点列を渡す。
func _draw_frame(
	ci: RID,
	points: PackedVector2Array,
	rect: Rect2,
	disabled: bool,
	pressed: bool,
	thickness: float = FRAME_THICKNESS
) -> void:
	var stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT],
		[FRAME_HIGHLIGHT_STOP, UiPalette.BRASS_LIGHT],
		[FRAME_MID_STOP, UiPalette.BRASS_MID],
		[FRAME_DARK_STOP, UiPalette.BRASS_DARK],
		[1.0, UiPalette.BRASS_BOUNCE],
	]
	if pressed:
		stops = [
			[0.0, UiPalette.BRASS_DARK],
			[FRAME_MID_STOP, UiPalette.BRASS_PRESSED_MID],
			[FRAME_DARK_STOP, UiPalette.BRASS_PRESSED_DARK],
			[1.0, UiPalette.BRASS_PRESSED_MID],
		]
	if disabled:
		stops = UiPaint.dim_gradient_stops(stops)

	UiPaint.fill_gradient_polygon(ci, points, rect, stops)

	var light := UiPalette.BRASS_HIGHLIGHT
	var dark := UiPalette.BRASS_DARK
	if disabled:
		light = UiPaint.disabled_tone(light)
		dark = UiPaint.disabled_tone(dark)
	UiPaint.draw_bevel(ci, points, light, dark, _bevel_width(BEVEL_WIDTH_FRAME, thickness), pressed)

	if not disabled:
		UiPaint.apply_grain(ci, rect, GRAIN_ALPHA_FRAME)


## 中央の凹んだパネル。枠とは逆向き(上が暗く下が明るい)のグラデーションで凹みを表現し、
## 内側の落ち込み影・グレインを重ねる。押下時は実測(pressed.png)に基づく「暗いスレート」
## 程度に留め、黒つぶれさせない。shadow_radiusにNO_INNER_SHADOWを渡すと落ち込み影を省略する
## (CHEVRON_LEFTのように一意な角丸半径を持たない形状向け)。
func _draw_panel(
	ci: RID,
	points: PackedVector2Array,
	rect: Rect2,
	disabled: bool,
	hover: bool,
	pressed: bool,
	shadow_radius: float,
	thickness: float = FRAME_THICKNESS
) -> void:
	var top_color := UiPalette.PANEL_SLATE_TOP
	var bottom_color := UiPalette.PANEL_SLATE_BOTTOM
	if hover:
		top_color = UiPalette.PANEL_AMBER_TOP
		bottom_color = UiPalette.PANEL_AMBER_BOTTOM
	elif pressed:
		top_color = UiPalette.PANEL_PRESSED_TOP
		bottom_color = UiPalette.PANEL_PRESSED_BOTTOM
	if disabled:
		top_color = UiPaint.disabled_tone(top_color)
		bottom_color = UiPaint.disabled_tone(bottom_color)

	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top_color], [1.0, bottom_color]])

	if not disabled:
		if shadow_radius >= 0.0:
			var shadow_alpha := INNER_SHADOW_ALPHA
			if pressed:
				shadow_alpha *= INNER_SHADOW_PRESSED_SCALE
			UiPaint.draw_inner_shadow(
				ci,
				rect,
				shadow_radius,
				CORNER_SEGMENTS,
				INNER_SHADOW_LAYERS,
				Color.BLACK,
				shadow_alpha
			)
		UiPaint.apply_grain(ci, rect, GRAIN_ALPHA_PANEL)

	var bevel_light := top_color.lightened(PANEL_LIGHTEN)
	var bevel_dark := bottom_color.darkened(PANEL_DARKEN)
	UiPaint.draw_bevel(
		ci, points, bevel_light, bevel_dark, _bevel_width(BEVEL_WIDTH_PANEL, thickness), pressed
	)


## ホバー時、外周へ広がる淡い琥珀のグロー(複数リング、外側ほど薄い)を描く(角丸/円/ピル用)。
func _draw_hover_glow(ci: RID, rect: Rect2, radii: PackedFloat32Array) -> void:
	for i in range(GLOW_RING_COUNT):
		var grow_amount: float = float(i + 1) * GLOW_RING_STEP
		var glow_rect: Rect2 = rect.grow(grow_amount)
		var glow_radii := PackedFloat32Array()
		for r in radii:
			glow_radii.append(r + grow_amount)
		var alpha: float = GLOW_BASE_ALPHA * (1.0 - float(i) / float(GLOW_RING_COUNT))
		var color := Color(
			UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, alpha
		)
		var points := UiPaint.rounded_rect_points(
			glow_rect, glow_radii[0], glow_radii[1], glow_radii[2], glow_radii[3], CORNER_SEGMENTS
		)
		UiPaint.fill_gradient_polygon(ci, points, glow_rect, [[0.0, color], [1.0, color]])


## ホバー時のグロー(CHEVRON_LEFT用)。半径がスカラー1個な点だけがrounded版と異なる。
func _draw_hover_glow_chevron(ci: RID, rect: Rect2, base_radius: float) -> void:
	for i in range(GLOW_RING_COUNT):
		var grow_amount: float = float(i + 1) * GLOW_RING_STEP
		var glow_rect: Rect2 = rect.grow(grow_amount)
		var glow_radius: float = base_radius + grow_amount
		var alpha: float = GLOW_BASE_ALPHA * (1.0 - float(i) / float(GLOW_RING_COUNT))
		var color := Color(
			UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, alpha
		)
		var points := UiPaint.chevron_left_points(
			glow_rect, glow_radius, CORNER_SEGMENTS, CHEVRON_SHOULDER_RATIO
		)
		UiPaint.fill_gradient_polygon(ci, points, glow_rect, [[0.0, color], [1.0, color]])


## 紋章(emblem)の配置を振り分けて描く。outer_rectはStyleBoxへ渡された全体矩形、
## body_rectはTOP_BADGE時に上端を空けた本体矩形(それ以外はouter_rectと同じ)。
func _draw_emblem_layer(ci: RID, outer_rect: Rect2, body_rect: Rect2, disabled: bool) -> void:
	match emblem_placement:
		EmblemPlacement.UPPER:
			_draw_emblem_upper(ci, outer_rect, body_rect)
		EmblemPlacement.RIGHT_INSET:
			var size: float = body_rect.size.y * EMBLEM_RIGHT_INSET_SIZE_RATIO
			var center := Vector2(
				body_rect.end.x - EMBLEM_RIGHT_INSET_MARGIN - size,
				body_rect.position.y + body_rect.size.y * 0.5
			)
			UiPaint.draw_emblem(ci, emblem, center, size)
		EmblemPlacement.TOP_BADGE:
			_draw_top_badge(ci, outer_rect, body_rect, disabled)
		_:
			var center := body_rect.position + body_rect.size * 0.5
			var size: float = min(body_rect.size.x, body_rect.size.y) * EMBLEM_CENTER_SIZE_RATIO
			UiPaint.draw_emblem(ci, emblem, center, size)


## UPPER配置: 紋章をボタン矩形全体ではなく、内側の凹んだパネル(枠を除いた領域)を
## 基準に、パネルの外周にもテキスト領域(content_margin_top)にも触れない大きさへ
## 逆算して描く。パネルが真円になる形状(CIRCLE)では、紋章の外接四角形の角が
## パネルの円弧の内側に収まる最大サイズを幾何学的に解く。それ以外の形状では
## 円弧の制約を使わず、矩形の余白だけで単純に収める(現状UPPERはCIRCLEでのみ使うため
## 保守的なフォールバックで十分)。
func _draw_emblem_upper(ci: RID, outer_rect: Rect2, body_rect: Rect2) -> void:
	var thickness := _frame_thickness(body_rect)
	var panel_rect := body_rect.grow(-thickness)
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		return

	var margin: float = min(panel_rect.size.x, panel_rect.size.y) * EMBLEM_UPPER_MARGIN_RATIO
	var text_bound: float = panel_rect.end.y
	if content_margin_top > 0.0:
		text_bound = outer_rect.position.y + content_margin_top

	var panel_center := panel_rect.position + panel_rect.size * 0.5
	var half_extent: float

	var panel_radius := 0.0
	if shape == Shape.CIRCLE:
		panel_radius = maxf(_corner_radii(body_rect)[0] - thickness, 0.0)

	if panel_radius > margin:
		# 紋章の外接正方形(半径he)の角が、パネル中心から見て常に一番遠い点になる。
		# その角をパネル中心からeffective_radius以内へ収める条件
		# he^2 + (k + 2*he)^2 <= effective_radius^2 (k = panel_center.y - text_bound + margin、
		# center_yをtext_bound側へ寄せてheを最大化する形で解いている)を、heについての
		# 二次不等式として解いた根の上限
		var effective_radius: float = panel_radius - margin
		var k: float = panel_center.y - text_bound + margin
		var discriminant: float = 5.0 * effective_radius * effective_radius - k * k
		if discriminant <= 0.0:
			return
		half_extent = (-2.0 * k + sqrt(discriminant)) / 5.0
	else:
		var avail_w: float = panel_rect.size.x - margin * 2.0
		var avail_h: float = (text_bound - margin) - (panel_rect.position.y + margin)
		half_extent = min(avail_w, avail_h) * 0.5

	if half_extent < EMBLEM_UPPER_MIN_HALF_EXTENT:
		return

	var size: float = half_extent / EMBLEM_UPPER_BOUND_RATIO
	var center_y: float = (text_bound - margin) - half_extent
	UiPaint.draw_emblem(ci, emblem, Vector2(panel_center.x, center_y), size)


## PILL本体の上端中央に飛び出す円形徽章(真鍮の縁取り+紋章)を描く。
func _draw_top_badge(ci: RID, outer_rect: Rect2, body_rect: Rect2, disabled: bool) -> void:
	var center := Vector2(
		outer_rect.position.x + outer_rect.size.x * 0.5,
		body_rect.position.y + TOP_BADGE_OVERLAP * 0.5
	)
	var badge_rect := Rect2(
		center - Vector2.ONE * TOP_BADGE_RADIUS, Vector2.ONE * TOP_BADGE_RADIUS * 2.0
	)
	var outline_points := UiPaint.rounded_rect_points_uniform(
		badge_rect, TOP_BADGE_RADIUS, CORNER_SEGMENTS
	)
	var outline_color := UiPalette.OUTLINE_DARK
	if disabled:
		outline_color = UiPaint.disabled_tone(outline_color)
	UiPaint.fill_gradient_polygon(
		ci, outline_points, badge_rect, [[0.0, outline_color], [1.0, outline_color]]
	)

	var inner_rect := badge_rect.grow(-TOP_BADGE_BEVEL_INSET)
	var inner_radius: float = TOP_BADGE_RADIUS - TOP_BADGE_BEVEL_INSET
	var inner_points := UiPaint.rounded_rect_points_uniform(
		inner_rect, inner_radius, CORNER_SEGMENTS
	)
	var stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT],
		[FRAME_MID_STOP, UiPalette.BRASS_MID],
		[1.0, UiPalette.BRASS_DARK]
	]
	if disabled:
		stops = UiPaint.dim_gradient_stops(stops)
	UiPaint.fill_gradient_polygon(ci, inner_points, inner_rect, stops)
	var light := UiPalette.BRASS_HIGHLIGHT
	var dark := UiPalette.BRASS_DARK
	if disabled:
		light = UiPaint.disabled_tone(light)
		dark = UiPaint.disabled_tone(dark)
	UiPaint.draw_bevel(ci, inner_points, light, dark, BEVEL_WIDTH_FRAME, false)

	UiPaint.draw_emblem(ci, emblem, center, TOP_BADGE_RADIUS * TOP_BADGE_ICON_RATIO)
