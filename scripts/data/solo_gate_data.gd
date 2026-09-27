class_name SoloGateData
extends Resource
## 遠征(ソロモード)の関門1つぶんの特殊ルール(GameDesign.md 27章「関門」)。
## `data/solo_gates/{id}.tres`。関門を1つ足すのは `.tres` を1個作るだけで済む
## (Architecture.md 10.15節)。

enum WinCondition { HP_ZERO, SURVIVE_TURNS, DESTROY_ALL_ENEMY_UNITS }

@export var id: String = ""
@export var display_name: String = ""
## 1〜2行の説明。結果パネル(負けたとき)にも出す。
@export var description: String = ""

## 初期盤面。`"id:体力:攻撃力"`(`PuzzleStageData` と同じ表現)。空なら空の盤面。
@export var own_board_units: Array[String] = []
@export var foe_board_units: Array[String] = []

@export var win_condition: WinCondition = WinCondition.HP_ZERO
## `win_condition == SURVIVE_TURNS` のときの目標(`MatchState.turn_count`)。
@export var survive_turns: int = 0

## `MatchState.sand_drop_count` へそのまま渡す。既定1。
@export var sand_drop_count: int = 1
## `MatchState.flip_disabled` へそのまま渡す。
@export var flip_disabled: bool = false
## `MatchState.clash_damage_multiplier` へそのまま渡す。既定1。
@export var clash_damage_multiplier: int = 1
