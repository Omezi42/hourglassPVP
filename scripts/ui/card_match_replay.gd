class_name CardMatchReplay
extends Control
## リプレイの再生(GameDesign.md 12章)。棋譜は「両者のデッキ・山札の種・手の並び」で、
## **任意の手数の局面は、初期状態から手を並べ直して作る**。
##
## v5.0では山札のシャッフルが種から決まるため、巻き戻しは差分を戻すのではなく
## 毎回作り直せばよい(局面のスナップショットを持たなくて済む)。

signal state_rebuilt(state: MatchState)

const PLAY_INTERVAL := 0.8
const BUTTON_SIZE := Vector2(70, 40)
## 再生コントロールの置き場所。手札の上に重ねないよう、対局中の行動ボタンと同じ
## 画面右の列(x=1108、幅148)へ2列で並べる(再生中は行動ボタンを出さないため空いている)。
const CONTROL_POSITION := Vector2(1108, 372)

var deck_a: Array = []
var deck_b: Array = []
var seed_value := 0
var actions: Array = []
var index := 0

var _row: GridContainer
var _counter: Label
var _timer: Timer
var _play_button: Button


func _ready() -> void:
	visible = false
	_build()


## 再生モードを抜ける。コントロールを隠し、自動再生のタイマーも止める。
func stop() -> void:
	visible = false
	_timer.stop()


## 保存済みの棋譜(matches/{id} と同じ形)を読み込んで先頭から再生できる状態にする。
func load_record(record: Dictionary) -> bool:
	deck_a = CardLibrary.deck_from_ids(record.get("deck_a", []))
	deck_b = CardLibrary.deck_from_ids(record.get("deck_b", []))
	seed_value = int(record.get("seed", 0))
	actions = record.get("actions", [])
	if deck_a.size() != MatchState.DECK_SIZE or deck_b.size() != MatchState.DECK_SIZE:
		return false
	visible = true
	goto(0)
	return true


## 先頭から count 手だけ進めた局面を作り直す。
func goto(count: int) -> void:
	index = clampi(count, 0, actions.size())
	var state := MatchState.new()
	add_child(state)
	state.start_match(
		deck_a,
		deck_b,
		MatchState.Side.A,
		seed_value,
		MatchState.COIN_ENABLED,
		MatchAction.contains_mulligan(actions)
	)
	for i in index:
		MatchAction.apply(state, actions[i])
	state_rebuilt.emit(state)
	_refresh()


func _refresh() -> void:
	_counter.text = "%d/%d" % [index, actions.size()]
	_play_button.text = "停止" if not _timer.is_stopped() else "再生"


func _build() -> void:
	_row = GridContainer.new()
	_row.columns = 2
	_row.add_theme_constant_override("h_separation", 8)
	_row.add_theme_constant_override("v_separation", 8)
	_row.position = CONTROL_POSITION
	add_child(_row)
	_row.add_child(_make("先頭", func() -> void: goto(0)))
	# 画面の出口(「戻る」)と紛れないよう、1手ぶんの前後は「1手戻/1手進」と書く。
	_row.add_child(_make("1手戻", func() -> void: goto(index - 1)))
	_play_button = _make("再生", _toggle_play)
	_row.add_child(_play_button)
	_row.add_child(_make("1手進", func() -> void: goto(index + 1)))
	_row.add_child(_make("最後", func() -> void: goto(actions.size())))
	_counter = Label.new()
	_counter.custom_minimum_size = Vector2(BUTTON_SIZE.x, 30)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_row.add_child(_counter)
	_timer = Timer.new()
	_timer.wait_time = PLAY_INTERVAL
	_timer.timeout.connect(_on_tick)
	add_child(_timer)


func _make(label: String, handler: Callable) -> Button:
	var button := CodedButton.make(label, BUTTON_SIZE)
	button.pressed.connect(handler)
	return button


func _toggle_play() -> void:
	if _timer.is_stopped():
		_timer.start()
	else:
		_timer.stop()
	_refresh()


func _on_tick() -> void:
	if index >= actions.size():
		_timer.stop()
		_refresh()
		return
	goto(index + 1)
