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
const TITLE_FONT_SIZE := UiPalette.T_LEAD
const HINT_FONT_SIZE := UiPalette.T_BODY
const HINT_GAP := 30.0
## 縦画面では中身ごと拡大して描く(案内の1行が本文24pxに届くように。GameDesign.md 9章「縦画面」)。
const PORTRAIT_ZOOM := 1.5
## 待っている間、印のくびれから砂が落ち続ける(動き続けてよいのは砂だけ。GameDesign.md 9章)。
const SAND_GRAINS := 3
## 1粒がくびれから底へ落ちる秒数。
const SAND_PERIOD := 0.72
## 落ちる距離 = 印の高さ × この比。
const SAND_DROP_RATIO := 0.30
## 粒の半径 = 印の幅 × この比(下限は SAND_MIN_RADIUS)。
const SAND_RADIUS_RATIO := 0.05
const SAND_MIN_RADIUS := 1.25
## 粒ごとの左右のずれ = 印の幅 × この比。
const SAND_SWAY_RATIO := 0.035
const SAND_FADE_IN := 0.15
const SAND_FADE_OUT := 0.25

var _title := ""
var _hint := ""
var _waiting := false
var _dots := 0
var _elapsed := 0.0
var _sand_time := 0.0
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
	_sand_time = 0.0
	visible = true
	set_process(waiting)
	queue_redraw()


func hide_message() -> void:
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_sand_time += delta
		queue_redraw()
	_elapsed += delta
	if _elapsed < DOTS_INTERVAL:
		return
	_elapsed = 0.0
	_dots = (_dots + 1) % (DOTS_MAX + 1)
	queue_redraw()


func _draw() -> void:
	if _font == null or _title.is_empty():
		return
	var zoom := PORTRAIT_ZOOM if ScreenOrientation.is_portrait() else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * zoom)
	var area := size / zoom
	var emblem_height := EMBLEM_SIZE * EMBLEM_VISUAL_RATIO
	var block := emblem_height + EMBLEM_GAP + TITLE_FONT_SIZE
	if not _hint.is_empty():
		block += HINT_GAP
	var top := (area.y - block) * 0.5
	var center_x := area.x * 0.5

	# 印は砂時計1つだけにする。**空であることを責める画面にしない**ため、
	# 「!」のような警告の記号は使わない。
	UiPaint.draw_emblem(
		get_canvas_item(),
		UiPaint.Emblem.HOURGLASS,
		Vector2(center_x, top + emblem_height * 0.5),
		EMBLEM_SIZE
	)
	if _waiting:
		var emblem_rect := Rect2(
			Vector2(center_x, top + emblem_height * 0.5) - Vector2.ONE * emblem_height * 0.5,
			Vector2.ONE * emblem_height
		)
		_draw_falling_sand(emblem_rect, UiPalette.GOLD)
	var baseline := top + emblem_height + EMBLEM_GAP
	# **巡回ドットは見出しの位置を動かさない**。中央揃えのまま末尾へ足すと、
	# 待っている間ずっと文が左右へ揺れる(バトルタブの印の置き方と同じ考え方)。
	var left := _line(_title, TITLE_FONT_SIZE, baseline, UiPalette.IVORY, area.x)
	if _waiting and _dots > 0:
		var width := _font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE).x
		draw_string(
			_font,
			Vector2(left + width, baseline),
			".".repeat(_dots),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			TITLE_FONT_SIZE,
			UiPalette.IVORY
		)
	if not _hint.is_empty():
		_line(_hint, HINT_FONT_SIZE, baseline + HINT_GAP, UiPalette.MUTED, area.x)


## くびれから底へ向かって砂の粒を重力で加速させながら落とす。
func _draw_falling_sand(emblem_rect: Rect2, color: Color) -> void:
	var neck := emblem_rect.get_center()
	var drop := emblem_rect.size.y * SAND_DROP_RATIO
	var radius := maxf(emblem_rect.size.x * SAND_RADIUS_RATIO, SAND_MIN_RADIUS)
	for i in SAND_GRAINS:
		var t := fposmod(_sand_time / SAND_PERIOD + float(i) / SAND_GRAINS, 1.0)
		var sway := (i - 1) * emblem_rect.size.x * SAND_SWAY_RATIO
		var pos := neck + Vector2(sway, drop * t * t)
		var alpha := minf(t / SAND_FADE_IN, (1.0 - t) / SAND_FADE_OUT)
		ShapePaint.circle(
			get_canvas_item(), pos, radius, Color(color, color.a * clampf(alpha, 0.0, 1.0))
		)


## 中央へ1行描き、その左端のx座標を返す(巡回ドットを右へ足すために使う)。
func _line(text: String, font_size: int, baseline: float, color: Color, area_width: float) -> float:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := (area_width - width) * 0.5
	draw_string(
		_font, Vector2(left, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)
	return left
