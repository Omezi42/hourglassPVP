class_name CardSetLibrary
extends RefCounted
## 基本セット以後に追加するカードの「カードセット」定義(GameDesign.md 8章・21章)。
## `EmoteLibrary` と同じくstaticのみで持つ。
##
## **`price == 0` はショップで売らないという印**(GameDesign.md 8章「買い切り以外の
## 追加手段も検討してよい」)。ソロモード(27章)のようにステージクリアで解放するセットは、
## ここへ登録したうえで `ShopCatalog` 側が `price > 0` のものだけを品目に並べる。

## **ソロモードの3枚(GameDesign.md 27章)は、1つの3枚セットではなく1枚ずつの
## セットに分ける。**ステージごとに別々のカードを解放する設計(27章の10ステージ案)
## のため、まとめて1セットにすると1回のクリアで3枚とも渡ってしまう。
const SETS: Dictionary = {
	"solo_chime":
	{
		"id": "solo_chime",
		"display_name": "刻限の砂(ソロモード)",
		"description": "ソロモードのステージをクリアして手に入る。ショップでは売らない。",
		"card_ids": ["chime"],
		"price": 0,
	},
	"solo_ward":
	{
		"id": "solo_ward",
		"display_name": "見習いの盾(ソロモード)",
		"description": "ソロモードのステージをクリアして手に入る。ショップでは売らない。",
		"card_ids": ["ward"],
		"price": 0,
	},
	"solo_goad":
	{
		"id": "solo_goad",
		"display_name": "揺さぶりの一手(ソロモード)",
		"description": "ソロモードのステージをクリアして手に入る。ショップでは売らない。",
		"card_ids": ["goad"],
		"price": 0,
	},
	## 基本セット以後初のショップ販売カードセット(GameDesign.md 8章)。
	## 「総量(体力+攻撃力)がちょうど5」を条件に発動するコンボ系5枚。
	"combo_five":
	{
		"id": "combo_five",
		"display_name": "五砂の刻",
		"description": "総量がちょうど5になった一瞬に懸けるコンボ系5枚",
		"card_ids": ["middle", "phase", "key", "cycle", "crest"],
		"price": 500,
	},
}

const ORDERED_IDS: Array[String] = ["solo_chime", "solo_ward", "solo_goad", "combo_five"]


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
