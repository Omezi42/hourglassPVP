class_name CardChallengeResult
extends Control
## リーサルパズルとソロモードの結果パネル(GameDesign.md 24章・27章「結果パネル」)。
##
## **対局の結果パネル(`CardMatchResult`)は流用しない。**あちらは勝敗の内訳(両者のHP・
## 手数・決め手)を出す作りで、こちらに要るのは「解けたか」「何が手に入ったか」「次に何をするか」。
## 質感と舞い落ちる砂だけを `ResultPanelFrame` / `ResultSandFall` で共有する。
##
## 上から「所属 → 結果 → 名前 → ひとこと → 受け皿 → ボタン」。受け皿はクリアなら報酬の札、
## 失敗ならヒント(ステージの条件)を出す。高さは中身に合わせて伸び縮みする。

signal next_pressed
signal retry_pressed
signal quit_pressed
signal log_pressed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_WIDTH := 600.0
const PADDING := Vector2(40, 26)
const PRIMARY_SIZE := Vector2(200, 52)
const BUTTON_SIZE := Vector2(168, 52)
const BUTTON_GAP := 14
const LOG_BUTTON_SIZE := Vector2(72, 34)
const LOG_BUTTON_MARGIN := 16.0
const LOG_FONT_SIZE := 14
const DIM_COLOR := Color(0, 0, 0, 0.72)
const ENTRANCE_DURATION := 0.42
const ENTRANCE_SCALE := 0.86

const EYEBROW_FONT_SIZE := 14
const TITLE_FONT_SIZE := 40
const NAME_FONT_SIZE := 20
const SUMMARY_FONT_SIZE := 18
const SUMMARY_VALUE_FONT_SIZE := 30
const NOTE_FONT_SIZE := 14
const FAIL_TITLE_COLOR := Color(0.78, 0.76, 0.72)
const STONE_RULE_COLOR := Color(0.45, 0.45, 0.48)
const RULE_HEIGHT := 8.0
const RULE_SPAN := 0.32
const RULE_DIAMOND := 4.0

## 受け皿(凹んだ面)
const TRAY_RADIUS := 12.0
const TRAY_PADDING := Vector2(20, 12)
const TRAY_TEXT_FONT_SIZE := 16
const TRAY_HEAD_FONT_SIZE := 13
const TRAY_TOP := Color(0.03, 0.025, 0.02, 0.72)
const TRAY_BOTTOM := Color(0.1, 0.08, 0.06, 0.6)
const TRAY_RIM_DARK := Color(0, 0, 0, 0.6)
const TRAY_RIM_LIGHT := Color(1, 0.9, 0.7, 0.12)

## 報酬の札
const REWARD_GAP := 28
const REWARD_VISUAL_SIZE := Vector2(64, 88)
const REWARD_ART_MAX := Vector2(60, 80)
const REWARD_ICON_SIZE := 56.0
const COIN_RADIUS := 24.0
const COIN_RIM := 3.0
const COIN_SHINE := Color(1, 0.9, 0.6, 0.5)
const REWARD_AMOUNT_FONT_SIZE := 30
const REWARD_NAME_FONT_SIZE := 20
const REWARD_SUB_FONT_SIZE := 13
const POOL_RADIUS := Vector2(30, 7)
const POOL_ALPHA := 0.35

var _dim: ColorRect
var _sand: ResultSandFall
var _panel: Control
var _box: VBoxContainer
var _log_button: Button
var _cleared := false
var _tween: Tween


## 結果パネルへ渡す中身。組み立ては呼び出し側(`CardMatchPuzzle` / `CardMatchSolo`)が持つ。
class Outcome:
	var cleared := false
	## 「リーサルパズル ・ 第1問」のような所属の1行。
	var eyebrow := ""
	## 問題名・ステージ名。空なら行ごと出さない(エンドレス)。
	var stage_name := ""
	## ひとことは「前 + 大きな数字 + 後」。数字が負なら数字を出さない。
	var summary_lead := ""
	var summary_value := -1
	var summary_tail := ""
	## 失敗したときの受け皿(ヒント / ステージの条件)。
	var tray_title := ""
	var tray_text := ""
	var reward: StageReward = null
	## 「次の問題へ」「次のステージへ」。空なら次が無い。
	var next_label := ""
	var show_log := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Pitfalls.md)。生成直後はサイズ0で、
	# 暗幕が盤面を覆わずクリックも止められない状態になる。
	size = SCREEN_SIZE
	_build()


