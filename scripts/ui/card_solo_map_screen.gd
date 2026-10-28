class_name CardSoloMapScreen
extends Control
## 遠征(ソロモード)の画面(GameDesign.md 27章)。出発・道・行き先の詳細・束・恩恵・
## 工房・記録の状態の出し分けと、`SoloRun`/`SoloProgress`への保存・読み込みだけを持つ
## (Architecture.md 10.15節)。見た目は責務ごとの子へ委ねる。

signal back_pressed
## いまの段の行き先で対局・関門を選んだ(`run.in_battle`が立った)。
signal battle_requested(run: SoloRun)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
const SCREEN_SIZE := Vector2(1280, 720)
const CONTENT_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const ROUTE_RATIO := 0.6
const STATUS_GAP := 24.0
## 縦画面(GameDesign.md 9章「縦のその他の画面」)。道を縦いっぱいに描き、最下段に状態の帯を置く。
## 山札の一覧(状態のパネル)と行き先の詳細は中身ごと `PORTRAIT_SHEET_ZOOM` 倍の下から引き出す板で出す。
const PORTRAIT_DEPARTURE_ZOOM := 1.25
const PORTRAIT_SHEET_ZOOM := 1.65
const PORTRAIT_GAP := 12.0
## 山札の板が内容の高さに占める割合。
const DECK_SHEET_RATIO := 0.78
const SHEET_CLOSE_SIZE := Vector2(160, 72)
const SHEET_CLOSE_FONT_SIZE := 24
const SHEET_SHADE_COLOR := Color(0, 0, 0, 0.55)
## 詳細の板を出したとき、いまの段を板の上へずらす時間。
const ROUTE_SHIFT_SECONDS := 0.18
const ABANDON_TITLE := "遠征をやめますか"
const ABANDON_MESSAGE := "ここでやめると、いまの遠征は終わります。"
const ABANDON_CONFIRM_TEXT := "やめる"
const ABANDON_CANCEL_TEXT := "キャンセル"
## 通過数「遠征の3段目に着いた」の段(0始まり。GameDesign.md 22章)。
const FUNNEL_FLOOR_INDEX := 2

var _run: SoloRun = null
var _departure: SoloDepartureView
var _route: SoloRouteView
var _status: SoloStatusPanel
var _destination: SoloDestinationPanel
var _bundle: SoloBundleOverlay
var _boon: SoloBoonOverlay
var _workshop: SoloWorkshopOverlay
var _summary: SoloRunSummary
var _confirm: ConfirmModal
## 道で選択中の行き先(-1は未選択)。`_route`が描くリング自体は自分で持つため、
## ここでは行き先の詳細パネルの出し分けにだけ使う。
var _selected_index := -1
## 出発で示す3つの作戦(深さを変えても引き直さない。GameDesign.md 27章「画面」)。
var _departure_themes: Array[String] = []
## 出発で示す最終戦の主(GameDesign.md 27章「主」)。作戦と同じく開き直すまで引き直さない。
var _departure_boss := ""
var _departure_depth := 0
var _header: ScreenHeader
var _portrait := false
## 道の切り抜き。縦で詳細の板を出したとき、道をこの中でずらしていまの段を見せる。
var _route_clip: Control
var _strip: SoloStatusStrip
var _sheet_shade: ColorRect
var _sheet_close: Button
var _deck_sheet_open := false
var _route_tween: Tween


func _ready() -> void:
	_build()


