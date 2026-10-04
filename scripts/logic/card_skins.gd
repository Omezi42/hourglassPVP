class_name CardSkins
extends RefCounted
## 「いま誰の視点で、どのカードにどのスキンが効いているか」を答える(GameDesign.md 31章、
## Architecture.md 10.19節)。砂時計の絵を引く口をここへ1つ足すことで、描画側は変えずに
## 「そのカードの絵を出すすべての場所で使う」が成り立つ。

## 誰のカードを描いているか。スキンは持ち主ごとに違うため、絵を引く側が渡す。
enum Viewer {
	## 自分の設定。手札・自分の駒・図鑑・デッキ編集など、ほとんどの画面。
	SELF,
	## 対局中の相手の設定(`set_opponent()` で受け取ったもの)。
	OPPONENT,
	## 常に元の絵。CPUの駒・リプレイ・観戦・ルール画面などの教材。
	NONE,
}

## カードid -> 効いているスキンid。自分のぶんは所有・ON/OFFが変わるたびに `invalidate()` で作り直す。
## **毎フレームの描画から引かれるため、ここで控えておく**(所有の読み口はローカルのファイルまで見に行く)。
static var _self_skins: Dictionary = {}
static var _self_ready := false
static var _opponent_skins: Dictionary = {}


static func texture(card: CardData, state: int, viewer: Viewer = Viewer.SELF) -> Texture2D:
	var skin_id := active_skin(card, viewer)
	if not skin_id.is_empty():
		return SkinLibrary.texture(skin_id, state)
	return HourglassArt.texture(card.art_key(), state)


## 手札の窓の光だまりの色。スキンが効いていなければ共通の絵の色相表から求めた色。
static func accent_color(card: CardData, viewer: Viewer = Viewer.SELF) -> Color:
	var skin_id := active_skin(card, viewer)
	if not skin_id.is_empty():
		return SkinLibrary.accent_color(skin_id)
	return HourglassArt.accent_color(card.art_key())


## そのカードに効いているスキンのid。効いていなければ空文字。
static func active_skin(card: CardData, viewer: Viewer = Viewer.SELF) -> String:
	if card == null or card.is_spell or card.is_token:
		return ""
	match viewer:
		Viewer.SELF:
			return String(_self_map().get(card.id, ""))
		Viewer.OPPONENT:
			return String(_opponent_skins.get(card.id, ""))
	return ""


## 対局の相手の設定を受け取る(`CardMatchOnline` が `fetch_profile()` の直後に呼ぶ)。
static func set_opponent(owned: Array, disabled: Array, enabled: Array) -> void:
	_opponent_skins = _resolve(owned, disabled, enabled)


## 対局を離れたら相手の設定を捨てる。CPU戦の相手はこれで元の絵になる。
static func clear_opponent() -> void:
	_opponent_skins = {}


## 自分の所有・ON/OFFが変わった。次に引かれたときに作り直す。
static func invalidate() -> void:
	_self_ready = false


static func _self_map() -> Dictionary:
	if not _self_ready:
		_self_ready = true
		_self_skins = _resolve(
			AccountService.owned_skin_ids(),
			AccountService.disabled_skin_ids(),
			AccountService.enabled_skin_ids()
		)
	return _self_skins


## 効いているかどうかの規則はここ1箇所。**配布のスキンは全員が持ち、既定がOFF**のため
## ONの一覧(`enabled`)を、買ったスキンは既定がONのためOFFの一覧(`disabled`)を見る。
static func is_on(skin_id: String, owned: Array, disabled: Array, enabled: Array) -> bool:
	if SkinLibrary.is_free(skin_id):
		return enabled.has(skin_id)
	return owned.has(skin_id) and not disabled.has(skin_id)


static func _resolve(owned: Array, disabled: Array, enabled: Array) -> Dictionary:
	var map: Dictionary = {}
	for skin_id in SkinLibrary.all():
		if is_on(skin_id, owned, disabled, enabled):
			map[SkinLibrary.card_id(skin_id)] = skin_id
	return map
