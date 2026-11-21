class_name CardSpotlight
extends RefCounted
## その日のカードスポットライト(GameDesign.md 9章・26章 / Architecture.md 10.14節)。
## 1枚を選んで書くのは正午の `announceCardSpotlight` だけで、ゲームは読むだけ。

const DOC_PATH := "public_stats/card_spotlight"
const JST_OFFSET := 9 * 3600
## 正午に次の1枚へ替わる。
const SWITCH_OFFSET := 12 * 3600


## いまのスポットライトの日(JSTの正午で区切る)。この値が変わったときだけ読み直す。
static func day_key(unix_time: int = -1) -> String:
	if unix_time < 0:
		unix_time = int(Time.get_unix_time_from_system())
	var date := Time.get_date_dict_from_unix_time(unix_time + JST_OFFSET - SWITCH_OFFSET)
	return "%04d-%02d-%02d" % [date.year, date.month, date.day]


## その日の1枚。読めない・砂術・絵が無いときは null(呼び手はサンドのままにする)。
static func fetch(client: FirestoreClient) -> CardData:
	if client == null or not await NetSession.sign_in():
		return null
	var fields: Dictionary = await client.get_document(DOC_PATH)
	return card_from_id(String(fields.get("card_id", "")))


static func card_from_id(card_id: String) -> CardData:
	var card := CardLibrary.find_by_id(card_id)
	if card == null or card.is_spell or not HourglassLive.has_shader(card.art_key()):
		return null
	return card
