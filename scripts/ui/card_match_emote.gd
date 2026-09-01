class_name CardMatchEmote
extends RefCounted
## 対局中のエモート機能(GameDesign.md 9章、Architecture.md 6.6)。
## ボタン・ポップアップUI・クールダウン・相手ミュート・CPU返答を受け持つ。

const COOLDOWN_SECONDS := 9.0
const EMOTE_BUTTON_SIZE := Vector2(148, 44)
const POPUP_WIDTH := 240.0
const POPUP_PADDING := 10.0
## ポップアップとエモートボタンの間隔。
const POPUP_GAP := 8.0

var mute_opponent := false

var _screen: CardMatchScreen
var _button: Button
var _popup: PanelContainer
var _mute_btn: Button
var _popup_anchor := Vector2.ZERO
var _cooldown := 0.0


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_setup_ui()


func _setup_ui() -> void:
	_button = CodedButton.make("エモート", EMOTE_BUTTON_SIZE)
	_button.pressed.connect(_toggle_popup)
	_screen.add_child(_button)

	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.custom_minimum_size = Vector2(POPUP_WIDTH, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.07, 0.96)
	style.border_color = UiPalette.BRASS_LIGHT
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = POPUP_PADDING
	style.content_margin_top = POPUP_PADDING
	style.content_margin_right = POPUP_PADDING
	style.content_margin_bottom = POPUP_PADDING
	_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = "◆ メッセージ選択 ◆"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	vbox.add_child(header)

	var hsep := HSeparator.new()
	vbox.add_child(hsep)

	for emote_id in EmoteLibrary.get_emote_ids():
		var item := EmoteItemButton.new(emote_id)
		item.pressed.connect(func() -> void: _on_emote_selected(emote_id))
		vbox.add_child(item)

	var hsep2 := HSeparator.new()
	vbox.add_child(hsep2)

	# 既定のボタンは真鍮の面で塗られるため、ミュートしていない状態のほうが強調されて
	# 見えてしまう。選択肢と同じ平坦な見た目にして、状態は文言と色だけで示す。
	_mute_btn = Button.new()
	_mute_btn.flat = true
	_mute_btn.custom_minimum_size = Vector2(POPUP_WIDTH - POPUP_PADDING * 2.0, 28.0)
	_mute_btn.add_theme_font_size_override("font_size", 12)
	_mute_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mute_btn.pressed.connect(_toggle_mute)
	_update_mute_button_text()
	vbox.add_child(_mute_btn)

	_popup.add_child(vbox)
	_screen.add_child(_popup)


## エモートのボタンと、その上へ開くポップアップの位置。**ポップアップは下端をボタンの
## 上へ合わせる**(上端を固定すると、選択肢を足したときに情報帯・手札まで伸びる)。
func set_position(btn_pos: Vector2) -> void:
	if _button != null:
		_button.position = btn_pos
	_popup_anchor = btn_pos
	_place_popup()


func _place_popup() -> void:
	if _popup == null:
		return
	var height: float = maxf(_popup.get_combined_minimum_size().y, _popup.size.y)
	_popup.position = Vector2(
		_popup_anchor.x - POPUP_WIDTH - 12.0, _popup_anchor.y - height - POPUP_GAP
	)


func popup_open() -> bool:
	return _popup != null and _popup.visible


func refresh() -> void:
	var pending_mulligan: bool = _screen.state != null and _screen.state.mulligan_pending
	var over: bool = _screen.state == null or _screen.state.is_match_over()
	var can_use: bool = _screen.interactive and not over and not pending_mulligan
	# エモートのUIは対局画面より後に足されるため、結果パネル・ログより手前に描かれる。
	# 終局後と読み返しの間は隠して、そちらの操作を塞がないようにする。
	_button.visible = _screen.interactive and not over
	if not _button.visible:
		_popup.visible = false
		return
	if pending_mulligan:
		_button.text = "エモート"
		_button.disabled = true
		if _popup.visible:
			_popup.visible = false
		return

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
	var pending_mulligan: bool = _screen.state != null and _screen.state.mulligan_pending
	if _cooldown > 0.0 or not _screen.interactive or pending_mulligan:
		_popup.visible = false
		return
	_popup.visible = not _popup.visible
	if _popup.visible:
		_place_popup()


