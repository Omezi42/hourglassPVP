extends SceneTree
## 実行時の負荷を画面別・場面別に測る(基準値の取得用。ゲーム本体は変えない)。
## 実行(ウィンドウ付きで描画させるため --headless は付けない。出力は logs/perf_probe.json と標準出力):
##   godot --path . --script res://tools/perf_probe.gd
## 垂直同期を切り fps上限を外して測る。保存データは UiState / CardDeckSave を一時ファイルへ向けて避ける。
## 「静止中に動いているもの」は、毎フレーム処理中のノード(is_processing)と、`draw` シグナルで数えた再描画を
## スクリプトのパス別に出す(各 _draw へは手を入れない)。

const OUTPUT_PATH := "res://logs/perf_probe.json"
const TEST_UI_STATE := "user://perf_probe_ui_state.json"
const TEST_DECKS := "user://perf_probe_decks.json"
const REAL_DECKS := "user://card_decks.json"
## 差し替え口が無く、Main の自動サインインが書き換えるファイル。測る前に控えて、終わりに戻す。
const ACCOUNT_PATH := "user://account.json"
const SCENE_MAIN := "res://scenes/main.tscn"

## 静止した画面を測る前の落ち着きのコマ数と、測るコマ数。
const SETTLE_FRAMES := 90
const SAMPLE_FRAMES := 300
## 画面の切り替え(フェード・横移動)が終わるまで待つコマ数の上限。
const SWITCH_WAIT_FRAMES := 240
## 対局: 手番待ちを測る前の落ち着き・測るコマ数、カードを出す演出・ターン終了の砂が落ちる間を測るコマ数。
const MATCH_IDLE_SETTLE_FRAMES := 90
const MATCH_IDLE_FRAMES := 300
const MATCH_PLAY_FRAMES := 120
const MATCH_END_TURN_FRAMES := 240
## 対局の通しを打ち切るコマ数の上限(台本が止まったときの保険)。
const MATCH_MAX_FRAMES := 12000
const FRAME_USEC := 1000.0
const SEC_TO_MSEC := 1000.0
const BYTES_PER_MB := 1048576.0
const P95 := 0.95
const TOP_SCRIPTS := 8
const NAME_WIDTH := 26

var _main: Control
var _last_usec := 0
var _phase := ""
var _samples := {}
var _results := {}
var _census_active := false
var _census := {}
var _draw_keys := {}
var _draw_items: Array[CanvasItem] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, true)
	var before := _user_file_hashes()
	var account_backup := _backup_file(ACCOUNT_PATH)
	_prepare_isolated_saves()
	_main = (load(SCENE_MAIN) as PackedScene).instantiate()
	root.add_child(_main)
	node_added.connect(_on_node_added)
	await _tick()
	await _measure_static("title", Callable())
	await _measure_static("home", func() -> void: _main._show_only(_main.home_screen))
	await _measure_static("deck_list", func() -> void: _main._on_deck_list_requested())
	await _measure_static(
		"deck_editor",
		func() -> void:
			var index := 0 if not CardDeckSave.list_decks().is_empty() else -1
			_main._on_deck_edit_requested(index)
	)
	await _measure_match()
	_write_results()
	_print_report()
	_cleanup_temp_files()
	_restore_file(ACCOUNT_PATH, account_backup)
	var after := _user_file_hashes()
	print("user:// の実データの変化: ", "なし" if before == after else "あり(要確認)")
	quit()


