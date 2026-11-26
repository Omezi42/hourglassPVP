extends RefCounted
## 砂時計の絵の表とカードの結びつきの検証(Architecture.md 4.1節)。
## カードを足したときに、シェーダー・焼いた絵・表の行のどれかを書き忘れると落ちる。
## 焼いた絵が描き手のシェーダーと食い違っていないかは `tools/check_hourglass_bake.py` が見る。

const SHADER_DIR := "res://resources/shaders/hourglasses"
## 絵(シェーダー・焼いた絵・砂の色)を別の回で足すセット。絵が揃ったらここから外す。
const ART_PENDING_SETS: Array[String] = ["early_bell", "fuse_sand"]


func run(assert_true: Callable) -> void:
	var table: HourglassSandTable = load(HourglassArt.TABLE_PATH)
	assert_true.call(table != null, "砂の色の表が読める")

	for art_id in table.entries.keys():
		var texture := table.texture_of(String(art_id))
		assert_true.call(HourglassArt.TEXTURES.has(texture), "%s の砂の質感が既知(%s)" % [art_id, texture])

	var cards := CardLibrary.all_cards()
	assert_true.call(cards.size() > 0, "カードが読める")
	for card in cards:
		# 砂術は砂時計の絵を持たない(GameDesign.md 6章)。
		if card.is_spell or ART_PENDING_SETS.has(card.set_id):
			continue
		var key := card.art_key()
		assert_true.call(key == card.id, "%s が他のカードの絵を借りていない(%s)" % [card.id, key])
		assert_true.call(table.has(key), "%s の砂の色が表にある" % card.id)
		var shader := "%s/%s.gdshader" % [SHADER_DIR, key]
		assert_true.call(ResourceLoader.exists(shader), "%s を描くシェーダーがある" % card.id)
		for state in HourglassArt.STATE_FILES.size():
			assert_true.call(
				HourglassArt.texture(key, state) != null,
				"%s の焼いた絵がある(%s)" % [card.id, HourglassArt.STATE_FILES[state]]
			)
