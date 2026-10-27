class_name WaitingCpuOffer
extends RefCounted
## 待っている間のCPU戦の入口(GameDesign.md 11章)。ランクマッチの待機画面が持つ。
## 「待っている間CPUと対戦する」ボタンを `arm()` で出す。自動ではCPU戦を始めない。

signal requested

## キューの確認(`MatchmakingQueue.POLL_INTERVAL_SECONDS`)2回ぶんより後に出し、
## 同時に待っている人どうしが先に出会えるようにする。
const FIRST_DELAY_SECONDS := 5.0
const BUTTON_SIZE := Vector2(360, 64)
## キャンセルボタンとの間隔。
const GAP := 16.0
## 縦画面(GameDesign.md 9章「縦画面」)。ボタンを指で押せる背丈にする。
const PORTRAIT_BUTTON_SIZE := Vector2(480, 80)
const PORTRAIT_FONT_SIZE := 26

var button: Button
var _host: Control
## 予約を取り消すための番号。待つ間に隠されたら、時間が来ても出さない。
var _serial := 0


func _init(host: Control, below: Button) -> void:
	_host = host
	button = CodedButton.make_in_group(
		"待っている間CPUと対戦する", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	button.pressed.connect(_on_pressed)
	host.add_child(button)
	place(below, false)
	hide()


## `below`(キャンセル)の真下へ置く。向きが変わったときにも呼ぶ。
func place(below: Button, portrait: bool) -> void:
	var button_size := PORTRAIT_BUTTON_SIZE if portrait else BUTTON_SIZE
	button.custom_minimum_size = button_size
	button.size = button_size
	button.position = Vector2(
		below.position.x + (below.size.x - button_size.x) * 0.5,
		below.position.y + below.size.y + GAP
	)
	if portrait:
		button.add_theme_font_size_override("font_size", PORTRAIT_FONT_SIZE)
	else:
		button.remove_theme_font_size_override("font_size")


## `delay` 秒たっても隠されなければボタンを出す。
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


## CPUのデッキを読む間に二度押しされないよう、押したら止めておく。
func _on_pressed() -> void:
	button.disabled = true
	requested.emit()
