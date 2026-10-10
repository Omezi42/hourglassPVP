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
	## 静止:ターン終了時に砂が落ちない(静止の刻)。
	STILL,
	## 砂が上へ戻る(攻撃力-n / 体力+n)。落砂の逆向き。
	FX_RAISE_SAND,
	## 条件付き破壊:攻撃力が体力より多い駒だけが砕け、若い駒には効かない。
	FX_DESTROY_AGED,
	## 墓地の砂時計の数だけ総量が増える(遺砂の刻)。
	FX_ADD_TOTAL_PER_GRAVE,
	## 墓地の砂時計1体を手札へ戻す。
	FX_RECOVER_FROM_GRAVE,
	## 墓地の砂時計1体を場に出す(蘇生)。
	FX_REVIVE_FROM_GRAVE,
	## 自分の砂時計1体を払う(砂葬)。相手を攻撃する台本では見せられないため分ける。
	FX_SACRIFICE,
	## 反転済みの味方が、同じターンにもう一度反転できるようになる(反響の刻)。
	FX_RESET_FLIP,
	## 反転権の残り回数が増える(反響の刻)。
	FX_GAIN_FLIP_RIGHT,
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
		CardEnums.Keyword.STILL:
			return Demo.STILL
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
		CardEnums.EffectType.RAISE_SAND:
			demo = Demo.FX_RAISE_SAND
		CardEnums.EffectType.ADD_TOTAL_PER_GRAVE:
			demo = Demo.FX_ADD_TOTAL_PER_GRAVE
		CardEnums.EffectType.RECOVER_FROM_GRAVE:
			demo = Demo.FX_RECOVER_FROM_GRAVE
		CardEnums.EffectType.REVIVE_FROM_GRAVE:
			demo = Demo.FX_REVIVE_FROM_GRAVE
		CardEnums.EffectType.RESET_FLIP:
			demo = Demo.FX_RESET_FLIP
		CardEnums.EffectType.GAIN_FLIP_RIGHT:
			demo = Demo.FX_GAIN_FLIP_RIGHT
	if demo == Demo.FX_DESTROY_UNIT and is_ally:
		demo = Demo.FX_SACRIFICE
	# 対象の絞り込み(攻撃力>体力)を持つ破壊は、効かない駒があることまで見せる。
	if (
		demo == Demo.FX_DESTROY_UNIT
		and effect.condition_scope == CardEnums.ConditionScope.ATTACK_OVER_HEALTH
	):
		demo = Demo.FX_DESTROY_AGED
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
		"self": effect.target == CardEnums.EffectTarget.SELF,
	}


# --- 台本 ---------------------------------------------------------------


## 台本と進捗(0.0〜1.0)から、その瞬間の盤面を組み立てる。
## 台本の中身は種類ごとのクラスが持ち、扱わない種類には空を返させて次のクラスへ回す
## (既定の盤面を返させると、台本が無いことに気づけないまま何かが動いて見える)。
func _stage(entry: Dictionary, t: float) -> Dictionary:
	var demo := int(entry["demo"])
	var value: int = entry.get("value", 1)
	var trigger: int = entry.get("trigger", CardEnums.Trigger.ON_PLAY)
	var stage: Dictionary
	if demo == Demo.FX_ADD_TOTAL:
		# 「反転:総量+1」(グロウ)だけが実際に反転を伴う。設置/落砂/余砂の総量+効果は
		# 反転しないため、台本の中で勝手に駒を裏返さない(トリガーで判定する)。
		stage = CardEffectDemoEffect.add_total(
			t, value, trigger == CardEnums.Trigger.ON_FLIP, entry.get("all", false)
		)
	elif (
		entry.get("ally", false)
		and (demo == Demo.FX_SWAP_STATS or demo == Demo.FX_DROP_SAND or demo == Demo.FX_RAISE_SAND)
	):
		# 味方を対象にする反転・砂落としは、相手への攻撃を挟まない
		# (`CardEffectDemoEffect.on_enemy_unit()` は「攻撃して当てる」演出であり、味方には使えない)。
		# 砂術は盤面に自分自身を持たないため「他の」を付けない(GameDesign.md 6章の
		# 自己除外は、効果を持つ砂時計自身を選べないという駒の制約であり砂術には無い)。
		stage = CardEffectDemoEffect.on_ally_unit(
			t, demo, value, entry.get("all", false), not entry.get("spell", false)
		)
	else:
		stage = CardEffectDemoEffect.stage(demo, t, value)
	if stage.is_empty():
		stage = CardEffectDemoKeyword.stage(demo, t)
	if stage.is_empty():
		stage = CardEffectDemoGrave.stage(demo, t, entry.get("self", false))
	if stage.is_empty():
		stage = CardEffectDemoEffect.on_enemy_unit(t, demo, value, entry.get("all", false))
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
		CardEnums.Trigger.ON_ALLY_DEATH:
			return "自分の他の砂時計が壊れたとき"
		CardEnums.Trigger.ON_ENEMY_FLIP:
			return "相手の砂時計が反転したとき"
	return "場に出したとき"


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
