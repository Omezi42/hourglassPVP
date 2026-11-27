class_name CardMatchStatus
extends Control
## 対局画面の状態表示(通信待ちの文言と、設置効果の対象選択の案内)。
##
## どちらも盤面の駒より手前へ出す必要があるが、`Control._draw()` は自分の子より
## 背面に描かれるため、対局画面そのものの `_draw()` で描くと卓と駒に隠れる。
## 独立したオーバーレイのノードとして持つ(`CardFlipBeam` と同じ理由)。
## `card_match_screen.gd` が1000行の上限に達しているため切り出した、という事情もある。

## 対象選択の案内は行動のボタンの脇へ出す(盤面へ重ねると、選ばせたい相手の
## カードそのものを隠してしまう)。位置は `CardMatchLayout.prompt_rect`。
const WAITING_FONT_SIZE := 24
## 通信待ちの札は卓の中央(`CardMatchLayout.waiting_center`)へ据える。
## 幅は文言(切断時の理由など、長い文言もある)に合わせて伸ばす。高さは固定。
const WAITING_PANEL_MIN_WIDTH := 340.0
const WAITING_PANEL_HEIGHT := 88.0
const WAITING_PANEL_PAD_X := 56.0
## 通信待ちの「...」演出。他の待機表示(ルームマッチ画面等)と同じ間隔・打ち方に揃える
## (GameDesign.md 9章)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5
## 不具合の報告と突き合わせるためのバージョン表示(GameDesign.md 11章)。位置は `CardMatchLayout.version_position`。
const VERSION_FONT_SIZE := 12

var waiting_text := ""
var targeting := false
## 反転を封じられている間(ジェイラー。GameDesign.md 9章)。押せない理由を、対象選択の案内と同じ席へ出す。
var jailed := false
var _dot_count := 0
var _dots_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func set_jailed(value: bool) -> void:
	if jailed == value:
		return
	jailed = value
	queue_redraw()


func _draw() -> void:
	draw_string(
		get_theme_default_font(),
		CardMatchLayout.current().version_position,
		GameVersion.display(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		VERSION_FONT_SIZE,
		Color(UiPalette.IVORY, 0.45)
	)
	if targeting:
		_draw_target_prompt()
	elif jailed:
		_draw_jail_note()
	if waiting_text.is_empty():
		return
	_draw_waiting_panel()


## 通信待ちの文言を、他の演出の無い時期(対局の開始前・切断からの復帰)にも
## 「壊れていない」と分かる硝子の札に載せて見せる。
func _draw_waiting_panel() -> void:
	var font := get_theme_default_font()
	var text := waiting_text + ".".repeat(_dot_count)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WAITING_FONT_SIZE)
	var width := maxf(WAITING_PANEL_MIN_WIDTH, text_size.x + WAITING_PANEL_PAD_X)
	var panel_size := Vector2(width, WAITING_PANEL_HEIGHT)
	var rect := Rect2(CardMatchLayout.current().waiting_center - panel_size * 0.5, panel_size)
	UiKit.glass(get_canvas_item(), rect)
	draw_string(
		font,
		rect.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.32),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		WAITING_FONT_SIZE,
		UiPalette.IVORY
	)


## 反転できない理由。対象選択の案内と同じ札の形で、左の見出しと下の補足の2行。
func _draw_jail_note() -> void:
	_draw_note("反転できない", "ジェイラーの封じ", UiPalette.FOE)


func _draw_target_prompt() -> void:
	_draw_note("対象を選ぶ", "他を押すと取消", UiPalette.SELECT)


func _draw_note(head: String, sub: String, accent: Color) -> void:
	var font := get_theme_default_font()
	# 縦では案内ごと拡大する(`prompt_rect` は拡大後の大きさ)。中身は横の大きさで描いて縮尺を掛ける。
	var shown := CardMatchLayout.current().prompt_rect
	var zoom := CardMatchLayout.current().text_scale
	draw_set_transform(shown.position, 0.0, Vector2.ONE * zoom)
	var prompt := Rect2(Vector2.ZERO, shown.size / zoom)
	UiKit.glass(get_canvas_item(), prompt, -1.0, 1.0, UiKit.GLASS_ALPHA, UiKit.rim_color(accent))
	draw_string(
		font,
		prompt.position + Vector2(12, 24),
		head,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiPalette.T_LEAD,
		accent
	)
	draw_string(
		font,
		prompt.position + Vector2(12, 44),
		sub,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UiPalette.T_SMALL,
		UiPalette.IVORY
	)
	draw_set_transform_matrix(Transform2D.IDENTITY)