func open() -> void:
	_run = SoloProgress.load_run(_uid())
	_selected_index = -1
	_refresh()
	if _run == null:
		var finished := SoloProgress.take_finished(_uid())
		if not finished.is_empty():
			_summary.open(finished)


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	_header = header
	header.set_title("遠征")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_departure = SoloDepartureView.new()
	_departure.position = CONTENT_RECT.position
	_departure.size = CONTENT_RECT.size
	_departure.theme_chosen.connect(_on_theme_chosen)
	_departure.depth_changed.connect(_on_departure_depth_changed)
	add_child(_departure)

	var route_w := CONTENT_RECT.size.x * ROUTE_RATIO - STATUS_GAP * 0.5
	var side_w := CONTENT_RECT.size.x * (1.0 - ROUTE_RATIO) - STATUS_GAP * 0.5
	var side_position := Vector2(
		CONTENT_RECT.position.x + route_w + STATUS_GAP, CONTENT_RECT.position.y
	)

	_route_clip = Control.new()
	_route_clip.clip_contents = true
	_route_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_clip.position = CONTENT_RECT.position
	_route_clip.size = Vector2(route_w, CONTENT_RECT.size.y)
	add_child(_route_clip)
	_route = SoloRouteView.new()
	_route.size = _route_clip.size
	_route.destination_selected.connect(_on_destination_selected)
	_route_clip.add_child(_route)

	_strip = SoloStatusStrip.new()
	_strip.visible = false
	_strip.deck_pressed.connect(_set_deck_sheet.bind(true))
	add_child(_strip)

	_sheet_shade = ColorRect.new()
	_sheet_shade.color = SHEET_SHADE_COLOR
	_sheet_shade.size = SCREEN_SIZE
	_sheet_shade.visible = false
	_sheet_shade.gui_input.connect(_on_sheet_shade_input)
	add_child(_sheet_shade)

	_status = SoloStatusPanel.new()
	_status.position = side_position
	_status.size = Vector2(side_w, CONTENT_RECT.size.y)
	_status.abandon_requested.connect(_on_abandon_requested)
	add_child(_status)

	_destination = SoloDestinationPanel.new()
	_destination.position = side_position
	_destination.size = Vector2(side_w, CONTENT_RECT.size.y)
	_destination.visible = false
	_destination.challenge_pressed.connect(_on_destination_challenge_pressed)
	_destination.back_pressed.connect(_on_destination_back_pressed)
	add_child(_destination)

	_sheet_close = CodedButton.make("閉じる", SHEET_CLOSE_SIZE)
	_sheet_close.add_theme_font_size_override("font_size", SHEET_CLOSE_FONT_SIZE)
	_sheet_close.visible = false
	_sheet_close.pressed.connect(_set_deck_sheet.bind(false))
	add_child(_sheet_close)

	_bundle = SoloBundleOverlay.new()
	_bundle.position = Vector2.ZERO
	_bundle.size = SCREEN_SIZE
	_bundle.visible = false
	_bundle.bundle_chosen.connect(_on_bundle_chosen)
	_bundle.skip_pressed.connect(_on_bundle_skip)
	add_child(_bundle)

	_boon = SoloBoonOverlay.new()
	_boon.position = Vector2.ZERO
	_boon.size = SCREEN_SIZE
	_boon.visible = false
	_boon.boon_chosen.connect(_on_boon_chosen)
	add_child(_boon)

	_workshop = SoloWorkshopOverlay.new()
	_workshop.position = Vector2.ZERO
	_workshop.size = SCREEN_SIZE
	_workshop.visible = false
	_workshop.card_removed.connect(_on_workshop_removed)
	_workshop.card_duplicated.connect(_on_workshop_duplicated)
	_workshop.skip_pressed.connect(_on_workshop_skip)
	add_child(_workshop)

	# `departure_pressed`は接続しない。押すと自分で隠れ、`open()`が既に出している
	# 出発の画面(`_departure`)がその下に見えているだけで足りるため。
	_summary = SoloRunSummary.new()
	_summary.position = Vector2.ZERO
	_summary.size = SCREEN_SIZE
	add_child(_summary)

	_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_abandon_confirmed)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。遠征の状態と選んでいる駒は保つ。
func apply_orientation(portrait: bool) -> void:
	if _header == null:
		return
	_header.apply_orientation(portrait)
	var screen := Vector2(
		ScreenOrientation.PORTRAIT_SIZE if portrait else ScreenOrientation.LANDSCAPE_SIZE
	)
	for overlay: Control in [_bundle, _boon, _workshop, _summary]:
		overlay.size = screen
		overlay.call("set_portrait", portrait)
	_portrait = portrait
	_sheet_shade.size = screen
	var content := _header.portrait_content_rect() if portrait else CONTENT_RECT
	var zoom := PORTRAIT_DEPARTURE_ZOOM if portrait else 1.0
	_departure.stacked = portrait
	_departure.position = content.position
	_departure.size = content.size / zoom
	_departure.scale = Vector2.ONE * zoom
	if portrait:
		_strip.position = Vector2(content.position.x, content.end.y - SoloStatusStrip.HEIGHT)
		_strip.size = Vector2(content.size.x, SoloStatusStrip.HEIGHT)
		_route_clip.position = content.position
		_route_clip.size = Vector2(
			content.size.x, content.size.y - SoloStatusStrip.HEIGHT - PORTRAIT_GAP
		)
		for panel: Control in [_status, _destination]:
			panel.scale = Vector2.ONE * PORTRAIT_SHEET_ZOOM
		var deck_h := content.size.y * DECK_SHEET_RATIO
		_status.position = Vector2(content.position.x, content.end.y - deck_h)
		_status.size = Vector2(content.size.x, deck_h) / PORTRAIT_SHEET_ZOOM
		_destination.size.x = content.size.x / PORTRAIT_SHEET_ZOOM
		_sheet_close.position = Vector2(
			content.end.x - SHEET_CLOSE_SIZE.x,
			_status.position.y - PORTRAIT_GAP - SHEET_CLOSE_SIZE.y
		)
	else:
		var route_w := CONTENT_RECT.size.x * ROUTE_RATIO - STATUS_GAP * 0.5
		var side_w := CONTENT_RECT.size.x * (1.0 - ROUTE_RATIO) - STATUS_GAP * 0.5
		_route_clip.position = CONTENT_RECT.position
		_route_clip.size = Vector2(route_w, CONTENT_RECT.size.y)
		for panel: Control in [_status, _destination]:
			panel.scale = Vector2.ONE
			panel.position = Vector2(
				CONTENT_RECT.position.x + route_w + STATUS_GAP, CONTENT_RECT.position.y
			)
			panel.size = Vector2(side_w, CONTENT_RECT.size.y)
	_route.position = Vector2.ZERO
	_route.size = _route_clip.size
	_route.vertical = portrait
	_route.relayout()
	_route.set_selected(_selected_index)
	_update_side_panel()
	# 出発の札は表示のたびに組むため、出ているときだけ組み直す。
	if _departure.visible:
		_refresh()


