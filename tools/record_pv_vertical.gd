extends "res://tools/record_pv.gd"
## SNS宣伝用の縦長PV(1080x1920・約25秒)の素材を書き出す。横長版(record_pv.gd)の画面と
## 台本の道具をそのまま使い、横長の対局画面を SubViewport の中で動かして、その映像を
## 縦の枠の中でカメラのように寄せ・振り回す。ナレーション(ずんだもん)の1行ごとに1カット。
##
## 1. ナレーションを作る(VOICEVOXエンジンを起動しておく):
##   python tools/pv_voice.py scratchpad/pvv/voice
## 2. 撮る(--headless は付けない。AVIは音声の取り出し用で、映像は --frames の連番PNGを使う):
##   godot --path . --write-movie scratchpad/pvv/audio.avi --fixed-fps 30
##     res://tools/record_pv_vertical.tscn -- --voice=scratchpad/pvv/voice --frames=scratchpad/pvv/f
## 3. 結合: 連番は <frames>/start.txt に書いた番号から始まる。音声も同じ秒数だけ頭を切る
##   (-ss <start/30>)。
##
## 縦長の画面はウィンドウ(画面の解像度で頭打ちになる)では撮れないため、SubViewport を
## 毎フレーム PNG へ保存する。

const FRAME_SIZE := Vector2i(1080, 1920)
## 横長の画面の論理サイズと、寄っても粗くならないよう実際に描く倍率。
const STAGE_SIZE := Vector2i(1280, 720)
const STAGE_RENDER_SCALE := 2
## 縦の枠の中で映像を見せる領域(上は見出し、下は字幕)。
const VIEW_RECT := Rect2(0, 390, 1080, 1130)

## カメラの倍率(縦の枠の1pxあたりの横長画面のpx)。
const ZOOM_WIDE := 1.0
const ZOOM_BOARD := 1.3
const ZOOM_PAIR := 2.1
const ZOOM_UNIT := 3.0
const ZOOM_OPEN := 2.6
const CAM_SNAP := 0.22
## 拍ごとに一瞬寄る量と、戻る時間。
const PUNCH_AMOUNT := 0.1
const PUNCH_DURATION := 0.25
const SHAKE_PIXELS := 26.0
const SHAKE_DURATION := 0.3

## 見出し(上)。
const TITLE_RECT := Rect2(40, 44, 1000, 56)
const TITLE_FONT_SIZE := 40
const HEAD_RECT := Rect2(20, 108, 1040, 270)
const HEAD_FONT_SIZE := 96
const HEAD_OUTLINE := 22
const HEAD_POP_FROM := 1.45
const HEAD_POP_DURATION := 0.22
## 字幕(下)。[ ] で囲んだ語を強調色にし、| で改行する。
const SUB_RECT := Rect2(36, 1540, 1008, 300)
const SUB_FONT_SIZE := 64
const SUB_OUTLINE := 16
const CREDIT_RECT := Rect2(20, 1866, 1040, 40)
const CREDIT_FONT_SIZE := 26
const CREDIT_TEXT := "VOICEVOX:ずんだもん"
const URL_TEXT := "unityroom.com/games/sunadokei_arena"
## ステッカー(映像の上に斜めに貼る短い語)。
const STICKER_FONT_SIZE := 64
const STICKER_HOLD := 0.9
const STICKER_ANGLE := -7.0
## カット間の白い閃光。
const FLASH_ALPHA := 0.75
const FLASH_DURATION := 0.18
## 背景に敷く映像のぼかしと暗さ。
const BG_SHADER := """
shader_type canvas_item;
uniform float radius = 18.0;
uniform float dim = 0.42;
void fragment() {
	vec4 sum = vec4(0.0);
	float taps = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			sum += texture(TEXTURE, UV + vec2(float(x), float(y)) * radius * TEXTURE_PIXEL_SIZE);
			taps += 1.0;
		}
	}
	COLOR = vec4(sum.rgb / taps * dim, 1.0);
}
"""

const COLOR_TEXT := Color(1.0, 0.97, 0.9)
const COLOR_GOLD := Color(1.0, 0.8, 0.3)
const COLOR_OUTLINE := Color(0.06, 0.03, 0.01, 1.0)
const COLOR_STICKER_BG := Color(0.62, 0.13, 0.08, 1.0)
const COLOR_STICKER_EDGE := Color(1.0, 0.84, 0.4, 1.0)

