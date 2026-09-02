extends Node


func _ready() -> void:
	HourglassArt.ensure_ready(self)
	await get_tree().process_frame
	await get_tree().process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CardDeckSheet.SHEET_SIZE)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var sheet := CardDeckSheet.new()
	viewport.add_child(sheet)
	add_child(viewport)
	await get_tree().process_frame
	sheet.show_deck(CardPresetDecks.basic(), "基本デッキ", "12345678")
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("res://scratchpad/deck_sheet.png")
	print("saved ", image.get_size())
	get_tree().quit()