func _refresh() -> void:
	_selected_index = -1
	var has_run := _run != null
	var boon_open := has_run and not _run.boon_offer.is_empty()
	var bundle_open := has_run and not boon_open and not _run.offer.is_empty()
	var workshop_open := has_run and not boon_open and not bundle_open and _run.workshop_open
	var route_open := has_run and not boon_open and not bundle_open and not workshop_open
	_departure.visible = not has_run
	_route.visible = route_open
	_deck_sheet_open = false
	_strip.visible = route_open and _portrait
	_sheet_shade.visible = false
	_sheet_close.visible = false
	_boon.visible = boon_open
	_bundle.visible = bundle_open
	_workshop.visible = workshop_open
	if not has_run:
		var uid := _uid()
		if _departure_themes.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			_departure_themes = SoloRun.theme_choices(rng)
			_departure_boss = SoloRun.boss_choice(rng)
			_departure_depth = clampi(
				SoloProgress.last_depth(uid), 0, SoloProgress.unlocked_depth(uid)
			)
		var best_depths: Array[int] = []
		for id in _departure_themes:
			best_depths.append(SoloProgress.theme_best_depth(uid, id))
		_departure.show_data(
			_departure_themes,
			SoloProgress.best_wins(uid),
			SoloProgress.clears(uid),
			_departure_depth,
			SoloProgress.unlocked_depth(uid),
			SoloProgress.cleared_theme_count(uid),
			CardCpuDecks.deck_ids().size(),
			best_depths,
			_departure_boss
		)
		_status.visible = false
		_destination.visible = false
		return
	if boon_open:
		var gate := SoloGateLibrary.find_by_id(_run.last_gate_id)
		_boon.show_data(_run.boon_offer, _run.boons, gate.display_name if gate != null else "")
		_status.visible = false
		_destination.visible = false
		return
	if bundle_open:
		_bundle.show_data(_run.offer, _run.wins, _run.deck_ids, _run.theme_id)
		_status.visible = false
		_destination.visible = false
		return
	if workshop_open:
		_workshop.show_data(_run.deck_ids)
		_status.visible = false
		_destination.visible = false
		return
	_route.show_data(
		_run.route, _run.floor, _run.chosen, _run.expert_from_floor(), _run.spring_amount()
	)
	_update_side_panel()


## いまの段の行き先を選ぶ(取り消せる)。道の駒が描くリングとは別に、右のパネルの
## 出し分けだけをここで持つ(GameDesign.md 27章「画面」)。
func _on_destination_selected(index: int) -> void:
	_selected_index = index
	_update_side_panel()


func _update_side_panel() -> void:
	if _run == null or not _route.visible:
		return
	var options := _run.current_destinations()
	var destination_open := _selected_index >= 0 and _selected_index < options.size()
	if not destination_open:
		_selected_index = -1
	_status.show_data(
		_run.theme_id, _run.hp, _run.max_hp, _run.wins, _run.deck_ids, _run.boons, _run.depth
	)
	if destination_open:
		_destination.show_data(options[_selected_index], _run)
	if not _portrait:
		_status.visible = not destination_open
		_destination.visible = destination_open
		return
	_strip.show_data(
		_run.theme_id, _run.hp, _run.max_hp, _run.wins, _run.deck_ids.size(), _run.boons, _run.depth
	)
	if destination_open:
		_deck_sheet_open = false
	_status.visible = _deck_sheet_open
	_sheet_shade.visible = _deck_sheet_open
	_sheet_close.visible = _deck_sheet_open
	_destination.visible = destination_open
	# 詳細の板は帯を覆う。後ろに隠れた帯のボタンを押させない。
	_strip.visible = not destination_open
	var shift := 0.0
	if destination_open:
		var content := _header.portrait_content_rect()
		_destination.size.y = _destination.content_height()
		var sheet_h := _destination.size.y * PORTRAIT_SHEET_ZOOM
		_destination.position = Vector2(content.position.x, content.end.y - sheet_h)
		var room := _destination.position.y - PORTRAIT_GAP - _route_clip.position.y
		shift = minf(0.0, room - _route.current_floor_bottom())
	_shift_route(shift)


