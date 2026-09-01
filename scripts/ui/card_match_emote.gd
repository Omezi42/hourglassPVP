class_name CardMatchEmote
extends RefCounted
## 対局中のエモート機能(GameDesign.md 9章、Architecture.md 6.6)。
## ボタン・ポップアップUI・クールダウン・CPU返答を受け持つ。

const COOLDOWN_SECONDS := 3.0
const EMOTE_BUTTON_SIZE := Vector2(148, 44)
const POPUP_WIDTH := 220.0
const POPUP_MARGIN := 10.0

var _screen: CardMatchScreen
var _button: Button
var _popup: PanelContainer
var _cooldown := 0.0


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_setup_ui()


func _setup_ui() -> void:
	_button = _screen._add_button("エモート", EMOTE_BUTTON_SIZE)
	_button.position = Vector2(
		CardMatchScreen.ACTION_COLUMN_X, CardMatchScreen.LOG_BUTTON_TOP - 52.0
	)
	_button.pressed.connect(_toggle_popup)

	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	_popup.position = Vector2(
		CardMatchScreen.ACTION_COLUMN_X - POPUP_WIDTH - 8.0,
		CardMatchScreen.LOG_BUTTON_TOP - 168.0
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = UiPalette.BRASS_LIGHT
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = POPUP_MARGIN
	style.content_margin_top = POPUP_MARGIN
	style.content_margin_right = POPUP_MARGIN
	style.content_margin_bottom = POPUP_MARGIN
	_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	for emote_id in EmoteLibrary.get_emote_ids():
		var text := EmoteLibrary.get_emote_text(emote_id)
		var btn := Button.new()
		btn.text = text
		btn.add_theme_font_size_override("font_size", 13)
		btn.custom_minimum_size = Vector2(POPUP_WIDTH - POPUP_MARGIN * 2.0, 32.0)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void: _on_emote_selected(emote_id))
		vbox.add_child(btn)

	_popup.add_child(vbox)
	_screen.add_child(_popup)


func refresh() -> void:
	var can_use: bool = (
		_screen.interactive and _screen.state != null and not _screen.state.is_match_over()
	)
	_button.visible = _screen.interactive
	if _cooldown > 0.0:
		_button.text = "%d秒" % int(ceilf(_cooldown))
		_button.disabled = true
	else:
		_button.text = "エモート"
		_button.disabled = not can_use
	if not can_use and _popup.visible:
		_popup.visible = false


func tick(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
		if _cooldown <= 0.0:
			refresh()
		else:
			_button.text = "%d秒" % int(ceilf(_cooldown))


func _toggle_popup() -> void:
	if _cooldown > 0.0 or not _screen.interactive:
		_popup.visible = false
		return
	_popup.visible = not _popup.visible


func close_popup() -> void:
	if _popup != null:
		_popup.visible = false


func _on_emote_selected(emote_id: String) -> void:
	close_popup()
	if _cooldown > 0.0 or not _screen.interactive:
		return
	_cooldown = COOLDOWN_SECONDS
	refresh()
	var action := MatchAction.emote(_screen.my_side, emote_id)
	_screen._perform(action)
	handle_emote(action)
	_maybe_cpu_reply()


func handle_emote(action: Dictionary) -> void:
	var side: int = int(action.get("side", -1))
	var emote_id: String = str(action.get("emote_id", ""))
	var text := EmoteLibrary.get_emote_text(emote_id)
	if text.is_empty():
		return
	var bar: PlayerInfoBar = _screen._own_bar if side == _screen.my_side else _screen._foe_bar
	if bar != null:
		bar.show_emote(text)


func _maybe_cpu_reply() -> void:
	if _screen._cpu == null or _screen.state == null or _screen.state.is_match_over():
		return
	if randf() < 0.35:
		var ids := EmoteLibrary.get_emote_ids()
		var reply_id: String = ids[randi() % ids.size()]
		var reply_text := EmoteLibrary.get_emote_text(reply_id)
		var timer := _screen.get_tree().create_timer(1.2)
		timer.timeout.connect(
			func() -> void:
				if (
					_screen.state != null
					and not _screen.state.is_match_over()
					and _screen._foe_bar != null
				):
					_screen._foe_bar.show_emote(reply_text)
		)
