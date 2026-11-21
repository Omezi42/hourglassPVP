class_name PackDefinition
extends Resource
## 弾1つぶんのパックの定義(GameDesign.md 21章 / Architecture.md 10.8.1節)。
## 確率・天井・価格はここだけに置き、コードへ書かない。

const DIR := "res://data/packs/"
## 売り出している弾のid(`data/packs/{id}.tres`)。弾を足すときはここへ1行足す。
const PACK_IDS: Array[String] = ["first"]

## 通常の枠(1〜`cards_per_pack - 1` 枚目)の確率。`CardEnums.Rarity` の並び(コモン→レジェンド)。合計1。
@export var slot_rates: Array[float] = []
## 最後の枠(レア以上確定)の確率。`slot_rates` と同じ並び。合計1。
@export var last_slot_rates: Array[float] = []
@export var id: String = ""
@export var display_name: String = ""
## 1パックの砂金。
@export var price: int = 0
@export var cards_per_pack: int = 5
## レジェンドが出ないまま開けたパックがこの数に達した次の最後の枠は、レジェンドになる。
## 「40パック目の5枚目」なので、出ないまま開けた数がこの値-1のとき確定する。
@export var pity_packs: int = 40
## 含めるテーマ(`CardSetLibrary` のid)。
@export var set_ids: Array[String] = []


## `rarity` が出る確率。`last` は最後の枠。
func rate(rarity: CardEnums.Rarity, last: bool) -> float:
	var rates := last_slot_rates if last else slot_rates
	return rates[rarity] if rarity < rates.size() else 0.0


## 弾のid(`data/packs/{id}.tres`)から読む。無ければ null。
static func load_pack(pack_id: String) -> PackDefinition:
	var path := DIR + pack_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackDefinition
