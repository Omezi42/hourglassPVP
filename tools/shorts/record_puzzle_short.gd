extends "res://tools/record_pv_vertical.gd"
## とどめ問題ショート(縦長・約25秒)。問題集(tools/shorts/puzzles.json。puzzle_forge.gd が
## 総当たりで選んだ難しい問題)から1問出し、考える時間を数えてから、正解手順を対局画面でそのまま再生する。
## 台本は tools/shorts/make_short.py が puzzle_lines.json から組み、問題ごと --narration= で渡す。
##
##   python tools/shorts/make_short.py puzzle 3

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
## 考える時間に字幕の欄へ出す、効果を持つカードの一覧。
const LEGEND_FONT_SIZE := 38
const NO_EFFECT_TEXT := "効果なし"
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
	var entry: Dictionary = _narration["puzzle"]
	_stage_data = _stage_from(entry["stage"])
	for action in entry["solution"]:
		_solution.append(_whole_numbers(action))
	_title.text = TITLE_TEXT
	_start_puzzle()
	_build_count()
	match_screen.visible = true
	await get_tree().process_frame
	_begin_capture()
	await _p1_problem()
	await _p2_think()
	await _p3_answer()
	# 問題集の手順が画面の局面で通らなかったら、崩れた動画を書き出さずに失敗で終える。
	var solved := int(match_screen.state.hp[MatchState.other_side(match_screen.my_side)]) <= 0
	if not solved:
		push_error("正解手順で相手のHPが0になりませんでした")
		get_tree().quit(1)
		return
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


func _stage_from(data: Dictionary) -> PuzzleStageData:
	var stage := PuzzleStageData.new()
	stage.id = "forge"
	stage.title = data["title"]
	stage.hint = data["hint"]
	stage.foe_hp = int(data["foe_hp"])
	stage.own_hp = int(data["own_hp"])
	stage.mana = int(data["mana"])
	stage.hand_ids.assign(data["hand_ids"])
	stage.own_units.assign(data["own_units"])
	stage.foe_units.assign(data["foe_units"])
	return stage


## JSONを通ると整数が小数になるため、手の番号を整数へ戻す。
func _whole_numbers(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[key] = _whole_numbers(value[key])
		return copy
	return value


## 盤面と手札のうち効果を持つカードを「名前:効果」の行にする(盤面を見ただけでは効果が分からないため)。
func _legend() -> String:
	var cards := {}
	for row in _stage_data.own_units + _stage_data.foe_units:
		var parsed := PuzzleStageData.parse_unit(row)
		if not parsed.is_empty():
			cards[(parsed["card"] as CardData).id] = parsed["card"]
	for id in _stage_data.hand_ids:
		cards[id] = _card(id)
	var lines: PackedStringArray = []
	for card in cards.values():
		var text := (card as CardData).describe()
		if text != NO_EFFECT_TEXT:
			lines.append("[color=#ffcf4a]%s[/color] %s" % [card.display_name, text])
	return "\n".join(lines)


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


## 2. 残りの体力を見出しに出し、考える時間を数える。字幕はカードの効果の一覧に替える。
func _p2_think() -> void:
	var length := _say(1)
	_headline(String(_heads()[1]).replace("{hp}", str(_stage_data.foe_hp)))
	_punch()
	await _until(length, 0.0)
	_sub.text = "[center][font_size=%d]%s[/font_size][/center]" % [LEGEND_FONT_SIZE, _legend()]
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


func _play_step(action: Dictionary) -> void:
	var from: Control
	var to: Control
	var label: String
	match String(action["type"]):
		"flip":
			from = match_screen.own_slot_view(action["slot"])
			to = from
			label = "反転!"
		"flip_right":
			from = _slot_view(action["target_side"], action["slot"])
			to = from
			label = "反転権!"
		"attack":
			from = match_screen.own_slot_view(action["slot"])
			if int(action["target_slot"]) < 0:
				to = match_screen.foe_bar
				label = "本体を攻撃!"
			else:
				to = match_screen.foe_slot_view(action["target_slot"])
				label = "駒を攻撃!"
		"play", "cast":
			from = match_screen.hand_view(action["hand_index"])
			to = _target_view(action.get("target", {}))
			label = "出す!" if action["type"] == "play" else "砂術!"
	_cam_to(_center_of(from).lerp(_center_of(to), 0.5), ZOOM_STEP)
	_sticker(label, VIEW_RECT.get_center() + STEP_STICKER_OFFSET, STEP_LEAD + STEP_HOLD * 0.6)
	await _wait(STEP_LEAD)
	match_screen._perform(action)
	_punch()
	if action["type"] == "attack":
		_shake()
	await _wait(STEP_HOLD)


func _slot_view(side: int, slot: int) -> Control:
	if side == match_screen.my_side:
		return match_screen.own_slot_view(slot)
	return match_screen.foe_slot_view(slot)


## 対象を取る手はその駒へ、取らない手は相手の情報帯へ寄る。
func _target_view(target: Dictionary) -> Control:
	if target.has("side"):
		return _slot_view(target["side"], target["slot"])
	return match_screen.foe_bar


## 4. 実際のエンドレスの結果パネル(「正解!」)へ寄る。
func _p4_result() -> void:
	var length := _say(3)
	_headline(_heads()[3])
	_flash_now()
	_cam_to(_problem_center(), ZOOM_RESULT, CAM_SNAP)
	await _until(length, 0.0)
