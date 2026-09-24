extends "res://tools/record_pv_vertical.gd"
## カード紹介ショート(縦長・約12秒)。1枚を「盤面へ置く → 詳細パネルの実演 → 締め」の3拍で見せる。
## 台本は tools/shorts/make_short.py が card_lines.json から組み、--narration= で渡す。
## 台本の lines は 先頭=つかみ / 最後=締め / その間=効果の説明、heads は つかみ・効果の見出し。
##
##   python tools/shorts/make_short.py card eye

const TITLE_TEXT := "砂時計アリーナ カード紹介"
const HOOK_SLOT := 2
## 砂術は盤面へ出ないため、手札の中ほどに置いて寄る。
const SPELL_HAND_INDEX := 2
const SPELL_HAND_FILLER := ["hammer", "tempest", "glass", "shield"]
## カードの大きさが伝わるよう、相手側にも駒を置く。[枠, id, 体力, 攻撃力]
const FOE_EXTRAS := [[1, "lance", 3, 4], [3, "shield", 4, 2]]
const ZOOM_DETAIL := 1.9
const ZOOM_PREVIEW := 2.6
## 詳細パネルを映す間、盤面を沈める暗さ。
const BACKDROP_COLOR := Color(0.02, 0.02, 0.04, 0.72)
const STICKER_OFFSET := Vector2(250, -330)

var _card_data: CardData
var _backdrop: ColorRect
var _detail: CardDetailPanel


func _run() -> void:
	_card_data = _card(_narration["card"])
	_title.text = TITLE_TEXT
	_setup_match()
	_build_detail()
	match_screen.visible = true
	await get_tree().process_frame
	_begin_capture()
	await _c1_hook()
	await _c2_effect()
	_backdrop.visible = false
	_detail.visible = false
	await _v9_outro()
	_capturing = false
	get_tree().quit()


func _build_detail() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = BACKDROP_COLOR
	_backdrop.size = Vector2(STAGE_SIZE)
	_backdrop.visible = false
	_stage.add_child(_backdrop)
	_detail = CardDetailPanel.new()
	_detail.visible = false
	_stage.add_child(_detail)


func _heads() -> Array:
	return _narration.get("heads", [_card_data.display_name, ""])


## 1. 盤面(砂術なら手札)へ置いた瞬間に寄る。
func _c1_hook() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	for extra in FOE_EXTRAS:
		_unit(foe, extra[0], extra[1], extra[2], extra[3])
	var focus: Vector2
	if _card_data.is_spell:
		var hand: Array = SPELL_HAND_FILLER.duplicate()
		hand.insert(SPELL_HAND_INDEX, _card_data.id)
		_dress_hand(hand)
		match_screen.refresh()
		await get_tree().process_frame
		focus = _center_of(match_screen.hand_view(SPELL_HAND_INDEX))
	else:
		_unit(my, HOOK_SLOT, _card_data.id, _card_data.total_sand, 0)
		match_screen.refresh()
		await get_tree().process_frame
		focus = _center_of(match_screen.own_slot_view(HOOK_SLOT))
	var length := _say(0)
	_headline(_heads()[0])
	_flash_now()
	_cam_cut(focus, ZOOM_OPEN)
	_cam_to(focus, ZOOM_UNIT, length)
	_punch()
	_sticker("コスト %d" % _card_data.cost, VIEW_RECT.get_center() + STICKER_OFFSET, length * 0.7)
	await _until(length, 0.0)


## 2. 詳細パネルを大きく映し、能力の実演へ寄りながら効果を読む。
func _c2_effect() -> void:
	_detail.show_card(_card_data)
	_backdrop.visible = true
	_detail.visible = true
	await get_tree().process_frame
	_detail.position = ((Vector2(STAGE_SIZE) - _detail.size) * 0.5).floor()
	_flash_now()
	_headline(_heads()[1])
	var panel_center := _center_of(_detail)
	var preview_center := _center_of(_detail._preview)
	_cam_cut(panel_center, ZOOM_DETAIL)
	for index in range(1, _lines.size() - 1):
		var length := _say(index)
		if index == 1:
			_cam_to(preview_center, ZOOM_PREVIEW, length)
		_punch()
		await _until(length, 0.0)
