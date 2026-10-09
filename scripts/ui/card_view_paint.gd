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

## 反転の予測の札(GameDesign.md 9章)。大きい数字=反転後 / 小さい数字=終了後。
const PILL_HEIGHT := 26.0
const PILL_PADDING := 5.0
const PILL_HEAD_FONT := 16
const PILL_TAIL_FONT := 11
## ターン終了で割れる駒のひび。絵の枠に対する比で置く(絵は枠より細い縦長のため内側へ寄せる)。
const CRACK_BOX := Vector2(0.55, 0.75)
const CRACK_BOX_DROP := 0.04
const CRACK_LIGHT := Color(1.0, 0.95, 0.9, 0.7)
const CRACK_PATHS := [
	[Vector2(0.55, 0.05), Vector2(0.45, 0.3), Vector2(0.58, 0.5), Vector2(0.48, 0.8)],
	[Vector2(0.45, 0.3), Vector2(0.25, 0.4)],
	[Vector2(0.58, 0.5), Vector2(0.78, 0.6)],
]


## 台座。空き枠でも常に描き、そこへ砂時計が立つ場所であることを示す。
## **上面の楕円+側面の帯を持つ、高さのある真鍮の器**として描く
## (GameDesign.md 9章「対局画面の再構築」)。光は上から受けるため、上面が明るく
## 側面は暗い。
static func pedestal_base(view: CardView) -> void:
	var ci := view.get_canvas_item()
	var top_center := Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y)
	var bottom_center := top_center + Vector2(0.0, CardView.PEDESTAL_HEIGHT)
	var radius := CardView.PEDESTAL_RADIUS
	# 接地の影(「光と影」の検証): 器の**足元**(下の楕円の位置)へ敷く。
	UiPaint.fill_ellipse(ci, bottom_center, radius * 1.12, Color(0.04, 0.03, 0.05, 0.35), 32)
	# 側面: 上面の楕円の下半分(左→右) + 下面の楕円の下半分(右→左)で帯を作る。
	var side_points := _pedestal_side_points(top_center, bottom_center, radius, 16)
	var side_rect := Rect2(
		top_center - Vector2(radius.x, 0.0),
		Vector2(radius.x * 2.0, CardView.PEDESTAL_HEIGHT + radius.y)
	)
	UiPaint.fill_gradient_polygon(
		ci,
		side_points,
		side_rect,
		[[0.0, UiPalette.BRASS_DARK], [1.0, UiPalette.BRASS_PRESSED_DARK]]
	)
	# 上面: 地の色 → 中央へ明るい楕円 → 暗い落ち込み。
	UiPaint.fill_ellipse(ci, top_center, radius, UiPalette.BRASS_MID, 32)
	UiPaint.fill_ellipse(ci, top_center, radius * 0.7, UiPalette.BRASS_LIGHT, 32)
	UiPaint.fill_ellipse(
		ci, top_center, radius * 0.46, Color(UiPalette.PEDESTAL_DEFAULT_ACCENT, 0.14), 32
	)
	# 上端側の縁(奥の弧)に光の当たりを1本引く。
	var highlight := PackedVector2Array()
	for i in 11:
		var t: float = float(i) / 10.0
		var angle: float = lerpf(-PI * 0.82, -PI * 0.18, t)
		highlight.append(top_center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	view.draw_polyline(highlight, Color(UiPalette.BRASS_HIGHLIGHT, 0.5), 1.5, true)
	# 駒が立っているときだけ、足元の影をもう一段濃く重ねる(既存の踏み込み表現)。
	if view.card != null:
		var shadow_base := radius * 0.85
		UiPaint.fill_ellipse(ci, bottom_center, shadow_base * 0.85, Color(0.0, 0.0, 0.0, 0.12), 24)
		UiPaint.fill_ellipse(ci, bottom_center, shadow_base * 0.65, Color(0.0, 0.0, 0.0, 0.16), 24)
		UiPaint.fill_ellipse(ci, bottom_center, shadow_base * 0.45, Color(0.0, 0.0, 0.0, 0.20), 24)


## 台座の側面の帯の点列(GameDesign.md 9章「対局画面の再構築」)。「下の楕円の
## 下半分の弧(左→右) + 上の楕円の下半分の弧(右→左)」の順につなぎ、閉じた帯にする。
static func _pedestal_side_points(
	top_center: Vector2, bottom_center: Vector2, radius: Vector2, segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = PI - t * PI
		points.append(bottom_center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = t * PI
		points.append(top_center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


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


## 「反転」ボタンにカーソルがある間、攻撃力・体力のバッジの真下へ1枚ずつ札を出す
## (GameDesign.md 9章)。大きい数字が反転後、小さい数字がこの手番の終わりに砂が落ちた後。
static func flip_preview(view: CardView, attack_anchor: Vector2, health_anchor: Vector2) -> void:
	var forecast := view.flip_preview
	var health_after: int = forecast["health_after"]
	_forecast_pill(view, attack_anchor, forecast["attack"], str(forecast["attack_after"]), false)
	var tail := "破壊" if health_after <= 0 else str(health_after)
	_forecast_pill(view, health_anchor, forecast["health"], tail, health_after <= 0)


static func _forecast_pill(
	view: CardView, anchor: Vector2, now: int, after: String, dead: bool
) -> void:
	var head := str(now)
	var tail := "›" + after
	var head_size := view._font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, PILL_HEAD_FONT)
	var tail_width := (
		view._font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, PILL_TAIL_FONT).x
	)
	var width := head_size.x + tail_width + PILL_PADDING * 2.0
	var center := anchor + Vector2(0, CardView.STAT_RADIUS + CardView.PREVIEW_GAP)
	var rect := Rect2(center - Vector2(width, PILL_HEIGHT) * 0.5, Vector2(width, PILL_HEIGHT))
	view.draw_rect(rect, Color(0.08, 0.07, 0.06, 0.95))
	view.draw_rect(rect, CardView.PREVIEW_ALIVE, false, 2.0)
	var baseline := center.y + head_size.y * 0.32
	var x := rect.position.x + PILL_PADDING
	view.draw_string(
		view._font,
		Vector2(x, baseline),
		head,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PILL_HEAD_FONT,
		CardView.PREVIEW_ALIVE
	)
	view.draw_string(
		view._font,
		Vector2(x + head_size.x, baseline),
		tail,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		PILL_TAIL_FONT,
		CardView.PREVIEW_DEAD if dead else CardView.SAND_AMBER
	)


## 「ターン終了」で割れる駒のひび。HPの器のひびと同じ描き方(暗い筋 + 明るい筋)。
static func crack(view: CardView) -> void:
	var art := view.board_art_box()
	var box := Rect2(
		art.get_center() - art.size * CRACK_BOX * 0.5 + Vector2(0, art.size.y * CRACK_BOX_DROP),
		art.size * CRACK_BOX
	)
	for path in CRACK_PATHS:
		var points := PackedVector2Array()
		var lit := PackedVector2Array()
		for p in path:
			var point := box.position + box.size * (p as Vector2)
			points.append(point)
			lit.append(point + Vector2(1.0, 0.0))
		view.draw_polyline(points, HpVesselFx.CRACK_DARK, 2.0, true)
		view.draw_polyline(lit, CRACK_LIGHT, 1.0, true)


## 空き枠の点線。
static func dashed_rect(view: CardView, rect: Rect2, color: Color) -> void:
	var x := rect.position.x
	while x < rect.end.x:
		var to := minf(x + 5, rect.end.x)
		view.draw_line(Vector2(x, rect.position.y), Vector2(to, rect.position.y), color, 2.0)
		view.draw_line(Vector2(x, rect.end.y), Vector2(to, rect.end.y), color, 2.0)
		x += 10.0
	var y := rect.position.y
	while y < rect.end.y:
		var to := minf(y + 5, rect.end.y)
		view.draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, to), color, 2.0)
		view.draw_line(Vector2(rect.end.x, y), Vector2(rect.end.x, to), color, 2.0)
		y += 10.0


