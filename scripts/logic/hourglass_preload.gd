class_name HourglassPreload
extends RefCounted
## 対局で使う砂時計の絵(止めた絵と、動く絵の後ろ・枠の層)を、対局の始め(マリガン・コイン)の間に
## 1コマ数msずつ読み込んでおく(Architecture.md 10.19節)。
##
## 絵は非可逆(WebP)で取り込んでおり、1枚の読み込みにデスクトップで5〜10ms、Web版ではその数倍かかる。
## 駒を初めて出す・状態が変わる瞬間に読むと、そのコマが止まる。読んだ絵はここが持ち続けるため、
## 後の `load()` は読み直さずに同じものを返す。

## 1コマで読み込みに使ってよい時間(マイクロ秒)。超えたら次のコマへ回す(最低1枚は読む)。
const FRAME_BUDGET_USEC := 4000

static var _queue: Array = []
static var _queued: Dictionary = {}
static var _held: Dictionary = {}


## `art_keys` の絵を読み込む予約をする。先に渡したものから、上向き → 落下中 → 落ちきりの順に読む。
## ヘッドレスでは描かないため何もしない。
static func request(art_keys: Array) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for state in HourglassArt.STATE_FILES.size():
		for art_key in art_keys:
			var job := "%s|%d" % [art_key, state]
			if _queued.has(job):
				continue
			_queued[job] = true
			_queue.append([String(art_key), state])
	var tree := Engine.get_main_loop() as SceneTree
	if not _queue.is_empty() and not tree.process_frame.is_connected(_step):
		tree.process_frame.connect(_step)


## まだ読み終えていない予約の数(テスト用)。
static func pending() -> int:
	return _queue.size()


static func _step() -> void:
	var started := Time.get_ticks_usec()
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		_load(job[0], job[1])
		if Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC:
			break
	if _queue.is_empty():
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_step)


static func _load(art_key: String, state: int) -> void:
	# 止めた絵は `HourglassArt` が控える。
	HourglassArt.texture(art_key, state)
	if not HourglassLive.has_shader(art_key):
		return
	for layer in [HourglassLive.LAYER_BACK, HourglassLive.LAYER_FRAME]:
		var path := HourglassLive.layer_path(art_key, state, layer)
		if not _held.has(path):
			_held[path] = load(path) if ResourceLoader.exists(path) else null
