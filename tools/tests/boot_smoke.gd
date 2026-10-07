extends SceneTree
## 起動シーン(Architecture.md 4.0.6節)の通し確認。タイトルが読み込みを待たずに出ること、
## 読み込み中に押した開始が `Main` へ引き渡された後に効くこと(初めての人は誘導対局へ入る。
## GameDesign.md 18章)を見る。`Main` を丸ごと起こすため `tools/check.sh` から起動する。

const TEST_SAVE_PATH := "user://test_boot_ui_state.json"
const POLL_SECONDS := 0.5
const MAX_POLLS := 400


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	UiState._save_path = TEST_SAVE_PATH
	var boot: Node = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(boot)
	current_scene = boot
	await process_frame
	var result := "boot smoke passed"
	var title: TitleScreen = boot.get_node_or_null("TitleScreen")
	if title == null or not title.visible:
		result = "boot smoke FAILED: title not shown on the first frame"
	else:
		title._begin_start()
		result = "boot smoke FAILED: start pressed while loading never reached the tutorial"
		for i in MAX_POLLS:
			await create_timer(POLL_SECONDS).timeout
			var main := current_scene
			if main != null and main.get("card_match_screen") != null:
				if main.get("_active_screen") == main.get("card_match_screen"):
					result = "boot smoke passed"
					break
	print(result)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	quit()
