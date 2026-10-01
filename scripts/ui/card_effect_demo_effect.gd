class_name CardEffectDemoEffect
extends RefCounted
## 効果の実演の台本(GameDesign.md 9章の実演の表のうち、エフェクトの種類ごとのもの)。
##
## `CardEffectPreview` の行数を上限から離すため切り出した(`CardEffectDemoKeyword` と
## 同じ流儀)。**台本は「時刻 → 盤面の状態」を返す純粋な関数**であり、盤面もフォントも
## 一切知らない。部品は `CardEffectStage` が持つ。


## (進捗, 値) だけで組める台本。扱わない種類は空の Dictionary を返し、呼び出し側が
## 他の台本へ回す。
static func stage(demo: int, t: float, value: int) -> Dictionary:
	match demo:
		CardEffectPreview.Demo.FX_DRAW:
			return _stage_draw(t, value)
		CardEffectPreview.Demo.FX_HEAL_PLAYER:
			return _stage_heal(t, value)
		CardEffectPreview.Demo.FX_DAMAGE_PLAYER:
			return _stage_damage_player(t, value)
		CardEffectPreview.Demo.FX_DAMAGE_PLAYER_PER_ENEMY_UNIT:
			return _stage_damage_per_unit(t, value)
		CardEffectPreview.Demo.FX_ADD_ATTACK:
			return _stage_add_attack(t, value)
		CardEffectPreview.Demo.FX_SUMMON:
			return _stage_summon(t)
		CardEffectPreview.Demo.FX_GRANT_KEYWORD:
			return _stage_grant_keyword(t, value)
		CardEffectPreview.Demo.FX_SILENCE:
			return _stage_silence(t)
		CardEffectPreview.Demo.FX_INVERT_HP:
			return _stage_invert_hp(t)
	return {}


## 総量が増える。**「反転:総量+1」(グロウ)のときだけ駒が実際に裏返る**
## (`show_flip`)。設置・落砂・余砂で載る同じ効果(フォージ・アンカー・ウェル・ハスク等)は
## 反転を伴わないため、そこで駒を裏返すと起きていないことを起きたと見せることになる。
static func add_total(t: float, value: int, show_flip: bool, all: bool) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var pieces: Array = [_add_total_piece(t, value, show_flip)]
	if all:
		pieces.append(_add_total_piece(t, value, show_flip))
	var scope := "自分の砂時計すべて" if all else "この砂時計"
	stage["trigger_note"] = "%sの総量が%d増える" % [scope, value]
	if t >= 0.68:
		var pops: Array = []
		for i in pieces.size():
			pops.append(
				CardEffectStage.pop(
					"own", i, "+%d" % value, UiPalette.GLOW_AMBER, CardEffectStage.seg(t, 0.68, 1.0)
				)
			)
		stage["pops"] = pops
	stage["own"] = pieces
	return stage


static func _add_total_piece(t: float, value: int, show_flip: bool) -> Dictionary:
	var piece: Dictionary
	if show_flip:
		var flip := CardEffectStage.seg(t, 0.25, 0.55)
		piece = CardEffectStage.piece(2, 3, 5) if flip < 0.5 else CardEffectStage.piece(3, 2, 5)
		piece["flip"] = flip if t >= 0.25 and t <= 0.6 else -1.0
	else:
		piece = CardEffectStage.piece(3, 2, 5)
	if t >= 0.68:
		piece["h"] = 3 + value
		piece["total"] = 5 + value
	return piece