func show_for(outcome: Outcome) -> void:
	_cleared = outcome.cleared
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var inner_width := PANEL_WIDTH - PADDING.x * 2.0
	_box.add_child(_label(outcome.eyebrow, EYEBROW_FONT_SIZE, UiPalette.TEXT_MUTED))
	_box.add_child(
		_label(
			"クリア!" if _cleared else "とどかなかった",
			TITLE_FONT_SIZE,
			UiPalette.GLOW_AMBER if _cleared else FAIL_TITLE_COLOR
		)
	)
	if not outcome.stage_name.is_empty():
		_box.add_child(_label(outcome.stage_name, NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE))
	_box.add_child(_gap(10))
	_box.add_child(_rule(inner_width))
	_box.add_child(_gap(10))
	_box.add_child(_summary(outcome))
	_box.add_child(_gap(14))
	_add_tray(outcome, inner_width)
	_box.add_child(_gap(20))
	_box.add_child(_buttons(outcome))
	_log_button.visible = outcome.show_log
	visible = true
	_sand.start(_cleared)
	_panel.modulate.a = 0.0
	_layout_and_enter.call_deferred()


func _add_tray(outcome: Outcome, width: float) -> void:
	var reward := outcome.reward
	if _cleared and reward != null and not reward.is_empty():
		_box.add_child(_reward_tray(reward, width))
		if reward.gold_pending:
			_box.add_child(_gap(6))
			_box.add_child(_label("砂金は次に接続できたときに反映", NOTE_FONT_SIZE, UiPalette.TEXT_MUTED))
		return
	if _cleared and reward != null and reward.already_cleared:
		_box.add_child(_label("クリア済み(報酬は初回のみ)", NOTE_FONT_SIZE, UiPalette.TEXT_MUTED))
		return
	if not _cleared and not outcome.tray_text.is_empty():
		_box.add_child(_text_tray(outcome.tray_title, outcome.tray_text, width))


## ボタンは次にいちばん押されるものを真鍮の主ボタンにする(GameDesign.md 24章の表)。
func _buttons(outcome: Outcome) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", BUTTON_GAP)
	var has_next := not outcome.next_label.is_empty()
	if _cleared:
		if has_next:
			row.add_child(_primary(outcome.next_label, next_pressed))
			row.add_child(_secondary("もう一度", retry_pressed))
			row.add_child(_secondary("一覧へ", quit_pressed))
		else:
			row.add_child(_primary("一覧へ", quit_pressed))
			row.add_child(_secondary("もう一度", retry_pressed))
	else:
		row.add_child(_primary("もう一度", retry_pressed))
		if has_next:
			row.add_child(_secondary(outcome.next_label, next_pressed))
		row.add_child(_secondary("一覧へ", quit_pressed))
	return row


