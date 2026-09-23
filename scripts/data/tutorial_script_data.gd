class_name TutorialScriptData
extends Resource
## 誘導対局の台本(GameDesign.md 18章、Architecture.md 4.1.5節)。
## **両者の手をすべて決めた台本**として持つ。何ターン目に何を出し、どこを殴り、
## 次に何を引くかまで決まっている。カードの調整で段が崩れたときに `.tres` だけを
## 直せば済むよう、台本をコードへ書かない。
## 成立は `tools/tests/tutorial_script_tests.gd` が確かめる。

const RESOURCE_PATH := "res://resources/tutorial/tutorial_script.tres"

## プレイヤー側の山札(id、引く順)。プリセット「基本」と同じ30枚の並べ替え。
@export var deck_a_ids: Array[String] = []
## CPU側の山札(id、引く順)。
@export var deck_b_ids: Array[String] = []
## 相手(CPU)の開始HP。4手番で勝って終わるための値(GameDesign.md 18章)。
@export var foe_start_hp: int = 4
## 両者の手を順に並べた台本本体。各要素は以下の形の Dictionary:
##   side: "a"(プレイヤー) / "b"(CPU) / "info"(読むだけ、行動を持たない)
##   kind: "mulligan" / "play" / "attack" / "flip" / "flip_right" / "end_turn"
##   card_id: kind=="play" のとき出すカードのid
##   ref: kind=="play" のとき、置いた駒をこの名前で後の手から参照できるように覚える
##   actor_ref: kind in ["attack","flip"] のとき、手を指す駒の参照名
##   target_kind: kind=="attack" のとき "unit"(相手の駒) / "face"(本体)
##   target_ref: 攻撃(駒)/反転権の対象の参照名
##   target_side: kind=="flip_right" のとき対象の陣営。"own" / "foe"
##   text: 指示の文(side=="a"/"info" のときだけ表示)
##   done: 手を終えたときの説明(実際の数値は実行時に組み込む)
##   wait_text: side=="b" のとき、CPUの手を待つ間に出す文
##   topic: 説明を読んでいる間に光らせる数字("mana"/"stats"/"foe_hp"/"flip_right")
@export var steps: Array[Dictionary] = []


func deck_a() -> Array:
	return _resolve(deck_a_ids)


func deck_b() -> Array:
	return _resolve(deck_b_ids)


func _resolve(ids: Array[String]) -> Array:
	var cards: Array = []
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		if card != null:
			cards.append(card)
	return cards
