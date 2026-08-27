class_name CardEnums
extends RefCounted
## v5.0のカード(砂時計)が使う語彙。GameDesign.md 1章・6章に対応する。
## 旧ルール(位相制)のGameEnumsとは別物であり、混ぜて使わない。

## 常在キーワード(GameDesign.md 6章)。1枚に複数持たせてよい。
enum Keyword {
	## 相手はこの砂時計を無視して他を攻撃できない。
	GUARD,
	## 最初に受けるダメージを1度だけ無効にする。
	GLASS,
	## 砂時計を攻撃したとき、超過分が相手プレイヤーへ抜ける。
	PIERCE,
	## この砂時計がダメージを与えた砂時計を破壊する。
	POISON,
	## 与えたダメージと同じだけ自分のHPを回復する。
	LIFESTEAL,
	## 1ターンに2回攻撃する。
	DOUBLE_STRIKE,
	## 場に出た瞬間に砂が2粒落ちる(すぐ攻撃できる)。
	QUICK,
}

## トリガーキーワード(GameDesign.md 6章)。
enum Trigger {
	## 設置:場に出したとき。
	ON_PLAY,
	## 反転:反転したとき。毎ターン行えるため常在効果として値付けする。
	ON_FLIP,
	## 余砂:破壊されたとき。
	ON_DEATH,
}

## エフェクトの対象。
enum EffectTarget {
	## この効果を持つ砂時計自身。
	SELF,
	## 相手の砂時計1体(選択。CPUは評価値で選ぶ)。
	ENEMY_UNIT,
	## 相手の砂時計すべて。
	ALL_ENEMY_UNITS,
	## 自分の砂時計すべて。
	ALL_ALLY_UNITS,
	## 相手プレイヤー。
	OPPONENT_PLAYER,
	## 自分プレイヤー。
	OWN_PLAYER,
}

## エフェクトの種類。新しいカードは原則この組み合わせだけで作る。
enum EffectType {
	## プレイヤーへ value ダメージ。
	DAMAGE_PLAYER,
	## 砂時計へ value ダメージ(砂が消える=総量が減る)。
	DAMAGE_UNIT,
	## 砂時計を破壊する。
	DESTROY_UNIT,
	## 体力と攻撃力を入れ替える(強制反転)。
	SWAP_STATS,
	## 総量を value 増やす(体力へ加算する)。
	ADD_TOTAL,
	## 砂を value 粒落とす(体力-value / 攻撃力+value)。
	DROP_SAND,
	## カードを value 枚引く。
	DRAW,
	## 自分のHPを value 回復する。
	HEAL_PLAYER,
	## 相手の砂時計の数 × value ダメージを相手プレイヤーへ。
	DAMAGE_PLAYER_PER_ENEMY_UNIT,
}


## キーワードの表示名(GameDesign.md 6章の語)。
static func keyword_name(keyword: int) -> String:
	match keyword:
		Keyword.GUARD:
			return "守護"
		Keyword.GLASS:
			return "硝子"
		Keyword.PIERCE:
			return "貫通"
		Keyword.POISON:
			return "毒砂"
		Keyword.LIFESTEAL:
			return "吸命"
		Keyword.DOUBLE_STRIKE:
			return "連撃"
		Keyword.QUICK:
			return "速落"
	return ""


## トリガーの表示名(GameDesign.md 6章の語)。
static func trigger_name(trigger: int) -> String:
	match trigger:
		Trigger.ON_PLAY:
			return "設置"
		Trigger.ON_FLIP:
			return "反転"
		Trigger.ON_DEATH:
			return "余砂"
	return ""
