extends "res://tools/record_pv_vertical.gd"
## とどめ問題ショート(縦長・約20秒)。エンドレス(GameDesign.md 24章)の問題を1問出し、
## 考える時間を数えてから、生成器が検証した解答手順を対局画面でそのまま再生する。
## 台本は tools/shorts/make_short.py が puzzle_lines.json から組み、--narration= で渡す
## (問題の種 `seed` も台本に入れる。同じ種なら同じ問題になる)。
##
##   python tools/shorts/make_short.py puzzle 12

const TITLE_TEXT := "砂時計アリーナ とどめ問題"
const PLAYER_NAME := "あなた"
const FOE_NAME := "相手"
const THINK_SECONDS := 5
const ZOOM_PROBLEM := 1.05
const ZOOM_STEP := 1.5
const ZOOM_RESULT := 1.6
## 1手ごとに、寄って札を貼ってから指すまでの間と、指した後に見せる間。
const STEP_LEAD := 0.35
const STEP_HOLD := 0.85
const STEP_STICKER_OFFSET := Vector2(250, -300)
## 考える時間の数字(映像の右上に大きく出す)。
const COUNT_CENTER := Vector2(930, 520)
const COUNT_FONT_SIZE := 200
const COUNT_OUTLINE := 34
const COUNT_POP_FROM := 1.6
const COUNT_POP_DURATION := 0.2

var _solution: Array = []
var _stage_data: PuzzleStageData
var _count: Label


func _run() -> void:
	var generated := PuzzleGenerator.generate_with_solution(int(_narration["seed"]))
	_stage_data = generated["stage"]
	_solution = generated["solution"]
	_title.text = TITLE_TEXT
	_start_puzzle()
	_build_count()
	match_screen.visible = true
	await get_tree().process_frame
	_begin_capture()
	await _p1_problem()
	await _p2_think()
	await _p3_answer()
	await _p4_result()
	await _v9_outro()
	_capturing = false
	get_tree().quit()


## 実際のエンドレスと同じ入口で局面を作る。エンドレスは進捗も砂金も書かない(Architecture.md 10.12.1節)。
func _start_puzzle() -> void:
	match_screen.puzzle.start(_stage_data, true)
	match_screen.bar_for(match_screen.my_side).display_name = PLAYER_NAME
	match_screen.foe_bar.display_name = FOE_NAME
	match_screen.refresh()


func _build_count() -> void:
	_count = _make_label(Rect2(), COUNT_FONT_SIZE, COUNT_OUTLINE, COLOR_GOLD)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.visible = false
	_frame.get_child(0).add_child(_count)
	_count.get_parent().move_child(_count, _flash.get_index())


func _heads() -> Array:
	return _narration["heads"]


func _problem_center() -> Vector2:
	return Vector2(STAGE_SIZE) * 0.5


## 1. 問題の盤面を見せる。
func _p1_problem() -> void:
	var length := _say(0)
	_headline(_heads()[0])
	_flash_now()
	_cam_cut(_problem_center(), ZOOM_PROBLEM * 1.3)
	_cam_to(_problem_center(), ZOOM_PROBLEM, length)
	await _until(length, 0.0)


## 2. 残りの体力を見出しに出し、考える時間を数える。字幕は問題のヒントに替える。
func _p2_think() -> void:
	var length := _say(1)
	_headline(String(_heads()[1]).replace("{hp}", str(_stage_data.foe_hp)))
	_punch()
	await _until(length, 0.0)
	_sub.text = "[center]%s[/center]" % _stage_data.hint
	_count.visible = true
	for remaining in range(THINK_SECONDS, 0, -1):
		_count.text = str(remaining)
		_count.size = _count.get_minimum_size()
		_count.position = COUNT_CENTER - _count.size * 0.5
		_count.pivot_offset = _count.size * 0.5
		_count.scale = Vector2.ONE * COUNT_POP_FROM
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_count, "scale", Vector2.ONE, COUNT_POP_DURATION)
		await _wait(1.0)
	_count.visible = false


## 3. 解答手順を1手ずつ再生する。
func _p3_answer() -> void:
	var length := _say(2)
	_headline(_heads()[2])
	_flash_now()
	await _until(length, 0.0)
	for step in _solution:
		await _play_step(step)


func _play_step(step: Dictionary) -> void:
	var my := match_screen.my_side
	var slot := int(step.get("slot", -1))
	var action: Dictionary
	var from: Control
	var to: Control
	var label: String
	match String(step["type"]):
		"flip":
			action = MatchAction.flip(my, slot)
			from = match_screen.own_slot_view(slot)
			to = from
			label = "反転!"
		"attack":
			var target_slot := int(step["target_slot"])
			action = MatchAction.attack(my, slot, target_slot)
			from = match_screen.own_slot_view(slot)
			if target_slot < 0:
				to = match_screen.foe_bar
				label = "攻撃!"
			else:
				to = match_screen.foe_slot_view(target_slot)
				label = "守護を割る!"
		"cast_id":
			var index := _hand_index(String(step["card_id"]))
			action = MatchAction.cast(my, index)
			from = match_screen.hand_view(index)
			to = match_screen.foe_bar
			label = "砂術!"
	_cam_to(_center_of(from).lerp(_center_of(to), 0.5), ZOOM_STEP)
	_sticker(label, VIEW_RECT.get_center() + STEP_STICKER_OFFSET, STEP_LEAD + STEP_HOLD * 0.6)
	await _wait(STEP_LEAD)
	match_screen._perform(action)
	_punch()
	if action["type"] == "attack":
		_shake()
	await _wait(STEP_HOLD)


func _hand_index(card_id: String) -> int:
	var hand: Array = match_screen.state.hand[match_screen.my_side]
	for i in hand.size():
		if (hand[i] as CardData).id == card_id:
			return i
	return -1


## 4. 実際のエンドレスの結果パネル(「正解!」)へ寄る。
func _p4_result() -> void:
	var length := _say(3)
	_headline(_heads()[3])
	_flash_now()
	_cam_to(_problem_center(), ZOOM_RESULT, CAM_SNAP)
	await _until(length, 0.0)