## カット3の早送り。
const FAST_ROUNDS := 3
const FAST_GAP := 0.3
## カット7の図鑑で次々にめくる間隔と、見出しの数を数え上げる時間。
const ALMANAC_FLIP_GAP := 0.11
const COUNT_UP_DURATION := 0.7
const COUNT_UP_TO := 70
## 最後の画面を見せ続ける時間。
const OUTRO_HOLD := 1.8
## ナレーションの行間と、音声が無いとき(試し撮り)の1行の長さ。
const LINE_GAP := 0.06
const FALLBACK_LINE_LENGTH := 1.6
const URL_FONT_SIZE := 42

## カメラ(Tweenで動かすため公開の変数にしている)。
var cam_center := Vector2(STAGE_SIZE) * 0.5
var cam_zoom := ZOOM_WIDE
var cam_punch := 0.0
var cam_shake := 0.0

var _stage: SubViewport
var _frame: SubViewport
var _view: TextureRect
var _bg: TextureRect
var _title: Label
var _head: Label
var _sub: RichTextLabel
var _flash: ColorRect
var _voice_player: AudioStreamPlayer
var _voices: Array[AudioStream] = []
var _lines: Array = []
var _frames_dir := ""
var _frame_index := 0
var _capturing := false


func _ready() -> void:
	_parse_args()
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	_build_stage()
	await super._ready()


func _parse_args() -> void:
	var voice_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--voice="):
			voice_dir = arg.trim_prefix("--voice=")
		elif arg.begins_with("--frames="):
			_frames_dir = arg.trim_prefix("--frames=")
	var narration: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tools/pv_narration.json")
	)
	_lines = narration["lines"]
	for i in _lines.size():
		var path := voice_dir.path_join("%02d.wav" % i)
		_voices.append(AudioStreamWAV.load_from_file(path) if voice_dir != "" else null)
	if _frames_dir != "":
		DirAccess.make_dir_recursive_absolute(_frames_dir)


func _screen_host() -> Node:
	return _stage


func _start_audio() -> void:
	super._start_audio()
	# ナレーションを聞かせるためBGMを下げる(設定は保存しない)。
	SoundBank._apply_bus_volume(SoundBank.BGM_BUS, SoundBank.DEFAULT_BGM_VOLUME * 0.5)


func _build_stage() -> void:
	_stage = SubViewport.new()
	_stage.size = STAGE_SIZE * STAGE_RENDER_SCALE
	_stage.size_2d_override = STAGE_SIZE
	_stage.size_2d_override_stretch = true
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	_frame = SubViewport.new()
	_frame.size = FRAME_SIZE
	_frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_frame)
	var preview := TextureRect.new()
	preview.texture = _frame.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	add_child(preview)


## 親の _build_captions() の代わりに縦の枠の中身を組む(画面を組み終えた後に呼ばれる)。
func _build_captions() -> void:
	var root := Control.new()
	root.size = Vector2(FRAME_SIZE)
	_frame.add_child(root)
	_bg = TextureRect.new()
	_bg.texture = _stage.get_texture()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.size = Vector2(FRAME_SIZE)
	var bg_material := ShaderMaterial.new()
	bg_material.shader = Shader.new()
	bg_material.shader.code = BG_SHADER
	_bg.material = bg_material
	root.add_child(_bg)
	var clip := Control.new()
	clip.position = VIEW_RECT.position
	clip.size = VIEW_RECT.size
	clip.clip_contents = true
	root.add_child(clip)
	_view = TextureRect.new()
	_view.texture = _stage.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.size = Vector2(STAGE_SIZE)
	clip.add_child(_view)
	_title = _make_label(TITLE_RECT, TITLE_FONT_SIZE, 10, COLOR_GOLD)
	_title.text = "砂時計アリーナ"
	root.add_child(_title)
	_head = _make_label(HEAD_RECT, HEAD_FONT_SIZE, HEAD_OUTLINE, COLOR_TEXT)
	_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_head.pivot_offset = HEAD_RECT.size * 0.5
	root.add_child(_head)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.scroll_active = false
	_sub.position = SUB_RECT.position
	_sub.size = SUB_RECT.size
	_sub.add_theme_font_override("normal_font", TextGlyphs.ui_font())
	_sub.add_theme_font_size_override("normal_font_size", SUB_FONT_SIZE)
	_sub.add_theme_color_override("default_color", COLOR_TEXT)
	_sub.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_sub.add_theme_constant_override("outline_size", SUB_OUTLINE)
	_sub.add_theme_constant_override("line_separation", 8)
	root.add_child(_sub)
	var credit := _make_label(CREDIT_RECT, CREDIT_FONT_SIZE, 8, COLOR_TEXT)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.text = CREDIT_TEXT
	root.add_child(credit)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = Vector2(FRAME_SIZE)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_voice_player = AudioStreamPlayer.new()
	add_child(_voice_player)


