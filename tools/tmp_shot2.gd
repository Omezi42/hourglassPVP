extends SceneTree


func _init() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	await process_frame
	var screen := CardMatchScreen.new()
	screen.anchor_right = 1.0
	screen.anchor_bottom = 1.0
	root.add_child(screen)
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	screen.start_cpu_match(CardPresetDecks.deck_of("basic"), CardDeckSave.random_deck(rng))
	await process_frame
	screen.state.mulligan(MatchState.Side.A, [])
	screen.state.mulligan(MatchState.Side.B, [])
	for i in 4:
		await process_frame
	# 盤面へ駒を置いてから撮る。空の卓では重なり具合が分からないため。
	var deck: Array = screen.state.deck[MatchState.Side.A]
	for i in 4:
		screen.state.board[MatchState.Side.A][i] = CardInstance.new(CardLibrary.find_by_id("sand"))
		screen.state.board[MatchState.Side.B][i] = CardInstance.new(CardLibrary.find_by_id("wall"))
	screen.refresh()
	var detail = screen.get("_detail")
	var hand: Array = screen.get("_hand_views")
	for v in hand:
		if v.visible and v.card != null:
			detail.hover(v)
			break
	for i in 6:
		await process_frame
	var panel = detail.get("_panel")
	print("visible=", panel.visible, " pos=", panel.position, " size=", panel.size)
	root.get_texture().get_image().save_png("scratchpad/shot_match_hand.png")
	var foe: Array = screen.get("_foe_slots")
	detail.hover(foe[3])
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("scratchpad/shot_match_foe.png")
	print("saved")
	quit()
