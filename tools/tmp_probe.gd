extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._show_only(main.card_list_screen)
	await process_frame
	await process_frame
	for c in main.card_list_screen.get_children():
		print(c.name, " ", c.get_class(), " pos=", c.position, " size=", c.size)
	quit()
