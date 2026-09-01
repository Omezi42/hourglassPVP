extends SceneTree
## ホーム画面のスクリーンショットを直接撮影するスクリプト

func _init() -> void:
	var home_scene := load("res://scenes/home_screen.tscn")
	var node: Control = home_scene.instantiate()
	root.add_child(node)
	_wait_and_capture(node)


func _wait_and_capture(home: Control) -> void:
	for i in range(10):
		await process_frame

	home.refresh_account()

	for i in range(5):
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	if img != null:
		var save_path := "user://home_screen_capture.png"
		img.save_png(save_path)
		print("Direct HomeScreen Screenshot saved successfully!")
	quit()