func _toggle_mute() -> void:
	mute_opponent = not mute_opponent
	_update_mute_button_text()


func _update_mute_button_text() -> void:
	if _mute_btn != null:
		if mute_opponent:
			_mute_btn.text = "相手エモート: ミュート中"
			_mute_btn.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
		else:
			_mute_btn.text = "相手エモート: 受信中"
			_mute_btn.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)


func close_popup() -> void:
	if _popup != null:
		_popup.visible = false


func _on_emote_selected(emote_id: String) -> void:
	close_popup()
	var pending_mulligan: bool = _screen.state != null and _screen.state.mulligan_pending
	if _cooldown > 0.0 or not _screen.interactive or pending_mulligan:
		return
	_cooldown = COOLDOWN_SECONDS
	refresh()
	var action := MatchAction.emote(_screen.my_side, emote_id)
	_screen._perform(action)
	handle_emote(action)
	_maybe_cpu_reply()


func handle_emote(action: Dictionary) -> void:
	var side: int = int(action.get("side", -1))
	var is_foe := side != _screen.my_side
	if is_foe and mute_opponent:
		return

	var emote_id: String = str(action.get("emote_id", ""))
	var text := EmoteLibrary.get_emote_text(emote_id)
	if text.is_empty():
		return
	var bar: PlayerInfoBar = _screen._foe_bar if is_foe else _screen._own_bar
	if bar != null:
		bar.show_emote(text)


func _maybe_cpu_reply() -> void:
	if _screen._cpu == null or _screen.state == null or _screen.state.is_match_over():
		return
	if mute_opponent:
		return
	if randf() < 0.35:
		var ids := EmoteLibrary.get_emote_ids()
		var reply_id: String = ids[randi() % ids.size()]
		var reply_text := EmoteLibrary.get_emote_text(reply_id)
		var timer := _screen.get_tree().create_timer(1.6)
		timer.timeout.connect(
			func() -> void:
				if (
					_screen.state != null
					and not _screen.state.is_match_over()
					and _screen._foe_bar != null
					and not mute_opponent
				):
					_screen._foe_bar.show_emote(reply_text)
		)


## エモート選択用カスタムボタン
class EmoteItemButton:
	extends Button
	var emote_id: String
	var _font: Font

	func _init(p_emote_id: String) -> void:
		emote_id = p_emote_id
		custom_minimum_size = Vector2(POPUP_WIDTH - POPUP_PADDING * 2.0, 36.0)
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _ready() -> void:
		_font = get_theme_default_font()
		if _font == null:
			_font = ThemeDB.fallback_font

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, 4.0, 4)
		var hovered := is_hovered()
		var bg_top := Color(0.2, 0.17, 0.14, 0.95) if hovered else Color(0.12, 0.1, 0.08, 0.9)
		var bg_bottom := Color(0.12, 0.1, 0.08, 0.95) if hovered else Color(0.06, 0.05, 0.04, 0.9)
		UiPaint.fill_gradient_polygon(
			get_canvas_item(), points, rect, [[0.0, bg_top], [1.0, bg_bottom]]
		)

		var outline := points.duplicate()
		outline.append(points[0])
		var border_color := UiPalette.GLOW_AMBER if hovered else UiPalette.BRASS_MID
		draw_polyline(outline, border_color, 1.2, true)

		if _font == null:
			return
		var text := EmoteLibrary.get_emote_text(emote_id)
		var text_color := UiPalette.BRASS_HIGHLIGHT if hovered else UiPalette.TEXT_OFFWHITE
		draw_string(
			_font, Vector2(10, size.y - 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_color
		)
