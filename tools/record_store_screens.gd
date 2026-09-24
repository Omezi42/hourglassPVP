extends "res://tools/record_pv.gd"
## 配信ページ(itch.io 等)に載せるスクリーンショット5枚(1280x720)を書き出す。
## PVの台本(record_pv.gd)の画面の組み立てを流用し、テロップを付けずに撮る。
##
## 実行(実際の描画結果を読むため --headless は付けない):
##   godot --path . res://tools/record_store_screens.tscn -- <出力先フォルダ>

## 盤面を撮る前に演出が落ち着くのを待つ秒数。
const SETTLE_SECONDS := 0.8
## 反転を撮るときの時間の流れ(Pitfalls.md「演出のスクリーンショット」)。
const FLIP_TIME_SCALE := 0.2
## 反転を始めてから撮るまでの実時間。
const FLIP_CAPTURE_DELAY := 0.35
const FLIP_ZOOM := 1.4
const ALMANAC_CARD_ID := "tempest"
const DECK_PRESET_ID := "basic"
## 描き終えてから読み出すまでに待つコマ数。
const SETTLE_FRAMES := 3

var _out_dir := ""


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if not args.is_empty() else "user://store_screens"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_setup_match()
	await _shot_title()
	await _shot_board()
	await _shot_flip()
	await _shot_almanac()
	await _shot_deck()
	get_tree().quit()


func _save(name: String) -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(name)
	get_viewport().get_texture().get_image().save_png(path)
	print("SAVED=%s" % path)


func _show_only(screen: Control) -> void:
	for node in [title_screen, match_screen, list_screen]:
		node.visible = node == screen


func _shot_title() -> void:
	_show_only(title_screen)
	await _wait(SETTLE_SECONDS)
	await _save("01_title.png")


## 中盤の盤面。双方に育ち方の違う駒を並べ、手札も持たせる。
func _shot_board() -> void:
	_show_only(match_screen)
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_unit(my, 0, "lock", 5, 2)
	_unit(my, 1, "lance", 2, 5)
	_unit(my, 2, "sand", 4, 3)
	_unit(my, 4, "wall", 6, 1)
	_unit(foe, 1, "drill", 3, 4)
	_unit(foe, 2, "poison", 5, 2)
	_unit(foe, 3, "glass", 1, 4)
	_unit(foe, 5, "sword", 4, 2)
	match_screen.state.hp[my] = 14
	match_screen.state.hp[foe] = 9
	match_screen.state.current_turn = my
	_dress_hand(HAND_IDS)
	match_screen.refresh()
	await _wait(SETTLE_SECONDS)
	await _save("02_board.png")


## 反転の途中。駒に寄り、時間を遅くして傾いた瞬間を撮る。
func _shot_flip() -> void:
	var my := match_screen.my_side
	match_screen.state.current_turn = my
	var view := match_screen.own_slot_view(1)
	_zoom_set_pivot(view.position + view.size * 0.5)
	match_screen.scale = Vector2.ONE * FLIP_ZOOM
	await _wait(SETTLE_SECONDS)
	Engine.time_scale = FLIP_TIME_SCALE
	match_screen._perform(MatchAction.flip(my, 1))
	await get_tree().create_timer(FLIP_CAPTURE_DELAY, true, false, true).timeout
	await _save("03_flip.png")
	Engine.time_scale = 1.0
	match_screen.scale = Vector2.ONE


func _shot_almanac() -> void:
	_show_only(list_screen)
	await get_tree().process_frame
	await get_tree().process_frame
	for view in list_screen._views:
		view.locked = false
		view.queue_redraw()
	list_screen._select(_card(ALMANAC_CARD_ID))
	await _wait(SETTLE_SECONDS)
	await _save("04_almanac.png")


func _shot_deck() -> void:
	_show_only(null)
	var editor := CardDeckEditorScreen.new()
	editor.anchor_right = 1.0
	editor.anchor_bottom = 1.0
	add_child(editor)
	editor._on_preset_picked(DECK_PRESET_ID)
	await _wait(SETTLE_SECONDS)
	await _save("05_deck.png")
