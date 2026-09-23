class_name TutorialCpuStrategy
extends CardCpuStrategy
## 誘導対局のCPUの指し手(GameDesign.md 18章)。**CPUもAIではなく台本どおりに指す**。
## `CardCpuStrategy` を継承するのは `CardMatchScreen._cpu` の型をそのまま使い回すため
## だけで、貪欲法(親クラスの中身)は一切呼ばない。
##
## 実際にどの駒でどこを攻撃するかは `CardMatchTutorial`(台本の進行そのものを持つ)へ
## 委譲する。ここは「CPUの番として呼ばれた」ことを取り次ぐだけの薄い代役。

var _tutorial: CardMatchTutorial


func _init(tutorial: CardMatchTutorial) -> void:
	_tutorial = tutorial


## 誘導対局のCPUは引き直さない(GameDesign.md 18章「同じ」)。
func choose_mulligan(_state: MatchState, _side: int) -> Array:
	return []


## 説明を読んでいる間は空を返して待つ。読み終えたら `cpu_resumed` で指し直す。
func choose_action(state: MatchState, side: int) -> Dictionary:
	if _tutorial.cpu_waiting():
		return {}
	var action := _tutorial.cpu_action(state, side)
	if action.is_empty():
		return MatchAction.end_turn(side)
	return action
