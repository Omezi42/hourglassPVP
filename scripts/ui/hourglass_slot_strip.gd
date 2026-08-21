class_name HourglassSlotStrip
extends HBoxContainer
## HPバー横に置く、片方のプレイヤーの砂時計5個をまとめて表示するコンポーネント
## (GameDesign.md 9章「対局画面ではHPバーの横に5個分のスロットを設け」に対応)。
##
## 対局フェーズでは、先頭 GameState.BOARD_SIZE 枠は場に出ている駒の参照専用ゴースト表示、
## 続く GameState.BENCH_SIZE 枠が実際の控えで、交代アクションの起点になる。
##
## 配置フェーズでは、5枠すべてを対等な「未配置の手札」として扱う(show_placement_hand())。
## 場へ配置済みの駒はこのストリップから消え、GameBoardの自分の場3マス側に表示が移る。

signal bench_pressed(bench_index: int)
signal placement_slot_pressed(index: int)
## 配置フェーズ中の効果詳細表示(GameDesign.md 9章)用。自分の手札・相手の公開手札の
## どちらでも、駒が表示されているスロットのクリックで発火する(HourglassSlot.info_requested
## をそのまま転送するだけで、選択操作の可否には関わらない)。
signal info_requested(index: int)

var _placement_mode := false

@onready var slots: Array[HourglassSlot] = [$Deployed0, $Deployed1, $Deployed2, $Bench0, $Bench1]


func _ready() -> void:
	for i in range(slots.size()):
		slots[i].slot_pressed.connect(_on_slot_pressed.bind(i))
		slots[i].info_requested.connect(_on_slot_info_requested.bind(i))
	_apply_match_mode()


## 対局フェーズの既定の見た目(場3枠=参照専用ゴースト、控え2枠=交代の起点)に戻す。
func _apply_match_mode() -> void:
	for i in range(GameState.BOARD_SIZE):
		slots[i].set_interactive(false)
	for i in range(GameState.BENCH_SIZE):
		slots[GameState.BOARD_SIZE + i].set_bench_mode(true)


func _on_slot_pressed(index: int) -> void:
	if _placement_mode:
		placement_slot_pressed.emit(index)
	elif index >= GameState.BOARD_SIZE:
		bench_pressed.emit(index - GameState.BOARD_SIZE)


func _on_slot_info_requested(index: int) -> void:
	info_requested.emit(index)


func show_state(board_instances: Array, bench_instances: Array) -> void:
	for i in range(GameState.BOARD_SIZE):
		var instance: HourglassInstance = board_instances[i] if i < board_instances.size() else null
		if instance == null:
			slots[i].clear()
		else:
			slots[i].show_deployed(instance.data)
	for i in range(GameState.BENCH_SIZE):
		var instance: HourglassInstance = bench_instances[i] if i < bench_instances.size() else null
		var slot := slots[GameState.BOARD_SIZE + i]
		if instance == null:
			slot.clear()
		else:
			slot.show_instance(instance)


## selected_index が -1 のときは、控えのどの駒も選択されていない扱いにする。
func set_selected_bench_index(selected_index: int) -> void:
	for i in range(GameState.BENCH_SIZE):
		slots[GameState.BOARD_SIZE + i].set_selected(i == selected_index)


## 場側の3枠は参照専用(押しても何も起きない)のため、操作可否の伝播は控え2枠のみに行う。
## 交代スキルの対象選択中、控え2枠を点滅ハイライトする(GameDesign.md 9章)。
## 盤面の移動先候補と同じ表現を流用する。
func show_swap_targets(active: bool) -> void:
	for i in range(GameState.BOARD_SIZE, slots.size()):
		slots[i].set_move_target(active)


func set_interactive(interactive: bool, reject_feedback: bool = false) -> void:
	for i in range(GameState.BENCH_SIZE):
		slots[GameState.BOARD_SIZE + i].set_interactive(interactive, reject_feedback)


## ActionMenuを控えの駒の近くへ出すための矩形。bench_indexはGameState.swap_in()に渡す
## 番号(0/1)と同じ意味を持つ(このスロット配列上ではBOARD_SIZE分オフセットしている)。
func get_bench_slot_rect(bench_index: int) -> Rect2:
	var slot := slots[GameState.BOARD_SIZE + bench_index]
	return Rect2(slot.global_position, slot.size)


## 配置フェーズ: deckの5枚を5枠すべてに表示する。placed_idsに含まれる駒は既に自分の場へ
## 配置済みのため、このストリップからは消す(空枠として表示する)。selected_idが一致する
## 駒には選択中の枠を出す。
func show_placement_hand(
	deck: Array[HourglassData], placed_ids: Array[String], selected_id: String = ""
) -> void:
	_placement_mode = true
	for i in range(slots.size()):
		if i >= deck.size() or placed_ids.has(deck[i].id):
			slots[i].clear()
			continue
		slots[i].set_bench_mode(false)
		slots[i].show_placement_card(deck[i])
		slots[i].set_selected(deck[i].id == selected_id)


func set_placement_interactive(interactive: bool) -> void:
	for slot in slots:
		slot.set_interactive(interactive)


## 配置フェーズから対局フェーズへ移る際に呼び、通常モードの見た目・操作可否へ戻す。
func exit_placement_mode() -> void:
	_placement_mode = false
	_apply_match_mode()
