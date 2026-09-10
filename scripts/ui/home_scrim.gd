class_name HomeScrim
extends Control
## ホーム画面で、背景の絵の上へ敷く帯と幕(GameDesign.md 9章)。
##
## **背景の絵は奥にあるものとして扱い、中身の乗る帯は落とす。**絵の上へ直に札や文字を
## 並べると、背景の明暗によって同じ札が読めたり読めなかったりする(たたかうタブの
## バトル背景は砂の渦が明るく、そこへ枠が重なると縁が溶けた)。
##
## **落としすぎない**のも条件で、絵が見えなくなると背景を持つ意味そのものが消える。
## 「絵が見えていて、その上の文字も読める」ところで止める。
##
## 帯は2つ。上=アカウント帯、中=タブの中身。**上の帯は中より濃くする**——そこに乗るのは
## 真鍮の小さな部品(名札・残高)で、枠のような大きな面を持たないため、地が明るいと
## 輪郭が背景へ紛れる。
##
## **下部タブには帯を敷かない。**タブのボタンは自分で額縁と面を持っており、その下へ
## 黒い半透明を重ねると、背景の絵が最下段だけ塗り潰されて画面が下で切れて見える
## (ユーザー判断)。

## アカウント帯の高さと、タブの中身が終わる位置。各タブの `TOP_BAND` / `BOTTOM` と同じ値。
const TOP_BAND := 112.0
const NAV_TOP := 560.0
## アカウント帯の下端へ通す真鍮の細線。**ここだけ線を引く**のは、上の帯と中身の境目が
## いちばん近く(名札の下すぐに枠の見出しが来る)、色の差だけでは切れ目が読めないため。
const RULE_HEIGHT := 2.0

const HEADER_STOPS := [
	[0.0, Color(0.05, 0.04, 0.04, 0.86)],
	[1.0, Color(0.09, 0.07, 0.06, 0.72)],
]
## 中は上下より薄い。**枠(`HomeFrame`)が自分の面を持つ**ため、ここまで濃くする必要がない。
const CONTENT_STOPS := [
	[0.0, Color(0.05, 0.04, 0.06, 0.58)],
	[0.5, Color(0.05, 0.04, 0.06, 0.46)],
	[1.0, Color(0.05, 0.04, 0.06, 0.58)],
]


static func make() -> HomeScrim:
	var scrim := HomeScrim.new()
	# **`set_anchors_preset()` は使わない。**生成直後(サイズ0)へ掛けると
	# 「いまの矩形を保つように」offset を計算し直し、0サイズのまま固定される
	# (Architecture.md 11章)。
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return scrim


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	_band(ci, Rect2(0.0, 0.0, size.x, TOP_BAND), HEADER_STOPS)
	_band(ci, Rect2(0.0, TOP_BAND, size.x, NAV_TOP - TOP_BAND), CONTENT_STOPS)
	# 真鍮の細線は中央が濃く、左右の端へ向かって消す(端まで一様に引くと帯が1本
	# 乗ったように見える。`ScreenHeader` の暗幕と同じ考え方)。
	var line_y: float = TOP_BAND - RULE_HEIGHT
	var half: float = size.x * 0.5
	_line_half(ci, Rect2(0.0, line_y, half, RULE_HEIGHT), false)
	_line_half(ci, Rect2(half, line_y, half, RULE_HEIGHT), true)


func _band(ci: RID, rect: Rect2, stops: Array) -> void:
	if rect.size.y <= 0.0:
		return
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	UiPaint.fill_gradient_polygon(ci, points, rect, stops)


## 細線の半分。`fill_gradient_polygon()` は縦方向の位置で色を決めるため、
## 横方向のグラデーションはここで頂点の色を直に置いて作る。
func _line_half(ci: RID, rect: Rect2, fade_out: bool) -> void:
	var solid := Color(UiPalette.BRASS_HIGHLIGHT, 0.62)
	var clear := Color(UiPalette.BRASS_HIGHLIGHT, 0.0)
	var left := clear if not fade_out else solid
	var right := solid if not fade_out else clear
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	RenderingServer.canvas_item_add_polygon(
		ci, points, PackedColorArray([left, right, right, left])
	)
