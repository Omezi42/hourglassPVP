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
signal matchmaking_pressed
signal home_pressed
signal log_pressed

## 内訳の行の役割。文字の大きさ(横 / 縦)・色・行の送り・縮めてよい下限を役割ごとに持つ。
enum Role { HP, MOVES, REASON, GOLD, WELCOME }

## ボタン3つ(「CPUともう1局」が最長)を枠の内側へ収める幅にする。高さは内訳の行数で決まる(`_arrange_lines()`)。
const PANEL_WIDTH := 640.0
## 内訳の行の数(HP・手数・決め手・砂金・はじめの7日)。
const LINE_COUNT := 5
## 行の組み方。最後の行の下端から、ボタン列とその下の余白までがパネルの高さ。
const LINE_START_Y := 112.0
const REWARD_GAP := 10.0
const LINES_TO_BUTTONS := 26.0
const BUTTON_ROW_HEIGHT := 64.0
const BUTTON_ROW_BOTTOM := 22.0
const MIN_PANEL_HEIGHT := 300.0
## 長い行が収まらないとき、左右にこれだけ余白を残して文字を1pxずつ下げる。
const LINE_SIDE_MARGIN := 40.0
const BUTTON_SIZE := Vector2(176, 56)
const BUTTON_GAP := 16
## 縦はモーダルと同じく論理幅 `PortraitModal.WIDTH` で組み、中身ごと拡大する(GameDesign.md 9章「縦画面」)。
## 内訳の行は拡大後に本文24pxへ届く大きさにする。
const PORTRAIT_PANEL_WIDTH := PortraitModal.WIDTH
const PORTRAIT_BUTTON_SIZE := Vector2(148, 56)
const PORTRAIT_BUTTON_GAP := 8
const LINE_FONT := {
	Role.HP: Vector2i(20, 22),
	Role.MOVES: Vector2i(15, 16),
	Role.REASON: Vector2i(15, 16),
	Role.GOLD: Vector2i(18, 20),
	Role.WELCOME: Vector2i(14, 15),
}
const LINE_PITCH := {
	Role.HP: 30.0,
	Role.MOVES: 26.0,
	Role.REASON: 26.0,
	Role.GOLD: 30.0,
	Role.WELCOME: 24.0,
}
const LINE_MIN_FONT := {Role.GOLD: 15, Role.WELCOME: 13}
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
var _panel_size := Vector2(PANEL_WIDTH, MIN_PANEL_HEIGHT)
var _panel_scale := 1.0
var _portrait := false
var _screen_size := Vector2(ScreenOrientation.LANDSCAPE_SIZE)
## いま出している行の役割・本文・縦位置(`_arrange_lines()` が決める)。
var _roles: Array[int] = []
var _line_y: Array[float] = []

var _won := false
var _neutral := false
var _matchmaking_mode := false
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
	_screen_size = layout.screen_size
	_portrait = layout.portrait
	_panel_scale = PortraitModal.SCALE if layout.portrait else 1.0
	if not (_tween != null and _tween.is_running()):
		_panel.scale = Vector2.ONE * _panel_scale
	var button_size := PORTRAIT_BUTTON_SIZE if layout.portrait else BUTTON_SIZE
	for button in _buttons:
		button.custom_minimum_size = button_size
	_button_row.add_theme_constant_override(
		"separation", PORTRAIT_BUTTON_GAP if layout.portrait else BUTTON_GAP
	)
	_arrange_lines()


## 勝敗を表示する。my_side が負なら「先手/後手の勝利」と第三者視点で書く。
## 誘導対局だけ主/副を入れ替える(GameDesign.md 18章)。「CPUともう1局」を真鍮の主要ボタンへ
## 昇格させ、「ホームへ」は既定の硝子のまま残す。
func show_for(
	state: MatchState,
	my_side: int,
	moves: int,
	reward: String = "",
	can_rematch: bool = false,
	is_tutorial: bool = false,
	can_matchmaking: bool = false
) -> void:
	_matchmaking_mode = can_matchmaking
	_rematch.visible = can_rematch or can_matchmaking
	_rematch.text = ("再度マッチング" if can_matchmaking else ("CPUともう1局" if is_tutorial else "もう一度"))
	CodedButton.apply_styles(
		_rematch,
		(
			CodedButton.PRIMARY_ACTION_GROUP
			if is_tutorial or can_matchmaking
			else CodedButton.WIDE_GROUP
		)
	)
	var winner: int = state.winner
	_won = my_side >= 0 and winner == my_side
	_neutral = my_side < 0 or winner < 0
	_title.text = _title_text(winner, my_side)
	_title.add_theme_color_override(
		"font_color", UiPalette.SAND_HI if (_won or _neutral) else UiPalette.MUTED
	)

	var own_hp: int = state.hp[my_side if my_side >= 0 else MatchState.Side.A]
	var foe_side: int = MatchState.other_side(my_side if my_side >= 0 else MatchState.Side.A)
	var texts: PackedStringArray = []
	_roles.clear()
	texts.append("自分 %d / 相手 %d" % [own_hp, state.hp[foe_side]])
	_roles.append(Role.HP)
	texts.append("%d手で決着" % moves)
	_roles.append(Role.MOVES)
	if winner >= 0:
		texts.append("決め手: %s" % CardMatchLog.reason_text(state, winner))
		_roles.append(Role.REASON)
	if not reward.is_empty():
		# 砂金の行のあとに、CPU戦だけ「はじめの7日」の行が続く。
		var reward_lines := reward.split("\n")
		for i in reward_lines.size():
			texts.append(reward_lines[i])
			_roles.append(Role.GOLD if i == 0 else Role.WELCOME)
	for i in _lines.size():
		var label: Label = _lines[i]
		if i < texts.size():
			label.text = texts[i]
			label.visible = true
			label.modulate.a = 0.0
		else:
			label.visible = false
	_arrange_lines()

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
	_tween.tween_property(_dim, "modulate:a", 1.0, CardMatchLayout.OVERLAY_DIM_FADE)
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
			label.position.y = _line_y[i] + (1.0 - t) * 10.0
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


