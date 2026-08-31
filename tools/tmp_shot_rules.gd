extends SceneTree


func _initialize() -> void:
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(root_ctrl)
	var tab := RulesTab.new()
	tab.anchor_right = 1.0
	tab.anchor_bottom = 1.0
	tab.offset_bottom = -160.0
	root_ctrl.add_child(tab)
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("scratchpad/rules_tab.png")
	quit()
