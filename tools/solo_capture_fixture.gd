class_name SoloCaptureFixture
extends CardSoloMapScreen
## 遠征の画面を状態ごとに撮るための台(`tools/capture_screen_layout.gd` から使う)。
## `SoloProgress.reset_for_test()` で保存を止め、固定の乱数で遠征を作って状態を再現する
## (`user://` の実データには触れない)。
##   godot --path . res://tools/capture_screen_layout.tscn -- <出力先> <portrait|landscape> \
##     'SoloCaptureFixture|stage|"route"' ...
## 状態: departure / route / route_mid / dest_battle / dest_gate / dest_spring / dest_workshop /
##       route_deck(縦の山札の板) / bundle / bundle_pick / boon / workshop / workshop_pick /
##       summary_lost / summary_cleared /
##       departure_hover / route_hover(最初の札・駒にカーソルが乗った見た目) /
##       weekly_departure / weekly_done(週替わりの遠征の出発の画面。順位表は固定の見本)

const SEED := 20261028
const THEME := "rush"
const MID_FLOOR := 3
const SEED_TRIES := 200
## 週替わりの順位表の見本(通信しないで撮る・測るため)。
const SAMPLE_BOARD: Array = [
	{"uid": "a", "name": "ゆうや", "icon": "", "wins": 6, "hp": 18},
	{"uid": "b", "name": "すなえる", "icon": "", "wins": 6, "hp": 9},
	{"uid": "c", "name": "アリア", "icon": "", "wins": 5, "hp": 21},
	{"uid": "d", "name": "ひろし", "icon": "", "wins": 5, "hp": 4},
	{"uid": "e", "name": "ミナ", "icon": "", "wins": 4, "hp": 12},
	{"uid": "f", "name": "ななし", "icon": "", "wins": 3, "hp": 16},
	{"uid": "g", "name": "ハルカ", "icon": "", "wins": 3, "hp": 7},
	{"uid": "h", "name": "こうた", "icon": "", "wins": 2, "hp": 20},
	{"uid": "i", "name": "リン", "icon": "", "wins": 1, "hp": 24},
]


func open() -> void:
	SoloProgress.reset_for_test()
	super.open()


func stage(state: String) -> void:
	var rng := RandomNumberGenerator.new()
	var run: SoloRun = null
	# 泉・工房・関門がそろって1段目より先に出る道になるまで種を進める(撮る状態を毎回同じにするため)。
	for i in SEED_TRIES:
		rng.seed = SEED + i
		run = SoloRun.create(THEME, 0, rng, SoloRun.boss_choice(rng))
		if _has_all_kinds(run):
			break
	if state.begins_with("weekly"):
		_stage_weekly(state)
		return
	match state:
		"departure", "departure_hover":
			_run = null
			_refresh()
			if state == "departure_hover":
				_hover_first(_departure)
			return
		"route_mid", "summary_lost", "summary_cleared":
			_advance(run, MID_FLOOR, rng)
		"bundle", "bundle_pick":
			_advance(run, 0, rng)
			_win_battle(run, rng)
		"boon":
			_win_gate(run, rng)
		"workshop", "workshop_pick":
			_advance(run, 1, rng)
			run.workshop_open = true
		"dest_spring", "dest_workshop":
			_walk_to(run, _target_of(run, _kind_of(state)), rng)
	if state.begins_with("summary"):
		if state == "summary_cleared":
			run.cleared = true
		run.over = true
		_run = null
		_refresh()
		_summary.open({"run": run.to_dict(), "reason": ""})
		return
	_run = run
	_refresh()
	if state == "route_hover":
		_hover_first(_route)
	if state == "route_deck":
		_set_deck_sheet(true)
	if state == "workshop_pick":
		_workshop.call("_on_card_pressed", run.deck_ids[0])
	if state == "bundle_pick":
		_bundle.call("_on_row_pressed", 0)
	if state.begins_with("dest_"):
		var row := _row_of(run, _kind_of(state))
		_route.set_selected(row)
		_on_destination_selected(row)
		# 道をずらす動きを終えた形で撮る・測る。
		if _route_tween != null:
			_route_tween.custom_step(ROUTE_SHIFT_SECONDS)


