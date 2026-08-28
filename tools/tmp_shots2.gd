extends SceneTree

const OUT := "user://shots/"

var main: Control


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", name)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(0.4).timeout
	main._show_only(main.card_match_screen)
	main.card_match_screen.start_cpu_match(
		CardPresetDecks.deck_of("basic"), CardPresetDecks.deck_of("rush")
	)
	await create_timer(0.6).timeout
	await _shot("20_mulligan")
	main.card_match_screen.state.mulligan(0, [])
	main.card_match_screen.state.mulligan(1, [])
	await create_timer(0.8).timeout
	await _shot("21_match_start")
	for i in 10:
		await create_timer(1.0).timeout
	await _shot("22_match_mid")
	quit()
