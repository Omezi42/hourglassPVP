extends SceneTree
## フェーズ22: スキルのUI(ActionMenu・交代の対象選択)確認用の一時スクリプト。
## 確認後にこのファイル自体を削除すること。

const SHOTS := "res://tools/tmp_shots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var screen: MatchScreen = load("res://scenes/match_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame

	var by_id: Dictionary = {}
	for card in MatchSetup.all_hourglasses():
		by_id[card.id] = card
	var board: Array[HourglassData] = [by_id["echo"], by_id["dash"], by_id["mirror"]]
	var bench: Array[HourglassData] = [by_id["sword"], by_id["king"]]
	var board_b: Array[HourglassData] = [by_id["sand"], by_id["sand"], by_id["sand"]]
	var bench_b: Array[HourglassData] = [by_id["sand"], by_id["sand"]]
	screen.start_cpu_match(board, bench, board_b, bench_b)
	await process_frame

	# 1) スキルを持たない相手の駒 → 反転のみ
	screen._on_opponent_position_pressed(GameState.BoardPosition.CENTER)
	await _shoot("01_opponent_flip_only")

	# 2) ダッシュ(加速)を選ぶ → 反転 + 加速
	screen._on_own_position_pressed(GameState.BoardPosition.CENTER)
	await _shoot("02_own_dash_skill")

	# 3) エコー(交代)を選ぶ → 反転 + 交代
	screen._on_own_position_pressed(GameState.BoardPosition.LEFT)
	await _shoot("03_own_echo_skill")

	# 4) 交代を押す → 控え2枠がハイライトされる
	screen._on_skill_pressed()
	await _shoot("04_bench_targets")

	# 5) 控えを選ぶ → 予約マークが付く
	screen._on_own_bench_pressed(1)
	await _shoot("05_reserved")

	print("skill=", screen.state.pending_action)
	quit(0)


func _shoot(name: String) -> void:
	for _i in range(20):
		await process_frame
	root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path("%s/%s.png" % [SHOTS, name])
	)
	print("shot ", name)
