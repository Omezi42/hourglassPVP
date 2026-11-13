extends "res://tools/record_pv.gd"
## 対局の動き(攻撃・決着・反転権)を、決まった盤面から自動操作して連番PNGに書き出す。
## 画面を SubViewport の中で組み、毎フレームそのPNGを保存するため、縦(720x1280)も
## ウィンドウの大きさに左右されずに撮れる。実際の押下(駒・反転権のボタン・HPの帯)は
## シグナルを直接出して通す。結果パネルを出す決着は本物の経路(CardMatchFinale)を通すが、
## 戦績・砂金・リプレイの書き込み(CardMatchOutcome)だけは何もしない版に差し替える。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を付ける。--headless は付けない):
##   godot --path . --write-movie scratchpad/motion/_movie.avi --fixed-fps 30
##     res://tools/record_match_motion.tscn -- <出力先> <場面> <portrait|landscape>
## 場面: attack / finale / flip_right は押下のシグナルを直接出す。mulligan(札を押して印が付く → 確定 → 手札へ)と
## result_win / result_loss(結果パネルが出る → ボタンのホバー・押下)は、マリガンと結果パネルを直接開いて合成のマウスで操作する。
## select_hover / drag_attack / cancel / hand_hover は合成のマウスイベントを SubViewport へ流し
## (ホバー・ドラッグ・右クリック・Esc が本物の経路を通る)、
## カーソルの位置を白い矢印で焼き込む(押している間は金の輪を足す)。
## 出力先/frames/00000.png ... と 出力先/events.txt(「名前 コマ番号」を1行ずつ)ができる。
## GIF・MP4・静止画への変換まで通すなら tools/record_match_motion.sh を使う。
##
## 撮る前に Godot プロセスが残っていないか `tasklist` で確認する(Pitfalls.md)。

const SCENES := [
	"attack",
	"finale",
	"flip_right",
	"select_hover",
	"drag_attack",
	"cancel",
	"hand_hover",
	"mulligan",
	"result_win",
	"result_loss"
]
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
## 合成カーソルの動き: 1区間を動かすコマ数、乗せたままの間のコマ数、押下を保つコマ数。
const GLIDE_FRAMES := 12
const HOVER_HOLD_FRAMES := 30
const PRESS_HOLD_FRAMES := 4
## 空き地を探す格子の間隔(px)。
const EMPTY_SCAN_STEP := 24
const POINTER_SHAPE: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(0, 20),
	Vector2(5, 15),
	Vector2(9, 24),
	Vector2(12, 22),
	Vector2(8, 14),
	Vector2(15, 14)
]
const CURSOR_DOWN_RADIUS := 14.0
const CURSOR_DOWN_COLOR := Color(1.0, 0.8, 0.3, 0.9)
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
## マリガンの場面: 後手(コイン1枚)の初期手札の枚数、配り終わりの待ち、結果パネルの場面の決着手数。
const MULLIGAN_HAND_SIZE := 4
const MULLIGAN_DEAL_FRAMES := 30
const RESULT_MOVES := 23
const RESULT_REWARD := "+30 砂金" + "\n" + "明日来ると 60砂金 ・ はじめの7日 3/7"

var _stage: SubViewport
var _out_dir := ""
var _scene_name := "attack"
var _portrait := false
var _recording := false
var _frame := 0
var _events: PackedStringArray = []
var _cursor: CursorMarker
var _mouse := Vector2.ZERO
var _mask := 0
var _rest_point := Vector2.ZERO
var _empty_point := Vector2.ZERO


## 合成カーソルの印(実マウスは撮れないため、位置を絵として焼き込む)。
class CursorMarker:
	extends Control
	var at := Vector2.ZERO
	var down := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 4000

	func _draw() -> void:
		if down:
			draw_arc(at, CURSOR_DOWN_RADIUS, 0.0, TAU, 32, CURSOR_DOWN_COLOR, 3.0)
		var points := PackedVector2Array()
		for p in POINTER_SHAPE:
			points.append(at + p)
		draw_colored_polygon(points, Color.WHITE)
		points.append(points[0])
		draw_polyline(points, Color.BLACK, 1.5)


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
	_setup_cursor()
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
		"select_hover":
			await _scene_select_hover()
		"drag_attack":
			await _scene_drag_attack()
		"cancel":
			await _scene_cancel()
		"hand_hover":
			await _scene_hand_hover()
		"mulligan":
			await _scene_mulligan()
		"result_win":
			await _scene_result(true)
		"result_loss":
			await _scene_result(false)
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


