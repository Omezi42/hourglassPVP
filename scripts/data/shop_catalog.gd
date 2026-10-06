class_name ShopCatalog
extends RefCounted
## ショップの品揃えと価格(GameDesign.md 21章、Architecture.md 10.8)。
## `CardLibrary` と同じく、Autoloadを使わず static のみで持つ。
##
## **品の中身そのものはここが持たない**。アイコンは `UserProfileLibrary`、
## エモートは `EmoteLibrary` が持ち、ここは「初期解放に含まれないものが並ぶ」という
## 規則と値段だけを持つ。品揃えを別の表にすると、アイコンを1つ足したときに
## 並べ忘れた品と、初期解放でも購入品でもないどこにも出ないidが生まれる。

## **新しい品種は末尾へ足す**(保存済みの値とずれないように)。
enum Kind { ICON, EMOTE, PLAYMAT, CARD_SET, SKIN }

## ランクマッチの勝利(30)を1勝として、アイコンは3勝ぶん・エモートは5勝ぶん。
## エモートのほうが高いのは、4つの枠へセットする(GameDesign.md 9章)ぶん、
## 1つ買うと対局中の選択そのものが変わるため。
## **プレイマットだけは1件ごとに値が違う**(標準1500 / 豪華3000。GameDesign.md 21章)。
## 対局中ずっと目に入り画面で最も面積が大きいため、桁を上げてある。
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
	for mat_id in PlaymatLibrary.purchasable_ids():
		list.append({"kind": Kind.PLAYMAT, "id": mat_id})
	# **`price == 0`のカードセット(ソロモードセット等)は並べない**(GameDesign.md 8章)。
	# ステージクリアのような買い切り以外の経路でしか所有できないため。
	for set_id in CardSetLibrary.purchasable_ids():
		list.append({"kind": Kind.CARD_SET, "id": set_id})
	for skin_id in SkinLibrary.purchasable_ids():
		list.append({"kind": Kind.SKIN, "id": skin_id})
	return list


## **プレイマットは品ごとに値が違う**ため、id を渡せる形にしてある。
static func price(kind: Kind, id := "") -> int:
	match kind:
		Kind.EMOTE:
			var own_price := EmoteLibrary.price(id)
			return own_price if own_price > 0 else EMOTE_PRICE
		Kind.PLAYMAT:
			return PlaymatLibrary.price(id)
		Kind.CARD_SET:
			return CardSetLibrary.price(id)
		Kind.SKIN:
			return SkinLibrary.price(id)
		_:
			return ICON_PRICE


## 品の名前。アイコンは紋章のモチーフ名、エモートは種類の名前。
static func item_name(kind: Kind, id: String) -> String:
	match kind:
		Kind.EMOTE:
			return EmoteLibrary.get_emote_name(id)
		Kind.PLAYMAT:
			return PlaymatLibrary.display_name(id)
		Kind.CARD_SET:
			return CardSetLibrary.display_name(id)
		Kind.SKIN:
			return SkinLibrary.display_name(id)
		_:
			return UserProfileLibrary.get_icon_name(id)


## 名前だけでは何を買うのか分からないものに添える1行(GameDesign.md 21章)。
## エモートは文言そのものが品にあたるため、実際に出る文をそのまま出す。
static func item_detail(kind: Kind, id: String) -> String:
	match kind:
		Kind.EMOTE:
			return "「%s」" % EmoteLibrary.get_emote_text(id)
		Kind.PLAYMAT:
			return "対局の卓に敷く"
		Kind.CARD_SET:
			# 中身のカードそのものは砂時計一覧・デッキ編集で確認できるため、
			# ここでは狙いの1行と枚数だけを添える(GameDesign.md 21章)。
			return "%s(%s)" % [CardSetLibrary.description(id), CardSetLibrary.count_text(id)]
		Kind.SKIN:
			var card := CardLibrary.find_by_id(SkinLibrary.card_id(id))
			return "「%s」の絵が変わる" % (card.display_name if card != null else "")
		_:
			return "アイコン"


static func kind_name(kind: Kind) -> String:
	match kind:
		Kind.EMOTE:
			return "エモート"
		Kind.PLAYMAT:
			return "プレイマット"
		Kind.CARD_SET:
			return "カードセット"
		Kind.SKIN:
			return "カードスキン"
		_:
			return "アイコン"


## 売り物として定義されているかどうか。購入の入口で必ず通す。
static func sells(kind: Kind, id: String) -> bool:
	for item in items():
		if item["kind"] == kind and str(item["id"]) == id:
			return true
	return false