## 名前の下の1行。**語として見せるキーワードだけを語で出し**、それ以外は短い言い換えで
## 書く(GameDesign.md 6章)。1行しか無いので、全文は詳細パネルに任せる。
static func keyword_text(view: CardView) -> String:
	var words: PackedStringArray = []
	if view.card != null and view.card.cannot_attack:
		words.append("攻撃不可")
	if view.card != null and view.card.cannot_flip:
		words.append("反転不可")
	# 場に出ている駒は**その駒がいま持っている**キーワードを出す。CardData を直接見ると、
	# 効果で与えられたキーワードと、消された状態が面に出ない。
	for keyword in _live_keywords(view):
		if CardEnums.is_named(keyword):
			words.append(CardEnums.keyword_name(keyword))
		else:
			words.append(CardEnums.keyword_short_text(keyword))
	if view.unit != null and view.unit.silenced:
		return "効果なし" if words.is_empty() else " ".join(words)
	if words.is_empty() and not view.card.rules_text.is_empty():
		return view.card.category_name()
	return " ".join(words)


## いま持っているキーワード。手札のカードは定義そのまま、場の駒は付与・消去を反映する。
static func _live_keywords(view: CardView) -> Array:
	if view.unit != null:
		return view.unit.keywords()
	var found: Array = []
	for keyword in view.card.named_keywords():
		found.append(keyword)
	for keyword in view.card.plain_keywords():
		found.append(keyword)
	return found
