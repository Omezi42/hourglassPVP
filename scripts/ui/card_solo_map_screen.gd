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
const ABANDON_TITLE := "遠征をやめますか"
const ABANDON_MESSAGE := "ここでやめると、いまの遠征は終わります。"
const ABANDON_CONFIRM_TEXT := "やめる"
const ABANDON_CANCEL_TEXT := "キャンセル"

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
	header.set_title("遠征")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_departure = SoloDepartureView.new()
	_departure.position = CONTENT_RECT.position
	_departure.size = CONTENT_RECT.size
	_departure.theme_chosen.connect(_on_theme_chosen)
	add_child(_departure)

	var route_w := CONTENT_RECT.size.x * ROUTE_RATIO - STATUS_GAP * 0.5
	var side_w := CONTENT_RECT.size.x * (1.0 - ROUTE_RATIO) - STATUS_GAP * 0.5
	var side_position := Vector2(
		CONTENT_RECT.position.x + route_w + STATUS_GAP, CONTENT_RECT.position.y
	)

	_route = SoloRouteView.new()
	_route.position = CONTENT_RECT.position
	_route.size = Vector2(route_w, CONTENT_RECT.size.y)
	_route.destination_selected.connect(_on_destination_selected)
	add_child(_route)

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


func _refresh() -> void:
	_selected_index = -1
	var has_run := _run != null
	var boon_open := has_run and not _run.boon_offer.is_empty()
	var bundle_open := has_run and not boon_open and not _run.offer.is_empty()
	var workshop_open := has_run and not boon_open and not bundle_open and _run.workshop_open
	var route_open := has_run and not boon_open and not bundle_open and not workshop_open
	_departure.visible = not has_run
	_route.visible = route_open
	_boon.visible = boon_open
	_bundle.visible = bundle_open
	_workshop.visible = workshop_open
	if not has_run:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var uid := _uid()
		_departure.show_data(
			SoloRun.theme_choices(rng), SoloProgress.best_wins(uid), SoloProgress.clears(uid)
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
	_route.show_data(_run.route, _run.floor, _run.chosen)
	_update_side_panel()


## いまの段の行き先を選ぶ(取り消せる)。道の駒が描くリングとは別に、右のパネルの
## 出し分けだけをここで持つ(GameDesign.md 27章「画面」)。
func _on_destination_selected(index: int) -> void:
	_selected_index = index
	_update_side_panel()


func _update_side_panel() -> void:
	if _run == null:
		return
	var options := _run.current_destinations()
	var destination_open := _selected_index >= 0 and _selected_index < options.size()
	_status.visible = not destination_open
	_destination.visible = destination_open
	if destination_open:
		_destination.show_data(options[_selected_index], _run)
	else:
		_selected_index = -1
		_status.show_data(_run.theme_id, _run.hp, _run.max_hp, _run.wins, _run.deck_ids, _run.boons)


func _on_destination_back_pressed() -> void:
	_route.set_selected(-1)
	_selected_index = -1
	_update_side_panel()


func _on_destination_challenge_pressed() -> void:
	_on_destination_chosen(_selected_index)


func _on_theme_chosen(theme_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_run = SoloRun.create(theme_id, rng)
	SoloProgress.save_run(_uid(), _run)
	_refresh()


## 行き先を選ぶ。対局・関門なら対局へ進み、泉・工房ならここで結果を反映して道へ戻る。
func _on_destination_chosen(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
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
