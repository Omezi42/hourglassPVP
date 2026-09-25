class_name NumberPad
extends GridContainer
## 数字だけを受け付ける欄へ添える画面上の数字パッド(GameDesign.md 9章)。
##
## 押した数字は対象の `LineEdit` へ足し、`text_changed` を流す。欄の側が持つ絞り込み
## (数字以外を落とす等)を、キーボードで打った場合と同じ経路で通すため。
## キーはフォーカスを取らない。欄のフォーカス(升のカーソル)を奪わないため。

signal confirmed

const COLUMNS := 3
const KEY_GAP := 8
const DIGITS := ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
const DELETE_LABEL := "消す"
const CONFIRM_LABEL := "決定"

var _target: LineEdit
var _keys: Array[Button] = []


## with_confirm: 確定のボタンが別に無い欄でだけ「決定」を置く。
static func make(target: LineEdit, key_size: Vector2, with_confirm: bool) -> NumberPad:
	var pad := NumberPad.new()
	pad._target = target
	pad.columns = COLUMNS
	pad.add_theme_constant_override("h_separation", KEY_GAP)
	pad.add_theme_constant_override("v_separation", KEY_GAP)
	for digit in DIGITS:
		pad._add_key(digit, key_size, CodedButton.WIDE_GROUP, pad._type.bind(digit))
	pad._add_key(DELETE_LABEL, key_size, CodedButton.WIDE_GROUP, pad._delete)
	pad._add_key("0", key_size, CodedButton.WIDE_GROUP, pad._type.bind("0"))
	if with_confirm:
		pad._add_key(CONFIRM_LABEL, key_size, CodedButton.PRIMARY_ACTION_GROUP, pad._confirm)
	return pad


## 全体の大きさ。置く側が矩形を決めるのに使う。
static func pad_size(key_size: Vector2) -> Vector2:
	var rows := ceili(float(DIGITS.size() + 3) / COLUMNS)
	return Vector2(
		key_size.x * COLUMNS + KEY_GAP * (COLUMNS - 1), key_size.y * rows + KEY_GAP * (rows - 1)
	)


func set_disabled(disabled: bool) -> void:
	for key in _keys:
		key.disabled = disabled


func _add_key(label: String, key_size: Vector2, group: String, handler: Callable) -> void:
	var key := CodedButton.make_in_group(label, key_size, group)
	key.focus_mode = Control.FOCUS_NONE
	key.pressed.connect(handler)
	_keys.append(key)
	add_child(key)


func _type(digit: String) -> void:
	if not _target.editable:
		return
	if _target.max_length > 0 and _target.text.length() >= _target.max_length:
		return
	_set_text(_target.text + digit)


func _delete() -> void:
	if not _target.editable or _target.text.is_empty():
		return
	_set_text(_target.text.left(-1))


func _confirm() -> void:
	if _target.editable:
		confirmed.emit()


func _set_text(text: String) -> void:
	_target.text = text
	_target.caret_column = text.length()
	_target.text_changed.emit(text)
