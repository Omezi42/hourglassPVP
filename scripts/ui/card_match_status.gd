class_name CardMatchStatus
extends Control
## 対局画面の状態表示(通信待ちの文言と、設置効果の対象選択の案内)。
##
## どちらも盤面の駒より手前へ出す必要があるが、`Control._draw()` は自分の子より
## 背面に描かれるため、対局画面そのものの `_draw()` で描くと卓と駒に隠れる。
## 独立したオーバーレイのノードとして持つ(`CardFlipBeam` と同じ理由)。
## `card_match_screen.gd` が1000行の上限に達しているため切り出した、という事情もある。

const SCREEN_SIZE := Vector2(1280, 720)
## 対象選択の案内。**行動ボタンの列へ出す**(盤面へ重ねると、選ばせたい相手の
## カードそのものを隠してしまう)。
const PROMPT_RECT := Rect2(1108, 240, 148, 52)
const WAITING_FONT_SIZE := 24
## 卓の中央(TABLE_RECT: y=74〜446)へ据える。画面全体の中心(y=360)だと、
## 手札より上の卓の範囲からわずかに外れて見えていた。
const WAITING_PANEL_CENTER := Vector2(640, 260)
## 幅は文言(切断時の理由など、長い文言もある)に合わせて伸ばす。高さは固定。
const WAITING_PANEL_MIN_WIDTH := 340.0
const WAITING_PANEL_HEIGHT := 88.0
const WAITING_PANEL_PAD_X := 56.0
## 通信待ちの「...」演出。他の待機表示(ルームマッチ画面等)と同じ間隔・打ち方に揃える
## (GameDesign.md 9章)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5
## 不具合の報告と突き合わせるためのバージョン表示(GameDesign.md 11章)。
## 行動の列のいちばん下、投了ボタンより下の空きへ小さく出す。
const VERSION_POS := Vector2(1108, 678)
const VERSION_FONT_SIZE := 12

var waiting_text := ""
var targeting := false
var _dot_count := 0
var _dots_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	_dots_timer = Timer.new()
	_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_dots_timer.timeout.connect(_on_dots_timeout)
	add_child(_dots_timer)


func set_waiting(text: String) -> void:
	waiting_text = text
	if text.is_empty():
		_dots_timer.stop()
		_dot_count = 0
	else:
		_dot_count = 0
		_dots_timer.start()
	queue_redraw()


func _on_dots_timeout() -> void:
	_dot_count = (_dot_count % BUSY_DOTS_MAX) + 1
	queue_redraw()


func set_targeting(value: bool) -> void:
	if targeting == value:
		return
	targeting = value
	queue_redraw()


func _draw() -> void:
	draw_string(
		get_theme_default_font(),
		VERSION_POS,
		GameVersion.display(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		VERSION_FONT_SIZE,
		Color(UiPalette.TEXT_OFFWHITE, 0.45)
	)
	if targeting:
		_draw_target_prompt()
	if waiting_text.is_empty():
		return
	_draw_waiting_panel()


## 通信待ちの文言を、他の演出の無い時期(対局の開始前・切断からの復帰・観戦の
## 開始待ち)にも「壊れていない」と分かる形で見せる。以前は素の文字を盤面へ
## 直に浮かせていたため、前の対局の駒が消えないまま重なると
## 「対局が壊れている」ようにしか見えなかった(盤面側は`_reset_for_new_match()`で
## 先に片付けてあるが、それでも文字だけが宙に浮くのは分かりにくい)。
func _draw_waiting_panel() -> void:
	var font := get_theme_default_font()
	var text := waiting_text + ".".repeat(_dot_count)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WAITING_FONT_SIZE)
	var width := maxf(WAITING_PANEL_MIN_WIDTH, text_size.x + WAITING_PANEL_PAD_X)
	var panel_size := Vector2(width, WAITING_PANEL_HEIGHT)
	var rect := Rect2(WAITING_PANEL_CENTER - panel_size * 0.5, panel_size)
	var points := UiPaint.rounded_rect_points_uniform(rect, 14.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.05, 0.07, 0.09, 0.92)], [1.0, Color(0.02, 0.03, 0.04, 0.92)]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(UiPalette.BRASS_MID, 0.9), 2.0, true)
	draw_string(
		font,
		rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.32),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		WAITING_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)


func _draw_target_prompt() -> void:
	var font := get_theme_default_font()
	draw_rect(PROMPT_RECT, Color(0.08, 0.12, 0.14, 0.95))
	draw_rect(PROMPT_RECT, CardView.SELECT_CYAN, false, 2.0)
	draw_string(
		font,
		PROMPT_RECT.position + Vector2(12, 24),
		"対象を選ぶ",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		CardView.SELECT_CYAN
	)
	draw_string(
		font,
		PROMPT_RECT.position + Vector2(12, 44),
		"他を押すと取消",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		UiPalette.TEXT_OFFWHITE
	)