## 合成カーソルの印を載せ、何も覆っていない地点(取り消しの空き押し・待機位置)を探す。
func _setup_cursor() -> void:
	_cursor = CursorMarker.new()
	_cursor.size = _stage.size
	_stage.add_child(_cursor)
	var mid := (
		(_view_center(match_screen.own_slot_view(1)) + _view_center(match_screen.foe_slot_view(1)))
		* 0.5
	)
	var best := INF
	var first := true
	var y := EMPTY_SCAN_STEP
	while y < int(_stage.size.y):
		var x := EMPTY_SCAN_STEP
		while x < int(_stage.size.x):
			var p := Vector2(x, y)
			_move(p)
			if _stage.gui_get_hovered_control() == match_screen:
				if first:
					_rest_point = p
					first = false
				if p.distance_to(mid) < best:
					best = p.distance_to(mid)
					_empty_point = p
			x += EMPTY_SCAN_STEP
		y += EMPTY_SCAN_STEP
	if first:
		push_warning("空き地が見つからない")
		_rest_point = Vector2(8, 8)
		_empty_point = _rest_point
	_move(_rest_point)


func _view_center(view: Control) -> Vector2:
	return view.get_global_transform() * (view.size * 0.5)


func _move(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = pos - _mouse
	event.button_mask = _mask
	_mouse = pos
	if _cursor != null:
		_cursor.at = pos
		_cursor.queue_redraw()
	_stage.push_input(event, true)


func _button(button: int, pressed: bool) -> void:
	var bit := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	_mask = (_mask | bit) if pressed else (_mask & ~bit)
	var event := InputEventMouseButton.new()
	event.position = _mouse
	event.global_position = _mouse
	event.button_index = button
	event.pressed = pressed
	event.button_mask = _mask
	if _cursor != null:
		_cursor.down = _mask != 0
		_cursor.queue_redraw()
	_stage.push_input(event, true)


## いまの位置から目的地まで、1コマごとに動かす(出だしと終わりを緩める)。
func _glide(to: Vector2, frames := GLIDE_FRAMES) -> void:
	var from := _mouse
	for i in range(1, frames + 1):
		_move(from.lerp(to, smoothstep(0.0, 1.0, float(i) / frames)))
		await get_tree().process_frame


func _click(button := MOUSE_BUTTON_LEFT) -> void:
	_button(button, true)
	await _frames(PRESS_HOLD_FRAMES)
	_button(button, false)


func _click_now(button: int) -> void:
	_button(button, true)
	_button(button, false)


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	_stage.push_input(event, true)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	_stage.push_input(release, true)


## 自分の駒を実際に押して選ぶ(ホバー→押下→離す)。
func _select_own(mark_name := "select_own") -> void:
	await _glide(_view_center(match_screen.own_slot_view(1)))
	await _click()
	_mark(mark_name)
	await _frames(STEP_PAUSE_FRAMES)


func _foe_hp_point() -> Vector2:
	var bar: Control = match_screen.foe_bar
	return bar.get_global_transform() * bar.hp_bar_rect().get_center()


## 駒を選び、攻撃できる相手→別の相手→相手のHP帯→反転ボタンの順にカーソルを乗せる。
func _scene_select_hover() -> void:
	await _glide(_view_center(match_screen.own_slot_view(1)))
	_mark("hover_own")
	await _frames(HOVER_HOLD_FRAMES / 2)
	await _click()
	_mark("select_own")
	await _frames(STEP_PAUSE_FRAMES)
	var stops := [
		["hover_foe_1", _view_center(match_screen.foe_slot_view(1))],
		["hover_foe_3", _view_center(match_screen.foe_slot_view(3))],
		["hover_face", _foe_hp_point()],
	]
	for stop in stops:
		await _glide(stop[1])
		_mark(stop[0])
		await _frames(HOVER_HOLD_FRAMES)
	var flip: Control = match_screen._flip_button
	if flip.visible:
		await _glide(flip.get_global_rect().get_center())
		_mark("hover_flip")
		await _frames(HOVER_HOLD_FRAMES)
	await _glide(_rest_point)
	_mark("leave")
	await _frames(HOVER_HOLD_FRAMES)


## 駒を押したまま相手の駒へ引き、矢印を引いて放す。着弾と戻りまで撮る。
func _scene_drag_attack() -> void:
	var attacker := match_screen.own_slot_view(1)
	var start := _view_center(attacker)
	var goal := _view_center(match_screen.foe_slot_view(1))
	attacker.strike_impact.connect(_mark.bind("impact"), CONNECT_ONE_SHOT)
	attacker.drag_started.connect(
		func(_v: CardView) -> void: _mark("drag_started"), CONNECT_ONE_SHOT
	)
	await _glide(start)
	await _frames(HOVER_HOLD_FRAMES / 2)
	_button(MOUSE_BUTTON_LEFT, true)
	_mark("press_own")
	await _frames(PRESS_HOLD_FRAMES)
	await _glide(start.lerp(goal, 0.5))
	_mark("drag_mid")
	await _frames(HOVER_HOLD_FRAMES / 2)
	await _glide(goal)
	_mark("over_target")
	await _frames(HOVER_HOLD_FRAMES)
	_button(MOUSE_BUTTON_LEFT, false)
	_mark("release")
	await _until(func(): return match_screen.strike_busy())
	_mark("strike_started")
	await _until(func(): return not match_screen.strike_busy())
	_mark("strike_settled")


## 駒を選んで相手に乗せ、右クリック / 空き押し / Esc の3通りで取り消す。
func _scene_cancel() -> void:
	var defender_at := _view_center(match_screen.foe_slot_view(1))
	await _select_own("select_own_a")
	await _glide(defender_at)
	_mark("hover_foe_before_cancel")
	await _frames(HOVER_HOLD_FRAMES / 2)
	_click_now(MOUSE_BUTTON_RIGHT)
	_mark("cancel_right_click")
	await _frames(HOVER_HOLD_FRAMES)
	await _glide(_rest_point)
	await _select_own("select_own_b")
	await _glide(_empty_point)
	await _frames(STEP_PAUSE_FRAMES / 2)
	await _click()
	_mark("cancel_empty_click")
	await _frames(HOVER_HOLD_FRAMES)
	await _glide(_rest_point)
	await _select_own("select_own_c")
	await _glide(_rest_point)
	_key(KEY_ESCAPE)
	_mark("cancel_escape")
	await _frames(HOVER_HOLD_FRAMES)


## 比べる基準: 手札の札に順にカーソルを乗せる(磨き込み済みのホバー)。
func _scene_hand_hover() -> void:
	var views: Array = match_screen._hand_views.filter(func(v: CardView) -> bool: return v.visible)
	for i in [0, 2, 4]:
		if i >= views.size():
			continue
		await _glide(_view_center(views[i]))
		_mark("hover_hand_%d" % i)
		await _frames(HOVER_HOLD_FRAMES)
	await _glide(_rest_point)
	_mark("leave")
	await _frames(HOVER_HOLD_FRAMES / 2)


## マリガン: 先手後手の一文 → 配る → 札を2枚押して印を付ける → 1枚を押して外す → 確定 → 相手待ち → 手札へ入る。
## 手札へ入るところは、相手の確定を待たずに画面を閉じて盤面を描き直して代用する。
func _scene_mulligan() -> void:
	var mulligan := match_screen._mulligan
	var cards: Array = []
	for id in HAND_IDS.slice(0, MULLIGAN_HAND_SIZE):
		cards.append(_card(id))
	mulligan.show_hand(cards, false, true)
	_mark("order_intro_started")
	await _until(func(): return not mulligan._intro_playing)
	_mark("order_intro_ended")
	await _frames(MULLIGAN_DEAL_FRAMES)
	_mark("deal_settled")
	for index in [0, 2]:
		var view: Control = mulligan._views[index]
		await _glide(_view_center(view))
		_mark("hover_card_%d" % index)
		await _frames(HOVER_HOLD_FRAMES / 2)
		_button(MOUSE_BUTTON_LEFT, true)
		_mark("press_card_%d" % index)
		await _frames(PRESS_HOLD_FRAMES)
		_button(MOUSE_BUTTON_LEFT, false)
		_mark("pick_card_%d" % index)
		await _frames(STEP_PAUSE_FRAMES)
	await _glide(_view_center(mulligan._views[0]))
	_mark("hover_picked_card_0")
	await _frames(HOVER_HOLD_FRAMES / 2)
	_button(MOUSE_BUTTON_LEFT, true)
	_mark("press_picked_card_0")
	await _frames(PRESS_HOLD_FRAMES)
	_button(MOUSE_BUTTON_LEFT, false)
	_mark("unpick_card_0")
	await _frames(STEP_PAUSE_FRAMES)
	await _glide(_view_center(mulligan._button))
	_mark("hover_confirm")
	await _frames(HOVER_HOLD_FRAMES / 2)
	_button(MOUSE_BUTTON_LEFT, true)
	_mark("press_confirm")
	await _frames(PRESS_HOLD_FRAMES)
	_button(MOUSE_BUTTON_LEFT, false)
	_mark("confirmed_waiting")
	await _frames(MULLIGAN_DEAL_FRAMES)
	mulligan.close()
	match_screen.refresh()
	_mark("mulligan_closed")
	await _frames(STEP_PAUSE_FRAMES)


## 結果パネルが出て、「もう一度」へカーソルを乗せて押す(放す前に外へ出して確定させない)。
func _scene_result(won: bool) -> void:
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	var state := match_screen.state
	state.winner = my if won else foe
	state.end_reason = MatchState.EndReason.HP_DEPLETED
	state.hp[my] = 12 if won else 0
	state.hp[foe] = 0 if won else 9
	match_screen._result.show_for(state, my, RESULT_MOVES, RESULT_REWARD, true)
	_mark("result_shown")
	await _frames(MAX_WAIT_FRAMES / 4)
	_mark("result_settled")
	var rematch: Control = match_screen._result._buttons[0]
	await _glide(_view_center(rematch))
	_mark("hover_rematch")
	await _frames(HOVER_HOLD_FRAMES / 2)
	_button(MOUSE_BUTTON_LEFT, true)
	_mark("press_rematch")
	await _frames(PRESS_HOLD_FRAMES * 3)
	await _glide(_rest_point)
	_button(MOUSE_BUTTON_LEFT, false)
	_mark("release_outside")
	await _frames(STEP_PAUSE_FRAMES)


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
