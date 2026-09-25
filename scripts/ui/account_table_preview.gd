class_name AccountTablePreview
extends Control
## アカウント画面の「対局ではこう見えます」(GameDesign.md 14章)。
## 選んでいるプレイマットの上に、対局と同じ `PlayerInfoBar` を置く。
## 見本専用の名札を描くと実物と形が食い違うため、本物をそのまま使う。

const BUMP_SCALE := 1.04
const BUMP_DURATION := 0.16
const FRAME_INSET := 8.0
const BAR_MARGIN := Vector2(14, 12)
## 右の群(マナ・山札)が見本の外へ押し出される幅。左の群(肖像・名札・HP)だけを見せる。
const BAR_WIDTH := 1200.0
const FRAME_WIDTH := 1.5

var mat_id := PlaymatLibrary.DEFAULT_ID
var _bar: PlayerInfoBar
var _bump_tween: Tween


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = PlayerInfoBar.new()
	add_child(_bar)
	# 帯は自分の `_ready()` で STOP に戻すため、足した後に塞ぐ(見本は押しても何も起きない)。
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout()


func show_profile(
	display_name: String, icon_id: String, title_id: String, p_mat_id: String
) -> void:
	_bar.display_name = display_name.strip_edges()
	_bar.icon_id = icon_id
	_bar.title_id = title_id
	mat_id = p_mat_id
	_bar.queue_redraw()
	queue_redraw()


## 選んだ瞬間の合図(GameDesign.md 9章)。帯だけを軽く跳ねさせる。
func bump() -> void:
	if _bump_tween != null and _bump_tween.is_valid():
		_bump_tween.kill()
	_bar.scale = Vector2.ONE
	_bump_tween = create_tween()
	(
		_bump_tween
		. tween_property(_bar, "scale", Vector2.ONE * BUMP_SCALE, BUMP_DURATION * 0.4)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_bump_tween
		. tween_property(_bar, "scale", Vector2.ONE, BUMP_DURATION * 0.6)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)


func _layout() -> void:
	if _bar == null:
		return
	_bar.size = Vector2(BAR_WIDTH, PlayerInfoBar.BAR_HEIGHT)
	_bar.position = Vector2(BAR_MARGIN.x, size.y - PlayerInfoBar.BAR_HEIGHT - BAR_MARGIN.y)
	_bar.pivot_offset = PlayerInfoBar.PORTRAIT_CENTER


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UiPalette.BOARD_TABLE_FILL)
	PlaymatPaint.draw_mat(self, rect.grow(-FRAME_INSET), mat_id)
	draw_rect(rect, UiPalette.BRASS_DARK, false, FRAME_WIDTH)