## 縦で詳細の板を出したとき、いまの段が板の上に見えるところまで道をずらす。
func _shift_route(y: float) -> void:
	if _route_tween != null:
		_route_tween.kill()
	if not is_inside_tree() or is_equal_approx(_route.position.y, y):
		_route.position.y = y
		return
	_route_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_route_tween.tween_property(_route, "position:y", y, ROUTE_SHIFT_SECONDS)


func _set_deck_sheet(open_sheet: bool) -> void:
	_deck_sheet_open = open_sheet
	_update_side_panel()


## 山札の板の後ろの暗幕は、押すと板をしまう。
func _on_sheet_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_set_deck_sheet(false)


## 道が見えている範囲(画面座標)。縦で詳細の板を出しているときは板の後ろを含めない
## (`tools/tests/solo_ui_audit.gd`が使う)。
func route_visible_rect() -> Rect2:
	var rect := _route_clip.get_global_rect()
	if _destination.visible and _portrait:
		rect.end.y = minf(rect.end.y, _destination.get_global_rect().position.y)
	return rect


func _on_destination_back_pressed() -> void:
	_route.set_selected(-1)
	_selected_index = -1
	_update_side_panel()


func _on_destination_challenge_pressed() -> void:
	_on_destination_chosen(_selected_index)


func _on_theme_chosen(theme_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_run = SoloRun.create(theme_id, _departure_depth, rng, _departure_boss)
	_departure_themes = []
	if FunnelService.has_reached(FunnelService.SOLO_START):
		FunnelService.reach(FunnelService.SOLO_AGAIN)
	else:
		FunnelService.reach(FunnelService.SOLO_START)
	SoloProgress.save_run(_uid(), _run)
	_refresh()


## 砂の深さの矢印(選べる範囲の判定・保存はここで持つ。GameDesign.md 27章「画面」)。
func _on_departure_depth_changed(delta: int) -> void:
	var uid := _uid()
	_departure_depth = clampi(_departure_depth + delta, 0, SoloProgress.unlocked_depth(uid))
	SoloProgress.set_last_depth(uid, _departure_depth)
	_refresh()


## 行き先を選ぶ。対局・関門なら対局へ進み、泉・工房ならここで結果を反映して道へ戻る。
func _on_destination_chosen(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if _run.floor >= FUNNEL_FLOOR_INDEX:
		FunnelService.reach(FunnelService.SOLO_FLOOR3)
	_run.choose(index, rng)
	# `in_battle`を立てたまま保存しておく。対局の途中で抜けたら負けにする(27章「中断と再開」)ため。
	SoloProgress.save_run(_uid(), _run)
	if _run.in_battle:
		battle_requested.emit(_run)
		return
	_refresh()


func _on_bundle_chosen(index: int) -> void:
	_run.take_bundle(index)
	_after_offer_choice()


func _on_bundle_skip() -> void:
	_run.pass_offer()
	_after_offer_choice()


func _on_boon_chosen(boon_id: String) -> void:
	_run.take_boon(boon_id)
	_after_offer_choice()


func _on_workshop_removed(card_id: String) -> void:
	_run.workshop_remove(card_id)
	_after_offer_choice()


func _on_workshop_duplicated(card_id: String) -> void:
	_run.workshop_duplicate(card_id)
	_after_offer_choice()


func _on_workshop_skip() -> void:
	_run.workshop_skip()
	_after_offer_choice()


func _after_offer_choice() -> void:
	if _run.over:
		SoloProgress.clear_run(_uid())
		_run = null
	else:
		SoloProgress.save_run(_uid(), _run)
	_refresh()


func _on_abandon_requested() -> void:
	_confirm.open_confirm(
		ABANDON_TITLE, ABANDON_MESSAGE, ABANDON_CONFIRM_TEXT, ABANDON_CANCEL_TEXT, true
	)


func _on_abandon_confirmed() -> void:
	SoloProgress.clear_run(_uid())
	_run = null
	_refresh()


func _uid() -> String:
	return StageReward.current_uid()
