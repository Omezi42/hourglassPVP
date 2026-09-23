class_name TutorialScriptData
extends Resource
## 誘導対局の台本(GameDesign.md 18章、Architecture.md 4.1.5節)。
## 両者の山札のidを30枚ずつ、**並びがそのまま引く順**で持つ。台本をコードへ書かないのは、
## カードの追加・調整で段階が崩れたときに `.tres` だけを直せば済むようにするため。
## 成立は `tools/tests/tutorial_script_tests.gd` が確かめる。

const RESOURCE_PATH := "res://resources/tutorial/tutorial_script.tres"

## プレイヤー側の山札(id、引く順)。プリセット「基本」と同じ30枚の並べ替え。
@export var deck_a_ids: Array[String] = []
## CPU側の山札(id、引く順)。
@export var deck_b_ids: Array[String] = []


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