## 行の大きさ・色・縦位置と、それに合わせたパネルの高さ・位置を決める。
## 高さは最後の行の下端から決まるため、行が少ない(投了など)ときは短いパネルになる。
## 画面の向きが変わったときも同じ式を通す。
func _arrange_lines() -> void:
	var font_index := 1 if _portrait else 0
	var width := PORTRAIT_PANEL_WIDTH if _portrait else PANEL_WIDTH
	var fit_width := width - LINE_SIDE_MARGIN * 2.0
	var y := LINE_START_Y
	_line_y.clear()
	for i in _lines.size():
		var label: Label = _lines[i]
		if not label.visible or i >= _roles.size():
			_line_y.append(y)
			continue
		var role: int = _roles[i]
		if role == Role.GOLD:
			y += REWARD_GAP
		var pitch: float = LINE_PITCH[role]
		var font_size: int = LINE_FONT[role][font_index]
		var min_font: int = LINE_MIN_FONT.get(role, font_size)
		var font := label.get_theme_font("font", "Label")
		while (
			font_size > min_font
			and (
				font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				> fit_width
			)
		):
			font_size -= 1
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", _line_color(role))
		label.size = Vector2(width, pitch)
		_line_y.append(y)
		label.position = Vector2(0, y)
		y += pitch
	_panel_size = Vector2(
		width, maxf(y + LINES_TO_BUTTONS + BUTTON_ROW_HEIGHT + BUTTON_ROW_BOTTOM, MIN_PANEL_HEIGHT)
	)
	_panel.custom_minimum_size = _panel_size
	_panel.size = _panel_size
	_panel.pivot_offset = _panel_size * 0.5
	_panel.position = (_screen_size - _panel_size) * 0.5
	_title.size.x = width
	_button_row.position = Vector2(0, _panel_size.y - BUTTON_ROW_HEIGHT - BUTTON_ROW_BOTTOM)
	_button_row.size = Vector2(width, BUTTON_ROW_HEIGHT)
	_panel.queue_redraw()


## 勝敗と中身の重みで色を分ける。砂金は勝ちタイトルと同じ金(負けの局でも金)。
static func _line_color(role: int) -> Color:
	match role:
		Role.HP:
			return UiPalette.IVORY
		Role.GOLD:
			return UiPalette.SAND_HI
	return UiPalette.MUTED


func _build() -> void:
	# 粒は暗幕の奥に置く(暗幕越しにうっすら見える程度に留める)。
	_sand = ResultSandFall.new()
	add_child(_sand)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, CardMatchLayout.OVERLAY_DIM_ALPHA)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Control.new()
	_panel.custom_minimum_size = _panel_size
	_panel.size = _panel_size
	_panel.pivot_offset = _panel_size * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(0, 40)
	_title.size = Vector2(PANEL_WIDTH, 52)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", UiPalette.T_TITLE)
	_panel.add_child(_title)

	for i in LINE_COUNT:
		var label := Label.new()
		label.size = Vector2(PANEL_WIDTH, LINE_PITCH[Role.HP])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.visible = false
		_panel.add_child(label)
		_lines.append(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", BUTTON_GAP)
	row.size = Vector2(PANEL_WIDTH, BUTTON_ROW_HEIGHT)
	_panel.add_child(row)
	_button_row = row
	# CPU戦では連戦、ランクマッチでは再度マッチングへ進む導線。
	_rematch = CodedButton.make("もう一度", BUTTON_SIZE)
	_rematch.pressed.connect(_on_rematch_pressed)
	_buttons.append(_rematch)
	row.add_child(_rematch)
	row.add_child(_make_button("ログ", log_pressed))
	row.add_child(_make_button("ホームへ", home_pressed))


## パネル本体の質感は `ResultPanelFrame` が持つ。勝利の瞬間だけ光条を重ねる。
func _draw_panel() -> void:
	var ci: RID = _panel.get_canvas_item()
	ResultPanelFrame.draw(ci, _panel_size, _won or _neutral)
	if _flash > 0.0 and _won:
		_draw_victory_flash(ci)


func _on_rematch_pressed() -> void:
	if _matchmaking_mode:
		matchmaking_pressed.emit()
	else:
		rematch_pressed.emit()


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
		RenderingServer.canvas_item_add_line(ci, from, to, Color(UiPalette.SAND, alpha), 2.0)


func _make_button(label: String, target: Signal) -> Button:
	var button := CodedButton.make(label, BUTTON_SIZE)
	button.pressed.connect(func() -> void: target.emit())
	_buttons.append(button)
	return button
