class_name CardMatchMulligan
extends Control
## 対局開始前のマリガン画面(GameDesign.md 2章・9章)。
## 初期手札を並べて引き直すカードを選ばせ、確定した位置を返すところまでが責務で、
## 実際の引き直しは `MatchState.mulligan()` が行う。

signal confirmed(indices: Array)

const SCREEN_SIZE := Vector2(1280, 720)
## 初期手札は対局の手札より大きく並べ、効果の文まで読めるようにする(詳細パネルはマリガン中に出さない)。
const CARD_SIZE := CardView.HAND_SIZE_PX * 1.35
const CARD_GAP := 28.0
## 見出しから確定ボタンまでの一群を画面の縦の中ほどへ置く。誘導対局ではこの下へ帯が入る
## (`CardMatchTutorial.MULLIGAN_BAND_TOP` は `BUTTON_Y` から決まる)。
const CONTENT_TOP := 110.0
const TURN_ORDER_Y := CONTENT_TOP
const TITLE_Y := CONTENT_TOP + 32.0
const HINT_Y := CONTENT_TOP + 90.0
const CARD_ROW_Y := CONTENT_TOP + 152.0
const BUTTON_SIZE := Vector2(280, 60)
const BUTTON_Y := CONTENT_TOP + 410.0
## 札の列の後ろの光だまりが、列の左右と上下へはみ出す量。
const STAGE_MARGIN := Vector2(150, 70)
## 引き直すカードは沈めて、押したことが手札の並びの中で分かるようにする。
const PICKED_SINK := 18.0
const PICK_DURATION := 0.14
## 開いた瞬間、手札が配られるように下から浮き上がってくる距離と間隔。
const DEAL_RISE := 46.0
const DEAL_DURATION := 0.32
const DEAL_STAGGER := 0.05
const DIM_FADE_DURATION := 0.3

## 誘導対局の間は札を選べない(GameDesign.md 18章)。「このままで開始」だけを受け付ける。
var picking_disabled := false
var _views: Array[CardView] = []
var _marks: Array[MulliganPickMark] = []
var _picked: Array[bool] = []
var _title: Label
var _hint: Label
## 自分が先手か後手か(GameDesign.md 9章)。残す札の重さの判断が手番で変わるため見出しの上に出す。
var _turn_order: Label
var _button: Button
var _waiting := false
var _dim: ColorRect
var _stage: MulliganStageLight
var _tween: Tween
var _pick_tweens: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**。コードで生成した直後(サイズ0)のノードへ使うと
	# 0サイズのまま固定され、暗幕が何も覆わない(Architecture.md 4章の既知の落とし穴)。
	size = SCREEN_SIZE
	_build()


## 初期手札を並べて開く。`has_coin` は後手がコインを持って始めるか(2章)。
func show_hand(cards: Array, is_first: bool, has_coin: bool) -> void:
	if is_first:
		_turn_order.text = "あなたは先手です"
	else:
		_turn_order.text = "あなたは後手です" + ("(コイン1枚)" if has_coin else "")
	_waiting = false
	_picked.clear()
	for view in _views:
		view.queue_free()
	_views.clear()
	_marks.clear()
	_pick_tweens.clear()
	var total := cards.size()
	var width := total * CARD_SIZE.x + maxf(total - 1, 0) * CARD_GAP
	var left := (SCREEN_SIZE.x - width) * 0.5
	_stage.position = Vector2(left, CARD_ROW_Y) - STAGE_MARGIN
	_stage.size = Vector2(width, CARD_SIZE.y) + STAGE_MARGIN * 2.0
	_stage.queue_redraw()
	for i in total:
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.position = Vector2(left + i * (CARD_SIZE.x + CARD_GAP), CARD_ROW_Y)
		view.pressed.connect(_on_card_pressed)
		add_child(view)
		view.show_card(cards[i], true)
		view.size = CARD_SIZE
		# 裏返した印は絵の窓の中央へ重ねる。
		var mark := MulliganPickMark.new()
		view.add_child(mark)
		mark.position = view._hand_art_box().get_center() - mark.size * 0.5
		_views.append(view)
		_marks.append(mark)
		_picked.append(false)
	_refresh(false)
	visible = true
	_start_entrance()


