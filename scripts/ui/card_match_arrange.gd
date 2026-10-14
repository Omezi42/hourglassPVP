class_name CardMatchArrange
extends RefCounted
## 対局画面の部品を、いまの `CardMatchLayout` の座標へ置く(Architecture.md 4.7節)。
## 組み立ての最後と、向きが変わったときに呼ぶ。**置き直すだけで状態は消さない**。
## `CardMatchBuild` と同じく対局画面の private メンバを直に触る(1000行の上限のための切り出し)。


static func apply(screen: CardMatchScreen) -> void:
	var layout := screen.layout
	_place_backdrop(screen, layout)
	_place_bars(screen, layout)
	_place_rows(screen, layout)
	_place_buttons(screen, layout)
	screen._history.set_layout(layout)
	screen._status.size = layout.screen_size
	screen._status.queue_redraw()
	screen._damage_assist.place()
	screen._mulligan.apply_layout(layout)
	screen._result.apply_layout(layout)
	screen._log.apply_layout(layout)
	# 揺れの基準位置を取り直す(位置が変わった卓と駒を元の位置へ戻さないように)。
	var shaken: Array[Control] = [screen._table]
	shaken.append_array(screen._foe_slots)
	shaken.append_array(screen._own_slots)
	screen._shake.bind(shaken)
	if screen.state != null:
		screen.refresh()


static func _place_backdrop(screen: CardMatchScreen, layout: CardMatchLayout) -> void:
	for control: Control in [screen._table_glow, screen._table, screen._table_dust]:
		control.position = layout.table_rect.position
		control.size = layout.table_rect.size
	screen._hand_panel.position = layout.hand_area.position
	screen._hand_panel.size = layout.hand_area.size
	screen._action_panel.visible = layout.action_panel_rect.has_area()
	screen._action_panel.position = layout.action_panel_rect.position
	screen._action_panel.size = layout.action_panel_rect.size
	screen._action_panel.queue_redraw()
	screen._backdrop.redraw_layout(layout)


static func _place_bars(screen: CardMatchScreen, layout: CardMatchLayout) -> void:
	for bar: PlayerInfoBar in [screen._foe_bar, screen._own_bar]:
		bar.size = layout.bar_size
		bar.scale = Vector2.ONE * layout.bar_scale
		bar.stacked = layout.bar_stacked
	screen._foe_bar.position = layout.foe_bar_position
	screen._own_bar.position = layout.own_bar_position


static func _place_rows(screen: CardMatchScreen, layout: CardMatchLayout) -> void:
	for i in MatchState.BOARD_SIZE:
		var foe := screen._foe_slots[i]
		foe.position = layout.slot_position(true, i)
		foe.base_scale = layout.piece_scale * CardMatchLayout.FOE_ROW_SCALE
		foe.stat_scale = layout.stat_scale
		var own := screen._own_slots[i]
		own.position = layout.slot_position(false, i)
		own.base_scale = layout.piece_scale
		own.stat_scale = layout.stat_scale


static func _place_buttons(screen: CardMatchScreen, layout: CardMatchLayout) -> void:
	CardMatchBuild.center_on(screen._coin_button, layout.coin_center)
	CardMatchBuild.center_on(screen._end_turn_button, layout.turn_end_center)
	CardMatchBuild.center_on(screen._clock_dial, layout.clock_center)
	CardMatchBuild.center_on(screen._back_button, layout.back_center)
	screen._flip_right.place(layout.flip_right_center, layout.flip_gauge_top_center)
	CardMatchBuild.center_on(screen._log_button, layout.log_center)
	CardMatchBuild.center_on(screen._surrender_button, layout.surrender_center)
	var emote_half := Vector2.ONE * ActionColumnLayout.SMALL_DIAMETER * 0.5
	screen._emote.set_position(layout.emote_center - emote_half)
	screen._menu.apply(layout)
