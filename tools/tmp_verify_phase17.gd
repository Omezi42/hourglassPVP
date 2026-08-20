extends SceneTree
## 一時検証スクリプト(フェーズ17)。CPU戦を直接起動し、予約マーク→ターン終了→
## 盤面ズームの解決演出をスクリーンショットで確認する。user:// には一切触れない。
## 確認後にこのファイル自体を削除すること。

const SHOT_DIR := "res://tools/_shots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var screen: MatchScreen = load("res://scenes/match_screen.tscn").instantiate()
	root.add_child(screen)
	screen.size = Vector2(1280, 720)
	await process_frame
	await process_frame

	var ids := ["sand", "sword", "king", "wall", "dash"]
	var board_a: Array[HourglassData] = []
	var bench_a: Array[HourglassData] = []
	var board_b: Array[HourglassData] = []
	var bench_b: Array[HourglassData] = []
	for i in range(3):
		board_a.append(_load(ids[i]))
		board_b.append(_load(ids[2 - i]))
	for i in range(3, 5):
		bench_a.append(_load(ids[i]))
		bench_b.append(_load(ids[i]))

	screen.start_cpu_match(board_a, bench_a, board_b, bench_b)
	await _settle(6)
	await _shot("01_start")

	# 自分の中央マスへ「反転」を設定する(盤面はまだ動かず、予約マークだけが出る)
	screen._on_own_position_pressed(GameState.BoardPosition.CENTER)
	await _settle(3)
	screen._on_flip_pressed()
	await _settle(6)
	await _shot("02_reservation_flip")
	print(
		(
			"pending=%s  center_state=%d"
			% [
				str(screen.state.pending_action),
				screen.state.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state
			]
		)
	)

	Engine.time_scale = 0.25
	screen._on_end_turn_pressed()
	await _settle(40)
	await _shot("03_resolve_zoom_left")
	print("camera scale=%s pos=%s" % [str(screen.board_camera.scale), str(screen.board_camera.position)])
	await _settle(60)
	await _shot("04_resolve_zoom_mid")
	await _settle(120)
	await _shot("05_resolve_later")
	Engine.time_scale = 1.0
	await _settle(120)
	print(
		(
			"after: A center=%d left=%d right=%d turn=%d"
			% [
				screen.state.board[GameState.PlayerSide.A][GameState.BoardPosition.CENTER].state,
				screen.state.board[GameState.PlayerSide.A][GameState.BoardPosition.LEFT].state,
				screen.state.board[GameState.PlayerSide.A][GameState.BoardPosition.RIGHT].state,
				screen.state.current_turn
			]
		)
	)
	await _shot("06_after_turn")
	quit(0)


func _load(id: String) -> HourglassData:
	return load("res://data/hourglasses/%s.tres" % id)


func _settle(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png("%s/%s.png" % [ProjectSettings.globalize_path(SHOT_DIR), name])
