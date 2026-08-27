extends SceneTree
## v5.0 対局画面のレイアウト検討用モック(使い捨て)。確認後にこのファイル自体を削除すること。

const OUT := "res://scratchpad/shots/v5_match_mock.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var mock := preload("res://tools/tmp_v5_mock_view.gd").new()
	mock.size = Vector2(1280, 720)
	root.add_child(mock)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://scratchpad/shots")
	root.get_texture().get_image().save_png(OUT)
	print("saved ", OUT)
	quit()
