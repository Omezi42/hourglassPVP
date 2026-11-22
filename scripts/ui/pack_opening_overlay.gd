class_name PackOpeningOverlay
extends Control
## パックの開封(GameDesign.md 21章「開封」)。**砂時計の動詞(返す・落ちる・止まる・巻き戻す)で組む。**
## 1. 封をした砂時計を押して返す → 2. 色の粒が混じって落ちる → 3. 割れて5枚の裏が配られる →
## 4. 押すと1枚ずつめくれる(エピックは浮いて震え、レジェンドは時を止めて巻き戻す)→
## 5. 札の下に「はじめて」/「所持 n / 上限」→ 6. 上限を超えた札は砂粒へ崩れて残高へ飛ぶ →
## 7. 「閉じる」と「つぎのパック(残り n)」。10パックは1パックずつ開ける。
##
## 抽選と保存は開く前に `PackService.open_packs()` が済ませている。ここは結果を見せるだけ。
## 座標は 1280x720 の舞台(`_stage`)で組み、画面の大きさに合わせて舞台ごと拡大する。

signal closed
## 押した(レジェンドの見せ場から列へ戻すのに使う)。
signal tapped

enum Phase { IDLE, VESSEL, TURNING, REVEAL, LEGEND, DONE }

const STAGE := Vector2(1280, 720)
const FIRST_TEXT := "はじめて"
const OVERFLOW_NOTE := "上限を超えたぶん"
const OWNED_FORMAT := "所持 %d / %d"
const DUST_FORMAT := "砂粒 +%d"
const VESSEL_AT := Vector2(640, 360)
const VESSEL_SCALE := 1.3
const ROW_TOP := 168.0
const ROW_GAP := 40.0
const TITLE_Y := 48.0
const REMAIN_Y := 80.0
const HINT_Y := 566.0
const BUTTON_Y := 610.0
const BUTTON_SIZE := Vector2(260, 58)
const BUTTON_GAP := 24.0
const CHIP_POS := Vector2(1060, 28)
const CHIP_SCALE := 1.25
const LEGEND_SCALE := 1.6
const EPIC_LIFT := 26.0
const EPIC_SHAKE := 4.0
## 段取りの秒数。
const APPEAR := 0.45
const FLIP := 0.55
const SETTLE := 0.2
const FALL := 1.25
const CRACK := 0.3
const SHATTER := 1.0
const DEAL := 0.45
const DEAL_STAGGER := 0.08
const TURN := 0.22
const HALF_FLIP := 0.12
const EPIC_CHARGE := 0.55
const CRUMBLE_DELAY := 0.3
const FLIGHT := 0.9
const SPECK_FROM := 0.25
const SPECK_TO := 0.9

var _stage: Control
var _vessel: Control
var _back_fx: PackOpeningFx
var _front_fx: PackOpeningFx
var _title: Label
var _remain: Label
var _hint: Label
var _chip: CurrencyChip
var _reveal_all: Button
var _close: Button
var _next: Button
var _slots: Array[PackCardSlot] = []
var _phase := Phase.IDLE
var _busy := false
var _pack: PackDefinition
var _packs: Array = []
var _index := 0
var _counts: Dictionary = {}
var _dust := 0
## 封をした砂時計の進み(0〜1)。`_shatter_at` は割れた時刻(`_front_fx.now()` の値。割れる前は負)。
var _appear := 0.0
var _flip := 0.0
var _settle := 0.0
var _fall := 0.0
var _crack := 0.0
var _shatter_at := -1.0
var _specks: Array = []
var _has_legend := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## `packs` は `PackService.open_packs()` の戻り値の "packs"。`counts_before` は開ける前の所持数(card_id → 枚数)。
func open(pack_id: String, packs: Array, counts_before: Dictionary, dust_before: int) -> void:
	_pack = PackDefinition.load_pack(pack_id)
	_packs = packs
	_counts = counts_before.duplicate()
	_dust = dust_before
	_chip.set_amount(_dust, false)
	_title.text = _pack.display_name if _pack != null else ""
	_layout()
	visible = true
	_show_pack(0)


