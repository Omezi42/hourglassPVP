class_name TutorialFacts
extends RefCounted
## 誘導対局で段階を終えたときの一言へ差し込む、いま自分の盤面で起きた実際の数値
## (GameDesign.md 18章)。台本の参照名 → CardInstance の表から文を組むだけで、盤面は持たない。


## 台本の1手の種類ごとに文を選ぶ。数値の無い手は空を返す。
static func for_step(step: Dictionary, refs: Dictionary) -> String:
	match str(step.get("kind", "")):
		"play":
			return _play(step, refs)
		"end_turn":
			return _end_turn(step, refs)
		"flip":
			return _flip(step, refs)
		"flip_right":
			return _flip_right(step, refs)
	return ""


static func _play(step: Dictionary, refs: Dictionary) -> String:
	var played: CardInstance = refs.get(str(step.get("ref", "")))
	return "" if played == null else "マナを%dつかったよ。" % played.data.cost


static func _end_turn(step: Dictionary, refs: Dictionary) -> String:
	var ref := str(step.get("ref", ""))
	var ticked: CardInstance = refs.get(ref) if not ref.is_empty() else null
	if ticked == null:
		return ""
	return (
		"%sの体力が%d→%d、攻撃力が%d→%dになったよ。"
		% [
			ticked.data.display_name,
			ticked.health + 1,
			ticked.health,
			ticked.attack - 1,
			ticked.attack,
		]
	)


static func _flip(step: Dictionary, refs: Dictionary) -> String:
	var flipped: CardInstance = refs.get(str(step.get("actor_ref", "")))
	if flipped == null:
		return ""
	return (
		"体力%d・攻撃力%dが入れ替わって、体力%d・攻撃力%dになったよ。"
		% [flipped.attack, flipped.health, flipped.health, flipped.attack]
	)


static func _flip_right(step: Dictionary, refs: Dictionary) -> String:
	var target: CardInstance = refs.get(str(step.get("target_ref", "")))
	if target == null:
		return ""
	return "相手の「%s」の体力が%dになったよ。" % [target.data.display_name, target.health]
