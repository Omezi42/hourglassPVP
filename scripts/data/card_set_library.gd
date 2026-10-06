class_name CardSetLibrary
extends RefCounted
## 基本セット以後に追加するカードの「カードセット」定義(GameDesign.md 8章・21章)。
## `EmoteLibrary` と同じくstaticのみで持つ。
##
## **`price == 0` はショップで売らないという印**(GameDesign.md 8章「買い切り以外の
## 追加手段も検討してよい」)。ソロモード(27章)のようにステージクリアで解放するセットは、
## ここへ登録したうえで `ShopCatalog` 側が `price > 0` のものだけを品目に並べる。
##
## **`planned_count` は段階公開の予定枚数**(GameDesign.md 21章)。`card_ids` には公開済みの
## カードだけを書き、毎日のビルドで1枚ずつ末尾へ足す。出そろったセットには書かない。

## **ソロモードの3枚(GameDesign.md 27章)は、1つの3枚セットではなく1枚ずつの
## セットに分ける。**ステージごとに別々のカードを解放する設計(27章の10ステージ案)
## のため、まとめて1セットにすると1回のクリアで3枚とも渡ってしまう。
const SETS: Dictionary = {
	"solo_chime":
	{
		"id": "solo_chime",
		"display_name": "チャイム(ソロモード)",
		"description": "ソロモードのステージをクリアして手に入る。ショップでは売らない。",
		"card_ids": ["chime"],
		"price": 0,
	},
	"solo_ward":
	{
		"id": "solo_ward",
		"display_name": "ウォード(ソロモード)",
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
	## 2番目のカードセット(GameDesign.md 8章)。「時を止める・巻き戻す」枠で、
	## 老いない駒・砂を上へ戻す・回復・条件付き除去を足してコントロールデッキを成立させる。
	"still_time":
	{
		"id": "still_time",
		"display_name": "静止の刻",
		"description": "時を止め、砂を巻き戻して長期戦へ持ち込む受けの9枚",
		"card_ids":
		[
			"freeze",
			"oasis",
			"spring",
			"anvil",
			"chronos",
			"clocktower",
			"rewind",
			"stasis",
			"verdict",
		],
		"price": 900,
	},
	## 3番目のカードセット(GameDesign.md 8章)。「砕けた砂は墓地に積もって次の糧になる」枠で、
	## 味方の破壊への反応・自壊の手段・墓地を読む効果を足し、駒の死を資源にするデッキを成立させる。
	"grave_sand":
	{
		"id": "grave_sand",
		"display_name": "遺砂の刻",
		"description": "砕けた砂を墓地から呼び戻し、駒の死を力に変える7枚",
		"card_ids": ["drift", "moss", "vigil", "relic", "cairn", "burial", "awaken"],
		"price": 700,
	},
}

const ORDERED_IDS: Array[String] = [
	"solo_chime", "solo_ward", "solo_goad", "combo_five", "still_time", "grave_sand"
]


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


## 予定枚数(GameDesign.md 21章「段階公開」)。`planned_count` が無いセットは出そろっている。
static func planned_count(set_id: String) -> int:
	var listed := card_ids(set_id).size()
	return maxi(int(SETS.get(set_id, {}).get("planned_count", listed)), listed)


## まだ公開していない枚数。0なら通常のセットと同じに見せる。
static func hidden_count(set_id: String) -> int:
	return planned_count(set_id) - card_ids(set_id).size()


## 品の名前やタイトルへ添える枚数。公開中は「n / m 枚公開中」。
static func count_text(set_id: String) -> String:
	if hidden_count(set_id) > 0:
		return "%d / %d 枚公開中" % [card_ids(set_id).size(), planned_count(set_id)]
	return "%d枚" % card_ids(set_id).size()


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
