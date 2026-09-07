extends SceneTree
## カードデータを Discord Bot(Cloud Functions)から読める形でJSONへ書き出す。
## `.tres` はGodot専用形式でFunctions側から読めないため、ビルドのたびにこれを実行し、
## 最新のカード一覧を `functions/data/cards.json` へ反映する(GameDesign.md 26章)。
##
## 使い方:
##   godot --headless --path . --script tools/export_card_data_json.gd

const OUTPUT_DIR := "res://functions/data"
const OUTPUT_PATH := OUTPUT_DIR + "/cards.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cards: Array = []
	for card in CardLibrary.sorted_by_pool_index():
		cards.append(_to_dict(card))

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("cannot open ", OUTPUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify({"cards": cards}, "\t"))
	file.close()
	print("wrote %d cards to %s" % [cards.size(), OUTPUT_PATH])
	quit()


## `/card` の表示に要る値だけを持たせる。効果文は describe() の完成品をそのまま渡し、
## Node.js側でキーワード・トリガーの語彙を再現させない(意味の対応表を二重に持たないため)。
func _to_dict(card: CardData) -> Dictionary:
	return {
		"id": card.id,
		"display_name": card.display_name,
		"cost": card.cost,
		"total_sand": card.total_sand,
		"is_spell": card.is_spell,
		"cannot_attack": card.cannot_attack,
		"pool_index": card.pool_index,
		"describe": card.describe(),
	}
