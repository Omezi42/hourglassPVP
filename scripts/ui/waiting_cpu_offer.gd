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

var button: Button
## 自動で始めるのを止めるボタン。`button` と同じ位置に出す。
var wait_button: Button
var _note: Label
var _host: Control
## 予約を取り消すための番号。待つ間に隠されたら、時間が来ても何もしない。
var _serial := 0


func _init(host: Control, below: Button) -> void:
	_host = host
	var at := Vector2(
		below.position.x + (below.size.x - BUTTON_SIZE.x) * 0.5,
		below.position.y + below.size.y + GAP
	)
	button = CodedButton.make_in_group(
		"待っている間CPUと対戦する", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	button.pressed.connect(_on_pressed)
	host.add_child(button)
	button.position = at

	wait_button = CodedButton.make("CPUと対戦せず待つ", BUTTON_SIZE)
	wait_button.pressed.connect(_on_wait_pressed)
	host.add_child(wait_button)
	wait_button.position = at

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	_note.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	_note.text = AUTO_NOTE % int(FIRST_DELAY_SECONDS)
	host.add_child(_note)
	_note.size = Vector2(NOTE_WIDTH, NOTE_FONT_SIZE * 2.0)
	_note.position = Vector2(
		at.x + (BUTTON_SIZE.x - NOTE_WIDTH) * 0.5, at.y + BUTTON_SIZE.y + GAP * 0.5
	)
	hide()


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
