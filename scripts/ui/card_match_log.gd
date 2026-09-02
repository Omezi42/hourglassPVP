class_name CardMatchLog
extends Control
## 対局ログ(GameDesign.md 9章)。`MatchState` のシグナルを購読して日本語の行を積み、
## 「ログ」ボタンで中央のモーダルとして開く。
##
## 記録と表示を1クラスに持たせているのは、**表示する文言と記録する文言を必ず同じにする**ため。
## 別々に組むと、実況に出る文と後から読み返す文がずれていく。

## 1行を積んだ。**画面上の実況はこれを購読して同じ文言を出す**
## (実況とログが食い違わないようにするため。GameDesign.md 9章)。
## `kind` は "turn" / "play" / "cast" / "flip" / "attack" / "death" / "hp" / "end"。
signal recorded(line: String, kind: String, side: int, slot: int)

const SCREEN_SIZE := Vector2(1280, 720)

const PANEL_SIZE := Vector2(720, 480)
const MAX_LINES := 200

var _lines: PackedStringArray = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _state: MatchState
var _side_labels := {MatchState.Side.A: "先手", MatchState.Side.B: "後手"}
var _last_hp := {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	size = SCREEN_SIZE
	_build()


## 自分が固定される対局(CPU戦・オンライン)では「あなた/相手」で書く。
func set_perspective(my_side: int) -> void:
	_side_labels = {my_side: "あなた", MatchState.other_side(my_side): "相手"}


func watch(state: MatchState) -> void:
	_state = state
	_last_hp = {
		MatchState.Side.A: state.hp[MatchState.Side.A],
		MatchState.Side.B: state.hp[MatchState.Side.B]
	}
	state.turn_started.connect(_on_turn_started)
	state.unit_played.connect(_on_unit_played)
	state.spell_cast.connect(_on_spell_cast)
	state.unit_flipped.connect(_on_unit_flipped)
	state.attack_performed.connect(_on_attack)
	state.unit_destroyed.connect(_on_unit_destroyed)
	state.hp_changed.connect(_on_hp_changed)
	state.turn_forfeited.connect(_on_turn_forfeited)
	state.match_ended.connect(_on_match_ended)


## 前の対局の行を捨てる。対局をまたいでログが積み重なるのを防ぐ。
## 購読していた `MatchState` は対局のたびに作り直されるため、参照も落とす。
func clear() -> void:
	_lines = []
	_state = null
	_last_hp = {}
	if visible:
		_rebuild()


func set_open(open: bool) -> void:
	visible = open
	if open:
		_rebuild()


func lines() -> PackedStringArray:
	return _lines


# --- 記録 ---------------------------------------------------------------


func record(line: String) -> void:
	_append(line, "note", -1, -1)


## 種別と場所を添えて積む。画面上の実況が「どこで起きたか」を知るために要る。
func _append(line: String, kind: String, side: int, slot: int) -> void:
	_lines.append(line)
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	if visible:
		_rebuild()
	recorded.emit(line, kind, side, slot)


func _name_of(side: int) -> String:
	return _side_labels.get(side, "?")


func _unit_name(side: int, slot: int) -> String:
	var unit: CardInstance = _state.board[side][slot]
	return "「%s」" % unit.data.display_name if unit != null else "砂時計"


func _on_turn_started(side: int) -> void:
	_append("── %sのターン ──" % _name_of(side), "turn", side, -1)


func _on_unit_played(side: int, slot: int) -> void:
	_append("%sが%sを出した" % [_name_of(side), _unit_name(side, slot)], "play", side, slot)


## 砂術は盤面へ出ないため枠を持たない(GameDesign.md 6章)。スポットライトを当てる
## 先が無いので slot は -1 にする。
func _on_spell_cast(side: int, card: CardData) -> void:
	_append("%sが「%s」を使った" % [_name_of(side), card.display_name], "cast", side, -1)


func _on_unit_flipped(side: int, slot: int) -> void:
	var unit: CardInstance = _state.board[side][slot]
	_append(
		(
			"%sが%sを反転(体力%d / 攻撃力%d)"
			% [_name_of(side), _unit_name(side, slot), unit.health, unit.attack]
		),
		"flip",
		side,
		slot
	)


func _on_attack(side: int, slot: int, target_slot: int) -> void:
	var attacker := _unit_name(side, slot)
	if target_slot < 0:
		_append(
			"%sの%sが%sへ攻撃" % [_name_of(side), attacker, _name_of(MatchState.other_side(side))],
			"attack",
			side,
			slot
		)
		return
	var foe := MatchState.other_side(side)
	_append(
		"%sの%sが%sの%sを攻撃" % [_name_of(side), attacker, _name_of(foe), _unit_name(foe, target_slot)],
		"attack",
		side,
		slot
	)


func _on_unit_destroyed(side: int, _slot: int, card: CardData) -> void:
	_append("%sの「%s」が砕けた" % [_name_of(side), card.display_name], "death", side, -1)


func _on_hp_changed(side: int, new_hp: int) -> void:
	var previous: int = _last_hp.get(side, new_hp)
	_last_hp[side] = new_hp
	var delta := previous - new_hp
	if delta > 0:
		record("%sに%dダメージ(残りHP%d)" % [_name_of(side), delta, new_hp])
	elif delta < 0:
		record("%sがHPを%d回復(残りHP%d)" % [_name_of(side), -delta, new_hp])


## 持ち時間切れは敗北ではなく手番の強制終了(GameDesign.md 5章)。何回目かを併せて出す。
## 次の手番が短くなること・連続で負けになることが、ログだけを追っても分かるようにする。
func _on_turn_forfeited(side: int, count: int) -> void:
	# 盤面には何も起きないため、**相手の時間切れは実況に出さないと読み取れない**
	# (何もせず手番が戻ってきたようにしか見えない)。種別を添えて積む。
	_append(
		"%sが持ち時間切れでターンを終了(%d回目 / %d回で敗北)" % [_name_of(side), count, MatchState.TURN_FORFEIT_LIMIT],
		"time_up",
		side,
		-1
	)


func _on_match_ended(winner: int) -> void:
	if winner < 0:
		record("引き分け(手数の上限に達した)")
		return
	record("%sの勝利(%s)" % [_name_of(winner), reason_text(_state, winner)])


## 決着の要因を1行で表す(GameDesign.md 5章)。結果パネルとログで共有する。
static func reason_text(state: MatchState, winner: int) -> String:
	var loser := MatchState.other_side(winner)
	match state.end_reason:
		MatchState.EndReason.SURRENDER:
			return "投了"
		MatchState.EndReason.TIMEOUT:
			return "持ち時間切れ"
		MatchState.EndReason.HP_DEPLETED:
			return "疲労でHPが0" if state.finished_by_fatigue else "HPが0"
	return "引き分け" if loser == winner else ""


# --- 表示 ---------------------------------------------------------------


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = (Vector2(1280, 720) - PANEL_SIZE) * 0.5
	var style: StyleBox = load("res://resources/theme/content_panel.tres")
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	# 見出しが無いと、暗幕の上に文だけが浮いていて何の一覧か分からない。
	var title := Label.new()
	title.text = "対局ログ"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	column.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	# VBoxContainer は子を横いっぱいに広げるため、明示的に中央へ縮める。
	var close := CodedButton.make("閉じる", Vector2(160, 48))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: set_open(false))
	column.add_child(close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		set_open(false)


## 新しい行が上に来るように積み直す。
func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	for i in range(_lines.size() - 1, -1, -1):
		var label := Label.new()
		label.text = _lines[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(label)
