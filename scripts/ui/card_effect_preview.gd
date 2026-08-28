class_name CardEffectPreview
extends Control
## 能力の実演(GameDesign.md 9章)。抽象化した砂時計の駒(手前=自分 / 奥=相手)と
## 細いHPバーだけを描き、そのカードの能力が盤面で何を起こすのかをループで見せる。
##
## **実演はカードごとではなく、キーワード / 効果の種類ごとに1本持つ。**
## カードは毎日のアプデで増え続けるため、1枚ずつ演出を書き起こす形は採らない。
## 既存の語彙の組み合わせで新しいカードを足せば、実演も自動的に付いてくる。
##
## 台本は「時刻 → 盤面の状態」を返す純粋な関数(`_stage()`)として書き、
## 保持する状態は経過時間だけにする。駒は `CardView` を流用せずここで簡略化して描く
## (実演で見せたいのは体力・攻撃力・砂・矢印の動きだけで、紋章や台座は情報を増やさないため)。

## 台本の種類(`Script` はGodot組み込みのクラス名と衝突するため `Demo` とする)。キーワード / トリガー / エフェクトの語彙に1対1で対応する。
enum Demo {
	## 効果を持たないカード。毎ターン砂が1粒落ち、体力0で砕けるという土台を見せる。
	BASIC,
	GUARD,
	GLASS,
	PIERCE,
	POISON,
	LIFESTEAL,
	DOUBLE_STRIKE,
	QUICK,
	## 反転したときのトリガー(効果を伴わないもの)。
	FLIP,
	FX_DAMAGE_PLAYER,
	FX_DAMAGE_UNIT,
	FX_DESTROY_UNIT,
	FX_SWAP_STATS,
	FX_ADD_TOTAL,
	FX_DROP_SAND,
	FX_DRAW,
	FX_HEAL_PLAYER,
	FX_DAMAGE_PLAYER_PER_ENEMY_UNIT,
}

const MIN_SIZE := Vector2(320, 200)
const PIECE_SIZE := Vector2(48, 56)
const SLOT_GAP := 44.0
const NOTE_FONT_SIZE := 14
const STAT_FONT_SIZE := 13
const HP_BAR_SIZE := Vector2(58, 8)
const HP_MAX := 30.0
## 1本の実演の長さ。短いと読み取る前に終わり、長いと待たされる。
const DEFAULT_DURATION := 4.4

const SAND_TOP := Color(0.98, 0.86, 0.5, 1.0)
const GLASS_TINT := Color(0.62, 0.78, 0.86, 0.35)
const BEAM_COLOR := Color(0.95, 0.62, 0.2, 1.0)
const BLOCKED_COLOR := Color(0.7, 0.72, 0.78, 0.9)

## 台本 → それを組み立てるメソッド。いずれも (進捗, 値) を受ける形へ揃えてある。
const STAGE_METHODS := {
	Demo.BASIC: "_stage_basic",
	Demo.GUARD: "_stage_guard",
	Demo.GLASS: "_stage_glass",
	Demo.PIERCE: "_stage_pierce",
	Demo.POISON: "_stage_poison",
	Demo.LIFESTEAL: "_stage_lifesteal",
	Demo.DOUBLE_STRIKE: "_stage_double_strike",
	Demo.QUICK: "_stage_quick",
	Demo.FLIP: "_stage_flip",
	Demo.FX_ADD_TOTAL: "_stage_add_total",
	Demo.FX_DRAW: "_stage_draw",
	Demo.FX_HEAL_PLAYER: "_stage_heal",
	Demo.FX_DAMAGE_PLAYER: "_stage_damage_player",
	Demo.FX_DAMAGE_PLAYER_PER_ENEMY_UNIT: "_stage_damage_per_unit",
}

var _font: Font
## 実演の並び。1要素 = {"demo": int, "value": int, "all": bool}
var _entries: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	# 置き場所によって使える高さが違うため、**呼び出し側が指定していれば尊重する**
	# (ここで上書きすると、詳細パネルが渡した高さが握り潰される)。
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = MIN_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	set_process(not _entries.is_empty())


