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
const SUBTITLE_TEXT := "HOURGLASS ARENA"
const TITLE_FONT_SIZE := 88
const SUBTITLE_FONT_SIZE := 30
## 文字の縁取り。濃紺で締めることで、背景の絵の上でも輪郭が沈まない。
const OUTLINE_WIDTH := 14
const OUTLINE_COLOR := Color(0.06, 0.09, 0.19, 1.0)
## 金の面。上下でわずかに差を付け、単色のベタ塗りに見えないようにする。
const GOLD_FACE := Color(0.98, 0.89, 0.62, 1.0)
const GOLD_SHADE := Color(0.72, 0.53, 0.2, 1.0)
const SUBTITLE_COLOR := Color(0.96, 0.93, 0.86, 1.0)
## 上部に置く砂時計の紋章。
const EMBLEM_SIZE := 58.0
## 左右へ伸びる飾り罫の長さ(サブタイトルの幅からの相対)。
const RULE_EXTENT := 0.34
const GLOW_RINGS := 5
const GLOW_SEGMENTS := 48


func _draw() -> void:
	var center_x := size.x * 0.5
	_draw_glow(Vector2(center_x, size.y * 0.5))
	UiPaint.draw_emblem(
		get_canvas_item(), UiPaint.Emblem.HOURGLASS, Vector2(center_x, EMBLEM_SIZE), EMBLEM_SIZE
	)
	var font := _font()
	var title_baseline := size.y * 0.62
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
	var sub_baseline := size.y * 0.9
	_draw_rules(sub_baseline - SUBTITLE_FONT_SIZE * 0.34)
	draw_string_outline(
		font,
		Vector2(0.0, sub_baseline),
		SUBTITLE_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		SUBTITLE_FONT_SIZE,
		6,
		OUTLINE_COLOR
	)
	draw_string(
		font,
		Vector2(0.0, sub_baseline),
		SUBTITLE_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		SUBTITLE_FONT_SIZE,
		SUBTITLE_COLOR
	)


## ロゴの背後に敷く柔らかい光。文字が背景の絵から浮くようにする。
func _draw_glow(center: Vector2) -> void:
	var ci := get_canvas_item()
	for i in range(GLOW_RINGS, 0, -1):
		var t := float(i) / float(GLOW_RINGS)
		var radius := Vector2(size.x * 0.5 * t, size.y * 0.42 * t)
		UiPaint.fill_ellipse(ci, center, radius, Color(0.85, 0.62, 0.22, 0.05), GLOW_SEGMENTS)


## サブタイトルの左右へ伸びる飾り罫。中央から外へ細くなる線と、その先の菱形。
func _draw_rules(y: float) -> void:
	var center_x := size.x * 0.5
	var inner := size.x * 0.19
	var outer := size.x * RULE_EXTENT
	for direction in [-1.0, 1.0]:
		var from := Vector2(center_x + inner * direction, y)
		var to := Vector2(center_x + outer * direction, y)
		draw_line(from, to, UiPalette.GLOW_AMBER, 2.0)
		var tip := to + Vector2(10.0 * direction, 0.0)
		var diamond := PackedVector2Array(
			[
				to + Vector2(0.0, -5.0),
				tip,
				to + Vector2(0.0, 5.0),
				to + Vector2(-6.0 * direction, 0.0),
			]
		)
		draw_colored_polygon(diamond, UiPalette.GLOW_AMBER)


func _font() -> Font:
	var font := get_theme_font("font", "Label")
	if font != null:
		return font
	return ThemeDB.fallback_font
