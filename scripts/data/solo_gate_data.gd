class_name SoloGateData
extends Resource
## 遠征(ソロモード)の関門・主1つぶんの特殊ルール(GameDesign.md 27章「関門」「主」)。
## 関門は `data/solo_gates/{id}.tres`、主は `data/solo_bosses/{id}.tres`。1つ足すのは `.tres` を
## 1個作るだけで済む(Architecture.md 10.15節)。

## 保存データ・`.tres`が整数で持つため末尾へ足す(Pitfalls.md)。
enum WinCondition { HP_ZERO, SURVIVE_TURNS, DESTROY_ALL_ENEMY_UNITS, WIN_WITHIN_TURNS }

@export var id: String = ""
@export var display_name: String = ""
## 1〜2行の説明。結果パネル(負けたとき)にも出す。
@export var description: String = ""

## 初期盤面。`"id:体力:攻撃力"`(`PuzzleStageData` と同じ表現)。空なら空の盤面。
@export var own_board_units: Array[String] = []
@export var foe_board_units: Array[String] = []

@export var win_condition: WinCondition = WinCondition.HP_ZERO
## `SURVIVE_TURNS` はこの`MatchState.turn_count`を超えた自分の手番で勝ち、
## `WIN_WITHIN_TURNS` はこれを超えた相手の手番で負け(期限)。
@export var survive_turns: int = 0

## `MatchState.sand_drop_count` へそのまま渡す。既定1。
@export var sand_drop_count: int = 1
## `MatchState.flip_disabled` へそのまま渡す。
@export var flip_disabled: bool = false
## `MatchState.clash_damage_multiplier` へそのまま渡す。既定1。
@export var clash_damage_multiplier: int = 1

## 対局開始時に相手のHPへ足す(主の「HPが8多い」、速攻勝負・急ぎの主は負の値)。
@export var foe_hp_bonus: int = 0
## 相手が自分の山札の写しを使う(鏡写し・鏡の主)。
@export var foe_uses_player_deck: bool = false
## 主の作戦(`CardCpuDecks`のid)。空なら道を作るときに残りから割り当てる。関門では使わない。
@export var cpu_deck: String = ""
## 相手の山札の砂時計がすべて速落を持つ(急ぎの主)。
@export var foe_quick: bool = false
## 0以外なら双方の反転権をこの回数にする(反転の応酬)。
@export var flip_rights: int = 0
