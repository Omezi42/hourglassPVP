class_name CardMatchEmote
extends RefCounted
## 対局中のエモート機能(GameDesign.md 9章、Architecture.md 6.6)。
## ボタン・ポップアップUI・クールダウン・相手ミュート・CPU返答を受け持つ。

const COOLDOWN_SECONDS := 9.0
## ボタンは「ログ」「投了」と同じ寸法・同じ作り方(`CodedButton.make`)で作る。
## 数pxでも違えると、同じ列に並んだときに1つだけ別物のボタンに見える。
const EMOTE_BUTTON_SIZE := CardMatchScreen.ACTION_BUTTON_SIZE
const POPUP_WIDTH := 244.0
const POPUP_PADDING := 12.0
const POPUP_ITEM_HEIGHT := 34.0
const POPUP_ITEM_GAP := 5.0
## ポップアップとエモートボタンの間隔。
const POPUP_GAP := 8.0

var mute_opponent := false

var _screen: CardMatchScreen
var _button: Button
var _popup: EmotePopupPanel
var _mute_btn: Button
## 選択肢を入れる欄。中身は開くたびに組み直す(枠の設定は対局の外で変えられるため)。
var _items_box: VBoxContainer
var _popup_anchor := Vector2.ZERO
var _cooldown := 0.0


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_setup_ui()


func _setup_ui() -> void:
	_button = CodedButton.make("エモート", EMOTE_BUTTON_SIZE)
	_button.pressed.connect(_toggle_popup)
	_screen.add_child(_button)

	_popup = EmotePopupPanel.new()
	_popup.visible = false
	_popup.custom_minimum_size = Vector2(POPUP_WIDTH, 0)
	_screen.add_child(_popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", POPUP_ITEM_GAP)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(vbox)

	var header := Label.new()
	header.text = "エモート"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	vbox.add_child(header)
	vbox.add_child(_hairline())

	_items_box = VBoxContainer.new()
	_items_box.add_theme_constant_override("separation", POPUP_ITEM_GAP)
	_items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_items_box)

	vbox.add_child(_hairline())

	# 既定のボタンは真鍮の面で塗られるため、ミュートしていない状態のほうが強調されて
	# 見えてしまう。選択肢と同じ平坦な見た目にして、状態は印(●/○)と色だけで示す。
	_mute_btn = Button.new()
	_mute_btn.flat = true
	_mute_btn.custom_minimum_size = Vector2(0.0, 26.0)
	_mute_btn.add_theme_font_size_override("font_size", 12)
	_mute_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mute_btn.pressed.connect(_toggle_mute)
	_update_mute_button_text()
	vbox.add_child(_mute_btn)


## 区切りは `HSeparator`(テーマ既定の白い線)ではなく真鍮の細線にする。
## 対局画面の他の区切りと同じ色でないと、ここだけ別のUIから来たように見える。
func _hairline() -> Control:
	var line := ColorRect.new()
	line.color = Color(UiPalette.BRASS_MID, 0.7)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## エモートのボタンと、その上へ開くポップアップの位置。**ポップアップは下端をボタンの
## 上へ合わせる**(上端を固定すると、選択肢を足したときに情報帯・手札まで伸びる)。
func set_position(btn_pos: Vector2) -> void:
	if _button != null:
		_button.position = btn_pos
	_popup_anchor = btn_pos
	_place_popup()


## 出すのはセットしている4つだけ(GameDesign.md 9章)。所有していても枠に入って
## いないものは出さない。**開くたびに組み直す**のは、このクラスが対局画面と一緒に
## 1度だけ作られるためで、アカウント画面で枠を変えても作り直されない。
func _rebuild_items() -> void:
	for child in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	for emote_id in AccountService.emote_slots():
		var item := EmoteItemButton.new(emote_id)
		item.pressed.connect(func() -> void: _on_emote_selected(emote_id))
		_items_box.add_child(item)


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
	# **マリガンの間も出さない。**送れない以上ボタンは無効の見た目になり、真鍮のまま並ぶ
	# 「ログ」「投了」の隣でそこだけ色が違って見える(押せないボタンを置く価値もない)。
	_button.visible = _screen.interactive and not over and not pending_mulligan
	if not _button.visible:
		_popup.visible = false
		return

	if _cooldown > 0.0:
		_button.text = _cooldown_label()
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
			_button.text = _cooldown_label()


