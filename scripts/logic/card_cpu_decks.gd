class_name CardCpuDecks
extends RefCounted
## CPU戦の完成したデッキ(GameDesign.md 13章)。作戦を持つ8つの表から
## 対局のたびに `pick()` で1つ選ぶ。`CardPresetDecks` と同じく「Autoloadを使わずstaticで
## 表として持つ」流儀で、`.tres` にはしない(デッキはカードの参照の並びにすぎないため)。
##
## 表の1行は id・名前・狙い1行に加えて、`preset`(`CardPresetDecks` のid。中身を
## 二重に持たない)か `cards`(id → 枚数)のどちらかを持つ。組み立ては
## `CardPresetDecks.build()` を共用する。

## 対局中の相手の名前(GameDesign.md 13章)。名前が空(記録から選んだデッキ。11章)なら
## 「CPU」だけを出す。
const FOE_NAME_PREFIX := "CPU ・ "
const FOE_NAME_PLAIN := "CPU"

const DECKS: Array[Dictionary] = [
	{
		"id": "basic",
		"name": "基本",
		"summary": "軽いカードを中心に、砂の進み方と相打ちを素直に使う",
		"preset": "basic",
	},
	{
		"id": "rush",
		"name": "速攻",
		"summary": "速落と貫通で早く殴りきる",
		"preset": "rush",
	},
	{
		"id": "heavy",
		"name": "重厚",
		"summary": "守護と大型で受け止め、盤面を残して勝つ",
		"preset": "heavy",
	},
	{
		"id": "flip",
		"name": "反転",
		"summary": "反転で攻撃力を上げ、反転の効果で押し込む",
		"cards":
		{
			"grain": 2,
			"wand": 2,
			"tick": 2,
			"dash": 2,
			"sand": 2,
			"shield": 2,
			"pivot": 2,
			"eye": 2,
			"echo": 2,
			"drill": 2,
			"wheel": 2,
			"twin": 2,
			"glow": 2,
			"page": 2,
			"turn": 2,
		},
	},
	{
		"id": "spill",
		"name": "余砂",
		"summary": "砂が落ちきったときの効果で、割れるほど得をする",
		"cards":
		{
			"seed": 2,
			"husk": 2,
			"pebble": 2,
			"rattle": 2,
			"dust": 2,
			"flask": 2,
			"shield": 2,
			"sprout": 2,
			"shell": 2,
			"legacy": 2,
			"drip": 2,
			"burst": 2,
			"bloom": 2,
			"obelisk": 2,
			"refill": 2,
		},
	},
	{
		"id": "control",
		"name": "除去",
		"summary": "守護で耐え、相手の砂時計を取り除いて盤面を握る",
		"cards":
		{
			"shield": 2,
			"watcher": 2,
			"blank": 2,
			"crown": 2,
			"glass": 2,
			"hammer": 2,
			"barb": 2,
			"gate": 2,
			"poison": 2,
			"guard": 2,
			"sweep": 2,
			"tower": 2,
			"seal": 2,
			"shatter": 2,
			"tempest": 2,
		},
	},
	{
		"id": "five",
		"name": "五砂",
		"summary": "総量5の砂時計を揃えて連携する(五砂の刻)",
		"cards":
		{
			"grain": 2,
			"sand": 2,
			"dash": 2,
			"forge": 2,
			"echo": 2,
			"drill": 2,
			"pivot": 2,
			"middle": 2,
			"phase": 2,
			"key": 2,
			"cycle": 2,
			"lock": 2,
			"guard": 2,
			"crest": 2,
			"refill": 2,
		},
	},
	{
		"id": "still",
		"name": "静止",
		"summary": "砂を上へ戻して時間を止め、長く居座る(静止の刻)",
		"cards":
		{
			"shield": 2,
			"sand": 2,
			"flask": 2,
			"balm": 2,
			"echo": 2,
			"freeze": 2,
			"gate": 2,
			"oasis": 2,
			"spring": 2,
			"anvil": 2,
			"chronos": 2,
			"rewind": 2,
			"stasis": 2,
			"verdict": 2,
			"refill": 2,
		},
	},
]


## 対局のたびに1つ選ぶ。戻り値は `{"name": String, "cards": Array}`。
static func pick(rng: RandomNumberGenerator) -> Dictionary:
	var row: Dictionary = DECKS[rng.randi_range(0, DECKS.size() - 1)]
	return {"name": str(row["name"]), "cards": _cards_of(row)}


## idからデッキだけを組む(テスト・表の健全さの検証用)。
static func deck_of(id: String) -> Array:
	for row in DECKS:
		if row["id"] == id:
			return _cards_of(row)
	return CardPresetDecks.basic()


## 8つの id(ソロモード・27章の出発の選択肢はここから引く)。
static func deck_ids() -> Array[String]:
	var ids: Array[String] = []
	for row in DECKS:
		ids.append(str(row["id"]))
	return ids


static func name_of(id: String) -> String:
	for row in DECKS:
		if row["id"] == id:
			return str(row["name"])
	return ""


static func summary_of(id: String) -> String:
	for row in DECKS:
		if row["id"] == id:
			return str(row["summary"])
	return ""


## `{"name", "cards"}` から対局中に出す相手の名前を作る(GameDesign.md 13章・11章)。
static func foe_name(deck: Dictionary) -> String:
	var name := str(deck.get("name", ""))
	return FOE_NAME_PLAIN if name.is_empty() else FOE_NAME_PREFIX + name


## idから直接、対局中に出す相手の名前を作る(ソロモード・27章)。
static func foe_name_of(id: String) -> String:
	return foe_name({"name": name_of(id)})


static func _cards_of(row: Dictionary) -> Array:
	if row.has("preset"):
		return CardPresetDecks.deck_of(str(row["preset"]))
	return CardPresetDecks.build(row["cards"])
