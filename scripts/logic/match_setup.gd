class_name MatchSetup
extends RefCounted

const HOURGLASS_DIR := "res://data/hourglasses/"
# エクスポート後のpck内では .tres が "<name>.tres.remap" として列挙される
const REMAP_SUFFIX := ".remap"

static var player_deck: Array[HourglassData] = []
static var opponent_deck: Array[HourglassData] = []


static func all_hourglasses() -> Array[HourglassData]:
	var result: Array[HourglassData] = []
	var dir := DirAccess.open(HOURGLASS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var resource_name := file_name.trim_suffix(REMAP_SUFFIX)
		if resource_name.ends_with(".tres"):
			result.append(load(HOURGLASS_DIR + resource_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: HourglassData, b: HourglassData) -> bool: return a.id < b.id)
	return result


static func find_by_id(id: String) -> HourglassData:
	for data in all_hourglasses():
		if data.id == id:
			return data
	return null
