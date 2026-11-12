extends "res://tools/record_pv.gd"
## 対局の動き(攻撃・決着・反転権)を、決まった盤面から自動操作して連番PNGに書き出す。
## 画面を SubViewport の中で組み、毎フレームそのPNGを保存するため、縦(720x1280)も
## ウィンドウの大きさに左右されずに撮れる。実際の押下(駒・反転権のボタン・HPの帯)は
## シグナルを直接出して通す。結果パネルを出す決着は本物の経路(CardMatchFinale)を通すが、
## 戦績・砂金・リプレイの書き込み(CardMatchOutcome)だけは何もしない版に差し替える。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を付ける。--headless は付けない):
##   godot --path . --write-movie scratchpad/motion/_movie.avi --fixed-fps 30
##     res://tools/record_match_motion.tscn -- <出力先> <attack|finale|flip_right> <portrait|landscape>
## 出力先/frames/00000.png ... と 出力先/events.txt(「名前 コマ番号」を1行ずつ)ができる。
## GIF・MP4・静止画への変換まで通すなら tools/record_match_motion.sh を使う。
##
## 撮る前に Godot プロセスが残っていないか `tasklist` で確認する(Pitfalls.md)。

const SCENES := ["attack", "finale", "flip_right"]
## 盤面が落ち着くまで撮らずに待つコマ数と、撮り始めの静止のコマ数。
const SETTLE_FRAMES := 40
const PRE_ROLL_FRAMES := 12
## 操作の間の間(押した結果が見えるまで)と、最後の余韻のコマ数。
const STEP_PAUSE_FRAMES := 18
const POST_HOLD_FRAMES := 36
## 待ちの上限(演出が終わらないときに固まらないための保険)。
const MAX_WAIT_FRAMES := 420
## 反転権で駒が裏返りきるまで(筋0.2秒 + 反転0.56秒)に足りるコマ数。
const FLIP_ANIM_FRAMES := 30
const EVENTS_FILE := "events.txt"
const FRAME_DIR := "frames"

## 盤面。自分=スロット1、相手=スロット1(攻撃・反転権の対象)。
const ATTACKER_ID := "lance"
const ATTACKER_HEALTH := 5
const ATTACKER_ATTACK := 4
const DEFENDER_ID := "sand"
const DEFENDER_HEALTH := 6
const DEFENDER_ATTACK := 2
const BYSTANDER_MY := {"slot": 3, "id": "wall", "health": 6, "attack": 1}
const BYSTANDER_FOE := {"slot": 3, "id": "poison", "health": 5, "attack": 2}
## 決着: 相手のHPと、それを倒しきる攻撃力。
const FINALE_FOE_HP := 4
const FINALE_ATTACK := 6
## 反転権: 自分・相手の残り回数と、反転させる相手の駒(体力と攻撃力が大きく違うもの)。
const FLIP_RIGHT_OWN := 3
const FLIP_RIGHT_FOE := 2
const FLIP_TARGET_ID := "drill"
const FLIP_TARGET_HEALTH := 5
const FLIP_TARGET_ATTACK := 2

var _stage: SubViewport
var _out_dir := ""
var _scene_name := "attack"
var _portrait := false
var _recording := false
var _frame := 0
var _events: PackedStringArray = []


## 戦績・砂金・リプレイを書かない結果の後始末。
class QuietOutcome:
	extends CardMatchOutcome

	func finish(_kind: int, _deck: Array) -> String:
		return ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or not args[1] in SCENES:
		push_error("usage: -- <out_dir> <%s> <portrait|landscape>" % "|".join(SCENES))
		get_tree().quit(1)
		return
	_out_dir = args[0]
	_scene_name = args[1]
	_portrait = args[2] == "portrait"
	DirAccess.make_dir_recursive_absolute(_out_dir.path_join(FRAME_DIR))
	ScreenOrientation.force_portrait_for_test(_portrait)
	CardMatchLayout.choose(_portrait)
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


## record_pv の版は終局の通知を外すが、決着の演出を見せたいので繋いだままにする。
func _setup_match() -> void:
	match_screen.start_cpu_match(_deck(), _deck())
	match_screen._cpu = null
	match_screen._outcome = QuietOutcome.new(match_screen)
	_quietly(match_screen._on_mulligan_confirmed.bind([]))
	_dress_hand(HAND_IDS)
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	for side in [my, foe]:
		match_screen.state.mana[side] = 7
		match_screen.state.max_mana[side] = 7
	match_screen.state.current_turn = my


