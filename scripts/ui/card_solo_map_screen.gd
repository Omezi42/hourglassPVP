class_name CardSoloMapScreen
extends Control
## 遠征(ソロモード)の画面(GameDesign.md 27章)。出発・道・候補の3つの状態を
## 責務ごとの子(`SoloDepartureView`/`SoloRouteView`/`SoloStatusPanel`/`SoloOfferOverlay`)へ
## 委ね、ここは状態の出し分けと`SoloRun`/`SoloProgress`への保存・読み込みだけを持つ
## (Architecture.md 10.15節)。見た目は承認済みのモック(`tools/tmp_mock_solo.gd`)のとおり。

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
var _offer: SoloOfferOverlay
var _confirm: ConfirmModal


func _ready() -> void:
	_build()


func open() -> void:
	_run = SoloProgress.load_run(_uid())
	_refresh()


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
	var status_w := CONTENT_RECT.size.x * (1.0 - ROUTE_RATIO) - STATUS_GAP * 0.5

	_route = SoloRouteView.new()
	_route.position = CONTENT_RECT.position
	_route.size = Vector2(route_w, CONTENT_RECT.size.y)
	_route.destination_chosen.connect(_on_destination_chosen)
	add_child(_route)

	_status = SoloStatusPanel.new()
	_status.position = Vector2(
		CONTENT_RECT.position.x + route_w + STATUS_GAP, CONTENT_RECT.position.y
	)
	_status.size = Vector2(status_w, CONTENT_RECT.size.y)
	_status.abandon_requested.connect(_on_abandon_requested)
	add_child(_status)

	_offer = SoloOfferOverlay.new()
	_offer.position = Vector2.ZERO
	_offer.size = SCREEN_SIZE
	_offer.visible = false
	_offer.card_chosen.connect(_on_offer_card_chosen)
	_offer.skip_pressed.connect(_on_offer_skip)
	add_child(_offer)

	_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_abandon_confirmed)


func _refresh() -> void:
	var has_run := _run != null
	var offer_open := has_run and not _run.offer.is_empty()
	_departure.visible = not has_run
	_route.visible = has_run and not offer_open
	_status.visible = has_run and not offer_open
	_offer.visible = offer_open
	if not has_run:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var uid := _uid()
		_departure.show_data(
			SoloRun.theme_choices(rng), SoloProgress.best_wins(uid), SoloProgress.clears(uid)
		)
		return
	if offer_open:
		_offer.show_data(_run.offer, _run.wins, _run.deck_ids.size(), _run.theme_id)
		return
	_route.show_data(_run.route, _run.floor, _run.chosen)
	_status.show_data(_run.theme_id, _run.hp, MatchState.INITIAL_HP, _run.wins, _run.deck_ids)


func _on_theme_chosen(theme_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_run = SoloRun.create(theme_id, rng)
	SoloProgress.save_run(_uid(), _run)
	_refresh()


func _on_destination_chosen(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_run.choose(index, rng)
	if _run.in_battle:
		battle_requested.emit(_run)
		return
	SoloProgress.save_run(_uid(), _run)
	_refresh()


func _on_offer_card_chosen(card_id: String) -> void:
	_run.take(card_id)
	_after_offer_choice()


func _on_offer_skip() -> void:
	_run.pass_offer()
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
