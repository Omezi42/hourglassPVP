extends Control
## SNS宣伝用PV(約31秒・1280x720)の素材フレームを書き出す。
## 対局画面の寄り→通常→反転→戦闘→反転権→図鑑→決着→タイトル、を固定の台本で再生する。
##
## 試し撮り(PNG連番。各カットの中ほどを見て確認する):
##   godot --path . --write-movie scratchpad/pv/f.png --fixed-fps 10 res://tools/record_pv.tscn
##
## 本番(AVI。BGM・効果音を含めて書き出す。--headless は付けない):
##   godot --path . --write-movie scratchpad/pv/pv.avi --fixed-fps 30 res://tools/record_pv.tscn
##
## 実行前に Godot プロセスが残っていないか `tasklist` で確認する(Pitfalls.md「非ヘッドレスの
## 静止画・動画キャプチャ」)。書き出し中はウィンドウを閉じない。

## 台本に使うデッキの構成札(見た目の一貫性のため、寄りで使う駒もここから引く)。
const DECK_IDS := [
	"drill",
	"lance",
	"wall",
	"sand",
	"grain",
	"shield",
	"glass",
	"poison",
	"hammer",
	"tempest",
	"dash",
	"sword"
]
## 手札の見栄え用(GameDesign.md 9章の対局画面には手札が要る)。
const HAND_IDS := ["hammer", "tempest", "poison", "glass", "shield"]

## 寄りの倍率(カット1・3で使う「駒そのものを中心に拡大」する演出)。
const ZOOM_CLOSE := 1.85
## カット1開始時の寄り(まだ何も置いていない盤面から寄り始める)。
const ZOOM_START := 1.25
## カット1で出す手札(先頭のドリルを出す)。
const C1_HAND_IDS := ["drill", "hammer", "tempest", "poison", "glass"]

## カット1(0-2.5秒): 手札から出す→体力/攻撃力の説明。**最初のフレームから動かす**
## (ズームは寄り続け、置いた直後にターン終了で砂が落ちる。静止して待たない)。
const C1_ZOOM_DURATION := 2.0
const C1_LINE1_DELAY := 0.4
const C1_TICK_DELAY := 0.6
const C1_END_HOLD := 0.6
## カット2(2.5-5秒): 早回しでの砂の遷移。ズームを戻す動きと重ねて同時に動かす。
const C2_ROUNDS := 3
const C2_TICK_GAP := 0.35
const C2_ZOOM_OUT_DURATION := 1.2
const C2_END_HOLD := 0.4
## カット3(6-10秒): 反転(スローモーション)。
const C3_TIME_SCALE := 0.5
const C3_FLIP_WAIT := 0.9
const C3_HOLD := 0.4
## カット4(10-14秒): 相打ち。
const C4_STRIKE_WAIT := 1.6
const C4_HOLD := 0.8
## カット5(14-18秒): 反転権。
const C5_STRIKE_WAIT := 1.6
const C5_HOLD := 0.8
## カット6(18-23秒): 図鑑。
const C6_PAGE_INTERVAL := 1.2
const C6_SCROLL_DURATION := 3.6
const C6_ALMANAC_IDS := ["hammer", "tempest", "poison"]
## カット7(23-27秒): 決着。
const C7_FOE_HP := 6
const C7_ATTACKER_HEALTH := 4
const C7_ATTACKER_ATTACK := 6
const C7_ASSIST_HOLD := 0.9
const C7_STRIKE_WAIT := 0.9
const C7_RESULT_HOLD := 1.2
## カット8(27-31秒): タイトルへ。
const C8_HOLD := 1.0

## テロップ(下寄り中央・濃い縁取り)。
const CAPTION_RECT := Rect2(40, 552, 1200, 96)
const CAPTION_FONT_SIZE := 34
const CAPTION_OUTLINE := 9
const CAPTION_FADE := 0.35
const CAPTION_COLOR := Color(1.0, 0.97, 0.9)
const CAPTION_OUTLINE_COLOR := Color(0.05, 0.03, 0.02, 0.92)
## カット8だけの小さな2行目(URL)。
const CAPTION_SUB_RECT := Rect2(40, 648, 1200, 40)
const CAPTION_SUB_FONT_SIZE := 20

