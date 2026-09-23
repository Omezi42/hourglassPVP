class_name TitleLogo
extends Control
## タイトルロゴのコード描画版(GameDesign.md 9章)。
##
## ロゴは本来「作品の絵そのもの」であり画像アセットとして扱うが、画像の生成は
## ユーザーの手作業で行う運用のため、画像が未配置の間もタイトル画面が成立するように
## 同じ構図をコードで描いておく。画像が置かれた時点でTitleScreenがそちらへ切り替える。
##
## **紋章・題字・飾り罫はすべて同じ金箔と濃紺の縁で描く**(部品ごとに色が違うと
## ひとつのロゴに見えない)。この節点が縁と落ち影を、子の`FoilLayer`が金箔の面を描く。

const TITLE_TEXT := "砂時計アリーナ"
const TITLE_FONT_SIZE := 96
const TITLE_BASELINE := 222.0
## 題字の金箔を掛ける帯(字面の上端〜下端)。
const TITLE_FOIL_TOP := 140.0
const TITLE_FOIL_BOTTOM := 230.0
## 縁取り。濃紺で締めることで、背景の絵の上でも輪郭が沈まない。
const OUTLINE_WIDTH := 16
const OUTLINE_COLOR := Color(0.06, 0.09, 0.19, 1.0)
## 縁の下へ敷く落ち影(紙から浮いた箔押しに見せる)。
const DROP_SHADOW_OFFSET := Vector2(0.0, 4.0)
const DROP_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.45)

const EMBLEM_CENTER_Y := 64.0
const EMBLEM_HALF := 50.0
const EMBLEM_OUTLINE := 6.0
## 紋章の縁を敷く向きの数(取り込みアイコンの輪郭を全周へずらして太らせる)。
const EMBLEM_OUTLINE_STEPS := 16
const EMBLEM_ICON := preload("res://assets/ui/icons/hourglass.png")

const RULE_Y := 262.0
## 飾り罫の長さ(中心から左右へ)。
const RULE_EXTENT := 260.0
const RULE_WIDTH := 2.5
const RULE_OUTLINE_WIDTH := 7.0
const RULE_CENTER_DIAMOND := 7.0
const RULE_END_DIAMOND := 5.0
## 菱形の縁(面の菱形より半径をこれだけ大きく取る)。
const DIAMOND_OUTLINE := 4.0
const RULE_FOIL_TOP := 250.0
const RULE_FOIL_BOTTOM := 274.0

var _font: Font


func _ready() -> void:
	_font = UiFonts.display_font(_theme_font())
	add_child(FoilLayer.new(_draw_emblem_face, _emblem_rect().position.y, _emblem_rect().end.y))
	add_child(FoilLayer.new(_draw_title_face, TITLE_FOIL_TOP, TITLE_FOIL_BOTTOM))
	add_child(FoilLayer.new(_draw_rule_face, RULE_FOIL_TOP, RULE_FOIL_BOTTOM))


func _draw() -> void:
	var rect := _emblem_rect()
	for i in EMBLEM_OUTLINE_STEPS:
		var offset := Vector2.RIGHT.rotated(TAU * i / EMBLEM_OUTLINE_STEPS) * EMBLEM_OUTLINE
		draw_texture_rect(
			EMBLEM_ICON, Rect2(rect.position + offset, rect.size), false, OUTLINE_COLOR
		)
	for layer in [[DROP_SHADOW_OFFSET, DROP_SHADOW_COLOR], [Vector2.ZERO, OUTLINE_COLOR]]:
		draw_string_outline(
			_font,
			Vector2(0.0, TITLE_BASELINE) + layer[0],
			TITLE_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			TITLE_FONT_SIZE,
			OUTLINE_WIDTH,
			layer[1]
		)
	_draw_rule(self, RULE_OUTLINE_WIDTH, DIAMOND_OUTLINE, OUTLINE_COLOR)


func _draw_emblem_face(layer: CanvasItem) -> void:
	layer.draw_texture_rect(EMBLEM_ICON, _emblem_rect(), false, Color.WHITE)


func _draw_title_face(layer: CanvasItem) -> void:
	layer.draw_string(
		_font,
		Vector2(0.0, TITLE_BASELINE),
		TITLE_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		TITLE_FONT_SIZE,
		Color.WHITE
	)


func _draw_rule_face(layer: CanvasItem) -> void:
	_draw_rule(layer, RULE_WIDTH, 0.0, Color.WHITE)


## 題字の下へ通す飾り罫。左右の端と中央に菱形を置いて締める。縁と面で太さだけを変えて2回描く。
func _draw_rule(layer: CanvasItem, width: float, diamond_grow: float, color: Color) -> void:
	var center_x := size.x * 0.5
	layer.draw_line(
		Vector2(center_x - RULE_EXTENT, RULE_Y),
		Vector2(center_x + RULE_EXTENT, RULE_Y),
		color,
		width
	)
	_draw_diamond(layer, Vector2(center_x, RULE_Y), RULE_CENTER_DIAMOND + diamond_grow, color)
	for direction in [-1.0, 1.0]:
		var end := Vector2(center_x + RULE_EXTENT * direction, RULE_Y)
		_draw_diamond(layer, end, RULE_END_DIAMOND + diamond_grow, color)


func _draw_diamond(layer: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array(
		[
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		]
	)
	layer.draw_colored_polygon(points, color)


func _emblem_rect() -> Rect2:
	var center := Vector2(size.x * 0.5, EMBLEM_CENTER_Y)
	return Rect2(
		center - Vector2(EMBLEM_HALF, EMBLEM_HALF), Vector2(EMBLEM_HALF, EMBLEM_HALF) * 2.0
	)


func _theme_font() -> Font:
	var base := get_theme_font("font", "Label")
	if base == null:
		base = ThemeDB.fallback_font
	return base
