class_name CardSetLibrary
extends RefCounted
## 基本セット以後に追加するカードの「カードセット」定義(GameDesign.md 8章・21章)。
## `EmoteLibrary` と同じくstaticのみで持つ。
##
## **`price == 0` はショップで売らないという印**(GameDesign.md 8章「買い切り以外の
## 追加手段も検討してよい」)。ソロモード(27章)のようにステージクリアで解放するセットは、
## ここへ登録したうえで `ShopCatalog` 側が `price > 0` のものだけを品目に並べる。

const SETS: Dictionary = {
	"solo":
	{
		"id": "solo",
		"display_name": "ソロモードセット",
		"description": "ソロモードのステージをクリアして手に入る3枚。ショップでは売らない。",
		"card_ids": ["chime", "ward", "goad"],
		"price": 0,
	},
}

const ORDERED_IDS: Array[String] = ["solo"]


static func has_set(set_id: String) -> bool:
	return SETS.has(set_id)


static func display_name(set_id: String) -> String:
	return str(SETS.get(set_id, {}).get("display_name", ""))


static func description(set_id: String) -> String:
	return str(SETS.get(set_id, {}).get("description", ""))


static func card_ids(set_id: String) -> Array[String]:
	var found: Array[String] = []
	for id in SETS.get(set_id, {}).get("card_ids", []):
		found.append(str(id))
	return found


## 0はショップで売らないセット(GameDesign.md 8章)。
static func price(set_id: String) -> int:
	return int(SETS.get(set_id, {}).get("price", 0))


## ショップに並べる、購入できるセットだけ(GameDesign.md 21章)。
static func purchasable_ids() -> Array[String]:
	var found: Array[String] = []
	for id in ORDERED_IDS:
		if price(id) > 0:
			found.append(id)
	return found
