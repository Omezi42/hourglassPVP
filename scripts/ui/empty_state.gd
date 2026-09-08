class_name EmptyState
extends Control
## 一覧に並べるものが無いとき、または待っているときの見せ方(GameDesign.md 12章・19章)。
##
## 「まだ対局履歴がありません」のような案内を1行出すことは以前から仕様にあるが、
## **置き場所が画面ごとに違い、広いパネルの左上に文字が1行だけ残っていた**。
## 空の一覧は壊れた画面と見分けが付かないため、置き場と組み立てをここへ集める。
##
## 出すのは「印 / 見出し / 次にすることの1行」の3つだけとし、
## 情報を足さない(押せるものも置かない——導線はヘッダーの主アクションが既に持つ)。

## 待っている間の巡回ドット。他の画面の待機表示(バトルタブ・ルームマッチ)と同じ間隔にする。
const DOTS_MAX := 3
const DOTS_INTERVAL := 0.5
## `UiPaint.draw_emblem` の `size` は半径にあたり、実際の高さはこの倍率ぶんになる。
const EMBLEM_SIZE := 32.0
const EMBLEM_VISUAL_RATIO := 1.7
const EMBLEM_GAP := 28.0
const TITLE_FONT_SIZE := 21
const HINT_FONT_SIZE := 16
const HINT_GAP := 30.0

var _title := ""
var _hint := ""
var _waiting := false
var _dots := 0
var _elapsed := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	set_process(false)


## `waiting` が真のときだけ見出しの末尾へ巡回ドットが付く(通信を待っている状態)。
func show_message(title: String, hint := "", waiting := false) -> void:
	_title = title
	_hint = hint
	_waiting = waiting
	_dots = 0
	_elapsed = 0.0
	visible = true
	set_process(waiting)
	queue_redraw()


func hide_message() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < DOTS_INTERVAL:
		return
	_elapsed = 0.0
	_dots = (_dots + 1) % (DOTS_MAX + 1)
	queue_redraw()


func _draw() -> void:
	if _font == null or _title.is_empty():
		return
	var emblem_height := EMBLEM_SIZE * EMBLEM_VISUAL_RATIO
	var block := emblem_height + EMBLEM_GAP + TITLE_FONT_SIZE
	if not _hint.is_empty():
		block += HINT_GAP
	var top := (size.y - block) * 0.5
	var center_x := size.x * 0.5

	# 印は砂時計1つだけにする。**空であることを責める画面にしない**ため、
	# 「!」のような警告の記号は使わない。
	UiPaint.draw_emblem(
		get_canvas_item(),
		UiPaint.Emblem.HOURGLASS,
		Vector2(center_x, top + emblem_height * 0.5),
		EMBLEM_SIZE
	)
	var baseline := top + emblem_height + EMBLEM_GAP
	# **巡回ドットは見出しの位置を動かさない**。中央揃えのまま末尾へ足すと、
	# 待っている間ずっと文が左右へ揺れる(バトルタブの印の置き方と同じ考え方)。
	var left := _line(_title, TITLE_FONT_SIZE, baseline, UiPalette.TEXT_OFFWHITE)
	if _waiting and _dots > 0:
		var width := _font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE).x
		draw_string(
			_font,
			Vector2(left + width, baseline),
			".".repeat(_dots),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			TITLE_FONT_SIZE,
			UiPalette.TEXT_OFFWHITE
		)
	if not _hint.is_empty():
		_line(_hint, HINT_FONT_SIZE, baseline + HINT_GAP, UiPalette.TEXT_MUTED)


## 中央へ1行描き、その左端のx座標を返す(巡回ドットを右へ足すために使う)。
func _line(text: String, font_size: int, baseline: float, color: Color) -> float:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := (size.x - width) * 0.5
	draw_string(
		_font, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)
	return left
