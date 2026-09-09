class_name SoloMatchConfig
extends Resource
## ソロモードのステージのうち、パズル型以外(CPU対戦型・特殊ルール型・連戦型・縛り型)が
## 使う対局設定(GameDesign.md 27章)。`SoloStageData.match_config` へ埋め込む。

enum WinCondition { HP_ZERO, SURVIVE_TURNS, DESTROY_ALL_ENEMY_UNITS }

## 30枚ぶんのid。**プレイヤー自身の構築デッキは使わない**(27章)。
@export var player_deck_ids: Array[String] = []
@export var opponent_deck_ids: Array[String] = []
## 連戦(GAUNTLET)型でのみ2以上。既定1。
@export var opponent_count: int = 1

## 初期盤面の上書き。`"id:体力:攻撃力"`(`PuzzleStageData`と同じ表現)。空なら
## 通常どおり空の盤面から開始する。
@export var own_board_units: Array[String] = []
@export var foe_board_units: Array[String] = []

@export var win_condition: WinCondition = WinCondition.HP_ZERO
## `win_condition == SURVIVE_TURNS` のときの目標ターン数。
@export var survive_turns: int = 0

## `MatchState.sand_drop_count` へそのまま渡す。既定1。
@export var sand_drop_count: int = 1
## 0 なら `MatchState.INITIAL_HP` のまま。0より大きければ両者のHPをこの値で開始する。
@export var hp_override: int = 0
## `MatchState.mana_frozen` へそのまま渡す。
@export var mana_frozen: bool = false
## `MatchState.flip_disabled` へそのまま渡す。
@export var flip_disabled: bool = false
## `MatchState.clash_damage_multiplier` へそのまま渡す。既定1。
@export var clash_damage_multiplier: int = 1
