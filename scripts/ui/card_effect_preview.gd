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
	FX_ADD_ATTACK,
	FX_SUMMON,
	FX_GRANT_KEYWORD,
	FX_SILENCE,
	## 相手の砂時計1体を持ち主の手札へ戻す(砂術)。
	FX_RETURN_TO_HAND,
	## 自分のHPを反転する(砂術)。残りHPと失ったHPが入れ替わる。
	FX_INVERT_HP,
}

const MIN_SIZE := Vector2(320, 200)
## 駒1体ぶんの寸法。**縦は枠の高さから逆算して決めてある**——自分と相手を上下へ
## 対面させるため、`枠の高さ - 駒の高さ×2 - 余白` が正になっていないと上下が重なる
## (56pxのときは実際に接していた)。`CardDetailPanel.PREVIEW_HEIGHT` と対で見ること。
const PIECE_SIZE := Vector2(48, 48)
const SLOT_GAP := 44.0
const NOTE_FONT_SIZE := 14
const STAT_FONT_SIZE := 13
const HP_BAR_SIZE := Vector2(58, 8)
const HP_MAX := 30.0
## 1本の実演の長さ。短いと読み取る前に終わり、長いと待たされる。
const DEFAULT_DURATION := 4.4

## 阻まれた攻撃(守護)。効いた攻撃の朱と区別するため、くすんだ色で引く。
const BLOCKED_COLOR := Color(0.52, 0.47, 0.38, 0.9)

