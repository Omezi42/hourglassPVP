extends RefCounted
## 砂時計の絵を色の数値から作る仕組みの検証(Architecture.md 4.1節)。
## 焼き付けそのものは描画器が要るため `tools/tests/verify_hourglass_art.gd` で確かめる。
## ここでは表とカードの結びつきだけを見る(カードを足したときに色を書き忘れると落ちる)。


func run(assert_true: Callable) -> void:
	var table: HourglassTintTable = load(HourglassArt.TABLE_PATH)
	assert_true.call(table != null, "色の表が読める")
	assert_true.call(table.has(HourglassArt.MASTER_ID), "原本が表にある")
	assert_true.call(table.source_of(HourglassArt.MASTER_ID).is_empty(), "原本に親はいない")

	for state in HourglassArt.STATE_FILES.size():
		var path := "%s/%s.png" % [HourglassArt.MASTER_DIR, HourglassArt.STATE_FILES[state]]
		assert_true.call(ResourceLoader.exists(path), "原本の絵がある: " + path)

	for art_id in table.entries.keys():
		var chain := table.chain(String(art_id))
		var depth := chain.size()
		assert_true.call(depth <= 2, "%s の変換は2段まで" % art_id)
		if String(art_id) != HourglassArt.MASTER_ID:
			assert_true.call(depth >= 1, "%s は原本から作られる" % art_id)

	var cards := CardLibrary.all_cards()
	assert_true.call(cards.size() > 0, "カードが読める")
	for card in cards:
		var key := card.art_key()
		assert_true.call(not key.is_empty(), "%s に絵のidがある" % card.id)
		assert_true.call(table.has(key), "%s の色が表にある(%s)" % [card.id, key])
