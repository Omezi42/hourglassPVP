class_name RarityTable
extends Resource
## レアリティごとの砂粒のレート(GameDesign.md 15章)。`CardEnums.Rarity` の並びで持つ。

const PATH := "res://data/rarity_table.tres"

## 上限を超えて出たカード1枚が変わる砂粒。
@export var dust_gain: Array[int] = []
## カード1枚の生成に要る砂粒。
@export var craft_cost: Array[int] = []

static var _cached: RarityTable = null


static func get_table() -> RarityTable:
	if _cached == null:
		_cached = load(PATH) as RarityTable
	return _cached


func gain_of(rarity: CardEnums.Rarity) -> int:
	return dust_gain[rarity]


func cost_of(rarity: CardEnums.Rarity) -> int:
	return craft_cost[rarity]
