class_name CardEffectPreview
extends Control
## カードの能力の実演(GameDesign.md 9章)。**本物の対局画面(`CardMatchScreen`)を枠の中で
## 動かし、盤面と両者の情報帯だけを切り抜いて見せる。**実演用の絵を別に持つと、カードの演出が
## 実演に映らず、対局画面と食い違った時点で誤った予習になるため。
##
## 台本は `CardEffectPlan` がカードから組み、段ごとに局面を作り直して1手ずつ指す。
## 対局は音を出さず(`CardMatchScreen.silent`)、勝敗・戦績・ミッションへは何も書かない
## (操作を受けない対局は `_interactive` を倒して作る。リーサルパズルと同じ作り方)。

## 1周を見終えた(撮影ツールが録り終わりを知るのに使う)。
signal cycle_finished

const MIN_SIZE := Vector2(320, 176)
## 局面を見せてから指すまで / 演出が落ち着いてから次の段へ移るまで。
const LEAD_SECONDS := 0.7
const HOLD_SECONDS := 1.3
## 演出の終わりを待つ上限。演出が止まらない不具合があっても実演が固まらないようにする。
const SETTLE_LIMIT_SECONDS := 6.0
## 切り抜く盤面のまわりに残す余白。
const CROP_MARGIN := 8.0

var _viewport: SubViewport
var _screen: CardMatchScreen
var _view: TextureRect
var _card: CardData
## 見せる段を1つに絞る(キーワード辞書)。-1 ならそのカードの段をすべて見せる。
var _only_kind := -1
## 再生中の台本の世代。カードを差し替えたら古い台本のループを抜けさせる。
var _generation := 0


func _ready() -> void:
	# 置き場所によって使える高さが違うため、**呼び出し側が指定していれば尊重する**。
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = MIN_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_viewport = SubViewport.new()
	_viewport.gui_disable_input = true
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_screen = CardMatchScreen.new()
	_screen.silent = true
	_screen.size = CardMatchLayout.current().screen_size
	_viewport.add_child(_screen)
	_view = TextureRect.new()
	_view.texture = _viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	resized.connect(_fit)
	visibility_changed.connect(_sync_updates)
	_fit()
	if _card != null:
		_run.call_deferred(_generation)


func show_card(card: CardData, only_kind := -1) -> void:
	_card = card
	_only_kind = only_kind
	_generation += 1
	if is_node_ready() and card != null:
		_run.call_deferred(_generation)


func clear() -> void:
	_card = null
	_generation += 1
	_sync_updates()


## 盤面と両者の情報帯を囲む矩形(縦横どちらの配置でも同じ問い合わせで取れる)。
func _crop() -> Rect2:
	var layout := CardMatchLayout.current()
	var bar := Vector2(layout.bar_size) * layout.bar_scale
	var rect := layout.table_rect
	rect = rect.merge(Rect2(layout.foe_bar_position, bar))
	rect = rect.merge(Rect2(layout.own_bar_position, bar))
	return rect.grow(CROP_MARGIN).intersection(Rect2(Vector2.ZERO, layout.screen_size))


func _fit() -> void:
	if _viewport == null:
		return
	var crop := _crop()
	_view.size = size
	_screen.position = -crop.position
	_viewport.size_2d_override = Vector2i(crop.size)
	# 描く解像度は枠の大きさに合わせる(1280x720 を描いてから縮めない)。
	var scale_to_fit := minf(size.x / crop.size.x, size.y / crop.size.y)
	_viewport.size = Vector2i((crop.size * maxf(scale_to_fit, 0.1)).ceil())
	_sync_updates()


func _sync_updates() -> void:
	if _viewport == null:
		return
	var showing := _card != null and is_visible_in_tree()
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	)


func _run(generation: int) -> void:
	_sync_updates()
	while generation == _generation and is_inside_tree():
		# 隠れている間(図鑑を閉じた・別のタブ)は局面を進めない。
		if not is_visible_in_tree():
			await _wait(HOLD_SECONDS)
			continue
		var kinds := CardEffectPlan.kinds(_card)
		if _only_kind >= 0:
			kinds = [_only_kind]
		for kind in kinds:
			if generation != _generation:
				return
			await _play_step(kind, generation)
		if generation == _generation:
			cycle_finished.emit()


## 1段ぶん。待つたびに世代を確かめ、カードが差し替わっていたら古い台本の手を指さない。
func _play_step(kind: int, generation: int) -> void:
	# 前のカードの攻撃の途中で局面を作り直すと、駒の演出の続きが宙に浮くため、終わりを待つ。
	await _settle()
	if generation != _generation:
		return
	_begin()
	var actions := CardEffectPlan.stage(_screen.state, _screen.my_side, _card, kind)
	_screen.refresh()
	await _wait(LEAD_SECONDS)
	for action in actions:
		if generation != _generation:
			return
		_screen._perform(action)
		await _settle()
	await _wait(HOLD_SECONDS)


## 局面を作り直す。CPUも持ち時間も持たない、操作を受けない対局を1つ作る。
func _begin() -> void:
	_screen._reset_for_new_match()
	_screen._interactive = false
	_screen._match_kind = CurrencyRules.MatchKind.NONE
	_screen.my_side = MatchState.Side.A
	_screen._begin_state(CardPresetDecks.basic(), CardPresetDecks.basic(), 1, false)
	_screen._cpu = null


func _settle() -> void:
	var waited := 0.0
	while waited < SETTLE_LIMIT_SECONDS and is_inside_tree():
		if _screen.state == null:
			return
		if not _screen._strike.busy() and not _screen._effect_strike.busy():
			return
		await get_tree().process_frame
		waited += get_process_delta_time()


func _wait(seconds: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(seconds).timeout
