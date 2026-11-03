class_name CardCpuFlipRight
extends RefCounted
## CPUの反転権の使い方(GameDesign.md 2章・13章)。`CardCpuStrategy` の行数を抑えるため切り出した。
## 難易度に依らないため static だけで持つ。

## 反転権は対局に2〜3回しか無い希少な資源のため、
## 通常の反転よりゲインの下限を高く取り、僅かな得のために使い切らせない。
const FLIP_RIGHT_MIN_GAIN := 3.0


## 反転権で相手の駒を弱めてから、同じ手番の攻撃で仕留める(GameDesign.md 2章)。
## **`choose()` は攻撃の後にしか検討しないため、それだけでは
## 「弱めた直後に攻撃力を渡すだけ」になってしまう(`docs/BalanceReport_v5.md` 12章)。
## この関数だけは攻撃の前に呼び、反転権と攻撃を1つの連携として組み立てる。**
## いま手持ちの攻撃力では仕留められない相手が、反転させれば
## (新しい体力 = いまの攻撃力)仕留められるようになる場合だけ使う。
static func setup(state: MatchState, side: int) -> Dictionary:
	if int(state.flip_right_remaining.get(side, 0)) <= 0:
		return {}
	var foe_side := MatchState.other_side(side)
	var best_attack := 0
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit != null and unit.can_attack():
			best_attack = maxi(best_attack, unit.attack)
	if best_attack <= 0:
		return {}
	for slot in state.attackable_slots(foe_side):
		var foe: CardInstance = state.board[foe_side][slot]
		if foe == null:
			continue
		# いまの攻撃力ですでに仕留められるなら、反転権を使わずそのまま攻撃で足りる。
		if foe.health <= best_attack:
			continue
		# 反転させると新しい体力は「いまの攻撃力」になる。それを自分の最大攻撃力で
		# 仕留められて、かつ反転させないと仕留められない場合だけ価値がある。
		if foe.attack <= 0 or foe.attack > best_attack or not foe.flippable():
			continue
		# **殺すのは反転そのものではなく、直後の攻撃**なので余砂の発火は他の除去と
		# 同じ扱いになる(既存の `_choose_attack` も攻撃の一撃で殺す際に余砂を
		# 避けていない)。ここで避けるのは反転そのもので発火する反転トリガーだけ。
		if not foe.data.effects_for(CardEnums.Trigger.ON_FLIP).is_empty():
			continue
		return MatchAction.flip_right(side, foe_side, slot)
	return {}


## 反転権(GameDesign.md 2章)。敵味方どちらの砂時計も対象に取れるため、
## 自分の駒を得な状態へ戻す案(通常の反転と同じ物差し)と、相手の駒を損な状態へ
## 追い込む案(`CardCpuStrategy.swap_value()`、既存のSWAP_STATSの評価をそのまま流用)を両方見て
## いちばん得な1手を選ぶ。**希少な資源のため `FLIP_RIGHT_MIN_GAIN` 未満なら温存する**。
static func choose(state: MatchState, side: int) -> Dictionary:
	if int(state.flip_right_remaining.get(side, 0)) <= 0:
		return {}
	var foe_side := MatchState.other_side(side)
	var best: Dictionary = {}
	var best_gain := FLIP_RIGHT_MIN_GAIN
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = state.board[side][slot]
		if unit == null or not unit.flippable():
			continue
		var gain := (
			CardCpuStrategy.lifetime_of(unit.attack, unit.health) - float(unit.lifetime_damage())
		)
		if unit.data.effects_for(CardEnums.Trigger.ON_FLIP).size() > 0:
			gain += CardCpuStrategy.FLIP_TRIGGER_BONUS
		if gain > best_gain:
			best_gain = gain
			best = MatchAction.flip_right(side, side, slot)
	for slot in MatchState.BOARD_SIZE:
		var foe: CardInstance = state.board[foe_side][slot]
		if foe == null or not foe.flippable():
			continue
		# **反転権は攻撃した後にしか検討しない**(出す→攻撃する→反転する→終える)ため、
		# 敵を生かしたまま反転させると、体力の少ない側へ攻撃力の高い側を渡すだけになり、
		# こちらは追撃できないまま相手の次の手番でその攻撃力をそのまま浴びる。
		# **確実に破壊できる(反転後の体力が0になる)場合に限って触る。**
		if foe.attack > 0:
			continue
		# **反転トリガーは持ち主を利する形で発火する**(グロウ=所有者の総量+1、
		# ホイール/ティック=所有者の相手=自分にダメージ、ページ=所有者が1枚引く)。
		# 誰が反転させても発動する(GameDesign.md 6章)ため、敵の反転持ちを反転権で
		# 触ると自分を助けるどころか敵を利するか自分が被弾する。対象から外す。
		if not foe.data.effects_for(CardEnums.Trigger.ON_FLIP).is_empty():
			continue
		# **破壊すると余砂(ON_DEATH)も持ち主を利する形で発火する**(ドロー・本体への
		# ダメージ等)。無償の除去に見えて、持ち主へ無償の起動効果を与えてしまう。
		if not foe.data.effects_for(CardEnums.Trigger.ON_DEATH).is_empty():
			continue
		var gain := CardCpuStrategy.swap_value(foe)
		if gain > best_gain:
			best_gain = gain
			best = MatchAction.flip_right(side, foe_side, slot)
	return best
