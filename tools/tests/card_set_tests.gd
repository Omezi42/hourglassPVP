extends RefCounted
## カードセットの段階公開(GameDesign.md 21章、Architecture.md 10.8.1節)。


func run(assert_true: Callable) -> void:
	for set_id in CardSetLibrary.ORDERED_IDS:
		var listed := CardSetLibrary.card_ids(set_id).size()
		var planned := CardSetLibrary.planned_count(set_id)
		assert_true.call(planned >= listed, "セット %s の予定枚数は公開済み以上" % set_id)
		assert_true.call(
			CardSetLibrary.hidden_count(set_id) == planned - listed, "セット %s の未公開枚数" % set_id
		)
		if not CardSetLibrary.SETS[set_id].has("planned_count"):
			assert_true.call(
				CardSetLibrary.hidden_count(set_id) == 0, "予定枚数の無いセット %s は出そろっている" % set_id
			)
			assert_true.call(
				CardSetLibrary.count_text(set_id) == "%d枚" % listed, "出そろったセット %s の枚数表記" % set_id
			)
		if CardSetLibrary.hidden_count(set_id) > 0:
			# 1枚目を公開した状態で売り出す(GameDesign.md 21章)
			assert_true.call(listed >= 1, "段階公開のセット %s は1枚目を公開している" % set_id)
			assert_true.call(CardSetLibrary.price(set_id) > 0, "段階公開のセット %s はショップで売る" % set_id)
			assert_true.call(
				CardSetLibrary.count_text(set_id) == "%d / %d 枚公開中" % [listed, planned],
				"段階公開のセット %s の枚数表記" % set_id
			)
	assert_true.call(CardSetLibrary.planned_count("__none") == 0, "無いセットの予定枚数は0")
