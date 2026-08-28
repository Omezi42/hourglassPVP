extends SceneTree

const OUT := "user://shots/"

var main: Control


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("saved ", name)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(0.4).timeout
	var which := "all"
	for a in OS.get_cmdline_user_args():
		which = a
	if which in ["all", "a"]:
		await _shot("01_title")
		main._show_only(main.home_screen)
		main.home_screen._select_tab(HomeScreen.TAB_RULES)
		await _shot("02_home_rules")
		main.home_screen._select_tab(HomeScreen.TAB_DECK)
		await _shot("03_home_deck")
		main.home_screen._select_tab(HomeScreen.TAB_BATTLE)
		await _shot("04_home_battle")
	if which in ["all", "b"]:
		main._show_only(main.card_list_screen)
		await _shot("05_card_list")
		main._show_only(main.card_deck_editor_screen)
		main.card_deck_editor_screen.open()
		await _shot("06_deck_editor")
		main._show_only(main.rule_screen)
		main.rule_screen.restart()
		await _shot("07_rule")
		main.rule_screen.show_page(4)
		await _shot("07b_rule_p5")
		main._show_only(main.keyword_dict_screen)
		await _shot("08_keyword_dict")
	if which in ["all", "c"]:
		main._show_only(main.stats_screen)
		main.stats_screen.open()
		await _shot("09_stats")
		main._show_only(main.replay_list_screen)
		await _shot("10_replay_list")
		main._show_only(main.account_screen)
		await _shot("11_account")
	quit()