## 実データを書き換えないよう、保存先を一時ファイルへ向ける。デッキは中身だけ読み取って写す。
func _prepare_isolated_saves() -> void:
	UiState._save_path = TEST_UI_STATE
	UiState.mark_home_seen()
	CardDeckSave.save_path = TEST_DECKS
	var real_path := ProjectSettings.globalize_path(REAL_DECKS)
	if FileAccess.file_exists(REAL_DECKS):
		var text := FileAccess.get_file_as_string(REAL_DECKS)
		var f := FileAccess.open(TEST_DECKS, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	else:
		print("実データのデッキが無いため空の状態で測る: ", real_path)
	MatchStats.reset_for_test({})
	SoloProgress.reset_for_test()
	PuzzleProgress.reset_for_test()
	DailyMissionService.reset_for_test()


## ファイルの中身を控える。無かったときは、無かったことを覚えて戻すときに消す。
func _backup_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	return {"exists": true, "bytes": FileAccess.get_file_as_bytes(path)}


func _restore_file(path: String, backup: Dictionary) -> void:
	if not backup["exists"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(backup["bytes"])
	f.close()


func _cleanup_temp_files() -> void:
	for path in [TEST_UI_STATE, TEST_DECKS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _user_file_hashes() -> Dictionary:
	var hashes := {}
	var dir := DirAccess.open("user://")
	if dir == null:
		return hashes
	for file_name in dir.get_files():
		if file_name.get_extension() == "json" and not file_name.begins_with("perf_probe"):
			hashes[file_name] = FileAccess.get_sha256("user://" + file_name)
	return hashes


# --- フレームの記録 ---------------------------------------------------------


## 1コマ進め、いま測っている場面があればそのコマの値を記録する。
func _tick() -> void:
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_usec) / FRAME_USEC
	_last_usec = now
	if _phase.is_empty():
		return
	var s: Dictionary = _samples[_phase]
	(s["frame_ms"] as Array).append(dt)
	(s["process_ms"] as Array).append(
		Performance.get_monitor(Performance.TIME_PROCESS) * SEC_TO_MSEC
	)
	(s["draw_calls"] as Array).append(
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	(s["objects"] as Array).append(
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	)
	s["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	s["static_mem"] = Performance.get_monitor(Performance.MEMORY_STATIC)
	s["video_mem"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)


func _begin_phase(phase_name: String) -> void:
	_phase = phase_name
	_samples[phase_name] = {"frame_ms": [], "process_ms": [], "draw_calls": [], "objects": []}


func _end_phase() -> void:
	_results[_phase] = _summarize(_samples[_phase])
	_phase = ""


func _summarize(s: Dictionary) -> Dictionary:
	var frames: Array = (s["frame_ms"] as Array).duplicate()
	frames.sort()
	var count := frames.size()
	return {
		"frames": count,
		"frame_ms_avg": _average(frames),
		"frame_ms_p95": frames[mini(count - 1, int(count * P95))] if count > 0 else 0.0,
		"frame_ms_max": frames[count - 1] if count > 0 else 0.0,
		"process_ms_avg": _average(s["process_ms"]),
		"draw_calls_avg": _average(s["draw_calls"]),
		"draw_calls_max": (s["draw_calls"] as Array).max() if count > 0 else 0.0,
		"objects_avg": _average(s["objects"]),
		"node_count": s.get("nodes", 0.0),
		"static_mem_mb": float(s.get("static_mem", 0.0)) / BYTES_PER_MB,
		"video_mem_mb": float(s.get("video_mem", 0.0)) / BYTES_PER_MB,
	}


func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()


func _wait_frames(count: int) -> void:
	for i in count:
		await _tick()


# --- 静止中の動きの集計 -------------------------------------------------------


func _census_begin() -> void:
	_census = {"processing": {}, "physics": {}, "redraws": {}, "redraw_nodes": {}}
	_draw_keys.clear()
	_draw_items.clear()
	_census_active = true
	_count_processing(root)
	_connect_draws(root)


func _census_end() -> Dictionary:
	_census_active = false
	for item in _draw_items:
		if is_instance_valid(item) and item.draw.is_connected(_on_item_draw.bind(item)):
			item.draw.disconnect(_on_item_draw.bind(item))
	_draw_items.clear()
	return {
		"processing": _ranked(_census["processing"]),
		"physics_processing": _ranked(_census["physics"]),
		"redraws": _ranked(_census["redraws"]),
		"redrawing_nodes": _ranked_sets(_census["redraw_nodes"]),
	}


func _count_processing(node: Node) -> void:
	if node.can_process():
		var key := _script_key(node)
		if node.is_processing():
			_census["processing"][key] = int(_census["processing"].get(key, 0)) + 1
		if node.is_physics_processing():
			_census["physics"][key] = int(_census["physics"].get(key, 0)) + 1
	for child in node.get_children():
		_count_processing(child)


func _connect_draws(node: Node) -> void:
	if node is CanvasItem:
		_watch_draw(node)
	for child in node.get_children():
		_connect_draws(child)


func _watch_draw(item: CanvasItem) -> void:
	_draw_keys[item.get_instance_id()] = _script_key(item)
	_draw_items.append(item)
	item.draw.connect(_on_item_draw.bind(item))


func _on_node_added(node: Node) -> void:
	if _census_active and node is CanvasItem:
		_watch_draw(node)


func _on_item_draw(item: CanvasItem) -> void:
	if not item.is_visible_in_tree():
		return
	var key: String = _draw_keys.get(item.get_instance_id(), "?")
	_census["redraws"][key] = int(_census["redraws"].get(key, 0)) + 1
	var seen: Dictionary = _census["redraw_nodes"].get(key, {})
	seen[item.get_instance_id()] = true
	_census["redraw_nodes"][key] = seen


func _script_key(node: Node) -> String:
	var s: Script = node.get_script()
	if s != null and not s.resource_path.is_empty():
		return s.resource_path.trim_prefix("res://")
	return "(%s)" % node.get_class()


func _ranked(counts: Dictionary) -> Array:
	var rows: Array = []
	for key in counts:
		rows.append({"script": key, "count": counts[key]})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["count"] > b["count"])
	return rows


func _ranked_sets(sets: Dictionary) -> Array:
	var counts := {}
	for key in sets:
		counts[key] = (sets[key] as Dictionary).size()
	return _ranked(counts)


# --- 場面 -------------------------------------------------------------------


## 画面を出し、落ち着いてから測る。`open` が空ならいま出ている画面をそのまま測る。
func _measure_static(scene_name: String, open: Callable) -> void:
	if open.is_valid():
		open.call()
		await _wait_switch()
	await _wait_frames(SETTLE_FRAMES)
	_begin_phase(scene_name)
	_census_begin()
	await _wait_frames(SAMPLE_FRAMES)
	_end_phase()
	_results[scene_name]["still"] = _census_end()
	print("測定済み: ", scene_name)


func _wait_switch() -> void:
	for i in SWITCH_WAIT_FRAMES:
		await _tick()
		if _main._fade_tween == null:
			return


## 誘導対局を台本どおりに進め、手番待ち・カードを出す演出・ターン終了の砂が落ちる間をそれぞれ測る。
func _measure_match() -> void:
	_main._on_tutorial_requested()
	await _wait_switch()
	var s: CardMatchScreen = _main.card_match_screen
	var t: CardMatchTutorial = s._tutorial
	var st: MatchState = s.state
	var idle_stage := 0
	var settle_left := 0
	var phase_left := 0
	var play_done := false
	var end_done := false
	for i in MATCH_MAX_FRAMES:
		await _tick()
		if phase_left > 0:
			phase_left -= 1
			if phase_left == 0:
				_finish_match_phase()
			continue
		if settle_left > 0:
			settle_left -= 1
			if settle_left == 0:
				_begin_phase("match_idle")
				_census_begin()
				phase_left = MATCH_IDLE_FRAMES
			continue
		if st.is_match_over() or (play_done and end_done and idle_stage == 2):
			break
		if s.strike_busy():
			continue
		if t._showing_done or not t._callout_active.is_empty():
			t._on_next_pressed()
		elif st.mulligan_pending:
			s._mulligan._on_confirm_pressed()
		elif st.current_turn == s.my_side and str(t._current_step().get("side", "")) == "a":
			var action := t._cpu_action_for(st, s.my_side, t._current_step())
			if action.is_empty():
				continue
			var kind: String = action.get("type", "")
			if idle_stage == 0:
				idle_stage = 1
				settle_left = MATCH_IDLE_SETTLE_FRAMES
				continue
			idle_stage = 2
			if kind == "play" and not play_done:
				play_done = true
				_begin_phase("match_play")
				phase_left = MATCH_PLAY_FRAMES
			elif kind == "end_turn" and not end_done:
				end_done = true
				_begin_phase("match_end_turn")
				phase_left = MATCH_END_TURN_FRAMES
			s._perform(action)
	for missing in ["match_idle", "match_play", "match_end_turn"]:
		if not _results.has(missing):
			print("測れなかった場面: ", missing)


func _finish_match_phase() -> void:
	var phase_name := _phase
	var still := {}
	if phase_name == "match_idle":
		still = _census_end()
	_end_phase()
	if not still.is_empty():
		_results[phase_name]["still"] = still
	print("測定済み: ", phase_name)


# --- 出力 -------------------------------------------------------------------


func _write_results() -> void:
	var dir_path := ProjectSettings.globalize_path("res://logs")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var f := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	var info := {
		"godot": Engine.get_version_info().get("string", ""),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"gpu": RenderingServer.get_video_adapter_name(),
		"window": Vector2i(root.size),
	}
	f.store_string(JSON.stringify({"environment": info, "scenes": _results}, "  "))
	f.close()
	print("書き出し: ", dir_path.path_join("perf_probe.json"))


func _print_report() -> void:
	print("")
	print(
		(
			"%-14s %7s %7s %7s %7s %6s %6s %6s %7s %7s"
			% [
				"scene",
				"avg ms",
				"p95 ms",
				"max ms",
				"proc ms",
				"draws",
				"objs",
				"nodes",
				"mem MB",
				"vram MB"
			]
		)
	)
	for key in _results:
		var r: Dictionary = _results[key]
		print(
			(
				"%-14s %7.2f %7.2f %7.2f %7.2f %6.0f %6.0f %6.0f %7.1f %7.1f"
				% [
					key,
					r["frame_ms_avg"],
					r["frame_ms_p95"],
					r["frame_ms_max"],
					r["process_ms_avg"],
					r["draw_calls_avg"],
					r["objects_avg"],
					r["node_count"],
					r["static_mem_mb"],
					r["video_mem_mb"],
				]
			)
		)
	for key in _results:
		var still: Dictionary = _results[key].get("still", {})
		if still.is_empty():
			continue
		print("")
		print("[%s] 毎フレーム処理中のノード(スクリプト別)" % key)
		_print_rows(still["processing"], "個")
		print("[%s] 計測中の再描画回数(スクリプト別、%s)" % [key, "回 / 描いたノード数"])
		_print_redraws(still["redraws"], still["redrawing_nodes"])


func _print_rows(rows: Array, unit: String) -> void:
	for i in mini(TOP_SCRIPTS, rows.size()):
		print("  %-*s %d%s" % [NAME_WIDTH + 20, rows[i]["script"], rows[i]["count"], unit])


func _print_redraws(rows: Array, node_rows: Array) -> void:
	var nodes := {}
	for r in node_rows:
		nodes[r["script"]] = r["count"]
	for i in mini(TOP_SCRIPTS, rows.size()):
		var key: String = rows[i]["script"]
		print("  %-*s %d回 / %dノード" % [NAME_WIDTH + 20, key, rows[i]["count"], nodes.get(key, 0)])
