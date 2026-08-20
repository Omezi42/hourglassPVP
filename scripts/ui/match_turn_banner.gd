class_name MatchTurnBanner
extends RefCounted
## 手番が自分に回ってきた瞬間、短いバナー(「あなたの番です」)を一瞬流す(P-5)。
## 自視点が固定される対局(オンライン/CPU戦)でのみ使う。ローカル対戦・観戦・リプレイは
## 「自分」が定まらないため対象外(MatchScreen._refresh_turn_label()の視点判定と揃えている)。

const BANNER_TEXT := "あなたの番です"
const HOLD_DURATION := 0.9
const FADE_IN_DURATION := 0.2
const FADE_OUT_DURATION := 0.4
const FONT_SIZE := 30
const TOP_OFFSET := 90.0

var _screen: MatchScreen
## null=未確定(直前の状態が分からないため初回は発火しない)。
var _last_is_my_turn: Variant = null


func _init(screen: MatchScreen) -> void:
	_screen = screen


func reset() -> void:
	_last_is_my_turn = null


## self_locked_viewでない対局(ローカル対戦・観戦・リプレイ)ではバナーを出さない。
func notify_turn(self_locked_view: bool, is_my_turn: bool) -> void:
	if not self_locked_view:
		_last_is_my_turn = null
		return
	if _last_is_my_turn == false and is_my_turn:
		_flash()
	_last_is_my_turn = is_my_turn


func _flash() -> void:
	var label := Label.new()
	label.text = BANNER_TEXT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5, 1))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	_screen.add_child(label)

	var min_size: Vector2 = label.get_minimum_size()
	label.pivot_offset = min_size * 0.5
	label.position = Vector2((_screen.size.x - min_size.x) * 0.5, TOP_OFFSET)
	label.modulate.a = 0.0
	label.scale = Vector2(0.85, 0.85)

	var tween := _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_property(label, "scale", Vector2.ONE, FADE_IN_DURATION)
	tween.chain().tween_interval(HOLD_DURATION)
	tween.chain().tween_property(label, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.chain().tween_callback(label.queue_free)