## カードの語彙から実演の並びを組む。効果を持たないカードには基本の砂の動きを当てる。
func show_card(card: CardData) -> void:
	_entries = []
	_time = 0.0
	if card != null:
		for keyword in card.keywords:
			var demo := _demo_for_keyword(keyword)
			if demo >= 0:
				_entries.append({"demo": demo, "value": 0, "all": false})
		for effect in card.effects:
			if effect == null:
				continue
			var entry := _entry_for_effect(effect)
			# 反転がトリガーの効果は、まず反転そのものを見せてから効果へ移る。
			# 総量+1(FX_ADD_TOTAL)は台本の中に反転を含むため、重ねて出さない。
			var flips: bool = effect.trigger == CardEnums.Trigger.ON_FLIP
			if flips and int(entry["demo"]) != Demo.FX_ADD_TOTAL:
				_entries.append({"demo": Demo.FLIP, "value": 0, "all": false})
			_entries.append(entry)
	if _entries.is_empty():
		_entries.append({"demo": Demo.BASIC, "value": 0, "all": false})
	set_process(true)
	queue_redraw()


## 語を1つ指定して実演する(キーワード辞書。GameDesign.md 17章)。
## `show_card()` は CardData から台本の並びを組む入口で、こちらはその手前へ入る。
func show_demo(demo: int, value: int = 0, all_units: bool = false) -> void:
	_entries = [{"demo": demo, "value": value, "all": all_units}]
	_time = 0.0
	set_process(true)
	queue_redraw()


func clear() -> void:
	_entries = []
	_time = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if _entries.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


static func _demo_for_keyword(keyword: int) -> int:
	match keyword:
		CardEnums.Keyword.GUARD:
			return Demo.GUARD
		CardEnums.Keyword.GLASS:
			return Demo.GLASS
		CardEnums.Keyword.PIERCE:
			return Demo.PIERCE
		CardEnums.Keyword.POISON:
			return Demo.POISON
		CardEnums.Keyword.LIFESTEAL:
			return Demo.LIFESTEAL
		CardEnums.Keyword.DOUBLE_STRIKE:
			return Demo.DOUBLE_STRIKE
		CardEnums.Keyword.QUICK:
			return Demo.QUICK
	return -1


## 効果1件を実演へ写す。**エフェクトの種類だけで決める**ため、新しいカードが
## 既存の種類を使う限り、ここへ手を入れずに実演が付く。
static func _entry_for_effect(effect: CardEffectData) -> Dictionary:
	var all := (
		effect.target == CardEnums.EffectTarget.ALL_ENEMY_UNITS
		or effect.target == CardEnums.EffectTarget.ALL_ALLY_UNITS
	)
	var demo := Demo.FX_DAMAGE_PLAYER
	match effect.effect_type:
		CardEnums.EffectType.DAMAGE_PLAYER:
			demo = Demo.FX_DAMAGE_PLAYER
		CardEnums.EffectType.DAMAGE_UNIT:
			demo = Demo.FX_DAMAGE_UNIT
		CardEnums.EffectType.DESTROY_UNIT:
			demo = Demo.FX_DESTROY_UNIT
		CardEnums.EffectType.SWAP_STATS:
			demo = Demo.FX_SWAP_STATS
		CardEnums.EffectType.ADD_TOTAL:
			demo = Demo.FX_ADD_TOTAL
		CardEnums.EffectType.DROP_SAND:
			demo = Demo.FX_DROP_SAND
		CardEnums.EffectType.DRAW:
			demo = Demo.FX_DRAW
		CardEnums.EffectType.HEAL_PLAYER:
			demo = Demo.FX_HEAL_PLAYER
		CardEnums.EffectType.DAMAGE_PLAYER_PER_ENEMY_UNIT:
			demo = Demo.FX_DAMAGE_PLAYER_PER_ENEMY_UNIT
	# 反転がトリガーの効果は、反転そのものの実演を兼ねる(2本並べると同じ動きが続くため)。
	return {"demo": demo, "value": maxi(effect.value, 1), "all": all}


# --- 台本 ---------------------------------------------------------------


static func _seg(t: float, from: float, to: float) -> float:
	if t <= from:
		return 0.0
	if t >= to:
		return 1.0
	return (t - from) / (to - from)


## 駒1体。total は砂の総量で、ダメージを受けると減る(GameDesign.md 4章)。
static func _piece(health: int, attack: int, total: int) -> Dictionary:
	return {
		"h": health,
		"a": attack,
		"total": total,
		"shatter": 0.0,
		"glass": false,
		"guard": false,
		"flip": -1.0,
		"fade": 1.0,
	}


static func _beam(from: Array, to: Array, progress: float, blocked := false) -> Dictionary:
	return {"from": from, "to": to, "p": progress, "blocked": blocked}


