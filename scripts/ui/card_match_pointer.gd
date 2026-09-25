class_name CardMatchPointer
extends RefCounted
## ポインタの受け口(Architecture.md 4.0節)。駒へのホバーを詳細・手札の並び・対象の光・
## マナのピップ・攻撃の予測へ配り、右クリックとEscで選択を取り消す(GameDesign.md 9章)。
## 押す/ドラッグする操作は `CardMatchTouch` が持つ。
## 切り出した他の進行役と同じく、画面の私設メンバを直に触る。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 詳細などは `_build()` の途中で作るため、駒より後に用意される。呼ばれた時点の参照を読む
## (生成時に束ねると、まだ空の参照を掴む)。
func on_view_hovered(view: CardView) -> void:
	var s := _screen
	if s._detail != null:
		s._detail.hover(view)
	if s._hand_layout != null:
		s._hand_layout.on_hovered(view)
	if s._targets != null:
		s._targets.on_hovered(view)
	# 手札の札にカーソルを乗せている間、支払うぶんのマナのピップを脈打たせる
	# (GameDesign.md 9章「対局画面の手触り」)。
	if view.mode == CardView.Mode.HAND and view.card != null:
		s._own_bar.highlight_cost(view.card.cost)
	var foe_slot := s._foe_slots.find(view)
	if foe_slot >= 0:
		set_hover_target(foe_slot)


func on_view_left() -> void:
	var s := _screen
	if s._detail != null:
		s._detail.leave()
	if s._hand_layout != null:
		s._hand_layout.on_left()
	if s._targets != null:
		s._targets.on_left()
	s._own_bar.highlight_cost(0)
	set_hover_target(CardMatchSelection.NO_HOVER)


## 攻撃の予測で「いま指している相手」を切り替える(GameDesign.md 9章)。
## 相手の駒・相手のHP帯へ入ったときと、そこから出たときに呼ぶ。
func set_hover_target(target: int) -> void:
	var s := _screen
	if s._selection == null or s._selection.hover_target == target:
		return
	s._selection.hover(target)
	if s.state != null and s._selection.is_board_selection():
		s._targets.refresh_own_preview()


## 選択は右クリックとEscでも取り消せるようにする(GameDesign.md 9章)。
## 「他を押す」以外に戻る手段が無いと、対象選択に入った後の抜け方が分からない。
func on_unhandled_input(event: InputEvent) -> void:
	var s := _screen
	if not s._interactive:
		return
	var cancelled := event.is_action_pressed("ui_cancel")
	if not cancelled and event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		cancelled = click.pressed and click.button_index == MOUSE_BUTTON_RIGHT
	if not cancelled:
		return
	# エモートの選択も同じ操作で閉じる。開いたまま盤面を隠し続ける状態を作らない。
	if s._emote != null and s._emote.popup_open():
		s._emote.close_popup()
		s.get_viewport().set_input_as_handled()
		return
	if s._selection.is_empty():
		return
	cancel_selection()
	s.refresh()
	s.get_viewport().set_input_as_handled()


## 選択を取り消す。光っていた枠を「短く縮んで消える」動きで消してから
## `selection` をクリアする(GameDesign.md 9章「対局画面の手触り」)。**選択の完了
## (出す/攻撃/反転/砂術を撃つ)による解除は対象にしない**——そちらは選んでいた駒が
## 演出そのもので置き換わるため、フッと消える見え方にはならない。
func cancel_selection() -> void:
	var s := _screen
	for view in s._foe_slots:
		if view.selected:
			view.play_unselect()
	for view in s._own_slots:
		if view.selected:
			view.play_unselect()
	if s._selection.is_hand_selection() and s._selection.hand_index < s._hand_views.size():
		s._hand_views[s._selection.hand_index].play_unselect()
	s._selection.clear()
