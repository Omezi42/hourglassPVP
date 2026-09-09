class_name SoloStageData
extends Resource
## ソロモードのステージ1つぶんの定義(GameDesign.md 27章)。
##
## パズル型は既存の `PuzzleStageData` をそのまま埋め込んで再利用する(新しいフィールドを
## 作らない)。それ以外の4種(CPU対戦型・特殊ルール型・連戦型・縛り型)は
## `SoloMatchConfig` を使う。カードと同じくデータ駆動で持ち、ステージを1つ足すのは
## `.tres` を1個作るだけで済む(Architecture.md 10.15節)。

enum Kind { PUZZLE, CPU_MATCH, SPECIAL_RULE, GAUNTLET, RESTRICTED }

## 一覧と保存に使う一意の識別子。
@export var id: String = ""
## ツリー上の並び順。v1は1本道のため、そのままツリー上の位置になる。
@export var order: int = 0
@export var display_name: String = ""
## 1〜2行の説明。
@export var description: String = ""
@export var stage_type: Kind = Kind.CPU_MATCH
## 前提ステージのid。**複数持てるようにしておく**(v1では常に1つだが、将来の分岐に備える)。
@export var requires: Array[String] = []

## 初回クリア時の砂金(必須)。
@export var reward_gold: int = 0
## 空なら無し。付与は`AccountService`の所有配列(アイコンと同じ経路)。
@export var reward_icon_id: String = ""
## 空なら無し。`CardSetLibrary`のid(ソロモード限定の1枚セット。GameDesign.md 27章)。
@export var reward_card_set_id: String = ""

## `stage_type == PUZZLE` のときだけ使う。
@export var puzzle: PuzzleStageData
## `PUZZLE` 以外で使う対局設定。
@export var match_config: SoloMatchConfig


func kind_label() -> String:
	match stage_type:
		Kind.PUZZLE:
			return "パズル型"
		Kind.CPU_MATCH:
			return "CPU対戦型"
		Kind.SPECIAL_RULE:
			return "特殊ルール型"
		Kind.GAUNTLET:
			return "連戦型"
		Kind.RESTRICTED:
			return "縛り型"
	return ""