static func _pop(at: String, index: int, text: String, color: Color, p: float) -> Dictionary:
	return {"at": at, "index": index, "text": text, "color": color, "p": p}


static func _empty_stage() -> Dictionary:
	return {
		"own": [],
		"foe": [],
		"own_hp": 1.0,
		"foe_hp": 1.0,
		"beams": [],
		"pops": [],
		"note": "",
		"draw_card": -1.0,
	}


## 台本と進捗(0.0〜1.0)から、その瞬間の盤面を組み立てる。
## 分岐は対応表に持たせる(台本が増えても分岐の列が伸びないようにするため)。
func _stage(entry: Dictionary, t: float) -> Dictionary:
	var demo := int(entry["demo"])
	var value: int = entry.get("value", 1)
	if STAGE_METHODS.has(demo):
		return call(STAGE_METHODS[demo], t, value)
	return _stage_on_enemy_unit(t, demo, value, entry.get("all", false))


func _stage_basic(t: float, _value: int) -> Dictionary:
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


func _stage_guard(t: float, _value: int) -> Dictionary:
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


func _stage_glass(t: float, _value: int) -> Dictionary:
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
			stage["pops"] = [_pop("own", 0, "-2", CardView.HEALTH_RED, _seg(t, 0.8, 1.0))]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


func _stage_pierce(t: float, _value: int) -> Dictionary:
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
		stage["pops"] = [_pop("foe_hp", 0, "-3", CardView.HEALTH_RED, _seg(t, 0.78, 1.0))]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


func _stage_poison(t: float, _value: int) -> Dictionary:
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


func _stage_lifesteal(t: float, _value: int) -> Dictionary:
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


func _stage_double_strike(t: float, _value: int) -> Dictionary:
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


func _stage_quick(t: float, _value: int) -> Dictionary:
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


func _stage_flip(t: float, _value: int) -> Dictionary:
	var stage := _empty_stage()
	var flip := _seg(t, 0.3, 0.65)
	var own := _piece(1, 4, 5) if flip < 0.5 else _piece(4, 1, 5)
	own["flip"] = flip if t >= 0.3 and t <= 0.7 else -1.0
	stage["note"] = "反転すると体力と攻撃力が入れ替わる"
	stage["own"] = [own]
	return stage


func _stage_add_total(t: float, value: int) -> Dictionary:
	var stage := _empty_stage()
	var flip := _seg(t, 0.25, 0.55)
	var own := _piece(2, 3, 5) if flip < 0.5 else _piece(3, 2, 5)
	own["flip"] = flip if t >= 0.25 and t <= 0.6 else -1.0
	stage["note"] = "反転したとき、この砂時計の総量が%d増える" % value
	if t >= 0.68:
		own["h"] = 3 + value
		own["total"] = 5 + value
		stage["pops"] = [_pop("own", 0, "+%d" % value, UiPalette.GLOW_AMBER, _seg(t, 0.68, 1.0))]
	stage["own"] = [own]
	return stage


func _stage_draw(t: float, value: int) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(5, 0, 5)
	own["fade"] = _seg(t, 0.0, 0.15)
	stage["note"] = "場に出したとき、カードを%d枚引く" % value
	stage["draw_card"] = _seg(t, 0.35, 0.85)
	stage["own"] = [own]
	return stage


func _stage_heal(t: float, value: int) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(5, 0, 5)
	own["fade"] = _seg(t, 0.0, 0.15)
	stage["own_hp"] = 0.6
	stage["note"] = "場に出したとき、自分のHPを%d回復する" % value
	if t >= 0.35:
		stage["beams"] = [_beam(["own", 0], ["own_hp", 0], _seg(t, 0.35, 0.65))]
	if t >= 0.65:
		stage["own_hp"] = 0.6 + (float(value) / HP_MAX) * _seg(t, 0.65, 0.9)
		stage["pops"] = [_pop("own_hp", 0, "+%d" % value, UiPalette.GLOW_AMBER, _seg(t, 0.65, 1.0))]
	stage["own"] = [own]
	return stage


