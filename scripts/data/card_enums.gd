class_name CardEnums
extends RefCounted
## v5.0のカード(砂時計)が使う語彙。GameDesign.md 1章・6章に対応する。
## 旧ルール(位相制)のGameEnumsとは別物であり、混ぜて使わない。

## 常在の能力(GameDesign.md 6章)。1枚に複数持たせてよい。
##
## **このうち「語として見せる」のは、複数のカードに載っているものだけ**(NAMED を参照)。
## 1枚にしか無い能力を語にすると、その語を覚えても他で使い回せず、
## カードを読むたびに語の意味を思い出す手間だけが増えるため。
## 語にしないものは、カードに効果の文をそのまま書く。
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
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由)。
enum Trigger {
	## 設置:場に出したとき。
	ON_PLAY,
	## 反転:反転したとき。毎ターン行えるため常在効果として値付けする。
	ON_FLIP,
	## 余砂:破壊されたとき。
	ON_DEATH,
	## 落砂:自分のターン終了時(砂が1粒落ちる瞬間)。
	ON_TURN_END,
	## 被弾:ダメージを受けたとき。硝子で無効化された場合は発動しない。
	ON_DAMAGED,
}

## エフェクトの対象。
##
## **新しい値は必ず末尾へ足す。**`.tres` は enum を整数で保存しているため、
## 途中へ挿入すると既存のカードの対象が丸ごとずれる(実際に一度やって、
## 全体除去が単体ドローになった)。並びの美しさより保存済みデータとの整合を取る。
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
	## 自分の砂時計1体(選択)。
	ALLY_UNIT,
}

## エフェクトの種類。
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由)。
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
	## 攻撃力を value 増やす(下の部屋へ砂を足す。体力は変わらない)。
	ADD_ATTACK,
	## 空き枠へ card_id の砂時計を1体出す。空きが無ければ何もしない。
	SUMMON,
	## 対象へ keyword のキーワードを与える。
	GRANT_KEYWORD,
	## 対象のキーワードと効果をすべて消す。
	SILENCE,
	## 対象の砂時計を持ち主の手札へ戻す(砂術。GameDesign.md 6章)。
	## **破壊ではないため余砂は発火しない**。戻るのは CardData であり、
	## 受けたダメージも与えられたキーワードも失われる。
	RETURN_TO_HAND,
}

## 語として見せるキーワード。**複数のカードに載っているものだけ**をここへ入れる。
## カードを追加してある能力が2枚目に載ったら、ここへ足して語へ昇格させる。
const NAMED: Array[Keyword] = [Keyword.GUARD, Keyword.GLASS, Keyword.PIERCE, Keyword.QUICK]


static func is_named(keyword: int) -> bool:
	return NAMED.has(keyword)


## 語にしない能力を、カードの狭い1行へ収める短い言い換え。
## **カードの面は左右の隅を数値バッジが占めるため、収まるのは4文字程度**しかない。
## 何をする能力かは keyword_description() が返す一文で読ませる。
static func keyword_short_text(keyword: int) -> String:
	match keyword:
		Keyword.POISON:
			return "破壊"
		Keyword.LIFESTEAL:
			return "回復"
		Keyword.DOUBLE_STRIKE:
			return "2回攻撃"
	return keyword_name(keyword)


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


## 能力の説明文(GameDesign.md 6章の表)。語にするものは【語】に添えて、
## 語にしないものはこれ単体で出す。デッキ編集の一覧にも収まる長さに保つ。
static func keyword_description(keyword: int) -> String:
	match keyword:
		Keyword.GUARD:
			return "相手はこの砂時計を無視して他を攻撃できない。"
		Keyword.GLASS:
			return "最初に受けるダメージを1度だけ無効にする。"
		Keyword.PIERCE:
			return "砂時計を攻撃したとき、超過分が相手プレイヤーへ抜ける。"
		Keyword.POISON:
			return "ダメージを与えた砂時計を破壊する"
		Keyword.LIFESTEAL:
			return "与えたダメージぶん自分のHPを回復する"
		Keyword.DOUBLE_STRIKE:
			return "1ターンに2回攻撃できる"
		Keyword.QUICK:
			return "場に出た瞬間に砂が2粒落ちる(すぐ攻撃できる)。"
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
		Trigger.ON_TURN_END:
			return "落砂"
		Trigger.ON_DAMAGED:
			return "被弾"
	return ""