## **手札が配られるように**下から浮き上がらせる(GameDesign.md 9章の
## 「場に出した砂時計は台座の少し上から落ちて着地する」と同じ思想を、
## 対局の入口であるマリガンにも及ぼす)。暗幕もあわせてフェードインさせ、
## 唐突に画面が切り替わったように見せない。
func _start_entrance() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_dim.modulate.a = 0.0
	_tween.tween_property(_dim, "modulate:a", 1.0, DIM_FADE_DURATION)
	_stage.modulate.a = 0.0
	_tween.tween_property(_stage, "modulate:a", 1.0, DIM_FADE_DURATION)
	_title.modulate.a = 0.0
	_turn_order.modulate.a = 0.0
	_tween.tween_property(_turn_order, "modulate:a", 1.0, DIM_FADE_DURATION)
	_hint.modulate.a = 0.0
	_tween.tween_property(_title, "modulate:a", 1.0, DIM_FADE_DURATION)
	_tween.tween_property(_hint, "modulate:a", 1.0, DIM_FADE_DURATION)
	for i in _views.size():
		var view: CardView = _views[i]
		var target_y := view.position.y
		view.position.y = target_y + DEAL_RISE
		view.modulate.a = 0.0
		(
			_tween
			. tween_property(view, "position:y", target_y, DEAL_DURATION)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
			. set_delay(i * DEAL_STAGGER)
		)
		_tween.tween_property(view, "modulate:a", 1.0, DEAL_DURATION).set_delay(i * DEAL_STAGGER)


func close() -> void:
	visible = false


func _on_card_pressed(view: CardView) -> void:
	if _waiting or picking_disabled:
		return
	var index := _views.find(view)
	if index < 0:
		return
	_picked[index] = not _picked[index]
	_refresh()


## 確定ボタンの位置。誘導対局が押す場所として囲む(GameDesign.md 18章)。
func confirm_rect() -> Rect2:
	return _button.get_global_rect()


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


## `animate` が false のときは沈み具合を即座に合わせる(開いた直後は配る演出が位置を動かすため)。
func _refresh(animate: bool = true) -> void:
	var count := 0
	for i in _views.size():
		var view: CardView = _views[i]
		var picked: bool = _picked[i]
		if picked:
			count += 1
		view.enabled = not picked
		view.badge = "戻す" if picked else ""
		_marks[i].set_shown(picked)
		var target_y := CARD_ROW_Y + (PICKED_SINK if picked else 0.0)
		if animate:
			_sink(view, target_y)
		view.queue_redraw()
	if _waiting:
		_title.text = "相手を待っています"
		_hint.text = "両者が確定すると対局が始まります"
		_button.disabled = true
		_button.text = "確定しました"
		return
	_title.text = "引き直すカードを選んでください"
	_hint.text = ("すなえるの指示に従って、そのまま開始してください" if picking_disabled else "選んだカードは山札へ戻し、同じ枚数を引き直します")
	_button.disabled = false
	_button.text = "このままで開始" if count == 0 else "%d枚を引き直す" % count


## 選んだ札を沈める / 戻す。押した瞬間に位置が飛ぶと、どの札が動いたのか目で追えない。
func _sink(view: CardView, target_y: float) -> void:
	var running: Tween = _pick_tweens.get(view)
	if running != null and running.is_valid():
		running.kill()
	var tween := create_tween()
	(
		tween
		. tween_property(view, "position:y", target_y, PICK_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_pick_tweens[view] = tween


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.78)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_stage = MulliganStageLight.new()
	add_child(_stage)

	_turn_order = _make_label(22, TURN_ORDER_Y)
	_turn_order.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	_title = _make_label(40, TITLE_Y)
	_hint = _make_label(20, HINT_Y)
	_hint.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)

	_button = CodedButton.make("このままで開始", BUTTON_SIZE)
	_button.position = Vector2((SCREEN_SIZE.x - BUTTON_SIZE.x) * 0.5, BUTTON_Y)
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
