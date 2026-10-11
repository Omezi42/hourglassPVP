extends SceneTree
## カードを順に1枚ずつ測り、1行ずつCSVへ足していく(BalanceReport_v5.md 2章の方式)。
## 1枚測り終えるたびに書き出すため、途中で止めても続きから再開できる(CSVにある id は飛ばす)。
## 並列で回すときは tools/balance/run_card_batch.sh から呼ぶ。
##
## 使い方:
##   Godot --headless --path . --script res://tools/balance/run_card_batch.gd -- \
##       out=tools/balance/out/cards.csv ids=all games=800 seed=42 shard=0/4
##
## ids: all(既定)/ カンマ区切りの id / set:<set_id>(set_id が空の基本セットは set:base)
## shard=i/n: 対象を n 等分した i 番目だけを測る(0始まり)

const HEADER := "id,name,kind,set_id,pool_index,cost,total,games,seed,win_rate"
const BASE_SET_LABEL := "base"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var out_path: String = args.get("out", "")
	if out_path.is_empty():
		printerr("out= が必要です")
		quit(1)
		return
	var games: int = int(args.get("games", "800"))
	var seed_value: int = int(args.get("seed", "42"))
	var targets := _select(str(args.get("ids", "all")))
	targets = _shard(targets, str(args.get("shard", "0/1")))

	var done := _measured_ids(out_path)
	var file := _open_for_append(out_path)
	if file == null:
		quit(1)
		return
	var probe := CardWinRateProbe.new()
	for card in targets:
		if done.has(card.id):
			continue
		var rate := probe.measure(card, games, seed_value)
		file.store_line(_row(card, games, seed_value, rate))
		file.flush()
		print("%s %.1f%%" % [card.id, rate * 100.0])
	file.close()
	quit()


func _select(ids: String) -> Array[CardData]:
	var cards := CardLibrary.all_cards()
	if ids == "all":
		return cards
	var picked: Array[CardData] = []
	if ids.begins_with("set:"):
		var set_id := ids.trim_prefix("set:")
		for card in cards:
			var label := card.set_id if not card.set_id.is_empty() else BASE_SET_LABEL
			if label == set_id:
				picked.append(card)
		return picked
	for id in ids.split(","):
		var card := CardLibrary.find_by_id(id.strip_edges())
		if card == null or card.is_token:
			printerr("unknown card id: ", id)
			continue
		picked.append(card)
	return picked


func _shard(cards: Array[CardData], spec: String) -> Array[CardData]:
	var parts := spec.split("/")
	var index := int(parts[0])
	var count := maxi(int(parts[1]), 1)
	var picked: Array[CardData] = []
	for i in cards.size():
		if i % count == index:
			picked.append(cards[i])
	return picked


func _measured_ids(path: String) -> Dictionary:
	var ids: Dictionary = {}
	if not FileAccess.file_exists(path):
		return ids
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty() or line == HEADER:
			continue
		ids[line.split(",")[0]] = true
	return ids


func _open_for_append(path: String) -> FileAccess:
	var exists := FileAccess.file_exists(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		printerr("cannot open: ", path)
		return null
	if exists:
		file.seek_end()
	else:
		file.store_line(HEADER)
	return file


func _row(card: CardData, games: int, seed_value: int, rate: float) -> String:
	var fields := [
		card.id,
		card.display_name,
		"spell" if card.is_spell else "hourglass",
		card.set_id if not card.set_id.is_empty() else BASE_SET_LABEL,
		card.pool_index,
		card.cost,
		card.total_sand,
		games,
		seed_value,
		"%.1f" % (rate * 100.0),
	]
	return ",".join(fields.map(func(value): return str(value)))


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
