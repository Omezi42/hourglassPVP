extends SceneTree

func _initialize() -> void:
	var screen := CardMatchScreen.new()
	root.add_child(screen)
	screen.size = Vector2(1280, 720)
	
	# _readyが実行されるのを待つ
	await process_frame
	await process_frame
	
	screen.start_cpu_match(CardPresetDecks.basic(), CardPresetDecks.basic())
	if screen._mulligan != null:
		screen._mulligan.close()
	
	# 時計を強制的に有効化し、残り12秒に設定
	screen.clocks.clock = MatchClock.new()
	screen.clocks.clock.remaining[screen.my_side] = 12.0
	screen.clocks.clock.remaining[screen.state.other_side(screen.my_side)] = 45.0
	screen.clocks.refresh_bars()
	
	# 演出の更新を進める
	for i in 25:
		screen._process(0.016)
		await process_frame
	
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("tools/screenshot_time_alert.png")
	print("Screenshot saved to tools/screenshot_time_alert.png")
	quit()
