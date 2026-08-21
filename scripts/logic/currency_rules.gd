class_name CurrencyRules
extends RefCounted
## 砂金(通貨)の獲得量と、報酬の対象になる条件をまとめた表(GameDesign.md 15章)。
## 数値をUI・対局画面へ散らさないよう、判定はすべてこのクラスを通す。

## 対局の種別。報酬額はこの種別で決まる。
## ローカル対戦(pass&play)・観戦・リプレイ再生は「自分が1人のプレイヤーとして
## 対局した」とは言えないため、NONEとして報酬の対象外にする。
enum MatchKind { NONE, RANDOM, ROOM, CPU }

const CURRENCY_NAME := "砂金"

## 種別ごとの [勝利, 敗北] の獲得量。負けても入るのは、勝てないプレイヤーが
## 一切貯められない状態を避けるため。ランダムマッチが厚いのは、相手が必要で
## 自分の都合だけでは繰り返せないため。
const REWARDS := {
	MatchKind.RANDOM: [30, 10],
	MatchKind.ROOM: [10, 5],
	MatchKind.CPU: [5, 2],
}

## これに満たない手数で終わった対局は報酬の対象外。開始直後に投了して
## 短時間で繰り返すことを防ぐ。
const MIN_MOVES := 10
## CPU戦で1日に報酬を得られる回数の上限。上限に達してもCPU戦自体は遊べる。
const CPU_DAILY_LIMIT := 10


## 判定結果を返す。
## {"amount": int, "reason": String}
##   amount … 実際に加算する額(0なら対象外)
##   reason … 対象外だった理由。結果パネルに1行として出す(対象なら空文字)
static func evaluate(kind: MatchKind, won: bool, move_count: int, cpu_today: int) -> Dictionary:
	if not REWARDS.has(kind):
		return {"amount": 0, "reason": ""}
	if move_count < MIN_MOVES:
		return {"amount": 0, "reason": "%d手未満の対局では%sを獲得できません" % [MIN_MOVES, CURRENCY_NAME]}
	if kind == MatchKind.CPU and cpu_today >= CPU_DAILY_LIMIT:
		return {
			"amount": 0, "reason": "CPU戦で%sを獲得できるのは1日%d戦までです" % [CURRENCY_NAME, CPU_DAILY_LIMIT]
		}
	var pair: Array = REWARDS[kind]
	return {"amount": int(pair[0] if won else pair[1]), "reason": ""}


## 結果パネルへ出す1行を組み立てる。
static func format_reward(result: Dictionary) -> String:
	var amount: int = int(result.get("amount", 0))
	if amount > 0:
		return "+%d %s" % [amount, CURRENCY_NAME]
	return str(result.get("reason", ""))