## 台本 → それを組み立てるメソッド。いずれも (進捗, 値) を受ける形へ揃えてある。
const STAGE_METHODS := {
	Demo.FX_DRAW: "_stage_draw",
	Demo.FX_HEAL_PLAYER: "_stage_heal",
	Demo.FX_DAMAGE_PLAYER: "_stage_damage_player",
	Demo.FX_DAMAGE_PLAYER_PER_ENEMY_UNIT: "_stage_damage_per_unit",
	Demo.FX_ADD_ATTACK: "_stage_add_attack",
	Demo.FX_SUMMON: "_stage_summon",
	Demo.FX_GRANT_KEYWORD: "_stage_grant_keyword",
	Demo.FX_SILENCE: "_stage_silence",
	Demo.FX_INVERT_HP: "_stage_invert_hp",
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
			entry["spell"] = card.is_spell
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
	# **対象が味方か敵かで、実演の描き方そのものが変わる**(下記 `_stage()`)。
	# ここを見落とすと、味方を対象にする効果(反転・砂落とし)が「相手を攻撃した」
	# 演出になってしまう(実際にピボット・逆さ砂・ラトル・ドリップ・ひとつまみで起きていた)。
	var is_ally := (
		effect.target == CardEnums.EffectTarget.ALLY_UNIT
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
		CardEnums.EffectType.ADD_ATTACK:
			demo = Demo.FX_ADD_ATTACK
		CardEnums.EffectType.SUMMON:
			demo = Demo.FX_SUMMON
		CardEnums.EffectType.GRANT_KEYWORD:
			demo = Demo.FX_GRANT_KEYWORD
		CardEnums.EffectType.SILENCE:
			demo = Demo.FX_SILENCE
		CardEnums.EffectType.RETURN_TO_HAND:
			demo = Demo.FX_RETURN_TO_HAND
		CardEnums.EffectType.INVERT_PLAYER_HP:
			demo = Demo.FX_INVERT_HP
	# 反転がトリガーの効果は、反転そのものの実演を兼ねる(2本並べると同じ動きが続くため)。
	# キーワードを与える効果だけは、値が「いくつ」ではなく「どの語か」を指す。
	var value := maxi(effect.value, 1)
	if demo == Demo.FX_GRANT_KEYWORD:
		value = effect.keyword
	return {
		"demo": demo,
		"value": value,
		"all": all,
		"ally": is_ally,
		"trigger": effect.trigger,
	}


# --- 台本 ---------------------------------------------------------------


## 台本と進捗(0.0〜1.0)から、その瞬間の盤面を組み立てる。
## 分岐は対応表に持たせる(台本が増えても分岐の列が伸びないようにするため)。
func _stage(entry: Dictionary, t: float) -> Dictionary:
	var demo := int(entry["demo"])
	var value: int = entry.get("value", 1)
	var trigger: int = entry.get("trigger", CardEnums.Trigger.ON_PLAY)
	var stage: Dictionary
	if demo == Demo.FX_ADD_TOTAL:
		# 「反転:総量+1」(グロウ)だけが実際に反転を伴う。設置/落砂/余砂の総量+効果は
		# 反転しないため、台本の中で勝手に駒を裏返さない(トリガーで判定する)。
		stage = _stage_add_total(
			t, value, trigger == CardEnums.Trigger.ON_FLIP, entry.get("all", false)
		)
	elif entry.get("ally", false) and (demo == Demo.FX_SWAP_STATS or demo == Demo.FX_DROP_SAND):
		# 味方を対象にする反転・砂落としは、相手への攻撃を挟まない
		# (下の `_stage_on_enemy_unit` は「攻撃して当てる」演出であり、味方には使えない)。
		# 砂術は盤面に自分自身を持たないため「他の」を付けない(GameDesign.md 6章の
		# 自己除外は、効果を持つ砂時計自身を選べないという駒の制約であり砂術には無い)。
		stage = _stage_on_ally_unit(
			t, demo, value, entry.get("all", false), not entry.get("spell", false)
		)
	elif STAGE_METHODS.has(demo):
		stage = call(STAGE_METHODS[demo], t, value)
	else:
		# 常在キーワードと基本の砂の台本は `CardEffectDemoKeyword` が持つ。扱わない語には
		# 空を返させ、その場合だけ「相手の駒へ効く効果」の台本へ回す(既定の盤面を
		# 返させると、台本が無いことに気づけないまま何かが動いて見える)。
		stage = CardEffectDemoKeyword.stage(demo, t)
		if stage.is_empty():
			stage = _stage_on_enemy_unit(t, demo, value, entry.get("all", false))
	var trigger_note: String = stage.get("trigger_note", "")
	if not trigger_note.is_empty():
		# 砂術は「いつ」を持たない(効果は撃った瞬間に1度だけ起きる。GameDesign.md 6章)。
		# 前置きを付けると「場に出したとき」と嘘を言うことになる。
		if entry.get("spell", false):
			stage["note"] = trigger_note
		else:
			stage["note"] = "%s、%s" % [_trigger_phrase(trigger), trigger_note]
	return stage


## トリガーを「いつ」を表す語へ写す。CardEnums.trigger_name() の語(設置 / 反転 / 余砂)は
## カードの面へ出す短い呼び名で、実演では何が起きたのかを文で読ませるため別に持つ。
static func _trigger_phrase(trigger: int) -> String:
	match trigger:
		CardEnums.Trigger.ON_FLIP:
			return "反転したとき"
		CardEnums.Trigger.ON_DEATH:
			return "壊れたとき"
		CardEnums.Trigger.ON_TURN_END:
			return "自分のターンの終わりに"
		CardEnums.Trigger.ON_DAMAGED:
			return "ダメージを受けたとき"
	return "場に出したとき"


## 総量が増える。**「反転:総量+1」(グロウ)のときだけ駒が実際に裏返る**
## (`show_flip`)。設置・落砂・余砂で載る同じ効果(フォージ・アンカー・ウェル・ハスク等)は
## 反転を伴わないため、そこで駒を裏返すと起きていないことを起きたと見せることになる。
func _stage_add_total(t: float, value: int, show_flip: bool, all: bool) -> Dictionary:
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
func _stage_add_attack(t: float, value: int) -> Dictionary:
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
func _stage_summon(_t: float, _value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(_t, 0.0, 0.15)
	stage["trigger_note"] = "空いた枠に砂時計が1体現れる"
	var pieces: Array = [own]
	if _t >= 0.4:
		var token := CardEffectStage.piece(2, 0, 2)
		token["fade"] = CardEffectStage.seg(_t, 0.4, 0.7)
		pieces.append(token)
	stage["own"] = pieces
	return stage


## 味方1体へキーワードを与える。守護なら台座の輪、硝子なら膜として現れる。
func _stage_grant_keyword(t: float, keyword: int) -> Dictionary:
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
func _stage_silence(t: float, _value: int) -> Dictionary:
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
			CardEffectStage.pop("foe", 0, "効果なし", BLOCKED_COLOR, CardEffectStage.seg(t, 0.6, 1.0))
		]
	stage["own"] = [own]
	stage["foe"] = [foe]
	return stage


func _stage_draw(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(5, 0, 5)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "カードを%d枚引く" % value
	stage["draw_card"] = CardEffectStage.seg(t, 0.35, 0.85)
	stage["own"] = [own]
	return stage


func _stage_heal(t: float, value: int) -> Dictionary:
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
		stage["own_hp"] = 0.6 + (float(value) / HP_MAX) * CardEffectStage.seg(t, 0.65, 0.9)
		stage["pops"] = [
			CardEffectStage.pop(
				"own_hp", 0, "+%d" % value, UiPalette.GLOW_AMBER, CardEffectStage.seg(t, 0.65, 1.0)
			)
		]
	stage["own"] = [own]
	return stage


## 残りHPと失ったHPを入れ替える。**深く削られているほど大きく戻る**ことを見せたいので、
## 少ない側から多い側へ動かす形にしている。
func _stage_invert_hp(t: float, _value: int) -> Dictionary:
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


func _stage_damage_player(t: float, value: int) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(6, 0, 6)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "相手プレイヤーへ%dダメージ" % value
	if t >= 0.3:
		stage["beams"] = [
			CardEffectStage.beam(["own", 0], ["foe_hp", 0], CardEffectStage.seg(t, 0.3, 0.62))
		]
	if t >= 0.62:
		stage["foe_hp"] = 1.0 - float(value) / HP_MAX
		stage["pops"] = [
			CardEffectStage.pop(
				"foe_hp", 0, "-%d" % value, InkFigure.RED, CardEffectStage.seg(t, 0.62, 1.0)
			)
		]
	stage["own"] = [own]
	stage["foe"] = [CardEffectStage.piece(4, 1, 5)]
	return stage


func _stage_damage_per_unit(t: float, value: int) -> Dictionary:
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
		stage["foe_hp"] = 1.0 - float(total) / HP_MAX
		var text := "-%d" % total
		stage["pops"] = [
			CardEffectStage.pop("foe_hp", 0, text, InkFigure.RED, CardEffectStage.seg(t, 0.68, 1.0))
		]
	stage["own"] = [own]
	stage["foe"] = foes
	return stage


## 相手の砂時計を対象に取る効果(ダメージ / 破壊 / 反転 / 砂を落とす)。
## 全体を対象にするものは的を2体にして、同じ動きを並べて見せる。
func _stage_on_enemy_unit(t: float, demo: int, value: int, all: bool) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(6, 0, 6)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	var foes: Array = [CardEffectStage.piece(5, 1, 6)]
	if all:
		foes.append(CardEffectStage.piece(4, 2, 6))
	stage["trigger_note"] = CardEffectDemoEnemy.note(demo, value, all)
	# 的が砕けた後も矢印が残らないよう、当たったところで消す。
	if t >= 0.3 and t < 0.8:
		var beams: Array = []
		for i in foes.size():
			beams.append(
				CardEffectStage.beam(
					["own", 0], ["foe", i], CardEffectStage.seg(t, 0.3 + 0.06 * i, 0.6 + 0.06 * i)
				)
			)
		stage["beams"] = beams
	if t >= 0.62:
		var landed := CardEffectStage.seg(t, 0.62, 0.85)
		for foe in foes:
			CardEffectDemoEnemy.apply(foe, demo, value, landed)
	stage["own"] = [own]
	stage["foe"] = foes
	return stage


## 味方の砂時計を対象に取る効果(反転 / 砂を落とす)。**攻撃ではないため相手の場は
## 一切出さず**、自分の場の中で「持ち主 → 対象の1体」へ光の筋を送るだけにする
## (`_stage_grant_keyword` と同じ語彙)。以前はここも `_stage_on_enemy_unit` を
## 通していたため、味方を対象にするピボット・逆さ砂・ラトル・ドリップ・ひとつまみが
## 「相手を攻撃してその駒を操作する」という誤った演出になっていた。
func _stage_on_ally_unit(
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
	if demo == Demo.FX_SWAP_STATS:
		stage["trigger_note"] = "%sの体力と攻撃力を入れ替える" % scope
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
## **紙に刷られた図版として描く**(GameDesign.md 9章)。実演を出すのは砂時計図鑑と
## キーワード辞書だけであり、どちらも盤面の再現ではなく理屈を読ませる場所のため。
func _draw_frame() -> Rect2:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.rounded_rect_points_uniform(rect, 6.0, 5),
		rect,
		[[0.0, Color(0.90, 0.845, 0.70)], [1.0, Color(0.80, 0.72, 0.56)]]
	)
	UiPaint.apply_grain(ci, rect, 0.07)
	# 二重の細い罫で囲み、四隅へ小さな菱形を打つ(図版の枠)。
	draw_rect(rect, Color(0.45, 0.33, 0.18, 0.55), false, 1.4)
	draw_rect(rect.grow(-4), Color(0.45, 0.33, 0.18, 0.30), false, 1.0)
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y),
		rect.end,
	]:
		draw_colored_polygon(
			PackedVector2Array(
				[
					corner + Vector2(0, -4),
					corner + Vector2(4, 0),
					corner + Vector2(0, 4),
					corner + Vector2(-4, 0),
				]
			),
			Color(0.45, 0.33, 0.18, 0.85)
		)
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
	InkFigure.hp_bar(self, rect, ratio)
	draw_string(
		_font,
		Vector2(rect.position.x, rect.position.y - 3),
		"自分" if own else "相手",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		InkFigure.INK_SOFT
	)


## 砂時計1体。上の部屋の砂=体力 / 下の部屋の砂=攻撃力(GameDesign.md 1章)。
## 描くのは `InkFigure` の部品だけで、ここは**台本の値を図版の引数へ写すだけ**にする。
func _draw_piece(center: Vector2, piece: Dictionary) -> void:
	var shatter: float = piece["shatter"]
	var alpha: float = piece["fade"] * (1.0 - clampf(shatter, 0.0, 1.0))
	if shatter > 0.0:
		InkFigure.broken(self, center, 10.0 + shatter * 8.0, 1.0 - clampf(shatter, 0.0, 1.0))
	if alpha <= 0.01:
		return
	# 反転中は持ち上げながら縦を潰す。ちょうど半回転で厚みだけの線になる。
	var flip: float = piece["flip"]
	var height := PIECE_SIZE.y
	var mid := center
	if flip >= 0.0:
		height *= maxf(absf(cos(flip * PI)), 0.14)
		mid -= Vector2(0.0, sin(flip * PI) * 8.0)
	var total: int = maxi(piece["total"], 1)
	InkFigure.hourglass(self, mid, height, float(piece["a"]) / float(total), alpha)
	if piece["glass"]:
		InkFigure.glass_film(self, mid, PIECE_SIZE.x * 0.46, false)
	if piece["guard"]:
		InkFigure.guard_ring(self, mid, PIECE_SIZE.x * 0.5, height * 0.5 + 6.0)
	# 攻撃力=左 / 体力=右 の慣習は保ちつつ、駒の**脇**へ置く。下へ張り出させると
	# 相手の駒と自分の駒を上下に並べたときに重なるため。
	var badge_y := center.y + PIECE_SIZE.y * 0.5 - 8.0
	var badge_x := PIECE_SIZE.x * 0.5 + 8.0
	_draw_stat(Vector2(center.x - badge_x, badge_y), piece["a"], InkFigure.RED, alpha)
	_draw_stat(Vector2(center.x + badge_x, badge_y), piece["h"], InkFigure.INK, alpha)


## 数値。図版なので枠を持たせず、インクの文字として置く。
func _draw_stat(at: Vector2, amount: int, color: Color, alpha: float) -> void:
	_centered_text(at + Vector2(0, 5), str(amount), STAT_FONT_SIZE, Color(color, alpha))


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
	var custom_color: Variant = beam.get("color")
	var color: Color = (
		custom_color if custom_color != null else (BLOCKED_COLOR if blocked else InkFigure.RED)
	)
	var head: Vector2 = from.lerp(to, progress)
	draw_line(from, head, Color(color, 0.9), 3.0)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * 5.0
	draw_colored_polygon(
		PackedVector2Array([head + dir * 8.0, head - side, head + side]), Color(color, 0.95)
	)
	if blocked and progress >= 1.0:
		InkFigure.broken(self, to, 7.0)


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
	draw_rect(rect, InkFigure.PAPER)
	draw_rect(rect, InkFigure.INK, false, 1.5)


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
		InkFigure.INK
	)


## 実演が複数あるとき、いま何本目かを示す。
func _draw_dots(index: int) -> void:
	var count := _entries.size()
	var start := size.x - 10.0 - float(count) * 10.0
	for i in count:
		var at := Vector2(start + float(i) * 10.0, 12.0)
		draw_circle(at, 3.0, InkFigure.INK if i == index else Color(InkFigure.INK_SOFT, 0.5))
