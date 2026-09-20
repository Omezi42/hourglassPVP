class_name CardViewPaint
extends RefCounted
## `CardView._draw()` から台座・封蝋・バッジ・予測の描画を移す受け皿
## (Architecture.md 10.10.1節)。`card_view.gd` が1000行の上限に達したため切り出した
## (Architecture.md 11章)。
##
## `UiPaint` と違って第1引数に `CardView`(= `CanvasItem`)を取る(`InkFigure` /
## `EmblemSeal` と同じ流儀)。紋章はテクスチャのため `draw_texture_rect()` を使う場面が
## 多く、`RenderingServer` 経由のRIDだけでは足りないため。**状態(`unit` / `card` /
## `selected` / `unselect_amount` / `counter_offset` / `spark_amount` 等)は
## `CardView` に残し、ここは描画だけを持つ。**


## 台座。空き枠でも常に描き、そこへ砂時計が立つ場所であることを示す。
static func pedestal_base(view: CardView) -> void:
	var ci := view.get_canvas_item()
	var center := Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)
	UiPaint.fill_ellipse(
		ci, center, CardView.PEDESTAL_RADIUS * 1.12, Color(0.04, 0.03, 0.05, 0.3), 32
	)
	UiPaint.fill_ellipse(ci, center, CardView.PEDESTAL_RADIUS, Color(0.24, 0.19, 0.18, 0.45), 32)
	UiPaint.fill_ellipse(
		ci,
		center,
		CardView.PEDESTAL_RADIUS * 0.66,
		Color(UiPalette.PEDESTAL_DEFAULT_ACCENT, 0.14),
		32
	)
	# 接地の影(「光と影」の検証): 駒が台座に立っていることを示す。輪(pedestal_ring)
	# より前に描き、既存の台座の塗りの上へ重ねる。
	if view.card != null:
		var shadow_base := CardView.PEDESTAL_RADIUS * 0.85
		UiPaint.fill_ellipse(ci, center, shadow_base * 0.85, Color(0.0, 0.0, 0.0, 0.10), 24)
		UiPaint.fill_ellipse(ci, center, shadow_base * 0.65, Color(0.0, 0.0, 0.0, 0.14), 24)
		UiPaint.fill_ellipse(ci, center, shadow_base * 0.45, Color(0.0, 0.0, 0.0, 0.18), 24)


## 台座の輪。守護は太い真鍮にする(GameDesign.md 9章)。**取り消しの戻る動き**
## (同章「対局画面の手触り」)は、`selected` が既に false へ戻った後も
## `unselect_amount` が残っているあいだ、縮んで消えていく輪として描く。
static func pedestal_ring(view: CardView) -> void:
	var center := Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)
	var guard: bool = view._has_live_keyword(CardEnums.Keyword.GUARD)
	var color := UiPalette.BRASS_MID
	var width := CardView.PEDESTAL_RING_WIDTH
	var radius := CardView.PEDESTAL_RADIUS
	if view.selected:
		color = CardView.SELECT_CYAN
		width = CardView.PEDESTAL_GUARD_RING_WIDTH
	elif guard:
		color = UiPalette.BRASS_HIGHLIGHT
		width = CardView.PEDESTAL_GUARD_RING_WIDTH
	elif view.card == null:
		color = Color(UiPalette.BRASS_MID, 0.6)
	if not view.selected and view.unselect_amount > 0.01:
		color = Color(CardView.SELECT_CYAN, view.unselect_amount)
		width = CardView.PEDESTAL_GUARD_RING_WIDTH
		radius = CardView.PEDESTAL_RADIUS.lerp(
			CardView.PEDESTAL_RADIUS * CardView.UNSELECT_SHRINK, 1.0 - view.unselect_amount
		)
	# 身構え(GameDesign.md 9章「対局画面の手触り」): 既存の選択の輪郭色そのままに、
	# 濃さだけをゆっくり脈打たせる。新しい輪は描かない。
	if view.brace:
		var pulse := (sin(view._brace_pulse) + 1.0) * 0.5
		color = Color(color, lerpf(CardView.BRACE_PULSE_MIN, CardView.BRACE_PULSE_MAX, pulse))
	UiPaint.draw_ellipse_ring(view.get_canvas_item(), center, radius, color, width, 40)


static func pedestal_glow(view: CardView, color: Color) -> void:
	UiPaint.fill_ellipse(
		view.get_canvas_item(),
		Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y),
		CardView.PEDESTAL_RADIUS * 0.9,
		color,
		32
	)