func _stage_damage_player(t: float, value: int) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(6, 0, 6)
	own["fade"] = _seg(t, 0.0, 0.15)
	stage["note"] = "場に出したとき、相手プレイヤーへ%dダメージ" % value
	if t >= 0.3:
		stage["beams"] = [_beam(["own", 0], ["foe_hp", 0], _seg(t, 0.3, 0.62))]
	if t >= 0.62:
		stage["foe_hp"] = 1.0 - float(value) / HP_MAX
		stage["pops"] = [_pop("foe_hp", 0, "-%d" % value, CardView.HEALTH_RED, _seg(t, 0.62, 1.0))]
	stage["own"] = [own]
	stage["foe"] = [_piece(4, 1, 5)]
	return stage


func _stage_damage_per_unit(t: float, value: int) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(6, 0, 6)
	own["fade"] = _seg(t, 0.0, 0.15)
	var foes: Array = [_piece(4, 1, 5), _piece(3, 2, 5)]
	var total: int = foes.size() * value
	stage["note"] = "相手の砂時計の数 × %d ダメージを相手プレイヤーへ" % value
	if t >= 0.3:
		stage["beams"] = [
			_beam(["foe", 0], ["foe_hp", 0], _seg(t, 0.3, 0.6)),
			_beam(["foe", 1], ["foe_hp", 0], _seg(t, 0.38, 0.68)),
		]
	if t >= 0.68:
		stage["foe_hp"] = 1.0 - float(total) / HP_MAX
		var text := "-%d" % total
		stage["pops"] = [_pop("foe_hp", 0, text, CardView.HEALTH_RED, _seg(t, 0.68, 1.0))]
	stage["own"] = [own]
	stage["foe"] = foes
	return stage


## 相手の砂時計を対象に取る効果(ダメージ / 破壊 / 反転 / 砂を落とす)。
## 全体を対象にするものは的を2体にして、同じ動きを並べて見せる。
func _stage_on_enemy_unit(t: float, demo: int, value: int, all: bool) -> Dictionary:
	var stage := _empty_stage()
	var own := _piece(6, 0, 6)
	own["fade"] = _seg(t, 0.0, 0.15)
	var foes: Array = [_piece(5, 1, 6)]
	if all:
		foes.append(_piece(4, 2, 6))
	stage["note"] = _note_on_enemy_unit(demo, value, all)
	# 的が砕けた後も矢印が残らないよう、当たったところで消す。
	if t >= 0.3 and t < 0.8:
		var beams: Array = []
		for i in foes.size():
			beams.append(_beam(["own", 0], ["foe", i], _seg(t, 0.3 + 0.06 * i, 0.6 + 0.06 * i)))
		stage["beams"] = beams
	if t >= 0.62:
		var landed := _seg(t, 0.62, 0.85)
		for foe in foes:
			_apply_on_enemy_unit(foe, demo, value, landed)
	stage["own"] = [own]
	stage["foe"] = foes
	return stage


static func _apply_on_enemy_unit(foe: Dictionary, demo: int, value: int, landed: float) -> void:
	match demo:
		Demo.FX_DESTROY_UNIT:
			foe["shatter"] = landed
		Demo.FX_SWAP_STATS:
			foe["flip"] = landed if landed < 1.0 else -1.0
			if landed >= 0.5:
				var health: int = foe["h"]
				foe["h"] = foe["a"]
				foe["a"] = health
		Demo.FX_DROP_SAND:
			foe["h"] = maxi(foe["h"] - value, 0)
			foe["a"] = foe["a"] + value
		_:
			var left: int = foe["h"] - value
			foe["total"] = maxi(foe["total"] - value, foe["a"])
			foe["h"] = maxi(left, 0)
			if left <= 0:
				foe["shatter"] = landed


static func _note_on_enemy_unit(demo: int, value: int, all: bool) -> String:
	var scope := "相手の砂時計すべて" if all else "相手の砂時計1体"
	match demo:
		Demo.FX_DESTROY_UNIT:
			return "場に出したとき、%sを破壊する" % scope
		Demo.FX_SWAP_STATS:
			return "場に出したとき、%sの体力と攻撃力を入れ替える" % scope
		Demo.FX_DROP_SAND:
			return "場に出したとき、%sの砂が%d粒落ちる" % [scope, value]
	return "場に出したとき、%sへ%dダメージ(砂は消える)" % [scope, value]


# --- 描画 ---------------------------------------------------------------


