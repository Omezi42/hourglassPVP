extends SceneTree
## 初めての人がタイトルを押すと、ホームを経ずに誘導対局へ入るか(GameDesign.md 18章)。
## 画面の `_ready()` が起動時にまとめて走るため、ホームを出す前に「ホームを見た」が立つと
## 初回の直行が黙って効かなくなる。`Main` を丸ごと起こすため `tools/check.sh` から起動する。

const TEST_SAVE_PATH := "user://test_first_launch_ui_state.json"
const WAIT_SECONDS := 5.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	UiState._save_path = TEST_SAVE_PATH
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var result := "first launch passed"
	if UiState.has_seen_home():
		result = "first launch FAILED: home marked seen before it was shown"
	else:
		main._on_title_start_requested()
		await create_timer(WAIT_SECONDS).timeout
		if main._active_screen != main.card_match_screen:
			result = "first launch FAILED: title did not lead to the tutorial"
	print(result)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	quit()
