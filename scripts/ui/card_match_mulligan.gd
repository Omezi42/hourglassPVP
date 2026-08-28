class_name CardMatchMulligan
extends Control
## 対局開始前のマリガン画面(GameDesign.md 2章・9章)。
## 初期手札を並べて引き直すカードを選ばせ、確定した位置を返すところまでが責務で、
## 実際の引き直しは `MatchState.mulligan()` が行う。

signal confirmed(indices: Array)

const SCREEN_SIZE := Vector2(1280, 720)
const CARD_GAP := 24.0
const CARD_ROW_Y := 172.0
## 引き直すカードは沈めて、押したことが手札の並びの中で分かるようにする。
const PICKED_SINK := 14.0

var _views: Array[CardView] = []
var _picked: Array[bool] = []
var _title: Label
var _hint: Label
var _button: Button
var _waiting := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**。コードで生成した直後(サイズ0)のノードへ使うと
	# 0サイズのまま固定され、暗幕が何も覆わない(Architecture.md 4章の既知の落とし穴)。
	size = SCREEN_SIZE
	_build()


## 初期手札を並べて開く。
func show_hand(cards: Array) -> void:
	_waiting = false
	_picked.clear()
	for view in _views:
		view.queue_free()
	_views.clear()
	var total := cards.size()
	var width := total * CardView.HAND_SIZE_PX.x + maxf(total - 1, 0) * CARD_GAP
	var left := (SCREEN_SIZE.x - width) * 0.5
	for i in total:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.position = Vector2(left + i * (CardView.HAND_SIZE_PX.x + CARD_GAP), CARD_ROW_Y)
		view.pressed.connect(_on_card_pressed)
		add_child(view)
		view.show_card(cards[i], true)
		_views.append(view)
		_picked.append(false)
	_refresh()
	visible = true


func close() -> void:
	visible = false


func _on_card_pressed(view: CardView) -> void:
	if _waiting:
		return
	var index := _views.find(view)
	if index < 0:
		return
	_picked[index] = not _picked[index]
	_refresh()


func _on_confirm_pressed() -> void:
	if _waiting:
		return
	var indices: Array = []
	for i in _picked.size():
		if _picked[i]:
			indices.append(i)
	# 相手の確定を待つ間も画面は出したままにする(何を選んだかを見返せるようにするため)。
	_waiting = true
	_refresh()
	confirmed.emit(indices)


func _refresh() -> void:
	var count := 0
	for i in _views.size():
		var view: CardView = _views[i]
		var picked: bool = _picked[i]
		if picked:
			count += 1
		view.enabled = not picked
		view.badge = "戻す" if picked else ""
		view.position.y = CARD_ROW_Y + (PICKED_SINK if picked else 0.0)
		view.queue_redraw()
	if _waiting:
		_title.text = "相手を待っています"
		_hint.text = "両者が確定すると対局が始まります"
		_button.disabled = true
		_button.text = "確定しました"
		return
	_title.text = "引き直すカードを選んでください"
	_hint.text = "選んだカードは山札へ戻し、同じ枚数を引き直します"
	_button.disabled = false
	_button.text = "このままで開始" if count == 0 else "%d枚を引き直す" % count


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_title = _make_label(40, 66.0)
	_hint = _make_label(20, 124.0)

	_button = CodedButton.make("このままで開始", Vector2(280, 64))
	_button.position = Vector2((SCREEN_SIZE.x - 280.0) * 0.5, 368.0)
	_button.pressed.connect(_on_confirm_pressed)
	add_child(_button)


func _make_label(font_size: int, top: float) -> Label:
	var label := Label.new()
	label.position = Vector2(0, top)
	label.size = Vector2(SCREEN_SIZE.x, font_size + 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
