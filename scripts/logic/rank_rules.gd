class_name RankRules
extends RefCounted
## ランクマッチの段位表・星の必要数・レートの増減表(GameDesign.md 28章)。
## 通信を一切持たない純粋なロジックとしてここへ集約する(Architecture.md 10.16節)。
##
## 段位は文字列のキーで表す("bronze1"〜"bronze3" / "silver1"〜"silver4" /
## "gold1"〜"gold5" / "platinum")。`players/{uid}` へそのまま保存する値であり、
## enumではなく文字列にしてあるのは、シーズンをまたいで保存されたデータを
## enumの並び変更で壊さないため。

const BRACKET_ORDER: Array[String] = ["bronze", "silver", "gold"]
const BRACKET_STEPS := {"bronze": 3, "silver": 4, "gold": 5}
const BRACKET_STAR_REQUIREMENT := {"bronze": 2, "silver": 3, "gold": 4}
const BRACKET_NAMES := {"bronze": "ブロンズ", "silver": "シルバー", "gold": "ゴールド"}

const PLATINUM_KEY := "platinum"
const PLATINUM_NAME := "プラチナ"
const PLATINUM_START_RATING := 1000

## シーズン開始時・降格しないプラチナから戻ってくることは無いため、
## 常にこの段位から始める。
const INITIAL_TIER := "bronze1"

## `progress_score()`が返すプラチナの底値。ブロンズ〜ゴールドの最大値より
## 十分大きく取り、プラチナの誰よりも下位の帯が上へ来ないようにする。
const PROGRESS_SCORE_PLATINUM_BASE := 100000

## プラチナのレート帯ごとの増減(GameDesign.md 28章)。`min`以上の間その行を使う。
## 100上がるごとに勝利側-2・敗北側+2し、1600以上で打ち止め。
const RATING_TABLE: Array[Dictionary] = [
	{"min": 1000, "win": 16, "lose": 8},
	{"min": 1100, "win": 14, "lose": 10},
	{"min": 1200, "win": 12, "lose": 12},
	{"min": 1300, "win": 10, "lose": 14},
	{"min": 1400, "win": 8, "lose": 16},
	{"min": 1500, "win": 6, "lose": 18},
	{"min": 1600, "win": 4, "lose": 20},
]


## 段位キーとして有効かどうか。
static func is_valid_tier(tier_key: String) -> bool:
	return tier_key == PLATINUM_KEY or not parse(tier_key).is_empty()


## "bronze2" を {"bracket": "bronze", "step": 2} へ分解する。無効なら空を返す。
static func parse(tier_key: String) -> Dictionary:
	for bracket in BRACKET_ORDER:
		if not tier_key.begins_with(bracket):
			continue
		var step_text := tier_key.substr(bracket.length())
		if not step_text.is_valid_int():
			continue
		var step := int(step_text)
		if step >= 1 and step <= int(BRACKET_STEPS[bracket]):
			return {"bracket": bracket, "step": step}
	return {}


## その段位で次の段階(★)へ進むために必要な星の数。プラチナや無効な段位は0。
static func star_requirement(tier_key: String) -> int:
	var parsed := parse(tier_key)
	if parsed.is_empty():
		return 0
	return int(BRACKET_STAR_REQUIREMENT[parsed["bracket"]])


## 星取り制の昇格判定。`stars`が必要数に達していれば次の段位・階級(無ければ次の帯)へ
## 進み、届いていなければそのまま(tierは変わらない)。ゴールド5から必要数を満たすと
## "platinum"へ進む。戻り値は {"tier": String, "stars": int}。
static func advance_stars(tier_key: String, stars: int) -> Dictionary:
	var parsed := parse(tier_key)
	if parsed.is_empty():
		return {"tier": tier_key, "stars": maxi(stars, 0)}
	var bracket: String = parsed["bracket"]
	var step: int = parsed["step"]
	var need := int(BRACKET_STAR_REQUIREMENT[bracket])
	if stars < need:
		return {"tier": tier_key, "stars": stars}
	if step < int(BRACKET_STEPS[bracket]):
		return {"tier": "%s%d" % [bracket, step + 1], "stars": 0}
	var next_bracket_index := BRACKET_ORDER.find(bracket) + 1
	if next_bracket_index < BRACKET_ORDER.size():
		return {"tier": "%s1" % BRACKET_ORDER[next_bracket_index], "stars": 0}
	return {"tier": PLATINUM_KEY, "stars": 0}


## 敗北時の星の減り方(0未満にはならない。GameDesign.md 28章)。
static func retreat_stars(stars: int) -> int:
	return maxi(stars - 1, 0)


## プラチナのレート増減。勝てば加算・負ければ減算した値を返す(呼び出し側で
## rating + delta する)。**下限は設けない**(降格しないため、レートは1000未満へも下がる)。
static func rating_delta(rating: int, won: bool) -> int:
	var row: Dictionary = RATING_TABLE[0]
	for entry in RATING_TABLE:
		if rating >= int(entry["min"]):
			row = entry
		else:
			break
	return int(row["win"]) if won else -int(row["lose"])


## 画面へ出す表示名("ブロンズ1" / "プラチナ")。
static func display_name(tier_key: String) -> String:
	if tier_key == PLATINUM_KEY:
		return PLATINUM_NAME
	var parsed := parse(tier_key)
	if parsed.is_empty():
		return tier_key
	return "%s%d" % [BRACKET_NAMES[parsed["bracket"]], int(parsed["step"])]


## その段位が属する帯("bronze"/"silver"/"gold"/"platinum")。月末報酬の判定に使う。
static func bracket_of(tier_key: String) -> String:
	if tier_key == PLATINUM_KEY:
		return PLATINUM_KEY
	var parsed := parse(tier_key)
	return str(parsed.get("bracket", BRACKET_ORDER[0]))


## aのほうが上位なら正、同じなら0、下位なら負を返す(ブロンズ<シルバー<ゴールド<プラチナ)。
## プラチナ内の高低(レート)はここでは比較しない(Architecture.md 10.16節)。
static func compare_tier(a: String, b: String) -> int:
	return _rank_value(a) - _rank_value(b)


static func _rank_value(tier_key: String) -> int:
	if tier_key == PLATINUM_KEY:
		return 1000
	var parsed := parse(tier_key)
	if parsed.is_empty():
		return -1
	return BRACKET_ORDER.find(parsed["bracket"]) * 10 + int(parsed["step"])


## プラチナに満たないプレイヤーもランキングへ並べるための、段位全体を貫く単一の
## 合成スコア(2026-09-16、ユーザー判断「進行度でもランクに残ったら嬉しい」への対応)。
## ブロンズ〜ゴールドは帯・階級・★を積み上げた値、プラチナは`PROGRESS_SCORE_PLATINUM_BASE`
## を底として実際のレートを足した値を返すため、**プラチナの誰よりも下位のブロンズが
## 上に来ることは無い**。並べる側(Firestoreの`orderBy`)は`rank_progress_score`という
## 1つのフィールドだけを見ればよく、帯によって並び方を切り替える必要がない。
static func progress_score(tier_key: String, stars: int, rating: int) -> int:
	if tier_key == PLATINUM_KEY:
		return PROGRESS_SCORE_PLATINUM_BASE + rating
	var parsed := parse(tier_key)
	if parsed.is_empty():
		return 0
	var bracket_index := BRACKET_ORDER.find(parsed["bracket"])
	return bracket_index * 100 + int(parsed["step"]) * 10 + maxi(stars, 0)