var title_screen: TitleScreen
var match_screen: CardMatchScreen
var list_screen: CardListScreen
var sand: SandTransition
var _caption: Label
var _caption_sub: Label


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	# 色変換の焼き付けを待ってから画面を組む(Pitfalls.md/HourglassArt冒頭のコメント)。
	# 待つ間は何も足していない黒地のままなので、頭に余計なコマが入っても幕は要らない。
	await HourglassArt.ensure_ready_and_wait(self)
	_start_audio()
	var host := _screen_host()
	title_screen = load("res://scenes/title_screen.tscn").instantiate()
	title_screen.visible = false
	host.add_child(title_screen)
	match_screen = CardMatchScreen.new()
	match_screen.anchor_right = 1.0
	match_screen.anchor_bottom = 1.0
	match_screen.visible = false
	host.add_child(match_screen)
	list_screen = CardListScreen.new()
	list_screen.anchor_right = 1.0
	list_screen.anchor_bottom = 1.0
	list_screen.visible = false
	host.add_child(list_screen)
	sand = SandTransition.new()
	host.add_child(sand)
	_build_captions()
	call_deferred("_run")


## 対局・図鑑・タイトルの画面を置く先。縦長版(record_pv_vertical.gd)は横長の画面を
## SubViewport の中で動かすため、ここを差し替える。
func _screen_host() -> Node:
	return self


## 音はMain._ready()が準備するため、ここで同じ準備をする。音量はプレイヤーの設定ではなく
## 既定値で鳴らす(設定は保存しない)。BGMはクリック待ちの解錠を先に済ませて即座に流す。
func _start_audio() -> void:
	SoundBank._sfx_volume = SoundBank.DEFAULT_SFX_VOLUME
	SoundBank._bgm_volume = SoundBank.DEFAULT_BGM_VOLUME
	SoundBank.ensure_ready(self)
	MusicPlayer.ensure_ready(self)
	MusicPlayer.notify_user_gesture()
	MusicPlayer.play(MusicPlayer.Track.MATCH)


## テロップ層。**最前面の独立ノード**として最後に足す(Pitfalls.md「後から add_child() した
## 子ほど手前に描かれる」)。
func _build_captions() -> void:
	_caption = _make_caption_label(CAPTION_RECT, CAPTION_FONT_SIZE)
	add_child(_caption)
	_caption_sub = _make_caption_label(CAPTION_SUB_RECT, CAPTION_SUB_FONT_SIZE)
	add_child(_caption_sub)


func _make_caption_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_override("font", TextGlyphs.ui_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CAPTION_COLOR)
	label.add_theme_color_override("font_outline_color", CAPTION_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", CAPTION_OUTLINE)
	label.add_theme_constant_override("line_spacing", 6)
	label.modulate.a = 0.0
	return label


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


func _deck() -> Array:
	var cards: Array = []
	for id in DECK_IDS:
		cards.append(_card(id))
		cards.append(_card(id))
	return cards


func _unit(side: int, slot: int, id: String, health: int, attack: int) -> CardInstance:
	var inst := CardInstance.new(_card(id))
	inst.health = health
	inst.attack = attack
	inst.summoned_this_turn = false
	inst.attacks_this_turn = 0
	inst.flipped_this_turn = false
	match_screen.state.board[side][slot] = inst
	return inst


func _clear_board() -> void:
	var state := match_screen.state
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	for side in [my, foe]:
		for slot in MatchState.BOARD_SIZE:
			state.board[side][slot] = null


## 手番の切り替わりで出る実況の幕(「対局開始」「あなたの番」)を出させない。
## 台本の間ずっと同じテロップを見せたいための撮影専用の処置で、`_interactive` を
## 一瞬だけ倒して `CardMatchTurnFeed` の表示条件を外す(呼び出しは同期関数のため、
## この間にフレームが描かれることはない)。
func _quietly(call: Callable) -> void:
	var was_interactive: bool = match_screen._interactive
	match_screen._interactive = false
	call.call()
	match_screen._interactive = was_interactive


func _dress_hand(ids: Array) -> void:
	var hand: Array = []
	for id in ids:
		hand.append(_card(id))
	match_screen.state.hand[match_screen.my_side] = hand


## カメラ寄り。**駒そのものを基準点にして拡大する**ため、scaleが変わっても
## position/pivot_offset を動かし直さずに済む(scale=1へ戻せば必ず等倍の元の見た目に戻る)。
func _zoom_set_pivot(point: Vector2) -> void:
	match_screen.pivot_offset = point
	match_screen.position = Vector2.ZERO


func _zoom_to(value: float, duration: float) -> void:
	var tween := create_tween()
	(
		tween
		. tween_property(match_screen, "scale", Vector2.ONE * value, duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _cap_show(text: String) -> void:
	_caption.text = text
	_caption.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, CAPTION_FADE)
	await tween.finished


func _cap_add_line(text: String) -> void:
	_caption.text += "\n" + text
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, CAPTION_FADE * 0.5)
	await tween.finished


func _cap_hide() -> void:
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 0.0, CAPTION_FADE)
	await tween.finished
	_caption.text = ""


