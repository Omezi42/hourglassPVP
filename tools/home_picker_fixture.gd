class_name HomePickerFixture
extends Control
## ホームのソロモードの選択モーダルを撮るための台(`tools/capture_screen_layout.gd` から使う)。
## `SoloProgress.reset_for_test()` で保存を止め、今週の遠征の札の状態(new / running / done)を再現する。
##   godot --path . res://tools/capture_screen_layout.tscn -- <出力先> <portrait|landscape> \
##     'HomePickerFixture|stage|"running"'

const HOME_SCENE := "res://scenes/home_screen.tscn"
const RUNNING_FLOOR := 2
const RUNNING_HP := 17
const DONE_WINS := 3
const DONE_HP := 11

var _home: HomeScreen
var _portrait := false


func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _home != null:
		_home.apply_orientation(portrait)


func open() -> void:
	SoloProgress.reset_for_test()
	_home = load(HOME_SCENE).instantiate()
	_home.anchor_right = 1.0
	_home.anchor_bottom = 1.0
	add_child(_home)
	_home.apply_orientation(_portrait)


func stage(state: String) -> void:
	var week := WeeklyExpedition.current_week()
	var run := WeeklyExpedition.create_run(week)
	if state == "running":
		run.floor = RUNNING_FLOOR
		run.hp = RUNNING_HP
		SoloProgress.save_run("", run)
	elif state == "done":
		run.wins = DONE_WINS
		run.hp = DONE_HP
		run.over = true
		SoloProgress.end_weekly_run("", run, "", false)
	_home.battle_tab.refresh()
	_home.battle_tab._open_picker(false)
