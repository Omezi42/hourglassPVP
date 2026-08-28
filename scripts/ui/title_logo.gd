class_name TitleLogo
extends Control
## タイトルロゴのコード描画版(GameDesign.md 9章)。
##
## ロゴは本来「作品の絵そのもの」であり画像アセットとして扱うが、画像の生成は
## ユーザーの手作業で行う運用のため、画像が未配置の間もタイトル画面が成立するように
## 同じ構図をコードで描いておく。画像が置かれた時点でTitleScreenがそちらへ切り替える。
##
## 色はUiPalette、図形はUiPaintを経由する(BoardTable/BarPanelと同じ流儀)。

const TITLE_TEXT := "砂時計アリーナ"
const TITLE_FONT_SIZE := 88
## 文字の縁取り。濃紺で締めることで、背景の絵の上でも輪郭が沈まない。
const OUTLINE_WIDTH := 14
const OUTLINE_COLOR := Color(0.06, 0.09, 0.19, 1.0)
## 金の面。上下でわずかに差を付け、単色のベタ塗りに見えないようにする。
const GOLD_FACE := Color(0.98, 0.89, 0.62, 1.0)
const GOLD_SHADE := Color(0.72, 0.53, 0.2, 1.0)
## 上部に置く砂時計の紋章。
const EMBLEM_SIZE := 58.0
## 題字の下へ通す飾り罫の長さ(ロゴ幅からの相対。中心から左右へこの割合ずつ)。
const RULE_EXTENT := 0.3
const GLOW_RINGS := 5
const GLOW_SEGMENTS := 48


func _draw() -> void:
	var center_x := size.x * 0.5
	_draw_glow(Vector2(center_x, size.y * 0.5))
	UiPaint.draw_emblem(
		get_canvas_item(), UiPaint.Emblem.HOURGLASS, Vector2(center_x, EMBLEM_SIZE), EMBLEM_SIZE
	)
	var font := _font()
	var title_baseline := size.y * 0.68
	draw_string_outline(
		font,
		Vector2(0.0, title_baseline),
		TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		TITLE_FONT_SIZE,
		OUTLINE_WIDTH,
		OUTLINE_COLOR
	)
	# 面と影を1pxずらして重ね、平らな塗りに厚みを持たせる。
	draw_string(
		font,
		Vector2(0.0, title_baseline + 3.0),
		TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		TITLE_FONT_SIZE,
		GOLD_SHADE
	)
	draw_string(
		font,
		Vector2(0.0, title_baseline),
		TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		TITLE_FONT_SIZE,
		GOLD_FACE
	)
	_draw_rule(size.y * 0.79)


## ロゴの背後に敷く柔らかい光。文字が背景の絵から浮くようにする。
func _draw_glow(center: Vector2) -> void:
	var ci := get_canvas_item()
	for i in range(GLOW_RINGS, 0, -1):
		var t := float(i) / float(GLOW_RINGS)
		var radius := Vector2(size.x * 0.5 * t, size.y * 0.42 * t)
		UiPaint.fill_ellipse(ci, center, radius, Color(0.85, 0.62, 0.22, 0.05), GLOW_SEGMENTS)


## 題字の下へ通す飾り罫。左右の端と中央に菱形を置いて締める。
func _draw_rule(y: float) -> void:
	var center_x := size.x * 0.5
	var extent := size.x * RULE_EXTENT
	draw_line(
		Vector2(center_x - extent, y), Vector2(center_x + extent, y), UiPalette.GLOW_AMBER, 2.0
	)
	_draw_diamond(Vector2(center_x, y), 7.0)
	for direction in [-1.0, 1.0]:
		_draw_diamond(Vector2(center_x + extent * direction, y), 5.0)


func _draw_diamond(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array(
		[
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		]
	)
	draw_colored_polygon(points, UiPalette.GLOW_AMBER)


func _font() -> Font:
	var font := get_theme_font("font", "Label")
	if font != null:
		return font
	return ThemeDB.fallback_font
