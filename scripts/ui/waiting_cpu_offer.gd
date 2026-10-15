class_name WaitingCpuOffer
extends RefCounted
## 待っている間のCPU戦の入口(GameDesign.md 11章)。ランクマッチの待機画面が持つ。
##
## 待機を始めたときは `start_auto()`: 予告の1行と「CPUと対戦せず待つ」を出し、
## 時間が来たら自動でCPU戦を始める。待つと選んだ後・CPU戦から戻った後は `arm()`:
## 「待っている間CPUと対戦する」ボタンを出すだけにする。

signal requested

## キューの確認(`MatchmakingQueue.POLL_INTERVAL_SECONDS`)2回ぶんより後に始め、
## 同時に待っている人どうしが先に出会えるようにする。
const FIRST_DELAY_SECONDS := 5.0
const AUTO_NOTE := "%d秒で相手が見つからなければ、待っている間CPUと対戦します"
const BUTTON_SIZE := Vector2(360, 64)
## キャンセルボタンとの間隔。
const GAP := 16.0
const NOTE_FONT_SIZE := 18
const NOTE_WIDTH := 720.0
## 縦画面(GameDesign.md 9章「縦画面」)。ボタンを指で押せる背丈に、予告を本文の目安(24px)にし、2行に折る。
const PORTRAIT_BUTTON_SIZE := Vector2(480, 80)
const PORTRAIT_FONT_SIZE := 26
const PORTRAIT_NOTE_FONT_SIZE := 24
const PORTRAIT_NOTE_WIDTH := 640.0

var button: Button
## 自動で始めるのを止めるボタン。`button` と同じ位置に出す。
var wait_button: Button
var _note: Label
var _host: Control
## 予約を取り消すための番号。待つ間に隠されたら、時間が来ても何もしない。
var _serial := 0


func _init(host: Control, below: Button) -> void:
	_host = host
	button = CodedButton.make_in_group(
		"待っている間CPUと対戦する", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	button.pressed.connect(_on_pressed)
	host.add_child(button)

	wait_button = CodedButton.make("CPUと対戦せず待つ", BUTTON_SIZE)
	wait_button.pressed.connect(_on_wait_pressed)
	host.add_child(wait_button)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 折り返しは幅より先に立てる(Pitfalls.md)。
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	_note.text = AUTO_NOTE % int(FIRST_DELAY_SECONDS)
	host.add_child(_note)
	place(below, false)
	hide()


## `below`(キャンセル)の真下へ置く。向きが変わったときにも呼ぶ。
func place(below: Button, portrait: bool) -> void:
	var button_size := PORTRAIT_BUTTON_SIZE if portrait else BUTTON_SIZE
	var at := Vector2(
		below.position.x + (below.size.x - button_size.x) * 0.5,
		below.position.y + below.size.y + GAP
	)
	for target: Button in [button, wait_button]:
		target.custom_minimum_size = button_size
		target.size = button_size
		target.position = at
		if portrait:
			target.add_theme_font_size_override("font_size", PORTRAIT_FONT_SIZE)
		else:
			target.remove_theme_font_size_override("font_size")
	var note_font := PORTRAIT_NOTE_FONT_SIZE if portrait else NOTE_FONT_SIZE
	var note_width := PORTRAIT_NOTE_WIDTH if portrait else NOTE_WIDTH
	_note.add_theme_font_size_override("font_size", note_font)
	_note.custom_minimum_size.x = note_width
	_note.size = Vector2(note_width, note_font * 2.0)
	_note.position = Vector2(
		at.x + (button_size.x - note_width) * 0.5, at.y + button_size.y + GAP * 0.5
	)


## 待機を始めたとき。`delay` 秒たっても隠されなければCPU戦を始める。
func start_auto(delay: float) -> void:
	hide()
	var serial := _serial
	wait_button.disabled = false
	wait_button.visible = true
	_note.visible = true
	await _host.get_tree().create_timer(delay).timeout
	if serial != _serial:
		return
	hide()
	requested.emit()


func arm(delay: float) -> void:
	hide()
	var serial := _serial
	if delay > 0.0:
		await _host.get_tree().create_timer(delay).timeout
	if serial == _serial:
		button.disabled = false
		button.visible = true


func hide() -> void:
	_serial += 1
	button.visible = false
	wait_button.visible = false
	_note.visible = false


## CPUのデッキを読む間に二度押しされないよう、押したら止めておく。
func _on_pressed() -> void:
	button.disabled = true
	requested.emit()


func _on_wait_pressed() -> void:
	arm(0.0)
