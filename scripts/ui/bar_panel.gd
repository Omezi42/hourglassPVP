class_name BarPanel
extends Control
## 対局画面の上下バー(TopBar/BottomBar)の背景。単色StyleBoxFlat(琥珀枠+半透明黒)が
## チープに見えるという指摘を受け、BoardTable(盤面テーブル)と同じ「無地でもコード描画で
## 質感を出す」方針で作り直した(J-17)。色はUiPalette、多段階グラデーション塗りは
## UiPaint(coded_button_style.gd等と共通のライブラリ)を経由する(フェーズ12 Q-6)。
##
## 四隅のリベット(鋲)は元々このバー独自の飾りとして存在したが、Architecture.md 4章の
## 「機能を伝えない純粋な飾りは置かない」方針(ボタンの角のネジ・渦巻き意匠を撤去した際に
## 確立した基準)に照らすと、このリベットも「バーが何かを固定されている」以上の意味を
## 伝えない純粋な小物装飾に当たると判断し、撤去した。

const BORDER_WIDTH := 2.0
const EDGE_LINE_WIDTH := 1.5
const EDGE_SHADOW_ALPHA_SCALE := 0.35
## バーの縁取り(枠線)は他のコード描画UIと共通のGLOW_AMBERを使う。
const BORDER_ALPHA := 0.9


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_draw_gradient_fill(rect)
	var border_color := Color(
		UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, BORDER_ALPHA
	)
	draw_rect(rect, border_color, false, BORDER_WIDTH)
	_draw_edge_lines(rect)


## 上端をわずかに明るく・下端をわずかに暗くし、フラットな一色塗りより厚みのある質感にする。
func _draw_gradient_fill(rect: Rect2) -> void:
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, UiPalette.BAR_FILL_TOP], [1.0, UiPalette.BAR_FILL_BOTTOM]]
	)


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
