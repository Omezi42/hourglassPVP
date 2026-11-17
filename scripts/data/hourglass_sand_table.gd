class_name HourglassSandTable
extends Resource
## 砂時計の絵ごとの砂の色と砂の質感(GameDesign.md 9章 / Architecture.md 4.1節)。
## 絵そのものは `resources/shaders/hourglasses/{id}.gdshader` が描き、ここは描き手へ渡す値だけを持つ。

## 絵のid → { sand: [r, g, b], [texture] }
@export var entries: Dictionary = {}


func has(art_id: String) -> bool:
	return entries.has(art_id)


func sand_of(art_id: String) -> Color:
	var rgb: Array = (entries[art_id] as Dictionary)["sand"]
	return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))


## 砂の質感の名前(無ければ空文字=さらさら)。
func texture_of(art_id: String) -> String:
	if not entries.has(art_id):
		return ""
	return String((entries[art_id] as Dictionary).get("texture", ""))
