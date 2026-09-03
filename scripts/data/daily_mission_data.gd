class_name DailyMissionData
extends RefCounted
## デイリーミッションの定義(GameDesign.md 23章)。
##
## **ミッションは Resource ではなく、この表がコードで持つ。**カード(`.tres`)と違って
## Inspector から編集する余地が無く、達成の数え方(`Metric`)とコードが1対1で対応するため。
## 1件足すときは `ALL` へ1行足し、必要なら `Metric` を1つ増やす。

## 数え方。**対局中に増えるもの**と、**終局のときだけ増えるもの**の2種類がある。
enum Metric {
	TRIGGER_TURN_END,  ## 落砂を発動した回数
	FLIP,  ## 反転した回数
	CAST_SPELL,  ## 砂術を撃った回数
	UNIT_PLAYED,  ## 砂時計を場に出した回数
	ATTACK,  ## 攻撃した回数
	WIN,  ## 勝った対局の数
	MATCH,  ## 遊んだ対局の数
}

## 1日に提示する数(GameDesign.md 23章)。
const DAILY_COUNT := 3


## 定義の全体。**この並びは日替わりの選び方に使う**ため、途中へ挿入せず末尾へ足す。
static func all() -> Array[Dictionary]:
	return [
		_m("fall_10", Metric.TRIGGER_TURN_END, 10, "落砂を10回発動する", 50),
		_m("flip_8", Metric.FLIP, 8, "反転を8回行う", 50),
		_m("spell_3", Metric.CAST_SPELL, 3, "砂術を3回撃つ", 50),
		_m("play_20", Metric.UNIT_PLAYED, 20, "砂時計を20体場に出す", 50),
		_m("attack_15", Metric.ATTACK, 15, "15回攻撃する", 50),
		_m("win_1", Metric.WIN, 1, "1勝する", 100),
		_m("match_3", Metric.MATCH, 3, "3回対局する", 50),
	]


static func find(id: String) -> Dictionary:
	for entry in all():
		if entry["id"] == id:
			return entry
	return {}


static func _m(id: String, metric: int, goal: int, text: String, reward: int) -> Dictionary:
	return {"id": id, "metric": metric, "goal": goal, "text": text, "reward": reward}