func _run() -> void:
	_setup_match()
	match_screen.visible = true
	match_screen.apply_orientation(_portrait)
	_build_board()
	match_screen.refresh()
	await _frames(SETTLE_FRAMES)
	_recording = true
	_capture_loop()
	await _frames(PRE_ROLL_FRAMES)
	match _scene_name:
		"attack":
			await _scene_attack()
		"finale":
			await _scene_finale()
		"flip_right":
			await _scene_flip_right()
	await _frames(POST_HOLD_FRAMES)
	_recording = false
	await _frames(2)
	_write_events()
	get_tree().quit()


func _build_board() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	var attack := FINALE_ATTACK if _scene_name == "finale" else ATTACKER_ATTACK
	_unit(my, 1, ATTACKER_ID, ATTACKER_HEALTH, attack)
	_place(my, BYSTANDER_MY)
	if _scene_name == "flip_right":
		_unit(foe, 1, FLIP_TARGET_ID, FLIP_TARGET_HEALTH, FLIP_TARGET_ATTACK)
		match_screen.state.flip_right_remaining[my] = FLIP_RIGHT_OWN
		match_screen.state.flip_right_remaining[foe] = FLIP_RIGHT_FOE
	else:
		_unit(foe, 1, DEFENDER_ID, DEFENDER_HEALTH, DEFENDER_ATTACK)
	_place(foe, BYSTANDER_FOE)
	if _scene_name == "finale":
		match_screen.state.hp[foe] = FINALE_FOE_HP
	match_screen.state.current_turn = my


func _place(side: int, spec: Dictionary) -> void:
	_unit(side, spec["slot"], spec["id"], spec["health"], spec["attack"])


## 自分の駒を選び、相手の駒を押す。着弾と戻りまで撮る。
func _scene_attack() -> void:
	var attacker := match_screen.own_slot_view(1)
	var defender := match_screen.foe_slot_view(1)
	attacker.strike_impact.connect(_mark.bind("impact"), CONNECT_ONE_SHOT)
	attacker.pressed.emit(attacker)
	_mark("select_own")
	await _frames(STEP_PAUSE_FRAMES)
	defender.pressed.emit(defender)
	_mark("press_target")
	await _until(func(): return match_screen.strike_busy())
	_mark("strike_started")
	await _until(func(): return not match_screen.strike_busy())
	_mark("strike_settled")


## 自分の駒を選び、相手のHPの帯を押す。器が砕けて結果パネルが出るまで撮る。
func _scene_finale() -> void:
	var attacker := match_screen.own_slot_view(1)
	attacker.strike_impact.connect(_mark.bind("impact"), CONNECT_ONE_SHOT)
	attacker.pressed.emit(attacker)
	_mark("select_own")
	await _frames(STEP_PAUSE_FRAMES)
	match_screen._touch.on_face_pressed()
	_mark("press_face")
	await _until(func(): return match_screen.strike_busy())
	_mark("strike_started")
	await _until(func(): return not match_screen.strike_busy())
	_mark("strike_settled")
	await _until(func(): return not match_screen.finale._pending)
	_mark("vessel_shatter_started")
	await _until(func(): return match_screen._result.visible)
	_mark("result_shown")
	await _frames(STEP_PAUSE_FRAMES)
	_mark("result_settled")


## 反転権のボタンを押し、相手の駒を押す。残りの粒が減るまで撮る。
func _scene_flip_right() -> void:
	var my := match_screen.my_side
	var target := match_screen.foe_slot_view(1)
	var button: RoundActionButton = match_screen._flip_right._button
	var before: int = match_screen.state.flip_right_remaining[my]
	button.pressed.emit()
	_mark("press_flip_right")
	await _frames(STEP_PAUSE_FRAMES)
	target.pressed.emit(target)
	_mark("press_target")
	await _until(func(): return match_screen.state.flip_right_remaining[my] < before)
	_mark("remaining_decreased")
	await _frames(FLIP_ANIM_FRAMES)
	_mark("flip_landed")
	await _frames(STEP_PAUSE_FRAMES * 2)
	_mark("flip_settled")


func _capture_loop() -> void:
	while _recording:
		await RenderingServer.frame_post_draw
		if not _recording:
			return
		var path := _out_dir.path_join(FRAME_DIR).path_join("%05d.png" % _frame)
		_stage.get_texture().get_image().save_png(path)
		_frame += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _until(condition: Callable) -> void:
	for i in MAX_WAIT_FRAMES:
		if condition.call():
			return
		await get_tree().process_frame
	push_warning("待ちの上限に達した")


func _mark(event_name: String) -> void:
	_events.append("%s %d" % [event_name, _frame])


func _write_events() -> void:
	var file := FileAccess.open(_out_dir.path_join(EVENTS_FILE), FileAccess.WRITE)
	_events.append("total %d" % _frame)
	for line in _events:
		file.store_line(line)
