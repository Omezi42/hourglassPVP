class_name ShopCatalog
extends RefCounted
## ショップの品揃えと価格(GameDesign.md 21章、Architecture.md 10.8)。
## `CardLibrary` と同じく、Autoloadを使わず static のみで持つ。
##
## **品の中身そのものはここが持たない**。アイコンは `UserProfileLibrary`、
## エモートは `EmoteLibrary` が持ち、ここは「初期解放に含まれないものが並ぶ」という
## 規則と値段だけを持つ。品揃えを別の表にすると、アイコンを1つ足したときに
## 並べ忘れた品と、初期解放でも購入品でもないどこにも出ないidが生まれる。

enum Kind { ICON, EMOTE }

## ランダムマッチの勝利(30)を1勝として、アイコンは3勝ぶん・エモートは5勝ぶん。
## エモートのほうが高いのは、4つの枠へセットする(GameDesign.md 9章)ぶん、
## 1つ買うと対局中の選択そのものが変わるため。
const ICON_PRICE := 100
const EMOTE_PRICE := 200


## 売り物の一覧。1件は {"kind": Kind, "id": String}。
## 並びはアイコンが先で、それぞれの定義順を保つ。
static func items() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for icon_id in UserProfileLibrary.get_available_icon_ids():
		if not UserProfileLibrary.INITIAL_ICON_IDS.has(icon_id):
			list.append({"kind": Kind.ICON, "id": str(icon_id)})
	for emote_id in EmoteLibrary.get_emote_ids():
		if not EmoteLibrary.DEFAULT_EMOTE_IDS.has(emote_id):
			list.append({"kind": Kind.EMOTE, "id": emote_id})
	return list


static func price(kind: Kind) -> int:
	return EMOTE_PRICE if kind == Kind.EMOTE else ICON_PRICE


## 品の名前。アイコンは紋章のモチーフ名、エモートは種類の名前。
static func item_name(kind: Kind, id: String) -> String:
	if kind == Kind.EMOTE:
		return EmoteLibrary.get_emote_name(id)
	return UserProfileLibrary.get_icon_name(id)


## 名前だけでは何を買うのか分からないものに添える1行(GameDesign.md 21章)。
## エモートは文言そのものが品にあたるため、実際に出る文をそのまま出す。
static func item_detail(kind: Kind, id: String) -> String:
	if kind == Kind.EMOTE:
		return "「%s」" % EmoteLibrary.get_emote_text(id)
	return "アイコン"


static func kind_name(kind: Kind) -> String:
	return "エモート" if kind == Kind.EMOTE else "アイコン"


## 売り物として定義されているかどうか。購入の入口で必ず通す。
static func sells(kind: Kind, id: String) -> bool:
	for item in items():
		if item["kind"] == kind and str(item["id"]) == id:
			return true
	return false
