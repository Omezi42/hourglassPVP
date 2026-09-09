class_name CardEffectStage
extends RefCounted
## 実演の台本が組み立てる「その瞬間の盤面」の部品(GameDesign.md 9章)。
##
## `CardEffectPreview` が1000行の上限に達したため切り出した(`CardEffectDemoEnemy` と
## 同じ流儀)。**台本はここが返す Dictionary を組み合わせるだけで書ける**状態を保つ——
## 新しいキーワードが増えても、部品を1つ足せば台本が組める(GameDesign.md 9章)。
## 純粋な static だけを持ち、盤面もフォントも一切知らない。


static func seg(t: float, from: float, to: float) -> float:
	if t <= from:
		return 0.0
	if t >= to:
		return 1.0
	return (t - from) / (to - from)


## 駒1体。total は砂の総量で、ダメージを受けると減る(GameDesign.md 4章)。
static func piece(health: int, attack: int, total: int) -> Dictionary:
	return {
		"h": health,
		"a": attack,
		"total": total,
		"shatter": 0.0,
		"glass": false,
		"guard": false,
		"flip": -1.0,
		"fade": 1.0,
	}


## `color` を指定しない場合は既定どおり(遮られた=くすんだ色 / それ以外=朱)。
## 味方への効果(反転を与える・砂を落とす等)は攻撃ではないため、朱ではなく
## `InkFigure.GREEN` を明示して「敵を攻撃した」ように読めるのを避ける。
static func beam(
	from: Array, to: Array, progress: float, blocked := false, color: Variant = null
) -> Dictionary:
	return {"from": from, "to": to, "p": progress, "blocked": blocked, "color": color}


static func pop(at: String, index: int, text: String, color: Color, p: float) -> Dictionary:
	return {"at": at, "index": index, "text": text, "color": color, "p": p}


static func empty_stage() -> Dictionary:
	return {
		"own": [],
		"foe": [],
		"own_hp": 1.0,
		"foe_hp": 1.0,
		"beams": [],
		"pops": [],
		"note": "",
		# **トリガーが決まって初めて文になる説明**。台本は「何が起きるか」だけを書き、
		# 「いつ起きるか」は entry の trigger から _stage() が前へ付ける。同じ効果が
		# 設置・反転・余砂のどれで載っても、台本を3通り持たずに正しい文が出る。
		"trigger_note": "",
		"draw_card": -1.0,
	}