func _layout() -> void:
	size = PortraitModal.screen_size()
	var zoom := minf(size.x / STAGE.x, size.y / STAGE.y)
	_stage.scale = Vector2.ONE * zoom
	_stage.position = (size - STAGE * zoom) * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.INK_950)
	UiKit.glow(get_canvas_item(), size * 0.5, size * 0.6, Color(UiPalette.INK_600, 0.5))


# ---- 1パックぶん -------------------------------------------------------------


func _show_pack(index: int) -> void:
	_index = index
	for slot in _slots:
		_stage.remove_child(slot)
		slot.queue_free()
	_slots.clear()
	_remain.text = "残り %dパック" % (_packs.size() - index - 1)
	_close.visible = false
	_next.visible = false
	_reveal_all.visible = false
	var entry: Dictionary = _packs[index]
	var ids: Array = entry.get("cards", [])
	var overflow: Array = entry.get("overflow", [])
	_specks.clear()
	_has_legend = false
	for i in ids.size():
		var card := CardLibrary.find_by_id(str(ids[i]))
		if card == null:
			continue
		var slot := PackCardSlot.new(card)
		slot.overflow = i < overflow.size() and bool(overflow[i])
		slot.caption = _caption_for(card, slot.overflow)
		slot.visible = false
		slot.pressed.connect(_on_slot_pressed)
		_stage.add_child(slot)
		_stage.move_child(slot, _back_fx.get_index())
		_slots.append(slot)
		if card.rarity != CardEnums.Rarity.COMMON:
			_specks.append([0.0, RarityPaint.color(card.rarity)])
		_has_legend = _has_legend or card.rarity == CardEnums.Rarity.LEGENDARY
	for i in _specks.size():
		_specks[i][0] = lerpf(SPECK_FROM, SPECK_TO, float(i + 1) / float(_specks.size() + 1))
	_appear = 0.0
	_flip = 0.0
	_settle = 0.0
	_fall = 1.0
	_crack = 0.0
	_shatter_at = -1.0
	_phase = Phase.VESSEL
	_hint.text = "押して返す"
	_hint.visible = false
	var tween := create_tween()
	(
		tween
		. tween_method(_set_vessel.bind("_appear"), 0.0, 1.0, APPEAR)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_callback(func() -> void: _hint.visible = true)


## めくったときに札の下へ出す文字。上限を超えたぶんは砂粒の数(GameDesign.md 21章)。
func _caption_for(card: CardData, overflow: bool) -> String:
	if overflow:
		return DUST_FORMAT % RarityTable.get_table().gain_of(card.rarity)
	var have := int(_counts.get(card.id, 0)) + 1
	_counts[card.id] = have
	return FIRST_TEXT if have == 1 else OWNED_FORMAT % [have, CardOwnership.cap(card)]


func _set_vessel(value: float, field: String) -> void:
	set(field, value)
	_vessel.queue_redraw()


## 2. 返して落とし、3. 割って配る。
func _turn_vessel() -> void:
	_phase = Phase.TURNING
	_hint.visible = false
	SoundBank.play(SoundBank.Sfx.FLIP)
	var tween := create_tween()
	(
		tween
		. tween_method(_set_vessel.bind("_flip"), 0.0, 1.0, FLIP)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_callback(func() -> void: _fall = 0.0)
	tween.tween_method(_set_vessel.bind("_settle"), 0.0, 1.0, SETTLE)
	tween.tween_method(_set_vessel.bind("_fall"), 0.0, 1.0, FALL)
	tween.tween_method(_set_vessel.bind("_crack"), 0.0, 1.0, CRACK)
	await tween.finished
	_shatter()
	await get_tree().create_timer(SHATTER * 0.35).timeout
	await _deal()
	_phase = Phase.REVEAL
	_hint.text = "押してめくる"
	_hint.visible = true
	_reveal_all.visible = true


func _shatter() -> void:
	SoundBank.play(SoundBank.Sfx.VESSEL_SHATTER)
	_shatter_at = _front_fx.now()
	var hue := UiPalette.RARITY_LEGEND if _has_legend else UiPalette.SAND_HI
	_front_fx.glow(
		VESSEL_AT, Vector2(460, 320), Color(hue.lerp(Color.WHITE, 0.5), 0.85), 0.05, 0.45
	)
	var colors: Array = [UiPalette.SAND_HI, UiPalette.SAND, UiPalette.SAND_DEEP]
	for speck in _specks:
		colors.append(speck[1])
	_front_fx.burst(VESSEL_AT + Vector2(0, 40), colors, 220, 620.0, 1.2, 300.0)
	_front_fx.shards(VESSEL_AT, UiPalette.GLASS_TINT, Vector2(60, 90))
	_vessel.queue_redraw()


func _row_position(i: int) -> Vector2:
	var width := PackCardSlot.CARD_SIZE.x * _slots.size() + ROW_GAP * (_slots.size() - 1)
	return Vector2((STAGE.x - width) * 0.5 + (PackCardSlot.CARD_SIZE.x + ROW_GAP) * i, ROW_TOP)


## 噴き出す砂の中から、裏の5枚が弧を描いて配られる。
func _deal() -> void:
	var from := VESSEL_AT - PackCardSlot.CARD_SIZE * 0.5
	var tween := create_tween().set_parallel(true)
	for i in _slots.size():
		var slot := _slots[i]
		slot.position = from
		slot.scale = Vector2.ONE * 0.4
		slot.rotation = -0.6
		slot.visible = true
		var to := _row_position(i)
		var delay := DEAL_STAGGER * i
		(
			tween
			. tween_method(
				func(p: float) -> void:
					var bend := from.lerp(to, 0.5) + Vector2(0, -120)
					slot.position = from.lerp(bend, p).lerp(bend.lerp(to, p), p)
					slot.rotation = lerpf(-0.6, 0.0, p),
				0.0,
				1.0,
				DEAL
			)
			. set_delay(delay)
			. set_ease(Tween.EASE_OUT)
			. set_trans(Tween.TRANS_CUBIC)
		)
		tween.tween_property(slot, "scale", Vector2.ONE, DEAL).set_delay(delay)
		tween.tween_property(slot, "lit", 1.0, DEAL).set_delay(delay + DEAL * 0.6)
	SoundBank.play(SoundBank.Sfx.PLACE)
	await tween.finished


# ---- めくる ------------------------------------------------------------------


func _on_slot_pressed(slot: PackCardSlot) -> void:
	if _phase == Phase.REVEAL and not _busy and not slot.revealed:
		_reveal(slot)
	else:
		_on_tap()


func _on_tap() -> void:
	match _phase:
		Phase.VESSEL:
			if _appear >= 1.0:
				_turn_vessel()
		Phase.REVEAL:
			if not _busy:
				var next := _next_hidden()
				if next != null:
					_reveal(next)
		Phase.LEGEND:
			tapped.emit()


func _next_hidden() -> PackCardSlot:
	for slot in _slots:
		if not slot.revealed:
			return slot
	return null


## 「すべてめくる」。残りを順にめくる(レジェンドの演出は省かない)。
func _reveal_rest() -> void:
	if _busy or _phase != Phase.REVEAL:
		return
	_reveal_all.visible = false
	var next := _next_hidden()
	while next != null:
		await _reveal(next)
		next = _next_hidden()


func _reveal(slot: PackCardSlot) -> void:
	_busy = true
	_hint.visible = false
	match slot.rarity:
		CardEnums.Rarity.LEGENDARY:
			await _reveal_legend(slot)
		CardEnums.Rarity.EPIC:
			await _charge_epic(slot)
			await _turn_and_flip(slot)
			_front_fx.shards(slot.card_center(), UiPalette.RARITY_EPIC, Vector2(30, 50), 24, 0.8)
		_:
			await _turn_and_flip(slot)
	await _settle_card(slot)
	_busy = false
	if _next_hidden() == null:
		_finish()
	elif _reveal_all.visible:
		_hint.visible = true


## めくる直前に裏の紋章の砂時計が返り、その色の砂粒が弾ける(レア以上は色の輪も)。
func _turn_and_flip(slot: PackCardSlot) -> void:
	var tween := create_tween()
	tween.tween_property(slot, "turn", PI, TURN).set_trans(Tween.TRANS_BACK)
	await tween.finished
	var hue := RarityPaint.color(slot.rarity)
	var colors := [hue, hue.lerp(Color.WHITE, 0.4), UiPalette.SAND_HI]
	_front_fx.burst(slot.card_center(), colors, 50, 260.0, 0.8, 200.0)
	if slot.rarity != CardEnums.Rarity.COMMON:
		_front_fx.ring(slot.card_center(), hue, 160.0, 0.6)
	await _flip_face(slot, slot.scale.y)


func _flip_face(slot: PackCardSlot, zoom: float) -> void:
	SoundBank.play(SoundBank.Sfx.FLIP)
	var tween := create_tween()
	tween.tween_property(slot, "scale:x", 0.0, HALF_FLIP).set_ease(Tween.EASE_IN)
	tween.tween_callback(slot.show_face)
	tween.tween_property(slot, "scale:x", zoom, HALF_FLIP).set_ease(Tween.EASE_OUT)
	await tween.finished


## エピック: 1枚だけ浮き上がって震え、後ろに紫の光が溜まる。
func _charge_epic(slot: PackCardSlot) -> void:
	var rest := slot.position
	_front_fx.glow(
		slot.card_center() + Vector2(0, -EPIC_LIFT),
		Vector2(170, 200),
		Color(UiPalette.RARITY_EPIC, 0.75),
		EPIC_CHARGE,
		EPIC_CHARGE + 0.5
	)
	var tween := create_tween()
	tween.tween_method(
		func(p: float) -> void:
			slot.position = (
				rest + Vector2(sin(p * 60.0) * EPIC_SHAKE * p, -EPIC_LIFT * minf(p * 3.0, 1.0))
			),
		0.0,
		1.0,
		EPIC_CHARGE
	)
	tween.tween_property(slot, "position", rest, HALF_FLIP)
	await tween.finished


## レジェンド: 時を止めてめくる。暗くなって中央へ上がる → 静止 → 巻き戻し → 閃光で表 → 押すと列へ戻る。
func _reveal_legend(slot: PackCardSlot) -> void:
	_phase = Phase.LEGEND
	var show_all := _reveal_all.visible
	_reveal_all.visible = false
	var rest := slot.position
	var index := slot.get_index()
	_stage.move_child(slot, _back_fx.get_index())
	var center := STAGE * 0.5 + Vector2(0, 20)
	_back_fx.start_legend(center)
	_front_fx.start_legend(center)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_back_fx, "dim", 1.0, PackOpeningFx.L_DIM)
	(
		tween
		. tween_property(slot, "position", center - PackCardSlot.CARD_SIZE * 0.5, 0.5)
		. set_delay(0.1)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(slot, "scale", Vector2.ONE * LEGEND_SCALE, 0.5).set_delay(0.1)
	await get_tree().create_timer(PackOpeningFx.L_STOP.x).timeout
	SoundBank.play(SoundBank.Sfx.SIG_FREEZE)
	await get_tree().create_timer(PackOpeningFx.L_REWIND.x - PackOpeningFx.L_STOP.x).timeout
	var rewind := create_tween()
	(
		rewind
		. tween_property(
			slot, "turn", -TAU * 2.0, PackOpeningFx.L_REWIND.y - PackOpeningFx.L_REWIND.x
		)
		. set_ease(Tween.EASE_IN)
	)
	await get_tree().create_timer(PackOpeningFx.L_FLASH - PackOpeningFx.L_REWIND.x).timeout
	slot.turn = 0.0
	await _flip_face(slot, LEGEND_SCALE)
	SoundBank.play(SoundBank.Sfx.RESULT_WIN)
	var gold := [UiPalette.RARITY_LEGEND, UiPalette.GOLD_HI, UiPalette.SAND_HI]
	_front_fx.burst(center, gold, 160, 520.0, 1.3, 120.0)
	_front_fx.ring(center, UiPalette.RARITY_LEGEND, 320.0, 0.9)
	await tapped
	var back := create_tween().set_parallel(true)
	back.tween_property(_back_fx, "dim", 0.0, 0.3)
	back.tween_property(slot, "position", rest, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	back.tween_property(slot, "scale", Vector2.ONE, 0.4)
	_back_fx.end_legend()
	_front_fx.end_legend()
	await back.finished
	_stage.move_child(slot, index)
	_reveal_all.visible = show_all
	_phase = Phase.REVEAL


## めくった後: 上限を超えた札は砂粒へ崩れて残高へ飛び、そうでなければ所持の札を出す。
func _settle_card(slot: PackCardSlot) -> void:
	if not slot.overflow:
		slot.show_caption = true
		return
	await get_tree().create_timer(CRUMBLE_DELAY).timeout
	var corner := slot.position + Vector2(PackCardSlot.CARD_SIZE.x, 0)
	var target := _chip.position + _chip.size * 0.5
	_front_fx.flight(corner, target, UiPalette.SAND_HI, FLIGHT)
	_front_fx.burst(corner, [UiPalette.SAND_HI, UiPalette.SAND], 30, 140.0, 0.6, 80.0)
	slot.fade_face()
	slot.show_caption = true
	await get_tree().create_timer(FLIGHT * 0.8).timeout
	_dust += RarityTable.get_table().gain_of(slot.rarity)
	_chip.set_amount(_dust)


func _finish() -> void:
	_phase = Phase.DONE
	_hint.visible = false
	_reveal_all.visible = false
	var left := _packs.size() - _index - 1
	_next.visible = left > 0
	_next.text = "つぎのパック(残り %d)" % left
	_close.visible = true
	var total := BUTTON_SIZE.x * (2 if left > 0 else 1) + (BUTTON_GAP if left > 0 else 0.0)
	_close.position = Vector2((STAGE.x - total) * 0.5, BUTTON_Y)
	_next.position = _close.position + Vector2(BUTTON_SIZE.x + BUTTON_GAP, 0)


# ---- 封をした砂時計の絵 -------------------------------------------------------


func _draw_vessel() -> void:
	var ci := _vessel.get_canvas_item()
	if _phase == Phase.IDLE:
		return
	if _shatter_at >= 0.0:
		_draw_flying_caps(ci, _front_fx.now() - _shatter_at)
		return
	var bob := Vector2(0, sin(_front_fx.now() * 2.4) * 4.0) * (1.0 - _flip)
	var tremble := (
		Vector2(sin(_front_fx.now() * 71.0), cos(_front_fx.now() * 57.0)) * (_crack * 6.0)
	)
	var center := VESSEL_AT + bob + tremble
	var foot := center + Vector2(0, PackVesselPaint.BULB * 0.55 * VESSEL_SCALE)
	UiKit.glow(ci, foot, Vector2(260, 120), Color(UiPalette.SAND, 0.18 * _appear))
	if _has_legend:
		UiKit.glow(
			ci,
			foot,
			Vector2(240, 170),
			Color(
				UiPalette.RARITY_LEGEND,
				0.5 * PackOpeningFx.seg(_fall, 0.4, 1.0) * float(_flip >= 1.0) + 0.3 * _crack
			)
		)
	var turn := PI * _flip if _fall >= 1.0 and _settle <= 0.0 else 0.0
	var xf := Transform2D(turn, Vector2.ONE * VESSEL_SCALE * maxf(_appear, 0.01), 0.0, center)
	var specks := _specks if _flip >= 1.0 else []
	PackVesselPaint.draw(ci, xf, _fall, _flip < 0.5, specks, 1.0, _settle)
	if _flip >= 1.0 and _fall > 0.0 and _fall < 1.0:
		_draw_stream(ci, xf)
	if _crack > 0.0:
		_draw_cracks(ci, xf)


## 首から落ちる砂の筋。積もる途中で、レア以上の粒が混じる時期はその色を混ぜる。
func _draw_stream(ci: RID, xf: Transform2D) -> void:
	var floor_d := PackVesselPaint.BULB - 6.0 - PackVesselPaint.SAND_AMOUNT * _fall
	ShapePaint.polyline(
		ci,
		PackedVector2Array([xf * Vector2.ZERO, xf * Vector2(0, floor_d)]),
		Color(UiPalette.SAND, 0.85),
		2.0,
		true
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 26:
		var ph := fposmod(_front_fx.now() * 2.2 + rng.randf(), 1.0)
		var tint := UiPalette.SAND_HI
		for speck in _specks:
			if absf(_fall - (float(speck[0]) - 0.06)) < 0.05 and i % 3 == 0:
				tint = speck[1]
		var at := xf * Vector2(rng.randf_range(-2.0, 2.0) * ph, floor_d * ph * ph)
		RenderingServer.canvas_item_add_rect(ci, Rect2(at, Vector2(3, 3)), tint)


func _draw_cracks(ci: RID, xf: Transform2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var hue := UiPalette.RARITY_LEGEND if _has_legend else UiPalette.GOLD_HI
	for i in 7:
		var sy := -1.0 if i % 2 == 0 else 1.0
		var bulb := PackVesselPaint.BULB
		var pt := Vector2(
			rng.randf_range(-PackVesselPaint.BULB_W * 0.6, PackVesselPaint.BULB_W * 0.6),
			sy * rng.randf_range(bulb * 0.3, bulb * 0.85)
		)
		var line := PackedVector2Array([xf * pt])
		for j in int(1 + _crack * 4):
			pt += Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18))
			line.append(xf * pt)
		if line.size() > 1:
			ShapePaint.polyline(ci, line, Color(hue.lerp(Color.WHITE, 0.6), 0.9), 1.6, true)


## 割れた後: 蓋が上下へ飛んで消える。
func _draw_flying_caps(ci: RID, age: float) -> void:
	if age > 1.0:
		return
	var k := 1.0 - age
	var lift := PackVesselPaint.BULB + PackVesselPaint.CAP_THICK
	for cap in [-1.0, 1.0]:
		var pos := (
			VESSEL_AT
			+ Vector2(
				cap * 60.0 * age, cap * lift * VESSEL_SCALE + cap * 260.0 * age + 400.0 * age * age
			)
		)
		PackVesselPaint.cap(
			ci, Transform2D(cap * 1.8 * age, Vector2.ONE * VESSEL_SCALE, 0.0, pos), k
		)


func _process(_delta: float) -> void:
	if visible and _phase in [Phase.VESSEL, Phase.TURNING]:
		_vessel.queue_redraw()


# ---- 組み立て ---------------------------------------------------------------


func _build() -> void:
	_stage = Control.new()
	_stage.size = STAGE
	_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.gui_input.connect(_on_stage_input)
	add_child(_stage)
	_vessel = Control.new()
	_vessel.size = STAGE
	_vessel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vessel.draw.connect(_draw_vessel)
	_stage.add_child(_vessel)
	_back_fx = PackOpeningFx.new()
	_back_fx.layer = PackOpeningFx.Layer.BACK
	_stage.add_child(_back_fx)
	_front_fx = PackOpeningFx.new()
	_front_fx.layer = PackOpeningFx.Layer.FRONT
	_stage.add_child(_front_fx)
	_title = _label(UiPalette.T_HEAD, UiPalette.IVORY, TITLE_Y)
	_remain = _label(UiPalette.T_SMALL, UiPalette.MUTED, REMAIN_Y)
	_hint = _label(UiPalette.T_BODY, UiPalette.MUTED, HINT_Y)
	_chip = CurrencyChip.new()
	_chip.dust = true
	_chip.scale_factor = CHIP_SCALE
	_chip.position = CHIP_POS
	_stage.add_child(_chip)
	_reveal_all = CodedButton.make_in_group("すべてめくる", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_reveal_all.position = Vector2((STAGE.x - BUTTON_SIZE.x) * 0.5, BUTTON_Y)
	_reveal_all.pressed.connect(_reveal_rest)
	_stage.add_child(_reveal_all)
	_close = CodedButton.make("閉じる", BUTTON_SIZE)
	_close.pressed.connect(_on_close)
	_stage.add_child(_close)
	_next = CodedButton.make_in_group("", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_next.pressed.connect(func() -> void: _show_pack(_index + 1))
	_stage.add_child(_next)
	for button in [_reveal_all, _close, _next]:
		button.visible = false
	PortraitModal.watch(self, _layout)


func _label(px: int, color: Color, center_y: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, center_y - px)
	label.size = Vector2(STAGE.x, px * 2)
	_stage.add_child(label)
	return label


func _on_stage_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_on_tap()


func _on_close() -> void:
	_phase = Phase.IDLE
	visible = false
	closed.emit()
