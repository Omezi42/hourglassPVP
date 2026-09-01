class_name HourglassTintTable
extends Resource
## 砂時計の絵の色を、カードの数ぶんの画像ではなく数値として持つ表(GameDesign.md 9章)。
##
## 1件は「親の絵のid」と「そこから1段ぶんの色変換」で、親をたどると必ず原本(サンド)へ着く。
## 数値は tools/fit_hourglass_tints.py が現行の絵から逆算したもので、
## カードを足すときは同じ道具で1行足す。

## 絵のid → { source, hue, sat, sat_bias, floor, value, value_bias, threshold }
@export var entries: Dictionary = {}


## 原本から目的の絵までの変換を、適用する順に並べて返す。
func chain(art_id: String) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var current := art_id
	while entries.has(current):
		var entry: Dictionary = entries[current]
		var source := String(entry.get("source", ""))
		if source.is_empty():
			break
		steps.push_front(entry)
		current = source
	return steps


## その絵の元になっている絵のid(原本なら空文字)。
func source_of(art_id: String) -> String:
	if not entries.has(art_id):
		return ""
	return String((entries[art_id] as Dictionary).get("source", ""))


func has(art_id: String) -> bool:
	return entries.has(art_id)