func _draw() -> void:
	if _entries.is_empty() or _font == null:
		return
	var span := DEFAULT_DURATION * float(_entries.size())
	var head := fmod(_time, span)
	var index: int = clampi(int(head / DEFAULT_DURATION), 0, _entries.size() - 1)
	var t: float = clampf((head - float(index) * DEFAULT_DURATION) / DEFAULT_DURATION, 0.0, 1.0)
	var stage := _stage(_entries[index], t)
	var board := _draw_frame()
	var layout := _layout(board, stage)
	# 盤面を挟んで対面していることを読ませる区切り線。
	var mid_y := board.get_center().y
	draw_line(
		Vector2(board.position.x, mid_y),
		Vector2(board.end.x, mid_y),
		Color(UiPalette.BRASS_MID, 0.5),
		1.0
	)
	_draw_hp_bar(layout["foe_hp"], stage["foe_hp"], false)
	_draw_hp_bar(layout["own_hp"], stage["own_hp"], true)
	for i in stage["foe"].size():
		_draw_piece(layout["foe"][i], stage["foe"][i])
	for i in stage["own"].size():
		_draw_piece(layout["own"][i], stage["own"][i])
	for beam in stage["beams"]:
		_draw_beam(layout, beam)
	if stage["draw_card"] >= 0.0:
		_draw_drawn_card(board, stage["draw_card"])
	for pop in stage["pops"]:
		_draw_pop(layout, pop)
	_draw_note(stage["note"])
	if _entries.size() > 1:
		_draw_dots(index)


## 枠を描き、駒を並べる領域を返す。
func _draw_frame() -> Rect2:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 5)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, Color(0.05, 0.05, 0.07, 0.92)], [1.0, Color(0.12, 0.11, 0.13, 0.92)]]
	)
	UiPaint.apply_grain(ci, rect, 0.05)
	UiPaint.draw_inner_shadow(ci, rect, 8.0, 5, 3, Color(0, 0, 0, 1), 0.4)
	draw_rect(rect, Color(UiPalette.BRASS_MID, 0.85), false, 1.5)
	var note_height := NOTE_FONT_SIZE * 2 + 12
	return Rect2(
		rect.position + Vector2(10, 8), Vector2(rect.size.x - 20, rect.size.y - 18 - note_height)
	)


## 駒とHPバーの位置を決める。HPバーは右端に置き、駒はその左の領域で中央に寄せる。
func _layout(board: Rect2, stage: Dictionary) -> Dictionary:
	var pieces_width := board.size.x - HP_BAR_SIZE.x - 12.0
	var center_x := board.position.x + pieces_width * 0.5
	var foe_y := board.position.y + PIECE_SIZE.y * 0.5 + 4.0
	var own_y := board.end.y - PIECE_SIZE.y * 0.5 - 4.0
	return {
		"own": _slots(center_x, own_y, stage["own"].size()),
		"foe": _slots(center_x, foe_y, stage["foe"].size()),
		"own_hp":
		Rect2(Vector2(board.end.x - HP_BAR_SIZE.x, own_y - HP_BAR_SIZE.y * 0.5), HP_BAR_SIZE),
		"foe_hp":
		Rect2(Vector2(board.end.x - HP_BAR_SIZE.x, foe_y - HP_BAR_SIZE.y * 0.5), HP_BAR_SIZE),
	}


static func _slots(center_x: float, y: float, count: int) -> Array:
	var found: Array = []
	var step := PIECE_SIZE.x + SLOT_GAP
	for i in count:
		var offset := (float(i) - (float(count) - 1.0) * 0.5) * step
		found.append(Vector2(center_x + offset, y))
	return found


func _draw_hp_bar(rect: Rect2, ratio: float, own: bool) -> void:
	var ci := get_canvas_item()
	var track := UiPaint.rounded_rect_points_uniform(rect, 3.0, 3)
	UiPaint.fill_gradient_polygon(
		ci, track, rect, [[0.0, Color(0.05, 0.05, 0.06, 1)], [1.0, Color(0.14, 0.13, 0.15, 1)]]
	)
	var filled := clampf(ratio, 0.0, 1.0)
	if filled > 0.0:
		var inner := Rect2(rect.position, Vector2(rect.size.x * filled, rect.size.y))
		var color := UiPalette.GLOW_AMBER if filled > 0.35 else CardView.HEALTH_RED
		draw_rect(inner, color)
	draw_rect(rect, Color(UiPalette.BRASS_MID, 0.9), false, 1.0)
	var label := "自分" if own else "相手"
	draw_string(
		_font,
		Vector2(rect.position.x, rect.position.y - 3),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(UiPalette.BRASS_HIGHLIGHT, 0.9)
	)


