class_name EmoteLibrary
extends RefCounted
## 対局中に使える定型エモートの定義と取得(GameDesign.md 9章、Architecture.md 6.6)。
## static のみで持つ。

const EMOTES: Dictionary = {
	"hello":
	{
		"id": "hello",
		"name": "挨拶",
		"text": "よろしくお願いします",
	},
	"praise":
	{
		"id": "praise",
		"name": "賞賛",
		"text": "見事な一手です",
	},
	"shock":
	{
		"id": "shock",
		"name": "驚き",
		"text": "なんだと…",
	},
	"advantage":
	{
		"id": "advantage",
		"name": "優勢",
		"text": "こちらに傾いているようですね",
	},
	"pinch":
	{
		"id": "pinch",
		"name": "劣勢",
		"text": "まずいですね…",
	},
	"think":
	{
		"id": "think",
		"name": "長考",
		"text": "少し考えさせてください",
	},
	"thanks":
	{
		"id": "thanks",
		"name": "感謝",
		"text": "ありがとうございました",
	},
	"good_game":
	{
		"id": "good_game",
		"name": "健闘",
		"text": "よい勝負でした",
	},
}

const ORDERED_IDS: Array[String] = [
	"hello",
	"praise",
	"shock",
	"advantage",
	"pinch",
	"think",
	"thanks",
	"good_game",
]

## 最初から持っていて、既定で4つの枠へ入っているエモート(GameDesign.md 9章)。
## ここに無いものはショップ(21章)で解放する。
const DEFAULT_EMOTE_IDS: Array[String] = [
	"hello",
	"praise",
	"shock",
	"advantage",
]

## 対局中に同時に出せる数。増えても選択肢は4行のままにする(GameDesign.md 9章)。
const SLOT_COUNT := 4


## 定義されているエモートすべて。対局中に出す4つは
## `AccountService.emote_slots()` から引く(所有と枠はアカウント側の関心のため)。
static func get_emote_ids() -> Array[String]:
	return ORDERED_IDS


static func has_emote(emote_id: String) -> bool:
	return EMOTES.has(emote_id)


static func get_emote_name(emote_id: String) -> String:
	var entry: Dictionary = EMOTES.get(emote_id, {})
	return str(entry.get("name", ""))


static func get_emote_text(emote_id: String) -> String:
	var entry: Dictionary = EMOTES.get(emote_id, {})
	return str(entry.get("text", ""))
