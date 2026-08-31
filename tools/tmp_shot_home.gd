extends SceneTree


func _initialize() -> void:
	SoundBank.ensure_ready(root)
	var scene: PackedScene = load("res://scenes/home_screen.tscn")
	var home: Control = scene.instantiate()
	home.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(home)
	await process_frame
	home.call("_select_tab", 0)
	for i in 12:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("scratchpad/home_rules.png")
	quit()