func _make_label(rect: Rect2, font_size: int, outline: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_override("font", TextGlyphs.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_constant_override("line_spacing", -8)
	return label


func _process(_delta: float) -> void:
	if _view == null:
		return
	var zoom := cam_zoom * (1.0 + cam_punch)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * cam_shake
	_view.scale = Vector2.ONE * zoom
	_view.position = VIEW_RECT.size * 0.5 - cam_center * zoom + shake


func _on_frame_post_draw() -> void:
	if _capturing and _frames_dir != "":
		_frame.get_texture().get_image().save_png(_frames_dir.path_join("%05d.png" % _frame_index))
	_frame_index += 1


# --- 演出の部品 -------------------------------------------------------------


func _cam_to(center: Vector2, zoom: float, duration := CAM_SNAP) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "cam_center", center, duration)
	tween.tween_property(self, "cam_zoom", zoom, duration)


func _cam_cut(center: Vector2, zoom: float) -> void:
	cam_center = center
	cam_zoom = zoom


func _center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _punch() -> void:
	cam_punch = PUNCH_AMOUNT
	create_tween().tween_property(self, "cam_punch", 0.0, PUNCH_DURATION).set_ease(Tween.EASE_OUT)


func _shake() -> void:
	cam_shake = SHAKE_PIXELS
	create_tween().tween_property(self, "cam_shake", 0.0, SHAKE_DURATION)


func _flash_now() -> void:
	_flash.color.a = FLASH_ALPHA
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH_DURATION)


func _headline(text: String) -> void:
	_head.text = text
	_head.scale = Vector2.ONE * HEAD_POP_FROM
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_head, "scale", Vector2.ONE, HEAD_POP_DURATION)


func _sticker(text: String, center: Vector2, hold := STICKER_HOLD) -> void:
	var label := _make_label(Rect2(), STICKER_FONT_SIZE, 12, COLOR_TEXT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_STICKER_BG
	box.border_color = COLOR_STICKER_EDGE
	box.set_border_width_all(6)
	box.set_corner_radius_all(18)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 6
	box.content_margin_bottom = 10
	label.add_theme_stylebox_override("normal", box)
	label.text = text
	_frame.get_child(0).add_child(label)
	label.get_parent().move_child(label, _flash.get_index())
	label.size = label.get_minimum_size()
	label.position = center - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.rotation_degrees = STICKER_ANGLE
	label.scale = Vector2.ZERO
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16)
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, 0.15)
	tween.tween_callback(label.queue_free)


## 行の [ ] を強調色へ置き換えて字幕に出し、読み上げを始める。読み上げの長さ(秒)を返す。
func _say(index: int) -> float:
	var text: String = _lines[index]
	text = text.replace("[", "[color=#ffcf4a]").replace("]", "[/color]")
	text = text.replace("|", "\n")
	_sub.text = "[center]" + text + "[/center]"
	var voice: AudioStream = _voices[index]
	if voice == null:
		return FALLBACK_LINE_LENGTH
	_voice_player.stream = voice
	_voice_player.play()
	return voice.get_length()


## 読み上げの残り(長さ - 既に使った秒数)だけ待つ。
func _until(length: float, spent: float) -> void:
	await _wait(maxf(length - spent, 0.0) + LINE_GAP)


func _swap_screen(show: Control) -> void:
	_flash.color.a = 1.0
	for screen in [match_screen, list_screen, title_screen]:
		screen.visible = screen == show
	await get_tree().process_frame
	await get_tree().process_frame
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH_DURATION * 1.5)


# --- 台本 ---------------------------------------------------------------------


func _run() -> void:
	_setup_match()
	match_screen.visible = true
	await get_tree().process_frame
	_capturing = true
	if _frames_dir != "":
		var file := FileAccess.open(_frames_dir.path_join("start.txt"), FileAccess.WRITE)
		file.store_string(str(_frame_index))
		file.close()
	await _v1_hook()
	await _v2_sand()
	await _v3_fast()
	await _v4_flip()
	await _v5_flip_foe()
	await _v6_clash()
	await _v7_almanac()
	await _v8_finish()
	await _v9_outro()
	_capturing = false
	get_tree().quit()