## クールダウン中も文言の頭は「エモート」のままにする。「9秒」とだけ出すと、
## 同じ列に並んだ「ログ」「投了」の中でそこだけ別のボタンへ変わったように見える。
func _cooldown_label() -> String:
	return "エモート %d" % int(ceilf(_cooldown))


func _toggle_popup() -> void:
	var pending_mulligan: bool = _screen.state != null and _screen.state.mulligan_pending
	if _cooldown > 0.0 or not _screen.interactive or pending_mulligan:
		_popup.visible = false
		return
	_popup.visible = not _popup.visible
	if _popup.visible:
		_rebuild_items()
		_place_popup()


func _toggle_mute() -> void:
	mute_opponent = not mute_opponent
	_update_mute_button_text()


func _update_mute_button_text() -> void:
	if _mute_btn != null:
		if mute_opponent:
			_mute_btn.text = "○ 相手のエモート:切"
			_mute_btn.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
		else:
			_mute_btn.text = "● 相手のエモート:入"
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
		var ids := AccountService.emote_slots()
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


## ポップアップの下地。対局画面の他のパネルと同じ質感(多段グラデーション + グレイン +
## 落ち込み影 + 真鍮の枠)で描く。テーマ既定の `PanelContainer` のままだと、
## 盤面の上でここだけ平坦なダイアログに見える。
class EmotePopupPanel:
	extends PanelContainer

	## 中身の余白だけを持つ空のスタイルにして、面そのものは `_draw()` で描く
	## (`Control._draw()` は自分の子より背面に描かれるため、選択肢の下敷きになる)。
	func _init() -> void:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = POPUP_PADDING
		empty.content_margin_top = POPUP_PADDING
		empty.content_margin_right = POPUP_PADDING
		empty.content_margin_bottom = POPUP_PADDING
		add_theme_stylebox_override("panel", empty)

	func _draw() -> void:
		var ci := get_canvas_item()
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 6)
		UiPaint.fill_gradient_polygon(
			ci,
			points,
			rect,
			[
				[0.0, Color(0.17, 0.14, 0.11, 0.98)],
				[0.5, Color(0.10, 0.08, 0.07, 0.98)],
				[1.0, Color(0.07, 0.055, 0.05, 0.98)]
			]
		)
		UiPaint.apply_grain(ci, rect, 0.07)
		UiPaint.draw_inner_shadow(ci, rect, 8.0, 6, 4, UiPalette.OUTLINE_DARK, 0.5)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, UiPalette.OUTLINE_DARK, 3.0, true)
		draw_polyline(outline, UiPalette.BRASS_LIGHT, 1.4, true)


## エモート選択用カスタムボタン
class EmoteItemButton:
	extends Button
	var emote_id: String
	var _font: Font

	func _init(p_emote_id: String) -> void:
		emote_id = p_emote_id
		custom_minimum_size = Vector2(0.0, POPUP_ITEM_HEIGHT)
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _ready() -> void:
		_font = get_theme_default_font()
		if _font == null:
			_font = ThemeDB.fallback_font

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var points := UiPaint.rounded_rect_points_uniform(rect, 5.0, 4)
		var hovered := is_hovered()
		var ci := get_canvas_item()
		var top := Color(0.26, 0.20, 0.14, 0.98) if hovered else Color(0.14, 0.115, 0.095, 0.9)
		var bottom := Color(0.16, 0.12, 0.09, 0.98) if hovered else Color(0.08, 0.065, 0.055, 0.9)
		UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top], [1.0, bottom]])

		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, UiPalette.GLOW_AMBER if hovered else UiPalette.BRASS_MID, 1.2, true)

		# 行頭の菱形。選べる行であることを、文字ではなく形で示す。
		var mark := Vector2(13.0, size.y * 0.5)
		var r := 3.4
		var diamond := PackedVector2Array(
			[
				mark + Vector2(0.0, -r),
				mark + Vector2(r, 0.0),
				mark + Vector2(0.0, r),
				mark + Vector2(-r, 0.0)
			]
		)
		var mark_color := UiPalette.GLOW_AMBER if hovered else UiPalette.BRASS_MID
		draw_colored_polygon(diamond, mark_color)

		if _font == null:
			return
		var text := EmoteLibrary.get_emote_text(emote_id)
		var text_color := UiPalette.BRASS_HIGHLIGHT if hovered else UiPalette.TEXT_OFFWHITE
		var baseline := (size.y + float(_font.get_ascent(13)) - float(_font.get_descent(13))) * 0.5
		draw_string(
			_font,
			Vector2(24.0, baseline),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 32.0,
			13,
			text_color
		)