func _cap_show_sub(main_text: String, sub_text: String) -> void:
	_caption.text = main_text
	_caption_sub.text = sub_text
	_caption.modulate.a = 0.0
	_caption_sub.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_caption, "modulate:a", 1.0, CAPTION_FADE)
	tween.tween_property(_caption_sub, "modulate:a", 1.0, CAPTION_FADE)
	await tween.finished


func _setup_match() -> void:
	match_screen.start_cpu_match(_deck(), _deck())
	# CPUに勝手に指させない(GameDesign.md仕様ではなく撮影の都合)。台本の手だけで進める。
	match_screen._cpu = null
	# 対局の勝敗・砂金・戦績・リプレイは実データへ書かない(Pitfalls.md「触れてはいけないもの」)。
	# 決着(カット7)は結果パネルを直接呼んで見せ、実際の後始末(CardMatchOutcome)は通さない。
	match_screen.state.match_ended.disconnect(match_screen._on_match_ended)
	_quietly(match_screen._on_mulligan_confirmed.bind([]))
	_dress_hand(HAND_IDS)
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	match_screen.state.mana[my] = 7
	match_screen.state.max_mana[my] = 7
	match_screen.state.mana[foe] = 7
	match_screen.state.max_mana[foe] = 7
	match_screen.refresh()


func _run() -> void:
	_setup_match()
	match_screen.visible = true
	await _cut1()
	await _cut2()
	await _cut3()
	await _cut4()
	await _cut5()
	await _cut6()
	await _cut7()
	await _cut8()
	get_tree().quit()


## 1. 手札からドリルを出す。最初のフレームから寄りが動き続け、静止して待たない。
## 上の砂=体力、下の砂=攻撃力。着地したターン終了で1粒落ちる。
func _cut1() -> void:
	_clear_board()
	var my := match_screen.my_side
	# 空き枠(0)を残し、両隣に既に育った駒を置いて盤面をにぎやかにしておく。
	_unit(my, 1, "lock", 6, 1)
	_unit(my, 2, "sand", 6, 1)
	_dress_hand(C1_HAND_IDS)
	match_screen.state.current_turn = my
	match_screen.refresh()
	var view := match_screen.own_slot_view(0)
	_zoom_set_pivot(view.position + view.size * 0.5)
	match_screen.scale = Vector2.ONE * ZOOM_START
	_zoom_to(ZOOM_CLOSE, C1_ZOOM_DURATION)
	match_screen._perform(MatchAction.play(my, 0, 0))
	await _wait(C1_LINE1_DELAY)
	await _cap_show("上の砂は「体力」")
	await _wait(C1_TICK_DELAY)
	_quietly(match_screen._perform.bind(MatchAction.end_turn(my)))
	_cap_add_line("下の砂は「攻撃力」")
	_quietly(match_screen._perform.bind(MatchAction.end_turn(MatchState.other_side(my))))
	await _wait(C1_END_HOLD)
	await _cap_hide()


## 2. 早回し: 自陣3体・相手の駒が同時に砂を落とす。寄りを戻す動きも同時に始める。
func _cut2() -> void:
	_zoom_to(1.0, C2_ZOOM_OUT_DURATION)
	_cap_show("時が経つほど、強く脆くなる。")
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	for i in C2_ROUNDS:
		_quietly(match_screen._perform.bind(MatchAction.end_turn(my)))
		_quietly(match_screen._perform.bind(MatchAction.end_turn(foe)))
		await _wait(C2_TICK_GAP)
	await _wait(C2_END_HOLD)
	await _cap_hide()
	match_screen.scale = Vector2.ONE
	match_screen.position = Vector2.ZERO