## 攻撃力だけが増える。**体力が変わらないことが要点**なので、上の部屋は動かさない。
static func _stage_add_attack(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(3, 2, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "攻撃力が%d増える" % value
	if t >= 0.45:
		own["a"] = 2 + value
		own["total"] = 5 + value
		stage["pops"] = [
			CardEffectStage.pop(
				"own", 0, "+%d" % value, UiPalette.GLOW_AMBER, CardEffectStage.seg(t, 0.45, 0.9)
			)
		]
	stage["own"] = [own]
	return stage


## 空き枠へ砂時計が1体現れる。**空きが無ければ何も起きない**ことは文で補う。
static func _stage_summon(t: float) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "空いた枠に砂時計が1体現れる"
	var pieces: Array = [own]
	if t >= 0.4:
		var token := CardEffectStage.piece(2, 0, 2)
		token["fade"] = CardEffectStage.seg(t, 0.4, 0.7)
		pieces.append(token)
	stage["own"] = pieces
	return stage


## 味方1体へキーワードを与える。守護なら台座の輪、硝子なら膜として現れる。
static func _stage_grant_keyword(t: float, keyword: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	var ally := CardEffectStage.piece(4, 1, 5)
	ally["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	var word := CardEnums.keyword_name(keyword)
	if word.is_empty():
		word = CardEnums.keyword_short_text(keyword)
	stage["trigger_note"] = "自分の砂時計1体が【%s】を持つ" % word
	if t >= 0.3:
		stage["beams"] = [
			CardEffectStage.beam(
				["own", 0], ["own", 1], CardEffectStage.seg(t, 0.3, 0.6), false, InkFigure.GREEN
			)
		]
	if t >= 0.6:
		ally["guard"] = keyword == CardEnums.Keyword.GUARD
		ally["glass"] = keyword == CardEnums.Keyword.GLASS
		stage["pops"] = [
			CardEffectStage.pop(
				"own", 1, word, UiPalette.GLOW_AMBER, CardEffectStage.seg(t, 0.6, 1.0)
			)
		]
	stage["own"] = [own, ally]
	return stage


## 相手1体の効果とキーワードを消す。守護の輪と硝子の膜が剥がれることで示す。
static func _stage_silence(t: float) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	var foe := CardEffectStage.piece(4, 1, 5)
	foe["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	foe["guard"] = true
	foe["glass"] = true
	stage["trigger_note"] = "相手の砂時計1体のキーワードと効果が消える"
	if t >= 0.3:
		stage["beams"] = [
			CardEffectStage.beam(["own", 0], ["foe", 0], CardEffectStage.seg(t, 0.3, 0.6))
		]
	if t >= 0.6:
		foe["guard"] = false
		foe["glass"] = false
		stage["pops"] = [
			CardEffectStage.pop(
				"foe", 0, "効果なし", CardEffectPreview.BLOCKED_COLOR, CardEffectStage.seg(t, 0.6, 1.0)
			)
		]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_draw(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "カードを%d枚引く" % value
	stage["draw_card"] = CardEffectStage.seg(t, 0.35, 0.85)
	stage["own"] = [own]
	return stage


static func _stage_heal(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["own_hp"] = 0.6
	stage["trigger_note"] = "自分のHPを%d回復する" % value
	if t >= 0.35:
		stage["beams"] = [
			CardEffectStage.beam(
				["own", 0],
				["own_hp", 0],
				CardEffectStage.seg(t, 0.35, 0.65),
				false,
				UiPalette.GLOW_AMBER
			)
		]
	if t >= 0.65:
		stage["own_hp"] = (
			0.6 + (float(value) / CardEffectPreview.HP_MAX) * CardEffectStage.seg(t, 0.65, 0.9)
		)
		stage["pops"] = [
			CardEffectStage.pop(
				"own_hp", 0, "+%d" % value, UiPalette.GLOW_AMBER, CardEffectStage.seg(t, 0.65, 1.0)
			)
		]
	stage["own"] = [own]
	return stage


## 残りHPと失ったHPを入れ替える。**深く削られているほど大きく戻る**ことを見せたいので、
## 少ない側から多い側へ動かす形にしている。
static func _stage_invert_hp(t: float) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["own_hp"] = 0.2
	stage["trigger_note"] = "自分の残りHPと失ったHPが入れ替わる"
	if t >= 0.3:
		stage["beams"] = [
			CardEffectStage.beam(
				["own", 0],
				["own_hp", 0],
				CardEffectStage.seg(t, 0.3, 0.6),
				false,
				UiPalette.GLOW_AMBER
			)
		]
	if t >= 0.6:
		stage["own_hp"] = 0.2 + 0.6 * CardEffectStage.seg(t, 0.6, 0.9)
		stage["pops"] = [
			CardEffectStage.pop(
				"own_hp", 0, "反転", UiPalette.GLOW_AMBER, CardEffectStage.seg(t, 0.6, 1.0)
			)
		]
	stage["own"] = [own]
	return stage


static func _stage_damage_player(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(6, 0, 6)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "相手プレイヤーへ%dダメージ" % value
	if t >= 0.3:
		stage["beams"] = [
			CardEffectStage.beam(["own", 0], ["foe_hp", 0], CardEffectStage.seg(t, 0.3, 0.62))
		]
	if t >= 0.62:
		stage["foe_hp"] = 1.0 - float(value) / CardEffectPreview.HP_MAX
		stage["pops"] = [
			CardEffectStage.pop(
				"foe_hp", 0, "-%d" % value, InkFigure.RED, CardEffectStage.seg(t, 0.62, 1.0)
			)
		]
	stage["own"] = [own]
	stage["foe"] = [CardEffectStage.piece(4, 1, 5)]
	return stage


static func _stage_damage_per_unit(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(6, 0, 6)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	var foes: Array = [CardEffectStage.piece(4, 1, 5), CardEffectStage.piece(3, 2, 5)]
	var total: int = foes.size() * value
	stage["note"] = "相手の砂時計の数 × %d ダメージを相手プレイヤーへ" % value
	if t >= 0.3:
		stage["beams"] = [
			CardEffectStage.beam(["foe", 0], ["foe_hp", 0], CardEffectStage.seg(t, 0.3, 0.6)),
			CardEffectStage.beam(["foe", 1], ["foe_hp", 0], CardEffectStage.seg(t, 0.38, 0.68)),
		]
	if t >= 0.68:
		stage["foe_hp"] = 1.0 - float(total) / CardEffectPreview.HP_MAX
		var text := "-%d" % total
		stage["pops"] = [
			CardEffectStage.pop("foe_hp", 0, text, InkFigure.RED, CardEffectStage.seg(t, 0.68, 1.0))
		]
	stage["own"] = [own]
	stage["foe"] = foes
	return stage


## 相手の砂時計を対象に取る効果(ダメージ / 破壊 / 反転 / 砂を落とす)。
## 全体を対象にするものは的を2体にして、同じ動きを並べて見せる。
static func on_enemy_unit(t: float, demo: int, value: int, all: bool) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(6, 0, 6)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	# 砂が上へ戻る効果は攻撃力までしか戻せないため、戻す余地のある老いた的にする。
	var aged := (
		demo == CardEffectPreview.Demo.FX_RAISE_SAND
		or demo == CardEffectPreview.Demo.FX_DESTROY_AGED
	)
	var foes: Array = [CardEffectStage.piece(2, 4, 6) if aged else CardEffectStage.piece(5, 1, 6)]
	if all:
		foes.append(CardEffectStage.piece(3, 3, 6) if aged else CardEffectStage.piece(4, 2, 6))
	# 条件付き破壊は、条件を満たさない若い駒を並べて「効かない」ことまで見せる。
	if demo == CardEffectPreview.Demo.FX_DESTROY_AGED:
		foes.append(CardEffectStage.piece(5, 1, 6))
	stage["trigger_note"] = CardEffectDemoEnemy.note(demo, value, all)
	# 条件付き破壊の若い駒(末尾)は対象に取らない。
	var struck: int = (
		foes.size() - 1 if demo == CardEffectPreview.Demo.FX_DESTROY_AGED else foes.size()
	)
	# 的が砕けた後も矢印が残らないよう、当たったところで消す。
	if t >= 0.3 and t < 0.8:
		var beams: Array = []
		for i in struck:
			beams.append(
				CardEffectStage.beam(
					["own", 0], ["foe", i], CardEffectStage.seg(t, 0.3 + 0.06 * i, 0.6 + 0.06 * i)
				)
			)
		stage["beams"] = beams
	if t >= 0.62:
		var landed := CardEffectStage.seg(t, 0.62, 0.85)
		for i in struck:
			CardEffectDemoEnemy.apply(foes[i], demo, value, landed)
	stage["own"] = [own]
	stage["foe"] = foes
	return stage


## 味方の砂時計を対象に取る効果(反転 / 砂を落とす)。**攻撃ではないため相手の場は
## 一切出さず**、自分の場の中で「持ち主 → 対象の1体」へ光の筋を送るだけにする
## (`_stage_grant_keyword()` と同じ語彙)。
static func on_ally_unit(
	t: float, demo: int, value: int, all: bool, exclude_self: bool
) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var caster := CardEffectStage.piece(6, 0, 6)
	caster["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	var allies: Array = [CardEffectStage.piece(3, 2, 5)]
	if all:
		allies.append(CardEffectStage.piece(2, 3, 5))
	var scope := "自分の砂時計すべて"
	if not all:
		scope = "自分の他の砂時計1体" if exclude_self else "自分の砂時計1体"
	if demo == CardEffectPreview.Demo.FX_SWAP_STATS:
		stage["trigger_note"] = "%sの体力と攻撃力を入れ替える" % scope
	elif demo == CardEffectPreview.Demo.FX_RAISE_SAND:
		stage["trigger_note"] = "%sの砂が%d粒上へ戻る(攻撃力-%d / 体力+%d)" % [scope, value, value, value]
	else:
		stage["trigger_note"] = "%sの砂が%d粒落ちる" % [scope, value]
	if t >= 0.3 and t < 0.8:
		var beams: Array = []
		for i in allies.size():
			beams.append(
				CardEffectStage.beam(
					["own", 0],
					["own", i + 1],
					CardEffectStage.seg(t, 0.3 + 0.06 * i, 0.6 + 0.06 * i),
					false,
					InkFigure.GREEN
				)
			)
		stage["beams"] = beams
	if t >= 0.62:
		var landed := CardEffectStage.seg(t, 0.62, 0.85)
		for ally in allies:
			CardEffectDemoEnemy.apply(ally, demo, value, landed)
	var pieces: Array = [caster]
	pieces.append_array(allies)
	stage["own"] = pieces
	return stage