## 中身の高さが決まってからパネルの大きさと位置を決め、入場させる。
## 折り返す説明文の高さは、コンテナが一度並べ終えるまで確定しないため1コマ待つ。
func _layout_and_enter() -> void:
	await get_tree().process_frame
	if not visible:
		return
	var content := _box.get_combined_minimum_size()
	var panel_size := Vector2(PANEL_WIDTH, content.y + PADDING.y * 2.0)
	_panel.size = panel_size
	_panel.position = ((SCREEN_SIZE - panel_size) * 0.5).round()
	_panel.pivot_offset = panel_size * 0.5
	_box.size = Vector2(PANEL_WIDTH - PADDING.x * 2.0, content.y)
	_log_button.position = Vector2(
		PANEL_WIDTH - LOG_BUTTON_SIZE.x - LOG_BUTTON_MARGIN, LOG_BUTTON_MARGIN
	)
	_panel.queue_redraw()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_panel.scale = Vector2.ONE * ENTRANCE_SCALE
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, ENTRANCE_DURATION * 0.7)
	_tween.tween_property(_panel, "modulate:a", 1.0, ENTRANCE_DURATION).set_trans(Tween.TRANS_SINE)
	(
		_tween
		. tween_property(_panel, "scale", Vector2.ONE, ENTRANCE_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _build() -> void:
	# 粒は暗幕の奥に置く(`CardMatchResult` と同じ見え方)。
	_sand = ResultSandFall.new()
	_sand.size = SCREEN_SIZE
	add_child(_sand)
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(
		func() -> void: ResultPanelFrame.draw(_panel.get_canvas_item(), _panel.size, _cleared)
	)
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.position = PADDING
	_box.add_theme_constant_override("separation", 0)
	_panel.add_child(_box)
	_log_button = CodedButton.make("ログ", LOG_BUTTON_SIZE)
	_log_button.add_theme_font_size_override("font_size", LOG_FONT_SIZE)
	_log_button.pressed.connect(func() -> void: log_pressed.emit())
	_panel.add_child(_log_button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.visible = not text.is_empty()
	return label


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


## 両脇へ細く伸びる線と、中央の菱形。
func _rule(width: float) -> Control:
	var line := Control.new()
	line.custom_minimum_size = Vector2(width, RULE_HEIGHT)
	var tone := UiPalette.BRASS_HIGHLIGHT if _cleared else STONE_RULE_COLOR
	line.draw.connect(
		func() -> void:
			var mid := Vector2(width * 0.5, RULE_HEIGHT * 0.5)
			var reach := width * RULE_SPAN
			var faded := Color(tone, 0.5)
			var inset := Vector2(RULE_DIAMOND * 2.5, 0)
			line.draw_line(mid - Vector2(reach, 0), mid - inset, faded, 1.0)
			line.draw_line(mid + inset, mid + Vector2(reach, 0), faded, 1.0)
			var d := RULE_DIAMOND
			line.draw_colored_polygon(
				PackedVector2Array(
					[
						mid + Vector2(0, -d),
						mid + Vector2(d, 0),
						mid + Vector2(0, d),
						mid + Vector2(-d, 0)
					]
				),
				tone
			)
	)
	return line


## ひとこと。数字だけを大きく出し、あとどれだけか(どれだけ残したか)を一目で読ませる。
func _summary(outcome: Outcome) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var lead := _label(outcome.summary_lead, SUMMARY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	var tail := _label(outcome.summary_tail, SUMMARY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	for label in [lead, tail]:
		label.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(lead)
	if outcome.summary_value >= 0:
		var value := _label(
			str(outcome.summary_value), SUMMARY_VALUE_FONT_SIZE, UiPalette.GLOW_AMBER
		)
		row.add_child(value)
	row.add_child(tail)
	return row


func _reward_tray(reward: StageReward, width: float) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", REWARD_GAP)
	if reward.gold > 0:
		row.add_child(_reward_item(_coin_visual(), "+%d" % reward.gold, "砂金", true))
	var card := reward.card()
	if card != null:
		var art := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
		row.add_child(_reward_item(_art_visual(art, true), card.display_name, "新しいカード", false))
	if not reward.icon_id.is_empty():
		var icon := UserProfileLibrary.get_icon_texture(reward.icon_id)
		row.add_child(
			_reward_item(
				_art_visual(icon, false),
				UserProfileLibrary.get_icon_name(reward.icon_id),
				"新しいアイコン",
				false
			)
		)
	return _recessed(row, width)


func _reward_item(visual: Control, head: String, sub: String, is_amount: bool) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 10)
	item.add_child(visual)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	var head_label := _label(
		head,
		REWARD_AMOUNT_FONT_SIZE if is_amount else REWARD_NAME_FONT_SIZE,
		UiPalette.GLOW_AMBER if is_amount else UiPalette.TEXT_OFFWHITE
	)
	head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sub_label := _label(sub, REWARD_SUB_FONT_SIZE, UiPalette.TEXT_MUTED)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(head_label)
	text.add_child(sub_label)
	item.add_child(text)
	return item


## 砂金の硬貨。
func _coin_visual() -> Control:
	var visual := Control.new()
	visual.custom_minimum_size = REWARD_VISUAL_SIZE
	visual.draw.connect(
		func() -> void:
			var ci := visual.get_canvas_item()
			var center := REWARD_VISUAL_SIZE * 0.5
			UiPaint.fill_circle(ci, center, COIN_RADIUS, UiPalette.BRASS_DARK, 32)
			UiPaint.fill_circle(ci, center, COIN_RADIUS - COIN_RIM, UiPalette.GLOW_AMBER, 32)
			UiPaint.fill_circle(ci, center + Vector2(-5, -6), COIN_RADIUS * 0.38, COIN_SHINE, 20)
			UiPaint.draw_ring(ci, center, COIN_RADIUS, UiPalette.OUTLINE_DARK, 2.0, 32)
	)
	return visual


## 手に入れたカード(砂時計を光だまりの上に立てる)・アイコンの絵。
func _art_visual(texture: Texture2D, standing: bool) -> Control:
	var visual := Control.new()
	visual.custom_minimum_size = REWARD_VISUAL_SIZE
	visual.draw.connect(
		func() -> void:
			if texture == null:
				return
			var box := REWARD_VISUAL_SIZE
			if not standing:
				var side := REWARD_ICON_SIZE
				visual.draw_texture_rect(
					texture, Rect2((box - Vector2(side, side)) * 0.5, Vector2(side, side)), false
				)
				return
			var foot := Vector2(box.x * 0.5, box.y - POOL_RADIUS.y)
			UiPaint.fill_ellipse(
				visual.get_canvas_item(),
				foot,
				POOL_RADIUS,
				Color(UiPalette.GLOW_AMBER, POOL_ALPHA),
				24
			)
			var tex_size := texture.get_size()
			var fit: float = minf(REWARD_ART_MAX.x / tex_size.x, REWARD_ART_MAX.y / tex_size.y)
			var draw_size := tex_size * fit
			visual.draw_texture_rect(
				texture,
				Rect2(Vector2(foot.x - draw_size.x * 0.5, foot.y + 2.0 - draw_size.y), draw_size),
				false
			)
	)
	return visual


func _text_tray(heading: String, body: String, width: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := _label(heading, TRAY_HEAD_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(head)
	var text := Label.new()
	# 折り返しは幅より先に立てる(Pitfalls.md)。
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = width - TRAY_PADDING.x * 2.0
	text.text = body
	text.add_theme_font_size_override("font_size", TRAY_TEXT_FONT_SIZE)
	text.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	box.add_child(text)
	return _recessed(box, width)


## 凹んだ面。中身の大きさに合わせて伸びる。
func _recessed(content: Control, width: float) -> MarginContainer:
	var tray := MarginContainer.new()
	tray.custom_minimum_size.x = width
	tray.add_theme_constant_override("margin_left", int(TRAY_PADDING.x))
	tray.add_theme_constant_override("margin_right", int(TRAY_PADDING.x))
	tray.add_theme_constant_override("margin_top", int(TRAY_PADDING.y))
	tray.add_theme_constant_override("margin_bottom", int(TRAY_PADDING.y))
	tray.add_child(content)
	tray.draw.connect(
		func() -> void:
			if tray.size.y < TRAY_RADIUS * 2.0:
				return
			var ci := tray.get_canvas_item()
			var rect := Rect2(Vector2.ZERO, tray.size)
			var points := UiPaint.rounded_rect_points_uniform(rect, TRAY_RADIUS, 6)
			UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, TRAY_TOP], [1.0, TRAY_BOTTOM]])
			UiPaint.draw_inner_shadow(ci, rect, TRAY_RADIUS, 10, 3, Color(0, 0, 0), 0.4)
			UiPaint.draw_bevel(ci, points, TRAY_RIM_DARK, TRAY_RIM_LIGHT, 1.5, false)
	)
	return tray


func _primary(label: String, target: Signal) -> Button:
	var button := CodedButton.make_in_group(label, PRIMARY_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	button.pressed.connect(func() -> void: target.emit())
	return button


func _secondary(label: String, target: Signal) -> Button:
	var button := CodedButton.make(label, BUTTON_SIZE)
	button.pressed.connect(func() -> void: target.emit())
	return button
