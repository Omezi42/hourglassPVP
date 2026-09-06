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

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(560, 340)
const ENTRANCE_DURATION := 0.42
## 行が現れる間隔。ここで区切ることで「勝敗 → 内訳 → 決め手」の順に読める。
const LINE_STAGGER := 0.14
const LINE_FADE := 0.22
const PARTICLE_COUNT := 40
const FLASH_DECAY := 1.1

var _dim: ColorRect
var _panel: Control
var _title: Label
var _lines: Array[Label] = []
var _rematch: Button
var _tween: Tween

var _won := false
var _neutral := false
var _reveal_elapsed := 0.0
var _revealing := false
var _flash := 0.0
## 各粒 {"pos":Vector2, "speed":float, "drift":float, "phase":float, "size":float}
var _particles: Array = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後は
	# サイズ0のため、暗幕が盤面を覆わずクリックも止められない状態になる。
	size = SCREEN_SIZE
	set_process(false)
	_build()


## 勝敗を表示する。my_side が負なら「先手/後手の勝利」と第三者視点で書く。
func show_for(
	state: MatchState, my_side: int, moves: int, reward: String = "", can_rematch: bool = false
) -> void:
	_rematch.visible = can_rematch
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
		texts.append(reward)
	for i in _lines.size():
		var label: Label = _lines[i]
		if i < texts.size():
			label.text = texts[i]
			label.visible = true
			label.modulate.a = 0.0
		else:
			label.visible = false

	_spawn_particles()
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
	_panel.scale = Vector2(0.82, 0.82)
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
	for p in _particles:
		p["pos"].y += p["speed"] * delta
		p["phase"] += delta * 1.4
		p["pos"].x += sin(p["phase"]) * p["drift"] * delta
		if p["pos"].y > SCREEN_SIZE.y + 12.0:
			p["pos"].y = -randf() * 60.0
			p["pos"].x = randf() * SCREEN_SIZE.x
		active = true
	queue_redraw()
	_panel.queue_redraw()
	if not active:
		set_process(false)


## 舞い落ちる粒。勝利=琥珀の砂、敗北=くすんだ灰。GameDesign.md 9章の
## 「消える砂と落ちる砂を演出で分ける」思想を結果パネルへも及ぼし、
## ここでも砂時計モチーフの延長として見せる。
func _draw() -> void:
	var ci := get_canvas_item()
	var color: Color = (
		Color(UiPalette.GLOW_AMBER, 0.55) if (_won or _neutral) else Color(0.55, 0.53, 0.5, 0.35)
	)
	for p in _particles:
		UiPaint.fill_circle(ci, p["pos"], p["size"], color, 8)


func _spawn_particles() -> void:
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in PARTICLE_COUNT:
		(
			_particles
			. append(
				{
					"pos":
					Vector2(
						rng.randf() * SCREEN_SIZE.x, rng.randf() * SCREEN_SIZE.y - SCREEN_SIZE.y
					),
					"speed":
					rng.randf_range(40.0, 110.0) * (0.6 if not (_won or _neutral) else 1.0),
					"drift": rng.randf_range(-12.0, 12.0),
					"phase": rng.randf() * TAU,
					"size": rng.randf_range(1.2, 2.6),
				}
			)
		)


func _line_base_y(index: int) -> float:
	return 116.0 + float(index) * 30.0


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = Control.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
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

	for i in 4:
		var label := Label.new()
		label.position = Vector2(0, _line_base_y(i))
		label.size = Vector2(PANEL_SIZE.x, 26)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
		label.visible = false
		_panel.add_child(label)
		_lines.append(label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.position = Vector2(0, PANEL_SIZE.y - 84.0)
	row.size = Vector2(PANEL_SIZE.x, 64.0)
	_panel.add_child(row)
	# 「もう一度」は連戦の導線(GameDesign.md 9章)。当面はCPU戦にだけ出す。
	_rematch = _make_button("もう一度", rematch_pressed)
	row.add_child(_rematch)
	row.add_child(_make_button("ログ", log_pressed))
	row.add_child(_make_button("ホームへ", home_pressed))


## パネル本体の質感(Architecture.md 4章のコード描画方針: 多段グラデーション + 面取り +
## 内側の落ち込み影 + グレイン)。勝敗で色調だけを差し替える。
func _draw_panel() -> void:
	var ci: RID = _panel.get_canvas_item()
	var rect := Rect2(Vector2.ZERO, PANEL_SIZE)
	var points := UiPaint.rounded_rect_points_uniform(rect, 20.0, 8)
	var stops: Array
	var light_edge: Color
	var dark_edge: Color
	if _won or _neutral:
		stops = [
			[0.0, Color(0.46, 0.28, 0.08, 0.98)],
			[0.35, Color(0.24, 0.15, 0.07, 0.98)],
			[1.0, Color(0.1, 0.08, 0.07, 0.98)],
		]
		light_edge = UiPalette.BRASS_HIGHLIGHT
		dark_edge = UiPalette.BRASS_DARK
	else:
		stops = [
			[0.0, Color(0.22, 0.22, 0.25, 0.98)],
			[0.4, Color(0.13, 0.13, 0.16, 0.98)],
			[1.0, Color(0.06, 0.06, 0.08, 0.98)],
		]
		light_edge = Color(0.4, 0.4, 0.44, 1.0)
		dark_edge = Color(0.05, 0.05, 0.06, 1.0)
	UiPaint.fill_gradient_polygon(ci, points, rect, stops)
	UiPaint.draw_inner_shadow(ci, rect.grow(-3.0), 18.0, 26, 4, Color(0, 0, 0), 0.32)
	UiPaint.draw_bevel(ci, points, light_edge, dark_edge, 3.0, false)
	var outline := points.duplicate()
	outline.append(points[0])
	var outline_colors := PackedColorArray()
	outline_colors.resize(outline.size())
	outline_colors.fill(UiPalette.OUTLINE_DARK)
	RenderingServer.canvas_item_add_polyline(ci, outline, outline_colors, 2.0, true)
	UiPaint.apply_grain(ci, rect, 0.05)
	if _flash > 0.0 and _won:
		_draw_victory_flash(ci)


## 勝利の瞬間だけ、タイトルの背後から光条を放射する(反転演出と同じ語彙、GameDesign.md 9章)。
## `_panel` の canvas item(ci)へ描く。`self`(ルート)の `draw_line()` を呼ぶと
## パネルではなくルート側の座標系へ描いてしまい、位置がずれるため。
func _draw_victory_flash(ci: RID) -> void:
	var center := Vector2(PANEL_SIZE.x * 0.5, 66.0)
	var alpha := _flash * 0.5
	var count := 14
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		var length: float = 60.0 + 40.0 * _flash
		var from := center + Vector2(cos(angle), sin(angle)) * 18.0
		var to := center + Vector2(cos(angle), sin(angle)) * length
		RenderingServer.canvas_item_add_line(ci, from, to, Color(UiPalette.GLOW_AMBER, alpha), 2.0)


func _make_button(label: String, target: Signal) -> Button:
	var button := CodedButton.make(label, Vector2(180, 56))
	button.pressed.connect(func() -> void: target.emit())
	return button