## 週替わりの遠征の出発の画面。`weekly_done` は挑戦を終えた週(自分の結果が札の場所に出る)。
func _stage_weekly(state: String) -> void:
	_weekly = true
	_week = WeeklyExpedition.current_week()
	var rows: Array = SAMPLE_BOARD.duplicate(true)
	for row: Dictionary in rows:
		row["icon"] = UserProfileLibrary.DEFAULT_ICON_ID
	WeeklyBoard.set_cache_for_test(_week, rows)
	_run = null
	if state == "weekly_done":
		var run := WeeklyExpedition.create_run(_week)
		run.wins = 3
		run.hp = 11
		run.over = true
		SoloProgress.end_weekly_run(_uid(), run, "", false)
	_layout_departure()
	_refresh()
	_open_weekly_board()


## カーソルが乗った見た目を撮るため、最初の札・駒のボタンへ乗ったことにする。
func _hover_first(view: Control) -> void:
	for child in view.get_children():
		if child is Button and child.has_meta(SoloUiPaint.HOVER_VISUAL_META):
			(child as Button).mouse_entered.emit()
			return


func _has_all_kinds(run: SoloRun) -> bool:
	for kind in [SoloRun.Kind.GATE, SoloRun.Kind.SPRING, SoloRun.Kind.WORKSHOP]:
		if _target_of(run, kind) == Vector2i.ZERO:
			return false
	return true


func _kind_of(state: String) -> int:
	match state:
		"dest_gate":
			return SoloRun.Kind.GATE
		"dest_spring":
			return SoloRun.Kind.SPRING
		"dest_workshop":
			return SoloRun.Kind.WORKSHOP
	return SoloRun.Kind.BATTLE


## 対局・関門だけを選び、勝って束を見送りながら`target`段まで進める。
func _advance(run: SoloRun, target: int, rng: RandomNumberGenerator) -> void:
	while run.floor < target and not run.over:
		var row := _first_open(run, [SoloRun.Kind.BATTLE, SoloRun.Kind.GATE])
		var is_gate := int(run.current_destinations()[row]["kind"]) == SoloRun.Kind.GATE
		run.choose(row, rng)
		run.finish_battle(true, run.hp - 3, rng)
		if is_gate:
			run.take_boon(run.boon_offer[0])
		run.pass_offer()


func _win_battle(run: SoloRun, rng: RandomNumberGenerator) -> void:
	run.choose(_first_open(run, [SoloRun.Kind.BATTLE, SoloRun.Kind.GATE]), rng)
	run.finish_battle(true, run.hp - 5, rng)
	if not run.boon_offer.is_empty():
		run.take_boon(run.boon_offer[0])


func _win_gate(run: SoloRun, rng: RandomNumberGenerator) -> void:
	_advance(run, _floor_with(run, SoloRun.Kind.GATE), rng)
	run.choose(_row_of(run, SoloRun.Kind.GATE), rng)
	run.finish_battle(true, run.hp - 5, rng)


## `kind`の行き先がある最初の位置(2段目以降。泉・工房は1段目に出ない)。
func _target_of(run: SoloRun, kind: int) -> Vector2i:
	for col in run.route.size():
		var rows: Array = run.route[col]
		for row in rows.size():
			if int(rows[row]["kind"]) == kind:
				return Vector2i(col, row)
	return Vector2i(0, 0)


func _floor_with(run: SoloRun, kind: int) -> int:
	return _target_of(run, kind).x


## `target`へつながる道を後ろからたどり、その手前の段まで選んで進める。
func _walk_to(run: SoloRun, target: Vector2i, rng: RandomNumberGenerator) -> void:
	var path: Array[int] = []
	var row := target.y
	for col in range(target.x - 1, -1, -1):
		var rows: Array = run.route[col]
		for r in rows.size():
			if SoloRun.next_rows(run.route, col, r).has(row):
				row = r
				break
		path.push_front(row)
	for r in path:
		var kind := int(run.current_destinations()[r]["kind"])
		run.choose(r, rng)
		if kind == SoloRun.Kind.WORKSHOP:
			run.workshop_skip()
		elif kind != SoloRun.Kind.SPRING:
			run.finish_battle(true, run.hp - 3, rng)
			if not run.boon_offer.is_empty():
				run.take_boon(run.boon_offer[0])
			run.pass_offer()


func _row_of(run: SoloRun, kind: int) -> int:
	var rows := run.current_destinations()
	for row in rows.size():
		if int(rows[row]["kind"]) == kind and run.is_open(row):
			return row
	return _first_open(run, [SoloRun.Kind.BATTLE, SoloRun.Kind.GATE])


func _first_open(run: SoloRun, kinds: Array) -> int:
	var rows := run.current_destinations()
	for row in rows.size():
		if kinds.has(int(rows[row]["kind"])) and run.is_open(row):
			return row
	return 0
