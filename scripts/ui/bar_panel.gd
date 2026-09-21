class_name BarPanel
extends Control
## 対局画面の上下バー(TopBar/BottomBar)の背景。単色StyleBoxFlat(琥珀枠+半透明黒)が
## チープに見えるという指摘を受け、BoardTable(盤面テーブル)と同じ「無地でもコード描画で
## 質感を出す」方針で作り直した(J-17)。色はUiPalette、多段階グラデーション塗りは
## UiPaint(coded_button_style.gd等と共通のライブラリ)を経由する(フェーズ12 Q-6)。
##
## 対局画面の再構築(GameDesign.md 9章)で、地を濃紺(`NAVY_PANEL_*`)・縁を真鍮へ
## 差し替えた(段階2)。角丸・グレイン・内側の落ち込み影は情報帯(`PlayerInfoBar`)や
## 行動の列と同じ質感の作り(グラデーション+グレイン+ベベル+落ち込み影)に揃える。
##
## 四隅のリベット(鋲)は元々このバー独自の飾りとして存在したが、Architecture.md 4章の
## 「機能を伝えない純粋な飾りは置かない」方針(ボタンの角のネジ・渦巻き意匠を撤去した際に
## 確立した基準)に照らすと、このリベットも「バーが何かを固定されている」以上の意味を
## 伝えない純粋な小物装飾に当たると判断し、撤去した。

const CORNER_RADIUS := 10.0
const CORNER_SEGMENTS := 6
const GRAIN_ALPHA := 0.06
const BRASS_OUTLINE_WIDTH := 1.5
const OUTER_OUTLINE_WIDTH := 1.0
const EDGE_LINE_WIDTH := 1.5
const EDGE_SHADOW_ALPHA_SCALE := 0.35
const INNER_SHADOW_LAYERS := 4
const INNER_SHADOW_ALPHA := 0.35


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER_RADIUS, CORNER_SEGMENTS)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA)
	UiPaint.draw_inner_shadow(
		ci,
		rect,
		CORNER_RADIUS,
		CORNER_SEGMENTS,
		INNER_SHADOW_LAYERS,
		Color(0, 0, 0),
		INNER_SHADOW_ALPHA
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.BRASS_MID, BRASS_OUTLINE_WIDTH, true)
	var outer_rect := rect.grow(OUTER_OUTLINE_WIDTH)
	var outer_points := UiPaint.rounded_rect_points_uniform(
		outer_rect, CORNER_RADIUS + OUTER_OUTLINE_WIDTH, CORNER_SEGMENTS
	)
	var outer_outline := outer_points.duplicate()
	outer_outline.append(outer_points[0])
	draw_polyline(outer_outline, UiPalette.OUTLINE_DARK, OUTER_OUTLINE_WIDTH, true)
	_draw_edge_lines(rect)


## 上下どちらのバーでも自然に見えるよう、上端に明るいハイライト・下端に薄い影を引く
## (TopBarでは上端が画面外側、BottomBarでは下端が画面外側になるが、どちらも
## 「外側寄りの縁をわずかに立体的に見せる」効果として共通に機能する)。
func _draw_edge_lines(rect: Rect2) -> void:
	var highlight := UiPalette.BAR_EDGE_HIGHLIGHT
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), highlight, EDGE_LINE_WIDTH)
	var shadow_color := Color(
		highlight.r, highlight.g, highlight.b, highlight.a * EDGE_SHADOW_ALPHA_SCALE
	)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, shadow_color, EDGE_LINE_WIDTH)
