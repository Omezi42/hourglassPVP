class_name MatchDamagePresenter
extends RefCounted
## 被弾の演出(HPバーの発光・画面フラッシュ・浮遊ダメージ数字)を担う。MatchScreenの
## _on_hp_changed(直接操作によるダメージ)とMatchTurnResolver(ターン進行の逐次演出)
## の両方から呼ばれるため、責務分離のため専用クラスへ切り出している。

const DAMAGE_FLASH_ALPHA := 0.28
const DAMAGE_FLASH_IN_DURATION := 0.07
const DAMAGE_FLASH_OUT_DURATION := 0.35
## 発生源が特定できない(sourceがnull)場合は、HPバー付近から上へ浮かせるだけの
## フォールバック演出にする。
const FLOATING_DAMAGE_FLIGHT_DURATION := 0.75
const FLOATING_DAMAGE_FALLBACK_RISE_DISTANCE := 36.0
const FLOATING_DAMAGE_FALLBACK_RISE_DURATION := 0.8
const FLOATING_DAMAGE_FADE_DELAY := 0.2
const FLOATING_DAMAGE_FADE_DURATION := 0.8

var _screen: MatchScreen


func _init(screen: MatchScreen) -> void:
	_screen = screen


## 被弾の手応えを出す。HPバーを光らせ、自分が受けた場合はさらに画面全体を赤く明滅させる。
func play_damage_feedback(side: GameState.PlayerSide) -> void:
	SoundBank.play(SoundBank.Sfx.DAMAGE)
	var is_self: bool = side == _screen.perspective_side()
	var bar: PlayerStatusBar = _screen.own_status if is_self else _screen.opponent_status
	bar.flash_damage()
	if not is_self:
		return

	var tween := _screen.create_tween()
	tween.tween_property(
		_screen.damage_flash, "color:a", DAMAGE_FLASH_ALPHA, DAMAGE_FLASH_IN_DURATION
	)
	tween.tween_property(_screen.damage_flash, "color:a", 0.0, DAMAGE_FLASH_OUT_DURATION)


## originに発生源の駒(source != null)が分かる場合は、その駒の位置からHPバーへ向けて
## 飛んでいく演出にする。分からない場合はHPバー付近から上へ浮かせて消すだけにする。
func spawn_floating_damage(side: GameState.PlayerSide, amount: int, source: Variant) -> void:
	var is_own_row: bool = side == _screen.perspective_side()
	var bar: ProgressBar = (
		_screen.own_status.hp_bar if is_own_row else _screen.opponent_status.hp_bar
	)
	var bar_position: Vector2 = bar.global_position + Vector2(bar.size.x * 0.5 - 12, -4)

	var source_rect := Rect2()
	if source != null:
		source_rect = _screen.game_board.get_board_slot_rect(
			_screen.perspective_side(), source["side"], source["position"]
		)

	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_screen.add_child(label)

	var tween := _screen.create_tween()
	if source_rect.size == Vector2.ZERO:
		label.global_position = bar_position
		tween.set_parallel(true)
		tween.tween_property(
			label,
			"position:y",
			label.position.y - FLOATING_DAMAGE_FALLBACK_RISE_DISTANCE,
			FLOATING_DAMAGE_FALLBACK_RISE_DURATION
		)
		tween.tween_property(label, "modulate:a", 0.0, FLOATING_DAMAGE_FADE_DURATION).set_delay(
			FLOATING_DAMAGE_FADE_DELAY
		)
	else:
		label.global_position = source_rect.get_center()
		tween.set_parallel(true)
		(
			tween
			. tween_property(
				label, "global_position", bar_position, FLOATING_DAMAGE_FLIGHT_DURATION
			)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
		tween.tween_property(label, "modulate:a", 0.0, FLOATING_DAMAGE_FLIGHT_DURATION).set_delay(
			FLOATING_DAMAGE_FADE_DELAY
		)
	tween.chain().tween_callback(label.queue_free)
