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
}

const ORDERED_IDS: Array[String] = [
	"hello",
	"praise",
	"shock",
	"advantage",
]


static func get_emote_ids() -> Array[String]:
	return ORDERED_IDS


static func get_emote_name(emote_id: String) -> String:
	var entry: Dictionary = EMOTES.get(emote_id, {})
	return str(entry.get("name", ""))


static func get_emote_text(emote_id: String) -> String:
	var entry: Dictionary = EMOTES.get(emote_id, {})
	return str(entry.get("text", ""))
