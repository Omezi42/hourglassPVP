class_name CardEffectDemoKeyword
extends RefCounted
## キーワードの実演の台本(GameDesign.md 9章の実演の表のうち、常在キーワードと基本の砂)。
##
## `CardEffectPreview` が1000行の上限に達したため切り出した(`CardEffectDemoEnemy` と
## 同じ流儀)。**台本は「時刻 → 盤面の状態」を返す純粋な関数**であり、盤面もフォントも
## 一切知らない。部品は `CardEffectStage` が持つ。


## その語の台本を組み立てる。扱わない語は空の Dictionary を返し、呼び出し側が
## 他の台本へ回す(ここで既定の盤面を返すと、扱えていないことに気づけなくなる)。
static func stage(demo: int, t: float) -> Dictionary:
	match demo:
		CardEffectPreview.Demo.BASIC:
			return _stage_basic(t)
		CardEffectPreview.Demo.GUARD:
			return _stage_guard(t)
		CardEffectPreview.Demo.GLASS:
			return _stage_glass(t)
		CardEffectPreview.Demo.PIERCE:
			return _stage_pierce(t)
		CardEffectPreview.Demo.POISON:
			return _stage_poison(t)
		CardEffectPreview.Demo.LIFESTEAL:
			return _stage_lifesteal(t)
		CardEffectPreview.Demo.DOUBLE_STRIKE:
			return _stage_double_strike(t)
		CardEffectPreview.Demo.QUICK:
			return _stage_quick(t)
		CardEffectPreview.Demo.FLIP:
			return _stage_flip(t)
	return {}


static func _stage_basic(t: float) -> Dictionary:
	var stage := _empty_stage()
	var total := 5
	var steps := total + 1
	var f: float = t * float(steps)
	var step: int = clampi(int(f), 0, steps - 1)
	var piece := _piece(total - step, step, total)
	if step >= total:
		piece["shatter"] = f - float(steps - 1)
		stage["note"] = "体力が0になると砕ける"
	else:
		stage["note"] = "毎ターン終了時、砂が1粒落ちる(体力-1 / 攻撃力+1)"
	stage["own"] = [piece]
	return stage


static func _stage_guard(t: float) -> Dictionary:
	var stage := _empty_stage()
	var keeper := _piece(4, 1, 5)
	keeper["guard"] = true
	var mate := _piece(3, 1, 4)
	var foe := _piece(3, 3, 6)
	if t < 0.5:
		stage["note"] = "相手は守護を無視して他を攻撃できない"
		stage["beams"] = [_beam(["foe", 0], ["own", 1], _seg(t, 0.08, 0.4), true)]
	else:
		stage["note"] = "攻撃は必ず守護の駒へ向かう"
		stage["beams"] = [_beam(["foe", 0], ["own", 0], _seg(t, 0.55, 0.85))]
		if t >= 0.85:
			keeper["h"] = 1
			keeper["total"] = 2
			foe["h"] = 2
			foe["total"] = 5
	stage["own"] = [keeper, mate]
	stage["foe"] = [foe]
	return stage