## 砂時計1体。上の部屋の砂=体力 / 下の部屋の砂=攻撃力(GameDesign.md 1章)。
func _draw_piece(center: Vector2, piece: Dictionary) -> void:
	var shatter: float = piece["shatter"]
	var alpha: float = piece["fade"] * (1.0 - clampf(shatter, 0.0, 1.0))
	if shatter > 0.0:
		_draw_shards(center, shatter)
	if alpha <= 0.01:
		return
	var flip: float = piece["flip"]
	var squash := 1.0
	var lift := 0.0
	if flip >= 0.0:
		squash = maxf(absf(cos(flip * PI)), 0.14)
		lift = sin(flip * PI) * 8.0
	var half := Vector2(PIECE_SIZE.x, PIECE_SIZE.y * squash) * 0.5
	var mid := center - Vector2(0.0, lift)
	var neck := PIECE_SIZE.x * 0.1
	var top_body: PackedVector2Array = [
		Vector2(mid.x - half.x, mid.y - half.y),
		Vector2(mid.x + half.x, mid.y - half.y),
		Vector2(mid.x + neck, mid.y),
		Vector2(mid.x - neck, mid.y),
	]
	var bottom_body: PackedVector2Array = [
		Vector2(mid.x - neck, mid.y),
		Vector2(mid.x + neck, mid.y),
		Vector2(mid.x + half.x, mid.y + half.y),
		Vector2(mid.x - half.x, mid.y + half.y),
	]
	var glass := Color(0.16, 0.18, 0.22, 0.9 * alpha)
	draw_colored_polygon(top_body, glass)
	draw_colored_polygon(bottom_body, glass)
	var total: int = maxi(piece["total"], 1)
	_draw_sand(mid, half, neck, float(piece["h"]) / float(total), true, alpha)
	_draw_sand(mid, half, neck, float(piece["a"]) / float(total), false, alpha)
	var frame := Color(UiPalette.BRASS_HIGHLIGHT, alpha)
	draw_polyline(top_body + PackedVector2Array([top_body[0]]), frame, 1.5)
	draw_polyline(bottom_body + PackedVector2Array([bottom_body[0]]), frame, 1.5)
	if piece["glass"]:
		draw_colored_polygon(top_body, Color(GLASS_TINT, GLASS_TINT.a * alpha))
		draw_colored_polygon(bottom_body, Color(GLASS_TINT, GLASS_TINT.a * alpha))
	if piece["guard"]:
		var ring := Rect2(center - half - Vector2(5, 5), (half + Vector2(5, 5)) * 2.0)
		draw_rect(ring, Color(UiPalette.BRASS_HIGHLIGHT, alpha), false, 3.0)
	# 攻撃力=左 / 体力=右 の慣習は保ちつつ、駒の**脇**へ置く。下へ張り出させると
	# 相手の駒と自分の駒を上下に並べたときに重なるため。
	var badge_y := center.y + PIECE_SIZE.y * 0.5 - 8.0
	var badge_x := PIECE_SIZE.x * 0.5 + 8.0
	_draw_stat(Vector2(center.x - badge_x, badge_y), piece["a"], CardView.ATTACK_ORANGE, alpha)
	_draw_stat(Vector2(center.x + badge_x, badge_y), piece["h"], CardView.HEALTH_RED, alpha)


## 砂は上の部屋では首元へ、下の部屋では底へ溜まる。
func _draw_sand(
	mid: Vector2, half: Vector2, neck: float, ratio: float, upper: bool, alpha: float
) -> void:
	var amount := clampf(ratio, 0.0, 1.0)
	if amount <= 0.01:
		return
	var span := half.y
	var edge := mid.y - span if upper else mid.y + span
	var level: float = lerp(mid.y, edge, amount)
	var reach: float = absf(level - mid.y) / maxf(span, 0.01)
	var width: float = lerp(neck, half.x, reach)
	var color := Color(SAND_TOP, alpha)
	if upper:
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(mid.x - neck, mid.y),
					Vector2(mid.x + neck, mid.y),
					Vector2(mid.x + width, level),
					Vector2(mid.x - width, level),
				]
			),
			color
		)
	else:
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(mid.x - width, level),
					Vector2(mid.x + width, level),
					Vector2(mid.x + half.x, mid.y + span),
					Vector2(mid.x - half.x, mid.y + span),
				]
			),
			color
		)


