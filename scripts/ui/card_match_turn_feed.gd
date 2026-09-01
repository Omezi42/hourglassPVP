class_name CardMatchTurnFeed
extends Control
## 手番の切り替わりと、相手の1手の実況(GameDesign.md 9章)。
##
## **手番はゲームでもっとも頻繁に変わる状態でありながら、押せるボタンの有無からしか
## 読み取れなかった。**また相手(CPU・オンライン)の手は短い間隔で続けて適用されるため、
## 何をされたのかがログを開かないと追えなかった。この2つをまとめて画面へ出す。
##
## **実況の文言は `CardMatchLog` が積んだ行をそのまま使う**(`recorded` を購読する)。
## 自前で組み立てると、読み返したログと画面に出た文が食い違うため。
##
## 盤面の駒より手前へ出す必要があるが、`Control._draw()` は自分の子より背面に描かれる。
## `CardMatchStatus` と同じく独立したオーバーレイのノードとして持つ。

const SCREEN_SIZE := Vector2(1280, 720)
const BANNER_DURATION := 1.1
const BANNER_FONT_SIZE := 44
const CAPTION_DURATION := 1.5
const CAPTION_FONT_SIZE := 19
const CAPTION_RISE := 22.0
const CAPTION_PAD := Vector2(16.0, 9.0)
## 実況を出す高さ。駒に重ねると、何が起きた駒なのかが隠れる。
const CAPTION_GAP := 44.0
## 実況に出す種別。ダメージ(hp)はHPバーの演出が示すため重ねない。
const NARRATED := ["play", "flip", "attack", "time_up"]

var _screen: CardMatchScreen
var _font: Font
var _banner_text := ""
var _banner_left := 0.0
var _caption_text := ""
var _caption_at := Vector2.ZERO
var _caption_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	set_process(false)


## 自分の手番が回ってきた。**自分の番のときだけ出す**(相手の番であることは
## 情報帯の明暗と実況で分かるため、二重に知らせない)。
func announce_turn() -> void:
	_banner_text = "あなたの番"
	_banner_left = BANNER_DURATION
	set_process(true)
	queue_redraw()


## 相手の1手を実況する。`at` は起きた場所(画面の座標)。
func say(text: String, at: Vector2) -> void:
	_caption_text = text
	_caption_at = at
	_caption_left = CAPTION_DURATION
	set_process(true)
	queue_redraw()


func clear() -> void:
	_banner_left = 0.0
	_caption_left = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_banner_left = maxf(_banner_left - delta, 0.0)
	_caption_left = maxf(_caption_left - delta, 0.0)
	if _banner_left <= 0.0 and _caption_left <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _banner_left > 0.0:
		_draw_banner()
	if _caption_left > 0.0:
		_draw_caption()


## 手番のバナー。出てすぐ消えるため、盤面を塞いでいる時間はごく短い。
func _draw_banner() -> void:
	var ratio := _banner_left / BANNER_DURATION
	# 出るときは速く、消えるときは緩く。
	var alpha: float = minf(ratio * 3.0, 1.0) * minf((1.0 - ratio) * 6.0 + 0.2, 1.0)
	var width := (
		_font.get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT_SIZE).x
	)
	var at := Vector2((SCREEN_SIZE.x - width) * 0.5, SCREEN_SIZE.y * 0.5)
	var plate := Rect2(
		Vector2(at.x - 34.0, at.y - BANNER_FONT_SIZE - 6.0),
		Vector2(width + 68.0, BANNER_FONT_SIZE + 26.0)
	)
	_draw_plate(plate, alpha * 0.72)
	draw_string(
		_font,
		at,
		_banner_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		BANNER_FONT_SIZE,
		Color(UiPalette.GLOW_AMBER, alpha)
	)


## 相手の1手の実況。起きた場所の上へ、少し浮かせながら出す。
func _draw_caption() -> void:
	var ratio := _caption_left / CAPTION_DURATION
	var alpha: float = minf(ratio * 5.0, 1.0)
	var rise := (1.0 - ratio) * CAPTION_RISE
	var width := (
		_font.get_string_size(_caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_FONT_SIZE).x
	)
	# **相手の駒は画面の上半分にあるため、その上へ出すと駒の絵に重なる。**
	# 盤面の中央側(下)へ逃がして、何が起きた駒なのかを隠さないようにする。
	var below := _caption_at.y < SCREEN_SIZE.y * 0.5
	# 下へ出すときは、駒の名前とキーワードの行を跨ぐぶんだけ余分に離す。
	var offset := (CAPTION_GAP + (26.0 if below else 0.0)) + rise
	var at := Vector2(_caption_at.x - width * 0.5, _caption_at.y + (offset if below else -offset))
	at.x = clampf(at.x, CAPTION_PAD.x + 8.0, SCREEN_SIZE.x - width - CAPTION_PAD.x - 8.0)
	at.y = clampf(at.y, CAPTION_FONT_SIZE + 16.0, SCREEN_SIZE.y - 16.0)
	var plate := Rect2(
		at - Vector2(CAPTION_PAD.x, CAPTION_FONT_SIZE + CAPTION_PAD.y * 0.5),
		Vector2(width + CAPTION_PAD.x * 2.0, CAPTION_FONT_SIZE + CAPTION_PAD.y * 2.0)
	)
	_draw_plate(plate, alpha * 0.88)
	draw_string(
		_font,
		at,
		_caption_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CAPTION_FONT_SIZE,
		Color(UiPalette.TEXT_OFFWHITE, alpha)
	)


func _draw_plate(rect: Rect2, alpha: float) -> void:
	var ci := get_canvas_item()
	var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 5)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, Color(0.05, 0.05, 0.07, alpha)], [1.0, Color(0.13, 0.11, 0.13, alpha)]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(UiPalette.BRASS_MID, alpha), 1.5, true)


## 対局ログを購読して、**相手の手だけ**を同じ文言で実況する(GameDesign.md 9章)。
## 自分の手は自分で指しているので出さない。配線をここへ置くことで、
## 対局画面は生成して `watch()` を呼ぶだけで済む。
func watch(screen: CardMatchScreen, log: CardMatchLog) -> void:
	_screen = screen
	if not log.recorded.is_connected(_on_recorded):
		log.recorded.connect(_on_recorded)


func _on_recorded(line: String, kind: String, side: int, slot: int) -> void:
	if _screen == null or side < 0 or side == _screen.my_side:
		return
	if not _screen.is_interactive() or not NARRATED.has(kind):
		return
	say(line, _screen.slot_center(side, slot))