static func _stage_glass(t: float) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(4, 0, 4)
	var foe := _piece(3, 2, 5)
	own["glass"] = true
	if t < 0.5:
		stage["note"] = "最初に受けるダメージは硝子が1度だけ無効にする"
		stage["beams"] = [_beam(["foe", 0], ["own", 0], _seg(t, 0.1, 0.35))]
		if t >= 0.35:
			own["glass"] = false
			stage["pops"] = [_pop("own", 0, "無効", BLOCKED_COLOR, _seg(t, 0.35, 0.5))]
	else:
		own["glass"] = false
		stage["note"] = "2度目からはそのまま通る"
		stage["beams"] = [_beam(["foe", 0], ["own", 0], _seg(t, 0.55, 0.8))]
		if t >= 0.8:
			own["h"] = 2
			own["total"] = 2
			stage["pops"] = [_pop("own", 0, "-2", InkFigure.RED, _seg(t, 0.8, 1.0))]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_pierce(t: float) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(3, 5, 8)
	var foe := _piece(2, 1, 3)
	stage["note"] = "砂時計を攻撃したとき、超過した砂が相手プレイヤーへ抜ける"
	if t < 0.5:
		stage["beams"] = [_beam(["own", 0], ["foe", 0], _seg(t, 0.12, 0.4))]
	if t >= 0.4:
		foe["shatter"] = _seg(t, 0.4, 0.62)
		own["h"] = 2
		own["total"] = 7
		stage["beams"].append(_beam(["own", 0], ["foe_hp", 0], _seg(t, 0.5, 0.78)))
	if t >= 0.78:
		stage["foe_hp"] = 1.0 - 3.0 / HP_MAX
		stage["pops"] = [_pop("foe_hp", 0, "-3", InkFigure.RED, _seg(t, 0.78, 1.0))]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_poison(t: float) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(3, 1, 4)
	var foe := _piece(6, 0, 6)
	stage["note"] = "1ダメージでも、与えれば相手の砂時計を破壊する"
	# 的が砕けた後も矢印が空を指し続けないよう、当たったところで消す。
	if t < 0.6:
		stage["beams"] = [_beam(["own", 0], ["foe", 0], _seg(t, 0.15, 0.45))]
	if t >= 0.45:
		foe["h"] = 5
		foe["total"] = 5
		foe["shatter"] = _seg(t, 0.5, 0.75)
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_lifesteal(t: float) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(4, 3, 7)
	var foe := _piece(5, 1, 6)
	stage["own_hp"] = 0.6
	stage["note"] = "与えたダメージぶん、自分のHPが回復する"
	stage["beams"] = [_beam(["own", 0], ["foe", 0], _seg(t, 0.15, 0.45))]
	if t >= 0.45:
		foe["h"] = 2
		foe["total"] = 3
		own["h"] = 3
		own["total"] = 6
		stage["own_hp"] = 0.6 + (3.0 / HP_MAX) * _seg(t, 0.45, 0.72)
		stage["pops"] = [_pop("own_hp", 0, "+3", UiPalette.GLOW_AMBER, _seg(t, 0.45, 0.8))]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_double_strike(t: float) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(4, 2, 6)
	var foe := _piece(6, 0, 6)
	stage["note"] = "同じ砂時計が1ターンに2回攻撃する"
	stage["beams"] = [_beam(["own", 0], ["foe", 0], _seg(t, 0.1, 0.35))]
	if t >= 0.35:
		foe["h"] = 4
		foe["total"] = 4
	if t >= 0.5:
		stage["beams"].append(_beam(["own", 0], ["foe", 0], _seg(t, 0.5, 0.75)))
	if t >= 0.75:
		foe["h"] = 2
		foe["total"] = 2
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_quick(t: float) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(5, 0, 5)
	var foe := _piece(5, 0, 5)
	own["fade"] = _seg(t, 0.0, 0.12)
	stage["note"] = "場に出た瞬間に砂が2粒落ちる"
	if t >= 0.3:
		own["h"] = 3
		own["a"] = 2
	if t >= 0.5:
		stage["note"] = "出したターンからそのまま攻撃できる"
		stage["beams"] = [_beam(["own", 0], ["foe", 0], _seg(t, 0.55, 0.82))]
	if t >= 0.82:
		foe["h"] = 3
		foe["total"] = 3
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


static func _stage_flip(t: float) -> Dictionary:
	var stage := _empty_stage()
	var flip := _seg(t, 0.3, 0.65)
	var own := _piece(1, 4, 5) if flip < 0.5 else _piece(4, 1, 5)
	own["flip"] = flip if t >= 0.3 and t <= 0.7 else -1.0
	stage["note"] = "反転すると体力と攻撃力が入れ替わる"
	stage["own"] = [own]
	return stage
