class_name BoardRow
## テーブル上の台座位置に合わせて3枠を絶対座標で配置するため、HBoxContainerではなく
## Controlを使う(奥列/手前列でサイズ・間隔を個別に持たせるため)。
extends Control

signal position_pressed(position: int)
## 対局中の効果詳細表示(GameDesign.md 9章)用。position_pressedとは独立して発火する。
signal info_requested(position: int)

@onready var slots: Array[HourglassSlot] = [$Left, $Center, $Right]


func _ready() -> void:
	for i in range(slots.size()):
		slots[i].slot_pressed.connect(_on_slot_pressed.bind(i))
		slots[i].info_requested.connect(_on_slot_info_requested.bind(i))


func show_board(board_instances: Array) -> void:
	for i in range(slots.size()):
		var instance: HourglassInstance = board_instances[i] if i < board_instances.size() else null
		if instance == null:
			slots[i].clear()
		else:
			slots[i].show_instance(instance)


## 配置フェーズ用。placedはサイズ3固定を想定し、null要素は空マス(配置先候補)として表示する。
## 空マスはclear()(非表示)ではなくshow_placement_empty()で表示したままにし、配置候補で
## あることをハイライトで示す(J-15。非表示のままだとクリックも届かないため)。
## どのマスに置くかが初期状態の選択そのものであるため(GameDesign.md 5章)、空マス・配置済み
## マスのどちらにもそのマスの初期状態(GameState.START_STATES)を渡し、状態名とイラストで示す。
func show_placement(placed: Array) -> void:
	for i in range(slots.size()):
		var start_state: int = -1
		if i < GameState.START_STATES.size():
			start_state = GameState.START_STATES[i]
		var data: HourglassData = placed[i] if i < placed.size() else null
		if data == null:
			slots[i].show_placement_empty(start_state)
		else:
			slots[i].set_bench_mode(false)
			slots[i].show_placement_card(data, start_state)


## selected_position が -1 のときは、この列のどの駒も選択されていない扱いにする。
func set_selected_position(selected_position: int) -> void:
	for i in range(slots.size()):
		slots[i].set_selected(i == selected_position)


func set_interactive(interactive: bool, reject_feedback: bool = false) -> void:
	for slot in slots:
		slot.set_interactive(interactive, reject_feedback)


## この行の各マスに設定された行動(GameDesign.md 4.3)を予約マークとして表示する。
## kindsは「マス番号 -> "flip"/"move"/"swap_in"」で、含まれないマスは未設定として消す。
func set_reservations(kinds: Dictionary) -> void:
	for i in range(slots.size()):
		slots[i].set_reservation(kinds.get(i, ""))


## 移動先候補として示すマス(自分の場でのみ使う)。選択中のマス以外を渡す想定。
func set_move_targets(positions: Array[int]) -> void:
	for i in range(slots.size()):
		slots[i].set_move_target(positions.has(i))


## 「落下中」の駒に、次の進行で落ちきりダメージが発生することを予告する(P-1)。
## hostileはこの行の駒がダメージを与える側(false=自分の場)か受ける側(true=相手の場)かを表す。
## suppressed_positionは反転が予約されているマス(GameDesign.md 9章)。反転すると上向きへ
## 戻ってから進行するため落下中で止まり、落ちきらないので予告を出さない。-1は予約なし。
func refresh_falling_warnings(
	board_instances: Array, hostile: bool, suppressed_position: int = -1
) -> void:
	for i in range(slots.size()):
		var instance: HourglassInstance = board_instances[i] if i < board_instances.size() else null
		var falling := instance != null and instance.state == GameEnums.HourglassState.FALLING
		slots[i].set_falling_warning(falling and i != suppressed_position, hostile)


## ターン進行の逐次演出中、この行の中でfocused_positionだけを拡大・発光させ、
## それ以外を暗く沈める(P-2)。focused_position=-1は「この行には注目対象がない」
## 扱いで、行全体を暗く沈める(注目は別の行にある場合に使う)。
func apply_spotlight(focused_position: int) -> void:
	var focused: Array[int] = []
	if focused_position >= 0:
		focused.append(focused_position)
	apply_spotlight_positions(focused)


## 行動演出(フェーズ14 S-1)用。注目させたいマスが複数ある場合(移動は入れ替わる2マスが
## 対象になる)に使う。空配列は「この行には注目対象がない」扱いで、行全体を暗く沈める。
func apply_spotlight_positions(focused_positions: Array[int]) -> void:
	for i in range(slots.size()):
		var is_focused := focused_positions.has(i)
		slots[i].set_spotlight(is_focused, not is_focused)


## 行動演出(移動/交代)用。この行のpositionの駒を、offsetぶんずらした位置から
## 定位置へ滑り込ませる(フェーズ14 S-2)。
func play_slide_in(position: int, offset: Vector2, arc_height: float = 0.0) -> void:
	if position < 0 or position >= slots.size():
		return
	slots[position].play_slide_in(offset, arc_height)


func clear_spotlight() -> void:
	for slot in slots:
		slot.clear_spotlight()


func _on_slot_pressed(position: int) -> void:
	position_pressed.emit(position)


func _on_slot_info_requested(position: int) -> void:
	info_requested.emit(position)
