extends RefCounted
## カードスキンの視点ごとの解決(GameDesign.md 31章、Architecture.md 10.19節)。
## 自分の所有はキャッシュ(`AccountService.apply_local_fields()`)だけで与え、`user://` へは書かない。


func run(assert_true: Callable) -> void:
	for skin_id in SkinLibrary.SKINS:
		var card := CardLibrary.find_by_id(SkinLibrary.card_id(skin_id))
		assert_true.call(card != null, "スキン %s の対象カードがある" % skin_id)
		if card != null:
			assert_true.call(
				not card.is_spell and not card.is_token, "スキン %s の対象は砂術・トークンでない" % skin_id
			)
		assert_true.call(SkinLibrary.price(skin_id) > 0, "スキン %s に値段がある" % skin_id)

	for skin_id in SkinLibrary.all():
		_check_skin(assert_true, skin_id)

	AccountService.reset()
	CardSkins.clear_opponent()


func _check_skin(assert_true: Callable, skin_id: String) -> void:
	var card := CardLibrary.find_by_id(SkinLibrary.card_id(skin_id))
	var state := HourglassArt.State.UPRIGHT
	var skin_art := SkinLibrary.texture(skin_id, state)
	var base_art := HourglassArt.texture(card.art_key(), state)
	assert_true.call(skin_art != null and skin_art != base_art, "%s の絵が読める" % skin_id)
	assert_true.call(ShopCatalog.sells(ShopCatalog.Kind.SKIN, skin_id), "%s がショップに並ぶ" % skin_id)

	AccountService.reset()
	AccountService.apply_local_fields({"owned_skins": [], "disabled_skins": []})
	CardSkins.invalidate()
	CardSkins.clear_opponent()
	for viewer in CardSkins.Viewer.values():
		assert_true.call(
			CardSkins.texture(card, state, viewer) == base_art, "%s: 誰も持っていなければ元の絵" % skin_id
		)

	AccountService.apply_local_fields({"owned_skins": [skin_id]})
	CardSkins.invalidate()
	assert_true.call(card.icon_upright == skin_art, "%s: 買えば自分の絵はスキンになる" % skin_id)
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.NONE) == base_art,
		"%s: 教材・再生は元の絵のまま" % skin_id
	)
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == base_art,
		"%s: 自分の所有は相手の駒へ効かない" % skin_id
	)
	assert_true.call(
		CardSkins.accent_color(card) == SkinLibrary.accent_color(skin_id),
		"%s: 光だまりもスキンの色" % skin_id
	)

	AccountService.apply_local_fields({"disabled_skins": [skin_id]})
	CardSkins.invalidate()
	assert_true.call(card.icon_upright == base_art, "%s: OFFにすれば元の絵" % skin_id)

	CardSkins.set_opponent([skin_id], [])
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == skin_art,
		"%s: 相手の所有は相手の駒へ効く" % skin_id
	)
	CardSkins.set_opponent([skin_id], [skin_id])
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == base_art,
		"%s: 相手がOFFなら元の絵" % skin_id
	)
	CardSkins.set_opponent([skin_id], [])
	CardSkins.clear_opponent()
	assert_true.call(
		CardSkins.texture(card, state, CardSkins.Viewer.OPPONENT) == base_art,
		"%s: 対局を離れたら相手の設定は消える" % skin_id
	)
