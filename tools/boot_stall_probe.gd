extends SceneTree
## 起動シーンから `Main.warm_up()` の完了までの1コマの停止を測る(Architecture.md 4.0.6節)。
## 引き渡しの前(裏読み込み)と後(warm_up)に分けて、最大の1コマと長いコマの数を出す。ゲーム本体は変えない。
## 実行: godot --headless --path . --script res://tools/boot_stall_probe.gd

const TEST_SAVE_PATH := "user://test_boot_stall_ui_state.json"
## これより長いコマを数える(ミリ秒)。
const LONG_FRAME_MSEC := 100.0
const MAX_FRAMES := 100000
const USEC_PER_MSEC := 1000.0

var _boot: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	UiState._save_path = TEST_SAVE_PATH
	_boot = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(_boot)
	current_scene = _boot
	var phases := {"boot": [], "warm_up": []}
	var last := Time.get_ticks_usec()
	for i in MAX_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var main := current_scene
		var handed_over := main != _boot and main != null
		phases["warm_up" if handed_over else "boot"].append((now - last) / USEC_PER_MSEC)
		last = now
		if handed_over and int(main.get("_warm")) == 2:
			break
	for phase: String in phases:
		_report(phase, phases[phase])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	quit()


func _report(phase: String, frames: Array) -> void:
	var total := 0.0
	var worst := 0.0
	var long := 0
	for f: float in frames:
		total += f
		worst = maxf(worst, f)
		if f > LONG_FRAME_MSEC:
			long += 1
	print(
		(
			"%s: %d frames, total %.0f ms, worst frame %.0f ms, frames over %.0f ms: %d"
			% [phase, frames.size(), total, worst, LONG_FRAME_MSEC, long]
		)
	)
