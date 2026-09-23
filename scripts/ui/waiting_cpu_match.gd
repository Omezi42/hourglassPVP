class_name WaitingCpuMatch
extends Node
## 待っている間のCPU戦(GameDesign.md 11章・Architecture.md 6.7節)の状態を持つ。
## いまCPU戦をしている待機画面(ランダム / ランク)と、知らせ(`WaitingCpuPrompt`)、
## 「このままCPUと続ける」を選んだ相手を覚える。画面の切り替えは `Main` が行う。

## 知らせで「マッチングする」が選ばれた。`Main` がCPU戦を打ち切って待機画面へ戻す。
signal match_chosen(waiting_screen: Control)

## CPU戦をしている待機画面。CPU戦をしていなければ null。
var waiting_screen: Control = null
var _prompt: WaitingCpuPrompt
var _prompt_uid := ""
## 「このままCPUと続ける」を選んだ相手。同じ相手については再び知らせない。
var _dismissed := {}


func _init(prompt: WaitingCpuPrompt) -> void:
	_prompt = prompt
	_prompt.match_pressed.connect(func() -> void: match_chosen.emit(finish()))
	_prompt.continue_pressed.connect(_on_continue_pressed)


## 待機画面のキューにCPU戦の印を立て、他の待機者の知らせを受け始める。
func begin(screen: Control) -> void:
	var queue: MatchmakingQueue = screen.queue
	if queue == null:
		return
	waiting_screen = screen
	if not queue.others_waiting.is_connected(_on_others_waiting):
		queue.others_waiting.connect(_on_others_waiting)
	queue.set_cpu_playing(true)


## CPU戦をやめる。CPU戦をしていた待機画面を返す(していなければ null)。
func finish() -> Control:
	var screen := waiting_screen
	waiting_screen = null
	_dismissed.clear()
	_prompt_uid = ""
	_prompt.close()
	return screen


## 選ぶ前に相手が待機をやめたら知らせを閉じ、まだ知らせていない相手がいれば出す。
func _on_others_waiting(uids: Array) -> void:
	if waiting_screen == null:
		return
	if _prompt.visible and not uids.has(_prompt_uid):
		_prompt.close()
	if _prompt.visible:
		return
	for uid in uids:
		if not _dismissed.has(uid):
			_prompt_uid = str(uid)
			_prompt.open()
			return


func _on_continue_pressed() -> void:
	_dismissed[_prompt_uid] = true
	_prompt.close()