func _board_center() -> Vector2:
	var rect := match_screen.own_slot_view(0).get_global_rect()
	rect = rect.merge(match_screen.own_slot_view(MatchState.BOARD_SIZE - 1).get_global_rect())
	rect = rect.merge(match_screen.foe_slot_view(0).get_global_rect())
	return rect.get_center()


## 1. 手札から出した瞬間の寄りから、盤面全体へ引く。
func _v1_hook() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_unit(my, 1, "lock", 6, 1)
	_unit(my, 2, "sand", 5, 2)
	_unit(my, 3, "wall", 5, 2)
	_unit(foe, 1, "lance", 3, 4)
	_unit(foe, 2, "glass", 5, 2)
	_unit(foe, 4, "shield", 6, 1)
	_dress_hand(C1_HAND_IDS)
	match_screen.state.current_turn = my
	match_screen.refresh()
	var length := _say(0)
	_headline("砂時計で戦う\nカードバトル!")
	_flash_now()
	_cam_cut(_center_of(match_screen.own_slot_view(0)), ZOOM_OPEN)
	match_screen._perform(MatchAction.play(my, 0, 0))
	_cam_to(_board_center(), ZOOM_BOARD, length)
	await _until(length, 0.0)


## 2. 1体へ寄って、上=体力・下=攻撃力を貼る。途中で1粒落とす。
func _v2_sand() -> void:
	var length := _say(1)
	var my := match_screen.my_side
	_headline("上の砂=体力\n下の砂=攻撃力")
	_cam_to(_center_of(match_screen.own_slot_view(0)), ZOOM_UNIT)
	_punch()
	var view_mid := VIEW_RECT.get_center()
	_sticker("▲ 体力", view_mid + Vector2(300, -260), length * 0.5)
	await _wait(length * 0.35)
	_sticker("▼ 攻撃力", view_mid + Vector2(290, 240), length * 0.5)
	_quietly(match_screen._perform.bind(MatchAction.end_turn(my)))
	_quietly(match_screen._perform.bind(MatchAction.end_turn(MatchState.other_side(my))))
	await _until(length, length * 0.35)


## 3. 盤面全体を早送りで回す。
func _v3_fast() -> void:
	var length := _say(2)
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_headline("毎ターン\n砂が落ちる!")
	_cam_to(_board_center(), ZOOM_BOARD)
	_sticker("▶▶ 早送り", VIEW_RECT.position + Vector2(800, 90), length * 0.8)
	var spent := 0.0
	for i in FAST_ROUNDS:
		_quietly(match_screen._perform.bind(MatchAction.end_turn(my)))
		_quietly(match_screen._perform.bind(MatchAction.end_turn(foe)))
		_punch()
		await _wait(FAST_GAP)
		spent += FAST_GAP
	await _until(length, spent)


## 4. 自分の駒を反転。
func _v4_flip() -> void:
	_clear_board()
	var my := match_screen.my_side
	_unit(my, 2, "lance", 1, 5)
	_unit(MatchState.other_side(my), 2, "sand", 4, 2)
	match_screen.state.current_turn = my
	match_screen.refresh()
	var length := _say(3)
	_flash_now()
	_headline("反転で\n数値が入れ替わる!")
	_cam_cut(_center_of(match_screen.own_slot_view(2)), ZOOM_UNIT)
	await _wait(0.25)
	match_screen._perform(MatchAction.flip(my, 2))
	_punch()
	_sticker("反転!", VIEW_RECT.get_center() + Vector2(270, -300))
	await _until(length, 0.25)


## 5. 反転権で相手の駒を裏返す。
func _v5_flip_foe() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_unit(foe, 3, "drill", 1, 6)
	_unit(my, 3, "grain", 3, 1)
	match_screen.state.current_turn = my
	match_screen.state.flip_right_remaining[my] = 3
	match_screen.refresh()
	var length := _say(4)
	_flash_now()
	_headline("相手の砂時計も\n反転できる!")
	_cam_cut(_center_of(match_screen.foe_slot_view(3)), ZOOM_UNIT * 0.85)
	await _wait(0.3)
	match_screen._flip_right.use_at(foe, 3)
	_punch()
	_sticker("反転権!", VIEW_RECT.get_center() + Vector2(-250, 300))
	await _until(length, 0.3)


