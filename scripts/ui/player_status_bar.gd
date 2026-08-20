class_name PlayerStatusBar
extends HBoxContainer

## 1プレイヤー分のHP・持ち時間の表示のみを担当する。どちらの視点かは MatchScreen が決める。
## HPバーの色は相手/自分の区別ではなく、HP残量から決める(残量表現としての赤を優先するため)。

const HP_TWEEN_DURATION := 0.4
const FLASH_COLOR := Color(1.7, 1.3, 1.3)
const FLASH_IN_DURATION := 0.06
const FLASH_OUT_DURATION := 0.3

## HP残量の割合がこの値を超えていれば安全圏(琥珀)、以下なら警告色以下へ移行する。
const HP_RATIO_WARNING_THRESHOLD := 0.5
## HP残量の割合がこの値以下になったら危険圏(赤)とする。
const HP_RATIO_DANGER_THRESHOLD := 0.25

const COLOR_HP_SAFE := Color(0.9, 0.68, 0.26, 1)
const COLOR_HP_WARNING := Color(0.92, 0.55, 0.16, 1)
const COLOR_HP_DANGER := Color(0.85, 0.2, 0.18, 1)

var _hp_tween: Tween
var _fill_stylebox: StyleBoxFlat

@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_value: Label = $HPValue
@onready var clock_label: Label = $ClockLabel


func _ready() -> void:
	hp_bar.max_value = GameState.INITIAL_HP
	# バーごとに独立したStyleBoxにしておかないと、色のTweenが他インスタンスへ波及してしまう
	_fill_stylebox = hp_bar.get_theme_stylebox("fill").duplicate()
	_fill_stylebox.bg_color = COLOR_HP_SAFE
	hp_bar.add_theme_stylebox_override("fill", _fill_stylebox)


## 表示名は、どちらの視点かを知っている MatchScreen 側から与える。
func setup(display_name: String) -> void:
	name_label.text = display_name


## HPは瞬時に切り替えず、バーを滑らかに減らして被弾の重さを伝える。バーの色もHP残量に応じて
## 同じ速さで補間する。リプレイの巻き戻しなど、演出が邪魔になる場面は animate=false で即座に反映する。
func show_hp(hp: int, animate: bool = true) -> void:
	hp_value.text = "%d/%d" % [hp, GameState.INITIAL_HP]
	var target_color := _color_for_hp(hp)

	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()

	if not animate:
		hp_bar.value = hp
		_fill_stylebox.bg_color = target_color
		return

	if (
		is_equal_approx(hp_bar.value, float(hp))
		and _fill_stylebox.bg_color.is_equal_approx(target_color)
	):
		return

	_hp_tween = create_tween()
	_hp_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hp_tween.set_parallel(true)
	_hp_tween.tween_property(hp_bar, "value", float(hp), HP_TWEEN_DURATION)
	_hp_tween.tween_property(_fill_stylebox, "bg_color", target_color, HP_TWEEN_DURATION)


func _color_for_hp(hp: int) -> Color:
	var ratio := float(hp) / float(GameState.INITIAL_HP)
	if ratio > HP_RATIO_WARNING_THRESHOLD:
		return COLOR_HP_SAFE
	if ratio > HP_RATIO_DANGER_THRESHOLD:
		return COLOR_HP_WARNING
	return COLOR_HP_DANGER


func flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(hp_bar, "modulate", FLASH_COLOR, FLASH_IN_DURATION)
	tween.tween_property(hp_bar, "modulate", Color.WHITE, FLASH_OUT_DURATION)


func show_clock(remaining_seconds: float) -> void:
	clock_label.text = _format_seconds(remaining_seconds)


## CPU戦は持ち時間を消費しないため、止まったままの時計を出さないよう非表示にする。
func set_clock_visible(clock_visible: bool) -> void:
	clock_label.visible = clock_visible


func _format_seconds(seconds: float) -> String:
	var whole := int(ceil(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]
