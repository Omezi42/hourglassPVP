class_name CardMatchLog
extends Control
## 対局ログ(GameDesign.md 9章)。`MatchState` のシグナルを購読して日本語の行を積み、
## 「ログ」ボタンで中央のモーダルとして開く。
##
## 記録と表示を1クラスに持たせているのは、**表示する文言と記録する文言を必ず同じにする**ため。
## 別々に組むと、実況に出る文と後から読み返す文がずれていく。
##
## 表示ではカード名(「」で囲んだ部分)を色分けし、カーソルを乗せると対局中と同じ詳細パネルを出す。
## **行ごとに登場順のカードを控えておき、「」の出現順と対応させる**(名前から引き直すと、
## 同名の別版やトークンを取り違える)。

## 1行を積んだ。**画面上の実況はこれを購読して同じ文言を出す**
## (実況とログが食い違わないようにするため。GameDesign.md 9章)。
## `kind` は "turn" / "play" / "cast" / "flip" / "attack" / "death" / "hp" / "end"。
signal recorded(line: String, kind: String, side: int, slot: int)

const PANEL_SIZE := Vector2(720, 480)
const TITLE_FONT_SIZE := 24
const MAX_LINES := 200
const CARD_NAME_COLOR := UiPalette.GLOW_AMBER
const NAME_OPEN := "「"
const NAME_CLOSE := "」"

var detail: CardMatchDetail

var _lines: PackedStringArray = []
## `_lines` と同じ並びで、その行に出るカードを「」の出現順に持つ。
var _line_cards: Array[Array] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _state: MatchState
var _side_labels := {MatchState.Side.A: "先手", MatchState.Side.B: "後手"}
var _last_hp := {}
var _panel: PanelContainer
var _dim: ColorRect
var _title: Label
## 行の文字の大きさ(0ならテーマの既定)。縦では大きくする(`apply_layout()`)。
var _line_font_size := 0
## タッチでカード名を押して出している詳細のカードと、いまの押下の時点で出ていたカード。
var _tapped_card: CardData
var _press_card: CardData
var _hide_pending := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	_build()


## 向きに合わせて置き直す(`CardMatchArrange`)。縦は画面をほぼ覆い、文字を大きくする(GameDesign.md 9章)。
func apply_layout(layout: CardMatchLayout) -> void:
	size = layout.screen_size
	_dim.size = layout.screen_size
	var panel_size := layout.log_panel_size
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.position = (layout.screen_size - panel_size) * 0.5
	_line_font_size = layout.log_font_size
	if layout.log_title_font_size > 0:
		_title.add_theme_font_size_override("font_size", layout.log_title_font_size)
	else:
		_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	if visible:
		_rebuild()


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
	state.flip_right_used.connect(_on_flip_right_used)
	state.attack_performed.connect(_on_attack)
	state.unit_destroyed.connect(_on_unit_destroyed)
	state.hp_changed.connect(_on_hp_changed)
	state.turn_forfeited.connect(_on_turn_forfeited)
	state.match_ended.connect(_on_match_ended)


## 前の対局の行を捨てる。対局をまたいでログが積み重なるのを防ぐ。
## 購読していた `MatchState` は対局のたびに作り直されるため、参照も落とす。
func clear() -> void:
	_lines = []
	_line_cards = []
	_state = null
	_last_hp = {}
	if visible:
		_rebuild()


func set_open(open: bool) -> void:
	visible = open
	_tapped_card = null
	if open:
		_rebuild()
	elif detail != null:
		detail.hide_now()


func lines() -> PackedStringArray:
	return _lines


# --- 記録 ---------------------------------------------------------------


func record(line: String) -> void:
	_append(line, "note", -1, -1)


## 種別と場所を添えて積む。画面上の実況が「どこで起きたか」を知るために要る。
func _append(line: String, kind: String, side: int, slot: int, cards: Array = []) -> void:
	_lines.append(line)
	_line_cards.append(cards)
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
		_line_cards.remove_at(0)
	if visible:
		_rebuild()
	recorded.emit(line, kind, side, slot)


func _name_of(side: int) -> String:
	return _side_labels.get(side, "?")


func _unit_name(side: int, slot: int) -> String:
	var unit: CardInstance = _state.board[side][slot]
	return "「%s」" % unit.data.display_name if unit != null else "砂時計"


## `_unit_name()` が「」を付けたときだけカードを返す(付けないときに控えると出現順がずれる)。
func _unit_cards(side: int, slot: int) -> Array:
	var unit: CardInstance = _state.board[side][slot]
	return [unit.data] if unit != null else []


func _on_turn_started(side: int) -> void:
	_append("── %sのターン ──" % _name_of(side), "turn", side, -1)


func _on_unit_played(side: int, slot: int) -> void:
	_append(
		"%sが%sを出した" % [_name_of(side), _unit_name(side, slot)],
		"play",
		side,
		slot,
		_unit_cards(side, slot)
	)


