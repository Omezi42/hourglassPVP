class_name CardMatchAlert
extends Control
## タイムリミット焦燥演出(GameDesign.md 9章)。
## 持ち時間が残り15秒以下になった際に、画面外周の微細な琥珀〜赤のヴィネットパルスで
## 直感的な緊迫感を演出する。

const ALERT_THRESHOLD := 15.0
const FADE_SPEED := 4.0

var remaining_seconds := -1.0
var is_my_turn := false

var _alert_alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _process(delta: float) -> void:
	var should_alert := (
		remaining_seconds >= 0.0 and remaining_seconds <= ALERT_THRESHOLD and is_my_turn
	)
	var target_alpha := 1.0 if should_alert else 0.0
	_alert_alpha = move_toward(_alert_alpha, target_alpha, delta * FADE_SPEED)
	if _alert_alpha > 0.0 or should_alert:
		queue_redraw()


func _draw() -> void:
	if _alert_alpha <= 0.0:
		return

	var time := Time.get_ticks_msec() * 0.006
	var pulse := (sin(time) + 1.0) * 0.5
	var alpha := _alert_alpha * (0.18 + 0.12 * pulse)

	var glow_color := UiPalette.WARNING_RED.lerp(UiPalette.GLOW_AMBER, pulse * 0.4)
	glow_color.a = alpha

	# 画面外周の警戒ラインとグラデーション帯
	var top_band := Rect2(0, 0, size.x, 16.0)
	var bottom_band := Rect2(0, size.y - 16.0, size.x, 16.0)
	draw_rect(top_band, glow_color)
	draw_rect(bottom_band, glow_color)

	draw_line(Vector2(2, 0), Vector2(2, size.y), glow_color, 4.0)
	draw_line(Vector2(size.x - 2, 0), Vector2(size.x - 2, size.y), glow_color, 4.0)
