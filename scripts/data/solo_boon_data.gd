class_name SoloBoonData
extends Resource
## 遠征(ソロモード)の恩恵1つぶんのデータ(GameDesign.md 27章「恩恵」)。
## `data/solo_boons/{id}.tres`。恩恵を1つ足すのは `.tres` を1個作るだけで済む
## (Architecture.md 10.15節)。効果の数値は既定0で、使わないものは書かなくてよい。

## メダルの絵は `assets/ui/icons/boon_{id}.png`(白のシルエット。CREDITS.md)。
const ICON_PATH := "res://assets/ui/icons/boon_%s.png"

@export var id: String = ""
@export var display_name: String = ""
## 1〜2行の説明。恩恵の札・状態パネルの一覧に出す。
@export var description: String = ""

## 丈夫な体: 最大HP+N。得たときにHPもN回復する(`SoloRun.take_boon()`)。
## 負の値(硝子の心臓)は最大HPを減らし、HPは新しい最大HPで頭打ちにする。
@export var max_hp_bonus: int = 0
## 深い泉: 泉の回復+N。
@export var spring_bonus: int = 0
## 目利き: 束の候補が3+Nつになる。
@export var extra_bundles: int = 0
## 先制の砂: 対局の開始時、相手のHPがN少ない。
@export var foe_hp_penalty: int = 0
## 用意周到: 対局の最初の手札をN枚多く引く。
@export var extra_opening_draw: int = 0
## 勝ち癖: 対局に勝つとHPがN回復する(上限はいまの最大HP)。
@export var win_heal: int = 0

## 戦い方を変える恩恵(27章の◆)。恩恵の候補には1つ以上含める(`SoloRun`)。
@export var changes_play: bool = false
## 身軽: 山札が`light_deck_max`枚以下なら、最初の手札を`light_deck_draw`枚多く引く。
@export var light_deck_max: int = 0
@export var light_deck_draw: int = 0
## 小さな軍勢: コスト`small_cost_max`以下の砂時計の総量+`small_total_bonus`。
@export var small_cost_max: int = 0
@export var small_total_bonus: int = 0
## 重い砂: コスト`heavy_cost_min`以上の砂時計のコスト-`heavy_cost_cut`。
@export var heavy_cost_min: int = 0
@export var heavy_cost_cut: int = 0
## 返し上手: 自分の砂時計を反転するたび(反転権を含む)、相手にNダメージ。
@export var flip_damage: int = 0
## 置き土産: 自分の砂時計が破壊されるたび、相手にNダメージ。
@export var death_damage: int = 0
## 砂袋: 対局の反転権+N。
@export var extra_flip_rights: int = 0
## 早起き: 対局の最初の自分の手番だけマナ+N。
@export var first_turn_mana: int = 0


## メダルの絵。無ければ null(メダルは枠だけを描く)。
func icon() -> Texture2D:
	var path := ICON_PATH % id
	return load(path) if ResourceLoader.exists(path) else null
