class_name CardMatchResult
extends Control
## 対局終了時に盤面へ重ねる結果パネル(GameDesign.md 9章)。
## 暗幕でクリックを受け止め、終局後に盤面が操作されるのを防ぐ。
##
## **勝敗で表情を変える。**勝利は琥珀の光と舞い落ちる砂、敗北は冷えた石の色と
## 舞い落ちる灰(GameDesign.md 9章「砂時計モチーフをそのまま演出に使う」の結果パネル版)。
## 入場はスケール+フェードのひと呼吸、行は間を置いて順に読ませる。演出はここまでに留め、
## 結果を読む・ボタンを押すという操作そのものは一切邪魔しない。

signal rematch_pressed
signal home_pressed
signal log_pressed

## ボタン3つ(「CPUともう1局」が最長)を枠の内側へ収める幅にする。
const PANEL_SIZE := Vector2(640, 370)
## 内訳の行の数(HP・手数・決め手・砂金・はじめの7日)。
const LINE_COUNT := 5
const BUTTON_SIZE := Vector2(176, 56)
const BUTTON_GAP := 16
## 縦はモーダルと同じく論理幅 `PortraitModal.WIDTH` で組み、中身ごと拡大する(GameDesign.md 9章「縦画面」)。
## 内訳の行は拡大後に本文24pxへ届く大きさにする。
const PORTRAIT_PANEL_SIZE := Vector2(PortraitModal.WIDTH, 370)
const PORTRAIT_BUTTON_SIZE := Vector2(148, 56)
const PORTRAIT_BUTTON_GAP := 8
const PORTRAIT_LINE_FONT := 18
const LINE_FONT := 16
const ENTRANCE_START_SCALE := 0.82
const ENTRANCE_DURATION := 0.42
## 行が現れる間隔。ここで区切ることで「勝敗 → 内訳 → 決め手」の順に読める。
const LINE_STAGGER := 0.14
const LINE_FADE := 0.22
const FLASH_DECAY := 1.1

var _dim: ColorRect
var _sand: ResultSandFall
var _panel: Control
var _title: Label
var _lines: Array[Label] = []
var _rematch: Button
var _buttons: Array[Button] = []
var _button_row: HBoxContainer
var _tween: Tween
var _panel_size := PANEL_SIZE
var _panel_scale := 1.0

var _won := false
var _neutral := false
var _reveal_elapsed := 0.0
var _revealing := false
var _flash := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後は
	# サイズ0のため、暗幕が盤面を覆わずクリックも止められない状態になる。
	set_process(false)
	_build()


## 向きに合わせて置き直す(`CardMatchArrange`)。縦はパネルを細く組んで中身ごと拡大し、画面の中央に置く。
func apply_layout(layout: CardMatchLayout) -> void:
	size = layout.screen_size
	_sand.size = layout.screen_size
	_dim.size = layout.screen_size
	_panel_size = PORTRAIT_PANEL_SIZE if layout.portrait else PANEL_SIZE
	_panel_scale = PortraitModal.SCALE if layout.portrait else 1.0
	_panel.custom_minimum_size = _panel_size
	_panel.size = _panel_size
	_panel.pivot_offset = _panel_size * 0.5
	_panel.position = (layout.screen_size - _panel_size) * 0.5
	if not (_tween != null and _tween.is_running()):
		_panel.scale = Vector2.ONE * _panel_scale
	_title.size.x = _panel_size.x
	var line_font := PORTRAIT_LINE_FONT if layout.portrait else LINE_FONT
	for label in _lines:
		label.size.x = _panel_size.x
		label.add_theme_font_size_override("font_size", line_font)
	var button_size := PORTRAIT_BUTTON_SIZE if layout.portrait else BUTTON_SIZE
	for button in _buttons:
		button.custom_minimum_size = button_size
	_button_row.add_theme_constant_override(
		"separation", PORTRAIT_BUTTON_GAP if layout.portrait else BUTTON_GAP
	)
	_button_row.position = Vector2(0, _panel_size.y - 84.0)
	_button_row.size = Vector2(_panel_size.x, 64.0)
	_panel.queue_redraw()


## 勝敗を表示する。my_side が負なら「先手/後手の勝利」と第三者視点で書く。
## 誘導対局だけ主/副を入れ替える(GameDesign.md 18章)。「CPUともう1局」を真鍮の主要ボタンへ
## 昇格させ、「ホームへ」は既定の凹んだパネルのまま残す。
func show_for(
	state: MatchState,
	my_side: int,
	moves: int,
	reward: String = "",
	can_rematch: bool = false,
	is_tutorial: bool = false
) -> void:
	_rematch.visible = can_rematch
	_rematch.text = "CPUともう1局" if is_tutorial else "もう一度"
	CodedButton.apply_styles(
		_rematch, CodedButton.PRIMARY_ACTION_GROUP if is_tutorial else CodedButton.WIDE_GROUP
	)
	var winner: int = state.winner
	_won = my_side >= 0 and winner == my_side
	_neutral = my_side < 0 or winner < 0
	_title.text = _title_text(winner, my_side)
	_title.add_theme_color_override(
		"font_color", UiPalette.GLOW_AMBER if (_won or _neutral) else UiPalette.TEXT_MUTED
	)

	var own_hp: int = state.hp[my_side if my_side >= 0 else MatchState.Side.A]
	var foe_side: int = MatchState.other_side(my_side if my_side >= 0 else MatchState.Side.A)
	var texts: PackedStringArray = []
	texts.append("自分 %d / 相手 %d" % [own_hp, state.hp[foe_side]])
	texts.append("%d手で決着" % moves)
	if winner >= 0:
		texts.append("決め手: %s" % CardMatchLog.reason_text(state, winner))
	if not reward.is_empty():
		texts.append_array(reward.split("\n"))
	for i in _lines.size():
		var label: Label = _lines[i]
		if i < texts.size():
			label.text = texts[i]
			label.visible = true
			label.modulate.a = 0.0
		else:
			label.visible = false

	_sand.start(_won or _neutral)
	_flash = 1.0 if _won else 0.0
	visible = true
	_start_entrance()