## 砂術は盤面へ出ないため枠を持たない(GameDesign.md 6章)。スポットライトを当てる
## 先が無いので slot は -1 にする。
func _on_spell_cast(side: int, card: CardData) -> void:
	_append("%sが「%s」を使った" % [_name_of(side), card.display_name], "cast", side, -1, [card])


func _on_unit_flipped(side: int, slot: int) -> void:
	var unit: CardInstance = _state.board[side][slot]
	_append(
		(
			"%sが%sを反転(体力%d / 攻撃力%d)"
			% [_name_of(side), _unit_name(side, slot), unit.health, unit.attack]
		),
		"flip",
		side,
		slot,
		_unit_cards(side, slot)
	)


## 反転権(GameDesign.md 2章)。誰が使ったかと、誰の駒を反転させたかを分けて書く
## (自分の駒に使った場合は持ち主を重ねて言わない)。
func _on_flip_right_used(actor_side: int, target_side: int, slot: int) -> void:
	var unit: CardInstance = _state.board[target_side][slot]
	var name := _unit_name(target_side, slot)
	var described := name if actor_side == target_side else "%sの%s" % [_name_of(target_side), name]
	_append(
		"%sが反転権で%sを反転(体力%d / 攻撃力%d)" % [_name_of(actor_side), described, unit.health, unit.attack],
		"flip_right",
		target_side,
		slot,
		_unit_cards(target_side, slot)
	)


func _on_attack(side: int, slot: int, target_slot: int) -> void:
	var attacker := _unit_name(side, slot)
	if target_slot < 0:
		_append(
			"%sの%sが%sへ攻撃" % [_name_of(side), attacker, _name_of(MatchState.other_side(side))],
			"attack",
			side,
			slot,
			_unit_cards(side, slot)
		)
		return
	var foe := MatchState.other_side(side)
	_append(
		"%sの%sが%sの%sを攻撃" % [_name_of(side), attacker, _name_of(foe), _unit_name(foe, target_slot)],
		"attack",
		side,
		slot,
		_unit_cards(side, slot) + _unit_cards(foe, target_slot)
	)


func _on_unit_destroyed(side: int, _slot: int, card: CardData) -> void:
	_append("%sの「%s」が砕けた" % [_name_of(side), card.display_name], "death", side, -1, [card])


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
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_panel = PanelContainer.new()
	var style: StyleBox = load("res://resources/theme/content_panel.tres")
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	# 見出しが無いと、暗幕の上に文だけが浮いていて何の一覧か分からない。
	_title = Label.new()
	_title.text = "対局ログ"
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	column.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	TouchScroll.enable(_scroll)
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
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.meta_underlined = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _line_font_size > 0:
			label.add_theme_font_size_override("normal_font_size", _line_font_size)
		label.text = _markup(_lines[i], _line_cards[i])
		var cards: Array = _line_cards[i]
		label.meta_hover_started.connect(
			func(meta: Variant) -> void:
				if detail != null and not TouchInput.active:
					detail.hover_card(cards[int(meta)], true)
		)
		label.meta_hover_ended.connect(
			func(_meta: Variant) -> void:
				if detail != null and not TouchInput.active:
					detail.leave()
		)
		label.gui_input.connect(_on_line_input)
		label.meta_clicked.connect(func(meta: Variant) -> void: _on_name_tapped(cards[int(meta)]))
		_list.add_child(label)


## タッチで行を押した。名前以外なら詳細を消す(名前なら直後の `meta_clicked` が取り消す)。
## 押下と `meta_clicked` のどちらが先に届いても同じ結果になるよう、判定は遅延で行う。
func _on_line_input(event: InputEvent) -> void:
	if not TouchInput.active or not ClickArea.is_primary_click(event):
		return
	_press_card = _tapped_card
	_hide_pending = true
	_settle_tap.call_deferred()


## カード名を押した(GameDesign.md 9章「タッチでの操作」)。同じ名前の2度押しで消す。
func _on_name_tapped(card: CardData) -> void:
	if not TouchInput.active or detail == null:
		return
	_hide_pending = false
	if card == _press_card:
		_tapped_card = null
		detail.hide_now()
		return
	_tapped_card = card
	detail.hover_card(card, true)


func _settle_tap() -> void:
	if not _hide_pending:
		return
	_hide_pending = false
	_tapped_card = null
	if detail != null:
		detail.hide_now()


## 「」で囲んだカード名を、出現順に `cards` と対応させて色付きのリンクにする。
## 控えより多い「」(カード以外の引用)は色を付けずにそのまま出す。
func _markup(line: String, cards: Array) -> String:
	var out := ""
	var rest := line
	var index := 0
	while index < cards.size():
		var open := rest.find(NAME_OPEN)
		var close := rest.find(NAME_CLOSE, open + 1)
		if open < 0 or close < 0:
			break
		var card_name := rest.substr(open, close - open + 1)
		out += _escape(rest.left(open))
		out += (
			"[url=%d][color=#%s]%s[/color][/url]"
			% [index, CARD_NAME_COLOR.to_html(false), _escape(card_name)]
		)
		rest = rest.substr(close + 1)
		index += 1
	return out + _escape(rest)


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