## 被ダメージで消える砂。**砕けて外へ散らす**(落ちる砂とは描き分ける。GameDesign.md 9章)。
func _draw_shards(center: Vector2, progress: float) -> void:
	var alpha := 1.0 - clampf(progress, 0.0, 1.0)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var reach := 6.0 + progress * 26.0
		var at := center + Vector2(cos(angle), sin(angle)) * reach
		draw_circle(at, maxf(3.0 * (1.0 - progress), 0.6), Color(SAND_TOP, alpha))


func _draw_stat(at: Vector2, amount: int, color: Color, alpha: float) -> void:
	draw_circle(at, 9.0, Color(0.07, 0.06, 0.08, alpha))
	draw_circle(at, 9.0, Color(color, alpha * 0.9))
	_centered_text(at + Vector2(0, 5), str(amount), STAT_FONT_SIZE, Color(0.1, 0.08, 0.06, alpha))


## 中央揃えは幅を決め打ちすると符号や2桁が切れるため、実測幅から左端を出す。
func _centered_text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		_font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color
	)


func _anchor(layout: Dictionary, ref: Array) -> Vector2:
	var where: String = ref[0]
	var index: int = ref[1]
	if where == "own_hp":
		return (layout["own_hp"] as Rect2).get_center()
	if where == "foe_hp":
		return (layout["foe_hp"] as Rect2).get_center()
	var slots: Array = layout[where]
	if slots.is_empty():
		return Vector2.ZERO
	return slots[clampi(index, 0, slots.size() - 1)]


func _draw_beam(layout: Dictionary, beam: Dictionary) -> void:
	var progress: float = beam["p"]
	if progress <= 0.0:
		return
	var from: Vector2 = _anchor(layout, beam["from"])
	var to: Vector2 = _anchor(layout, beam["to"])
	var blocked: bool = beam["blocked"]
	var color := BLOCKED_COLOR if blocked else BEAM_COLOR
	var head: Vector2 = from.lerp(to, progress)
	draw_line(from, head, Color(color, 0.9), 3.0)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * 5.0
	draw_colored_polygon(
		PackedVector2Array([head + dir * 8.0, head - side, head + side]), Color(color, 0.95)
	)
	if blocked and progress >= 1.0:
		var cross := 7.0
		draw_line(to - Vector2(cross, cross), to + Vector2(cross, cross), CardView.HEALTH_RED, 3.0)
		draw_line(
			to - Vector2(cross, -cross), to + Vector2(cross, -cross), CardView.HEALTH_RED, 3.0
		)


func _draw_pop(layout: Dictionary, pop: Dictionary) -> void:
	var progress: float = pop["p"]
	if progress <= 0.0:
		return
	var alpha: float = 1.0 - clampf((progress - 0.6) / 0.4, 0.0, 1.0)
	var at: Vector2 = _anchor(layout, [pop["at"], pop["index"]]) - Vector2(0, 22 + progress * 12.0)
	# 枠の外へはみ出さないよう、上端で止める。
	at.y = maxf(at.y, 26.0)
	_centered_text(at, pop["text"], 16, Color(pop["color"], alpha))


## 引いたカードが山札から手札へ入る様子。
func _draw_drawn_card(board: Rect2, progress: float) -> void:
	var card_size := Vector2(20, 27)
	var from := Vector2(board.end.x - 14, board.get_center().y + 10)
	var to := Vector2(board.position.x + 24, board.end.y - 14)
	var at: Vector2 = from.lerp(to, progress) - card_size * 0.5
	var rect := Rect2(at, card_size)
	draw_rect(rect, Color(0.22, 0.18, 0.14, 1))
	draw_rect(rect, UiPalette.BRASS_HIGHLIGHT, false, 1.5)


func _draw_note(text: String) -> void:
	if text.is_empty():
		return
	var baseline := size.y - NOTE_FONT_SIZE * 2 - 2
	draw_multiline_string(
		_font,
		Vector2(12, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 24,
		NOTE_FONT_SIZE,
		2,
		UiPalette.TEXT_OFFWHITE
	)


## 実演が複数あるとき、いま何本目かを示す。
func _draw_dots(index: int) -> void:
	var count := _entries.size()
	var start := size.x - 10.0 - float(count) * 10.0
	for i in count:
		var at := Vector2(start + float(i) * 10.0, 12.0)
		var color := UiPalette.GLOW_AMBER if i == index else Color(UiPalette.BRASS_MID, 0.8)
		draw_circle(at, 3.0, color)