func _title_text(winner: int, my_side: int) -> String:
	if winner < 0:
		return "引き分け"
	if my_side < 0:
		return "%sの勝利!" % ("先手" if winner == MatchState.Side.A else "後手")
	return "勝利!" if winner == my_side else "敗北..."


func _start_entrance() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * (ENTRANCE_START_SCALE * _panel_scale)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, ENTRANCE_DURATION * 0.7)
	_tween.tween_property(_panel, "modulate:a", 1.0, ENTRANCE_DURATION).set_trans(Tween.TRANS_SINE)
	(
		_tween
		. tween_property(_panel, "scale", Vector2.ONE * _panel_scale, ENTRANCE_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_reveal_elapsed = 0.0
	_revealing = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var active := false
	if _revealing:
		_reveal_elapsed += delta
		var last_needed := 0.0
		for i in _lines.size():
			var label: Label = _lines[i]
			if not label.visible:
				continue
			var start: float = ENTRANCE_DURATION * 0.55 + float(i) * LINE_STAGGER
			var t: float = clampf((_reveal_elapsed - start) / LINE_FADE, 0.0, 1.0)
			label.modulate.a = t
			label.position.y = _line_base_y(i) + (1.0 - t) * 10.0
			last_needed = maxf(last_needed, start + LINE_FADE)
		if _reveal_elapsed < last_needed:
			active = true
		else:
			_revealing = false
	if _flash > 0.0:
		_flash = maxf(_flash - delta * FLASH_DECAY, 0.0)
		active = true
	_panel.queue_redraw()
	if not active:
		set_process(false)


func _line_base_y(index: int) -> float:
	return 116.0 + float(index) * 30.0


func _build() -> void:
	# 粒は暗幕の奥に置く(暗幕越しにうっすら見える程度に留める)。
	_sand = ResultSandFall.new()
	add_child(_sand)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Control.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(0, 40)
	_title.size = Vector2(PANEL_SIZE.x, 52)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_panel.add_child(_title)

	for i in LINE_COUNT:
		var label := Label.new()
		label.position = Vector2(0, _line_base_y(i))
		label.size = Vector2(PANEL_SIZE.x, 26)
		label.add_theme_font_size_override("font_size", LINE_FONT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
		label.visible = false
		_panel.add_child(label)
		_lines.append(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", BUTTON_GAP)
	row.position = Vector2(0, PANEL_SIZE.y - 84.0)
	row.size = Vector2(PANEL_SIZE.x, 64.0)
	_panel.add_child(row)
	_button_row = row
	# 「もう一度」は連戦の導線(GameDesign.md 9章)。当面はCPU戦にだけ出す。
	_rematch = _make_button("もう一度", rematch_pressed)
	row.add_child(_rematch)
	row.add_child(_make_button("ログ", log_pressed))
	row.add_child(_make_button("ホームへ", home_pressed))


## パネル本体の質感は `ResultPanelFrame` が持つ。勝利の瞬間だけ光条を重ねる。
func _draw_panel() -> void:
	var ci: RID = _panel.get_canvas_item()
	ResultPanelFrame.draw(ci, _panel_size, _won or _neutral)
	if _flash > 0.0 and _won:
		_draw_victory_flash(ci)


## 勝利の瞬間だけ、タイトルの背後から光条を放射する(反転演出と同じ語彙、GameDesign.md 9章)。
## `_panel` の canvas item(ci)へ描く。`self`(ルート)の `draw_line()` を呼ぶと
## パネルではなくルート側の座標系へ描いてしまい、位置がずれるため。
func _draw_victory_flash(ci: RID) -> void:
	var center := Vector2(_panel_size.x * 0.5, 66.0)
	var alpha := _flash * 0.5
	var count := 14
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		var length: float = 60.0 + 40.0 * _flash
		var from := center + Vector2(cos(angle), sin(angle)) * 18.0
		var to := center + Vector2(cos(angle), sin(angle)) * length
		RenderingServer.canvas_item_add_line(ci, from, to, Color(UiPalette.GLOW_AMBER, alpha), 2.0)


func _make_button(label: String, target: Signal) -> Button:
	var button := CodedButton.make(label, BUTTON_SIZE)
	button.pressed.connect(func() -> void: target.emit())
	_buttons.append(button)
	return button
