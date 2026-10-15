extends "res://tools/record_pv.gd"
## 対局画面を横(1280x720)と縦(720x1280)の両方で撮る(Architecture.md 4.7節)。中盤の盤面を
## SubViewport の中で組み、縦は `ScreenOrientation.force_portrait_for_test()` で並べ直す。
## 縦画面の確認用。撮った絵の良し悪しは人が判断する(CLAUDE.md)。
##
## 実行(実際の描画結果を読むため --headless は付けない):
##   godot --path . res://tools/capture_match_layout.tscn -- <出力先フォルダ> [モード]
## モード: both(既定)/ landscape / portrait / overlays / panels
## overlays は縦で、重ね物(遠征の札・再生の操作)を1枚ずつ撮る。
## panels は縦で、マリガン(先手3枚・後手4枚)と結果パネルを1枚ずつ撮る。

const SETTLE_SECONDS := 0.8
const SETTLE_FRAMES := 4

var _stage: SubViewport
var _out_dir := ""
var _which := "both"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_which = args[1] if args.size() > 1 else "both"
	var portrait_only := _which in ["portrait", "overlays", "panels"]
	ScreenOrientation.force_portrait_for_test(portrait_only)
	CardMatchLayout.choose(portrait_only)
	_stage = SubViewport.new()
	_stage.size = ScreenOrientation.base_size()
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	var preview := TextureRect.new()
	preview.texture = _stage.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	add_child(preview)
	await super._ready()


func _screen_host() -> Node:
	return _stage


func _start_audio() -> void:
	pass


func _build_captions() -> void:
	pass


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if not args.is_empty() else "user://match_layout"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_setup_match()
	match_screen.visible = true
	_dress_board()
	if _which == "overlays":
		await _shoot_overlays()
		get_tree().quit()
		return
	if _which == "panels":
		await _shoot_panels()
		get_tree().quit()
		return
	if _which != "portrait":
		await _shoot(false, "match_landscape.png")
	if _which != "landscape":
		await _shoot(true, "match_portrait.png")
	get_tree().quit()


func _shoot(portrait: bool, file_name: String) -> void:
	ScreenOrientation.force_portrait_for_test(portrait)
	_stage.size = ScreenOrientation.base_size()
	match_screen.apply_orientation(portrait)
	match_screen.refresh()
	await _wait(SETTLE_SECONDS)
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(file_name)
	_stage.get_texture().get_image().save_png(path)
	print("SAVED=%s" % path)


func _dress_board() -> void:
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
	var history := match_screen._history
	history._push(foe, "設置", _card("sword"))
	history._push(my, "攻撃 → 相手", _card("lance"))
	history._push(foe, "反転", _card("glass"))
	history._push(my, "砂術", _card("tempest"))
	history._appear = 1.0


func _shoot_overlays() -> void:
	var solo := match_screen._solo
	var plaque := solo._plaque
	solo._run = SoloRun.new()
	plaque._run = solo._run
	plaque._floor_text = "遠征 ・ 深さ2 ・ 3段目"
	plaque._kind_text = "関門『砂嵐の番人』"
	plaque._goal_lead = "相手の場に あと"
	plaque._goal_value = 3
	plaque._goal_tail = "体"
	plaque.visible = true
	await _shoot(true, "overlay_solo.png")
	solo._run = null
	plaque.visible = false
	CardMatchArrange.place_history(match_screen, match_screen.layout)

	match_screen._interactive = false
	var replay := CardMatchReplay.new()
	match_screen._replay = replay
	match_screen.add_child(replay)
	replay.apply_layout(match_screen.layout)
	replay.visible = true
	replay._counter.text = "12/40"
	match_screen.refresh()
	await _shoot(true, "overlay_replay.png")


func _shoot_panels() -> void:
	var mulligan := match_screen._mulligan
	var hands := [
		HAND_IDS.slice(0, MatchState.FIRST_PLAYER_HAND),
		HAND_IDS.slice(0, MatchState.SECOND_PLAYER_HAND)
	]
	for ids in hands:
		var cards: Array = []
		for id in ids:
			cards.append(_card(id))
		mulligan.show_hand(cards, ids.size() == MatchState.FIRST_PLAYER_HAND, true)
		mulligan._picked[1] = true
		mulligan._refresh(false)
		mulligan._place_cards()
		await _shoot(true, "mulligan_%d.png" % ids.size())
	mulligan.close()
	match_screen.state.winner = match_screen.my_side
	var reward := "砂金 +30\nはじめの7日 3日目を受け取りました"
	match_screen._result.show_for(match_screen.state, match_screen.my_side, 23, reward, true)
	await _shoot(true, "result.png")