## 3. 反転(スローモーション)。
func _cut3() -> void:
	_clear_board()
	_unit(match_screen.my_side, 0, "lance", 1, 5)
	match_screen.refresh()
	var view := match_screen.own_slot_view(0)
	_zoom_set_pivot(view.position + view.size * 0.5)
	match_screen.scale = Vector2.ONE * ZOOM_CLOSE
	Engine.time_scale = C3_TIME_SCALE
	await _cap_show("ひっくり返せば、体力と攻撃力が入れ替わる。")
	match_screen.state.current_turn = match_screen.my_side
	match_screen._perform(MatchAction.flip(match_screen.my_side, 0))
	await _wait(C3_FLIP_WAIT)
	await _cap_hide()
	await _wait(C3_HOLD)
	Engine.time_scale = 1.0
	match_screen.scale = Vector2.ONE
	match_screen.position = Vector2.ZERO


## 4. 相打ち。
func _cut4() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_unit(my, 1, "wall", 5, 3)
	_unit(foe, 1, "sand", 5, 3)
	match_screen.refresh()
	match_screen.state.current_turn = my
	await _cap_show("ぶつかれば、互いの砂を削り合う。")
	match_screen._perform(MatchAction.attack(my, 1, 1))
	await _wait(C4_STRIKE_WAIT)
	await _cap_hide()
	await _wait(C4_HOLD)


## 5. 反転権で相手の駒を裏返す。
func _cut5() -> void:
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	_unit(foe, 0, "drill", 1, 6)
	_unit(my, 0, "grain", 3, 1)
	match_screen.refresh()
	match_screen.state.current_turn = my
	match_screen.state.flip_right_remaining[my] = 3
	await _cap_show("相手の砂時計さえ、ひっくり返せ。")
	match_screen._flip_right.use_at(foe, 0)
	await _wait(C5_STRIKE_WAIT)
	await _cap_hide()
	await _wait(C5_HOLD)


## 6. 砂時計図鑑。左は自動スクロール、右は3枚をめくって見せる。
func _cut6() -> void:
	await sand.cover()
	match_screen.visible = false
	list_screen.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	# 未購入のカードでも「未発見」表示にしない(撮影専用の見せ方)。
	for view in list_screen._views:
		view.locked = false
		view.queue_redraw()
	list_screen._order_button.visible = false
	for node in get_tree().get_nodes_in_group(CardListScreen.BACK_GROUP):
		node.visible = false
	var scroll := list_screen._grid.get_parent() as ScrollContainer
	var max_scroll := scroll.get_v_scroll_bar().max_value - scroll.size.y
	var scroll_tween := create_tween()
	scroll_tween.tween_property(scroll, "scroll_vertical", int(max_scroll), C6_SCROLL_DURATION)
	await sand.reveal()
	await _cap_show("70種以上の「砂時計」と「砂術」")
	for id in C6_ALMANAC_IDS:
		list_screen._select(_card(id))
		await _wait(C6_PAGE_INTERVAL)
	await _cap_hide()


## 7. 決着。打点アシストが「決着可能」を示してから本体を殴る。
func _cut7() -> void:
	await sand.cover()
	list_screen.visible = false
	match_screen.visible = true
	_clear_board()
	var my := match_screen.my_side
	var foe := MatchState.other_side(my)
	match_screen.state.current_turn = my
	match_screen.state.hp[foe] = C7_FOE_HP
	_unit(my, 1, "lance", C7_ATTACKER_HEALTH, C7_ATTACKER_ATTACK)
	_unit(my, 0, "grain", 4, 2)
	_unit(foe, 2, "glass", 3, 1)
	match_screen.refresh()
	await sand.reveal()
	await _cap_show("落ちゆく砂の、その先を読め。")
	await _wait(C7_ASSIST_HOLD)
	match_screen._perform(MatchAction.attack(my, 1, -1))
	await _wait(C7_STRIKE_WAIT)
	match_screen.refresh()
	match_screen._result.show_for(
		match_screen.state, my, match_screen.state.turn_count, "", false, false
	)
	await _cap_hide()
	await _wait(C7_RESULT_HOLD)


## 8. タイトルへ戻り、プレイの導線を示す。
func _cut8() -> void:
	await sand.cover()
	match_screen.visible = false
	title_screen.visible = true
	title_screen.start_label.visible = false
	title_screen.account_button.visible = false
	await sand.reveal()
	await _cap_show_sub("ブラウザで今すぐ無料プレイ", "unityroom.com/games/sunadokei_arena")
	await _wait(C8_HOLD)
