extends "res://tools/record_pv.gd"
## 対局画面を横(1280x720)と縦(720x1280)の両方で撮る(Architecture.md 4.7節)。中盤の盤面を
## SubViewport の中で組み、縦は `ScreenOrientation.force_portrait_for_test()` で並べ直す。
## 縦画面の確認用。撮った絵の良し悪しは人が判断する(CLAUDE.md)。
##
## 実行(実際の描画結果を読むため --headless は付けない):
##   godot --path . res://tools/capture_match_layout.tscn -- <出力先フォルダ> [モード]
## モード: both(既定)/ landscape / portrait / overlays
## overlays は縦で、重ね物(実況・墓地の一覧・再生の操作・誘導対局の帯)を1枚ずつ撮る。

const SETTLE_SECONDS := 0.8
const SETTLE_FRAMES := 4

var _stage: SubViewport
var _out_dir := ""
var _which := "both"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_which = args[1] if args.size() > 1 else "both"
	var portrait_only := _which == "portrait" or _which == "overlays"
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
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	var feed := match_screen._feed
	feed.say("相手は『ドリル』で『ランス』を攻撃", match_screen._geometry.slot_center(foe, 1))
	feed._banner_text = "あなたの番"
	feed._banner_duration = CardMatchTurnFeed.BANNER_DURATION
	feed._banner_left = CardMatchTurnFeed.BANNER_DURATION * 0.6
	feed.set_process(false)
	await _shoot(true, "overlay_feed.png")
	feed.clear()

	var pile: Array = []
	for id in ["sand", "sand", "lance", "glass", "drill", "wall", "sword", "poison", "lock"]:
		pile.append(_card(id))
	match_screen._pile.open_pile("相手の墓地", pile)
	await _shoot(true, "overlay_pile.png")
	match_screen._pile.visible = false

	var tutorial := match_screen._tutorial
	tutorial._label.text = String.chr(10).join(
		["相手に3ダメージ、こっちも2削れたよ。", "体力が0になると割れちゃうよ。反転すれば長生きできるんだ"]
	)
	tutorial._next_button.visible = true
	tutorial.visible = true
	await _shoot(true, "overlay_tutorial.png")
	tutorial.visible = false

	match_screen._interactive = false
	var replay := CardMatchReplay.new()
	match_screen._replay = replay
	match_screen.add_child(replay)
	replay.apply_layout(match_screen.layout)
	replay.visible = true
	replay._counter.text = "12/40"
	match_screen.refresh()
	await _shoot(true, "overlay_replay.png")
