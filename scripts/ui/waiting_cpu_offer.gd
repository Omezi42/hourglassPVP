class_name WaitingCpuOffer
extends RefCounted
## 待機画面の「待っている間CPUと対戦する」ボタン(GameDesign.md 11章)。
## ランクマッチの待機画面が持つ。人を待つ前にCPUへ流れないよう、
## 待機を始めてから少し置いて出す。

signal requested

## キューの確認(`MatchmakingQueue.POLL_INTERVAL_SECONDS`)2回ぶんより後に出し、
## 同時に待っている人どうしが先に出会えるようにする。
const FIRST_DELAY_SECONDS := 5.0
const BUTTON_SIZE := Vector2(360, 64)
## キャンセルボタンとの間隔。
const GAP := 16.0

var button: Button
var _host: Control
## 出す予約を取り消すための番号。待つ間に隠されたら、時間が来ても出さない。
var _serial := 0


func _init(host: Control, below: Button) -> void:
	_host = host
	button = CodedButton.make_in_group(
		"待っている間CPUと対戦する", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	button.visible = false
	button.pressed.connect(_on_pressed)
	host.add_child(button)
	button.position = Vector2(
		below.position.x + (below.size.x - BUTTON_SIZE.x) * 0.5,
		below.position.y + below.size.y + GAP
	)


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
