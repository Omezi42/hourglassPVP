extends Control


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	var screen := CardMatchScreen.new()
	screen.anchor_right = 1.0
	screen.anchor_bottom = 1.0
	add_child(screen)
	var deck := CardDeckSave.random_deck()
	var foe := CardDeckSave.random_deck()
	screen.start_cpu_match(deck, foe)
	await get_tree().process_frame
	var st: MatchState = screen.state
	if st.mulligan_pending:
		st.mulligan(MatchState.Side.A, [])
		st.mulligan(MatchState.Side.B, [])
	# 自分の駒を1体置き、召喚酔いを解いて反転できる状態にする
	var card: CardData = load("res://data/cards/sand.tres")
	var unit := CardInstance.new(card)
	unit.summoned_this_turn = false
	unit.drop_sand(2)
	st.board[MatchState.Side.A][2] = unit
	st.current_turn = MatchState.Side.A
	screen.refresh()
	screen.own_slot_view(2).pressed.emit(screen.own_slot_view(2))
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://scratchpad/flip_button.png")
	get_tree().quit()