## 台座の正面に彫り込んだ銘板。ここだけは濃く出し、近づいたときに
## 「この駒が何者か」を確定できるようにする。
static func pedestal_plaque(view: CardView, tint: Color) -> void:
	if view.card == null or view.card.emblem == null:
		return
	var ci := view.get_canvas_item()
	# 相打ちの反撃中は counter_offset ぶんだけ攻撃側へ突き出す(GameDesign.md 9章)。
	var center := Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - 4.0) + view.counter_offset
	UiPaint.fill_circle(
		ci, center, CardView.EMBLEM_PLAQUE_RADIUS, Color(0.08, 0.06, 0.05, 0.85), 24
	)
	UiPaint.fill_circle(
		ci, center, CardView.EMBLEM_PLAQUE_RADIUS - 1.5, UiPalette.BRASS_MID * tint, 24
	)
	var half := Vector2(CardView.EMBLEM_PLAQUE_SIDE, CardView.EMBLEM_PLAQUE_SIDE) * 0.5
	# 影を1pxずらして重ね、真鍮へ彫り込まれたように見せる。
	view.draw_texture_rect(
		view.card.emblem,
		Rect2(center - half + Vector2(0.0, 1.0), half * 2.0),
		false,
		Color(0.08, 0.06, 0.04, 0.7)
	)
	view.draw_texture_rect(
		view.card.emblem,
		Rect2(center - half, half * 2.0),
		false,
		Color(UiPalette.BRASS_HIGHLIGHT, 0.95) * tint
	)
	UiPaint.draw_ring(
		ci, center, CardView.EMBLEM_PLAQUE_RADIUS, UiPalette.BRASS_HIGHLIGHT * tint, 1.0, 24
	)
	if view.spark_amount > 0.01:
		var radius := (
			CardView.EMBLEM_PLAQUE_RADIUS + CardView.SPARK_RADIUS * (1.0 - view.spark_amount)
		)
		UiPaint.draw_ring(
			ci, center, radius, Color(1.0, 0.92, 0.6, 0.7 * view.spark_amount), 2.0, 28
		)


## 封蝋の印。手札は紙の札であるため、台座の銘板ではなく蝋で押した印として出す。
static func hand_seal(view: CardView, tint: Color) -> void:
	if view.card.emblem == null or view.card.is_spell:
		return
	var ci := view.get_canvas_item()
	var scale: float = view._hand_scale()
	var radius := CardView.HAND_SEAL_RADIUS * scale
	var center := Vector2(radius + 4.0 * scale, view.size.y - radius - 4.0 * scale)
	UiPaint.fill_circle(ci, center, radius + 1.0, Color(0.08, 0.05, 0.04, 0.8), 24)
	UiPaint.fill_circle(ci, center, radius, UiPalette.BRASS_MID * tint, 24)
	var half := Vector2(CardView.HAND_SEAL_SIDE, CardView.HAND_SEAL_SIDE) * 0.5 * scale
	view.draw_texture_rect(
		view.card.emblem,
		Rect2(center - half + Vector2(0.0, 1.0), half * 2.0),
		false,
		Color(0.08, 0.05, 0.03, 0.7)
	)
	view.draw_texture_rect(
		view.card.emblem, Rect2(center - half, half * 2.0), false, UiPalette.BRASS_HIGHLIGHT * tint
	)


## 右上の小さな添え字(デッキ編集の「2/2」など)。
static func badge(view: CardView, rect: Rect2) -> void:
	var width := view._font.get_string_size(view.badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
	var chip := Rect2(rect.size.x - width - 5, 5, width, 22)
	view.draw_rect(chip, Color(0.08, 0.07, 0.06, 0.92))
	view.draw_rect(chip, UiPalette.BRASS_HIGHLIGHT, false, 1.0)
	view.draw_string(
		view._font,
		chip.position + Vector2(6, 17),
		view.badge,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		UiPalette.BRASS_HIGHLIGHT
	)


## コスト/総量/攻撃力/体力のバッジ。**バッジの跳ね**(GameDesign.md 9章「対局画面の
## 手触り」)は `radius` に呼び出し側が `stat_punch` ぶんの拡縮を掛けて渡す形にし、
## ここでは大きさをそのまま使うだけにする(円の太さ・文字のサイズも半径に連動するため、
## 自然に一緒に跳ねる)。
static func stat(view: CardView, center: Vector2, value: int, color: Color, radius: float) -> void:
	view.draw_circle(center, radius, Color(0.08, 0.07, 0.06, 0.95))
	view.draw_arc(center, radius, 0.0, TAU, 24, color, 2.5 * radius / CardView.STAT_RADIUS)
	var text := str(value)
	var font_size := maxi(CardView.MIN_FONT_SIZE, roundi(20.0 * radius / CardView.STAT_RADIUS))
	var width := view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	view.draw_string(
		view._font,
		center + Vector2(-width * 0.5, font_size * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


## 「この攻撃の後どうなるか」を体力バッジの真下へ出す。相打ちのため攻撃側にも出る。
static func preview(view: CardView, anchor: Vector2) -> void:
	if view.preview_health < 0:
		return
	var color := CardView.PREVIEW_DEAD if view.preview_dead else CardView.PREVIEW_ALIVE
	var center := anchor + Vector2(0, CardView.STAT_RADIUS + CardView.PREVIEW_GAP)
	view.draw_circle(center, CardView.PREVIEW_RADIUS, Color(0.08, 0.07, 0.06, 0.95))
	view.draw_arc(center, CardView.PREVIEW_RADIUS, 0.0, TAU, 20, color, 2.0)
	var text := "破壊" if view.preview_dead else str(view.preview_health)
	var font_size := 12 if view.preview_dead else 15
	var text_size := view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	view.draw_string(
		view._font,
		center + Vector2(-text_size.x * 0.5, text_size.y * 0.32),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
