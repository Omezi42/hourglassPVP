extends RefCounted
## カードスキンの視点ごとの解決(GameDesign.md 31章、Architecture.md 10.19節)。
## 自分の設定はキャッシュ(`AccountService.apply_local_fields()`)だけで与え、`user://` へは書かない。
## **空の一覧はローカルの控えへ落ちて読む**ため、自分の設定には必ず中身のある一覧を渡す。

const UNUSED_ID := "__none"
## 定義に無いid。`is_free()` が false になるため、買ったスキンの規則を確かめるのに使う。
const BOUGHT_ID := "__bought"


func run(assert_true: Callable) -> void:
	for skin_id in SkinLibrary.SKINS:
		var card := CardLibrary.find_by_id(SkinLibrary.card_id(skin_id))
		assert_true.call(card != null, "スキン %s の対象カードがある" % skin_id)
		if card != null:
			assert_true.call(
				not card.is_spell and not card.is_token, "スキン %s の対象は砂術・トークンでない" % skin_id
			)
		var free := SkinLibrary.is_free(skin_id)
		assert_true.call(
			free == (SkinLibrary.price(skin_id) == 0), "スキン %s は配布なら0、売り物なら値段がある" % skin_id
		)

	_check_rules(assert_true)
	for skin_id in SkinLibrary.all():
		_check_skin(assert_true, skin_id)

	AccountService.reset()
	CardSkins.clear_opponent()


func _check_rules(assert_true: Callable) -> void:
	var none: Array = []
	assert_true.call(CardSkins.is_on(BOUGHT_ID, [BOUGHT_ID], none, none), "買ったスキンは買った時点でON")
	assert_true.call(
		not CardSkins.is_on(BOUGHT_ID, [BOUGHT_ID], [BOUGHT_ID], none), "買ったスキンはOFFにできる"
	)
	assert_true.call(not CardSkins.is_on(BOUGHT_ID, none, none, none), "買っていなければ効かない")


func _check_skin(assert_true: Callable, skin_id: String) -> void:
	var card := CardLibrary.find_by_id(SkinLibrary.card_id(skin_id))
	var state := HourglassArt.State.UPRIGHT
	var skin_art := SkinLibrary.texture(skin_id, state)
	var base_art := HourglassArt.texture(card.art_key(), state)
	var free := SkinLibrary.is_free(skin_id)
	assert_true.call(skin_art != null and skin_art != base_art, "%s の絵が読める" % skin_id)
	assert_true.call(
		ShopCatalog.sells(ShopCatalog.Kind.SKIN, skin_id) != free,
		"%s は売り物ならショップに並び、配布なら並ばない" % skin_id
	)

	var on := _on_fields(skin_id)
	var off := _off_fields()
	AccountService.reset()
	AccountService.apply_local_fields(off)
	CardSkins.invalidate()
	CardSkins.clear_opponent()
	assert_true.call(
		AccountService.owned_skin_ids().has(skin_id) == free, "%s: 配布なら全員が持つ" % skin_id
	)
	for viewer in CardSkins.Viewer.values():
		assert_true.call(
			CardSkins.texture(card, state, viewer) == base_art, "%s: 効いていなければ元の絵" % skin_id
		)

	AccountService.apply_local_fields(on)
	CardSkins.invalidate()
	assert_true.call(card.icon_upright == skin_art, "%s: ONなら自分の絵はスキンになる" % skin_id)
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.NONE) == base_art,
		"%s: 教材・再生は元の絵のまま" % skin_id
	)
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == base_art,
		"%s: 自分の設定は相手の駒へ効かない" % skin_id
	)
	assert_true.call(
		CardSkins.accent_color(card) == SkinLibrary.accent_color(skin_id),
		"%s: 光だまりもスキンの色" % skin_id
	)

	CardSkins.set_opponent(on["owned_skins"], on["disabled_skins"], on["enabled_skins"])
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == skin_art,
		"%s: 相手がONなら相手の駒へ効く" % skin_id
	)
	CardSkins.set_opponent(off["owned_skins"], off["disabled_skins"], off["enabled_skins"])
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == base_art,
		"%s: 相手がOFFなら元の絵" % skin_id
	)
	CardSkins.set_opponent(on["owned_skins"], on["disabled_skins"], on["enabled_skins"])
	CardSkins.clear_opponent()
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == base_art,
		"%s: 対局を離れたら相手の設定は消える" % skin_id
	)


## 配布はONの一覧に載せ、買ったスキンは所有に載せてOFFの一覧から外す。
func _on_fields(skin_id: String) -> Dictionary:
	return {
		"owned_skins": [UNUSED_ID] if SkinLibrary.is_free(skin_id) else [skin_id],
		"disabled_skins": [UNUSED_ID],
		"enabled_skins": [skin_id] if SkinLibrary.is_free(skin_id) else [UNUSED_ID],
	}


## 配布はONの一覧に載せず、買ったスキンは所有に載せない。
func _off_fields() -> Dictionary:
	return {
		"owned_skins": [UNUSED_ID],
		"disabled_skins": [UNUSED_ID],
		"enabled_skins": [UNUSED_ID],
	}