## 6. 相打ち。
func _v6_clash() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_unit(my, 2, "wall", 5, 3)
	_unit(foe, 2, "sand", 5, 3)
	match_screen.state.current_turn = my
	match_screen.refresh()
	var length := _say(5)
	var own_center := _center_of(match_screen.own_slot_view(2))
	var mid := own_center.lerp(_center_of(match_screen.foe_slot_view(2)), 0.5)
	_flash_now()
	_headline("ぶつけて\n削り合え!")
	_cam_cut(mid, ZOOM_PAIR)
	match_screen._perform(MatchAction.attack(my, 2, 2))
	await _wait(0.45)
	_shake()
	_punch()
	_sticker("激突!", VIEW_RECT.get_center() + Vector2(260, 0))
	await _until(length, 0.45)


## 7. 図鑑を次々にめくり、種類の多さを数え上げる。
func _v7_almanac() -> void:
	for view in list_screen._views:
		view.locked = false
		view.queue_redraw()
	list_screen._order_button.visible = false
	for node in get_tree().get_nodes_in_group(CardListScreen.BACK_GROUP):
		node.visible = false
	await _swap_screen(list_screen)
	var length := _say(6)
	var scroll := list_screen._grid.get_parent() as ScrollContainer
	_cam_cut(_center_of(scroll), ZOOM_UNIT * 0.6)
	_cam_to(_center_of(scroll), ZOOM_PAIR * 0.75, length)
	var max_scroll := scroll.get_v_scroll_bar().max_value - scroll.size.y
	create_tween().tween_property(scroll, "scroll_vertical", int(max_scroll), length)
	_count_up()
	var spent := 0.0
	var index := 0
	while spent < length:
		list_screen._select(list_screen._views[index % list_screen._views.size()].card)
		index += 7
		await _wait(ALMANAC_FLIP_GAP)
		spent += ALMANAC_FLIP_GAP
	await _wait(LINE_GAP)


func _count_up() -> void:
	var tween := create_tween()
	tween.tween_method(
		func(value: int) -> void: _head.text = "砂時計\n%d種" % value, 0, COUNT_UP_TO, COUNT_UP_DURATION
	)
	tween.tween_callback(_headline.bind("砂時計\n70種以上!"))
	tween.tween_callback(_punch)


## 8. とどめ。
func _v8_finish() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	match_screen.state.current_turn = my
	match_screen.state.hp[foe] = C7_FOE_HP
	_unit(my, 2, "lance", C7_ATTACKER_HEALTH, C7_ATTACKER_ATTACK)
	_unit(my, 1, "grain", 4, 2)
	_unit(foe, 3, "glass", 3, 1)
	match_screen.refresh()
	await _swap_screen(match_screen)
	var length := _say(7)
	_headline("打点を\n読み切れ!")
	_cam_cut(_center_of(match_screen.own_slot_view(2)), ZOOM_PAIR)
	_cam_to(_center_of(match_screen._foe_bar), ZOOM_PAIR, 0.6)
	match_screen._perform(MatchAction.attack(my, 2, -1))
	await _wait(0.6)
	_shake()
	_flash_now()
	match_screen.refresh()
	match_screen._result.show_for(
		match_screen.state, my, match_screen.state.turn_count, "", false, false
	)
	_cam_to(_center_of(match_screen._result), ZOOM_PAIR * 0.8, 0.3)
	await _until(length, 0.6)


## 9. タイトルと遊び方の導線。
func _v9_outro() -> void:
	title_screen.start_label.visible = false
	title_screen.account_button.visible = false
	await _swap_screen(title_screen)
	var length := _say(8)
	_headline("ブラウザで\n今すぐ無料!")
	_cam_cut(Vector2(STAGE_SIZE) * 0.5, ZOOM_OPEN * 0.6)
	_cam_to(Vector2(STAGE_SIZE) * 0.5, ZOOM_WIDE * 1.2, length + OUTRO_HOLD)
	await _until(length, 0.0)
	_sub.text = (
		"[center][font_size=%d][color=#ffcf4a]%s[/color][/font_size][/center]"
		% [URL_FONT_SIZE, URL_TEXT]
	)
	_punch()
	await _wait(OUTRO_HOLD)
