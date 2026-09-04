class_name CardDeckShelf
extends Control
## 編成中のデッキを**コスト帯ごとの段**として描く(GameDesign.md 9章)。
##
## **段そのものがコスト帯であり、段の長さがそのままマナカーブになる。**1本ずつコストの
## バッジを付ける形は、30本を等間隔に詰め込んだ小ささでは数字が読めない。段で分ければ
## 左端に1つ大きく出すだけで全部のコストが読め、別に棒グラフを持つ必要も無くなる。
##
## **1つの `Control` が全段を `_draw()` で描き、当たり判定を矩形の表として持つ。**
## 30本ぶんのノードを並べると、枚数を1枚動かすたびに生成と破棄が走るうえ、
## 段の高さ・駒の大きさが段ごとに決まるためレイアウトをコンテナへ任せられない。

## カーソルが乗っている1本。詳細パネルを出すために画面側が拾う。
signal card_hovered(card: CardData)
signal hover_left
signal card_added(card: CardData)
signal card_removed(card: CardData)

## 段の高さの下限。これを下回るとスクロールへ切り替える(GameDesign.md 9章)。
const MIN_ROW_HEIGHT := 98.0
## 駒の下に取る名前の帯と、棚板・余白を合わせた1行あたりの取り分。
const NAME_BAND := 18.0
const ROW_CHROME := 40.0
## 左端のコスト見出しに使う幅。
const LABEL_WIDTH := 62.0
## カーソルを乗せた駒の下へ出す「−」「+」。
const STEP_BUTTON := Vector2(30, 26)
const STEP_GAP := 6.0
## ホイール1段ぶんのスクロール量。
const WHEEL_STEP := 48.0

const COST_TOP := Color(0.46, 0.70, 0.98)
const COST_BOTTOM := Color(0.11, 0.24, 0.52)
const TOTAL_TOP := Color(1.0, 0.84, 0.46)
const TOTAL_BOTTOM := Color(0.72, 0.44, 0.12)
const SPELL_TOP := Color(0.72, 0.80, 1.0)
const SPELL_BOTTOM := Color(0.28, 0.36, 0.68)
const NAME_COLOR := Color(0.86, 0.80, 0.68)
const BACK_TOP := Color(0.10, 0.068, 0.048)
const BACK_BOTTOM := Color(0.16, 0.105, 0.072)

## 表示するデッキ(CardData の配列。同名は重複して入る)。
var deck: Array = []:
	set(value):
		deck = value
		_rebuild()

var _font: Font
## 縦のスクロール量。**`ScrollContainer` へ入れずに自前で持つ**——あちらの中では
## 自分の `size.y` が中身の高さそのものになり、「1画面に何段入るか」を知れない。
## 外から見える高さを渡す形も試したが、レイアウトの確定より前に段が組まれて
## 高さ0のまま下限で並び、棚が画面の半分しか使わなかった。
var _scroll := 0.0
## コスト順に並べた段。1要素 = {"cost":, "ids":, "cards":, "counts":, "total":}
var _lanes: Array[Dictionary] = []
## 押せる場所。1要素 = {"rect":, "card":, "kind":}(kind は "piece" / "minus" / "plus")
var _hits: Array[Dictionary] = []
var _hover_id := ""
var _art_size := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _notification(what: int) -> void:
	# **大きさが決まったら描き直す。**段の高さは自分の `size.y` から決めるため、
	# レイアウトの確定を受け取らないと、最初に描いたときの小さい高さのまま残る
	# (実際、棚が画面の上半分しか使わなかった)。
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		return
	if what == NOTIFICATION_MOUSE_EXIT and not _hover_id.is_empty():
		_hover_id = ""
		hover_left.emit()
		queue_redraw()


func _rebuild() -> void:
	_lanes = _group_by_cost(deck)
	_hover_id = ""
	_scroll = 0.0
	queue_redraw()


## **同名2枚は1本にまとめる**(GameDesign.md 9章)。素直に30本並べると、1つのコストへ
## 種類が集まった段に律速されて全段の駒が小さくなる。
static func _group_by_cost(cards: Array) -> Array[Dictionary]:
	var by_cost: Dictionary = {}
	for card in cards:
		if card == null:
			continue
		if not by_cost.has(card.cost):
			by_cost[card.cost] = {
				"cost": card.cost, "ids": [], "cards": {}, "counts": {}, "total": 0
			}
		var lane: Dictionary = by_cost[card.cost]
		if not lane["cards"].has(card.id):
			lane["ids"].append(card.id)
			lane["cards"][card.id] = card
			lane["counts"][card.id] = 0
		lane["counts"][card.id] += 1
		lane["total"] += 1
	var costs: Array = by_cost.keys()
	costs.sort()
	var lanes: Array[Dictionary] = []
	for cost in costs:
		# 段の中はカードを並べるすべての画面と同じ順にする(GameDesign.md 9章)。
		var lane: Dictionary = by_cost[cost]
		var sorted: Array = []
		for id in lane["ids"]:
			sorted.append(lane["cards"][id])
		sorted.sort_custom(CardLibrary.compare_by_cost)
		var ids: Array = []
		for card in sorted:
			ids.append(card.id)
		lane["ids"] = ids
		lanes.append(lane)
	return lanes


func _draw() -> void:
	_hits.clear()
	var rect := Rect2(Vector2.ZERO, size)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(rect, 8.0, 6),
		rect,
		[[0.0, BACK_TOP], [1.0, BACK_BOTTOM]]
	)
	UiPaint.draw_inner_shadow(get_canvas_item(), rect, 8.0, 8, 7, Color(0, 0, 0), 0.7)
	if _lanes.is_empty():
		_draw_empty(rect)
		return

	# **段の高さには下限を置き、下回ったらスクロールする**(GameDesign.md 9章)。
	# コストが7段までばらけると、等分した高さでは駒が潰れて砂の量すら読めない。
	var rows := _lanes.size()
	var row_h: float = maxf(size.y / float(rows), MIN_ROW_HEIGHT)
	var content_h := row_h * float(rows)
	var scrolls := content_h > size.y + 0.5
	_scroll = clampf(_scroll, 0.0, maxf(content_h - size.y, 0.0))
	var lane_width := size.x - LABEL_WIDTH - (22.0 if scrolls else 10.0)
	# **縦の上限は全段そろえ、横だけ段ごとに詰める。**全段そろえる形にすると、
	# 種類が集まった1段が全体を道連れにして小さくする。
	var cap_h: float = (row_h - ROW_CHROME) / 1.30
	for i in rows:
		var top: float = i * row_h - _scroll
		# 画面の外の段は描かない(当たり判定も積まない)。
		if top > size.y or top + row_h < 0.0:
			continue
		_draw_lane(_lanes[i], Rect2(0.0, top, size.x, row_h), lane_width, cap_h)
	if scrolls:
		_draw_scrollbar(size.y / content_h, _scroll / maxf(content_h - size.y, 1.0))


## スクロールの目安。棚の右端へ細い真鍮の柱として通す。
func _draw_scrollbar(ratio: float, progress: float) -> void:
	var track := Rect2(size.x - 12.0, 8.0, 6.0, size.y - 16.0)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(track, 3.0, 4),
		track,
		[[0.0, Color(0.05, 0.04, 0.03)], [1.0, Color(0.11, 0.09, 0.07)]]
	)
	var knob_h: float = maxf(track.size.y * ratio, 24.0)
	var knob := Rect2(
		Vector2(track.position.x, track.position.y + (track.size.y - knob_h) * progress),
		Vector2(track.size.x, knob_h)
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(knob, 3.0, 4),
		knob,
		[[0.0, UiPalette.BRASS_HIGHLIGHT], [1.0, UiPalette.BRASS_DARK]]
	)


func _draw_empty(rect: Rect2) -> void:
	draw_string(
		_font,
		Vector2(rect.position.x, rect.get_center().y),
		"左の一覧から砂時計を選ぶと、ここへ並びます",
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		15,
		Color(0.62, 0.58, 0.50)
	)


func _draw_lane(lane: Dictionary, rect: Rect2, lane_width: float, cap_h: float) -> void:
	var ids: Array = lane["ids"]
	# **少ない段は左詰めにする。**幅いっぱいへ等分すると、3本しかない段が間延びして
	# 棚に並んでいるようには見えない。
	var step: float = minf(lane_width / float(ids.size()), cap_h + 16.0)
	var art_w: float = minf(step - 8.0, cap_h)
	var art_h: float = art_w * 1.30
	var base_y: float = rect.end.y - NAME_BAND - 12.0
	_draw_ledge(rect, base_y)
	_draw_cost_head(rect, lane, base_y)

	for j in ids.size():
		var card: CardData = lane["cards"][ids[j]]
		var count: int = lane["counts"][ids[j]]
		var cx: float = LABEL_WIDTH + (j + 0.5) * step
		var base := Vector2(cx, base_y)
		var art := Rect2(base - Vector2(art_w * 0.5, art_h - 2.0), Vector2(art_w, art_h))
		_hits.append({"rect": art, "card": card, "kind": "piece"})
		if card.id == _hover_id:
			_draw_hover_glow(base, art_w)
		UiPaint.fill_ellipse(
			get_canvas_item(), base, Vector2(art_w * 0.40, 5.0), Color(0, 0, 0, 0.5), 20
		)
		if card.is_spell:
			_draw_spell_plate(art, card)
		else:
			var icon := card.icon_upright
			if icon != null:
				draw_texture_rect(icon, art, false)
		# **コストは段が示すので、駒に付けるのは総量だけ。**枚数の印とは対角に置く
		# (隣り合わせると「×2 3」と続けて読めてしまう)。
		var badge_r: float = clampf(art_w * 0.21, 8.0, 14.0)
		_draw_total(Vector2(art.end.x - badge_r * 0.5, art.end.y - badge_r - 4.0), card, badge_r)
		if count >= 2:
			_draw_count(
				Vector2(art.position.x + badge_r, art.position.y + badge_r - 2.0), count, badge_r
			)
		draw_string(
			_font,
			Vector2(cx - step * 0.5, base.y + 26.0),
			card.display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			step,
			12 if step < 74.0 else 13,
			NAME_COLOR
		)
		if card.id == _hover_id:
			_draw_steps(base, art_h, count)


## 棚板。**厚みのある帯として渡す**。1本線だと段が分かれて見えず、
## 30本が1枚の面へ貼り付いているように読める。
func _draw_ledge(rect: Rect2, base_y: float) -> void:
	var ledge := Rect2(rect.position.x + LABEL_WIDTH - 8.0, base_y, rect.size.x - LABEL_WIDTH, 7)
	(
		UiPaint
		. fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points_uniform(ledge, 2.0, 3),
			ledge,
			[
				[0.0, UiPalette.BRASS_HIGHLIGHT],
				[0.45, UiPalette.BRASS_MID],
				[1.0, Color(0.16, 0.10, 0.06)],
			]
		)
	)
	for i in 5:
		draw_line(
			Vector2(ledge.position.x, ledge.end.y + i),
			Vector2(ledge.end.x, ledge.end.y + i),
			Color(0, 0, 0, 0.26 * (1.0 - float(i) / 5.0)),
			1.0
		)


## 段の見出し。コストを菱形で大きく置き、その下へ枚数を添える。
func _draw_cost_head(rect: Rect2, lane: Dictionary, base_y: float) -> void:
	var center := Vector2(rect.position.x + 26.0, base_y - 20.0)
	_draw_diamond(center, int(lane["cost"]), 19.0)
	draw_string(
		_font,
		Vector2(rect.position.x, base_y + 14.0),
		"%d枚" % int(lane["total"]),
		HORIZONTAL_ALIGNMENT_CENTER,
		52,
		14,
		Color(0.80, 0.74, 0.62)
	)


func _draw_diamond(center: Vector2, value: int, r: float) -> void:
	var points := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0),
		]
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, COST_TOP], [1.0, COST_BOTTOM]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.03, 0.06, 0.14), 2.0)
	draw_string(
		_font,
		center - Vector2(20, -6),
		str(value),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 3),
		Color.WHITE
	)


## 総量。**砂術は総量を持たないため「術」と出す**(空欄にすると総量0と見分けが付かない)。
func _draw_total(center: Vector2, card: CardData, r: float) -> void:
	var top: Color = SPELL_TOP if card.is_spell else TOTAL_TOP
	var bottom: Color = SPELL_BOTTOM if card.is_spell else TOTAL_BOTTOM
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.circle_points(center, r, 20),
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, top], [1.0, bottom]]
	)
	UiPaint.draw_ring(get_canvas_item(), center, r, Color(0.10, 0.06, 0.03), 1.8, 20)
	draw_string(
		_font,
		center - Vector2(20, -5),
		"術" if card.is_spell else str(card.total_sand),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 2),
		Color(0.14, 0.08, 0.03)
	)


## 2枚積みの印。**1枚のものには出さない**(「×1」は情報にならない)。
func _draw_count(center: Vector2, count: int, r: float) -> void:
	var scale: float = clampf(r / 13.0, 0.68, 1.0)
	var half := Vector2(17, 12) * scale
	var rect := Rect2(center - half, half * 2.0)
	var points := UiPaint.rounded_rect_points_uniform(rect, 6.0 * scale, 5)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.30, 0.22, 0.15)], [1.0, Color(0.13, 0.09, 0.06)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.72, 0.58, 0.36), 1.6)
	draw_string(
		_font,
		Vector2(rect.position.x, rect.get_center().y + 5.0 * scale),
		"×%d" % count,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		int(15.0 * scale),
		Color(0.96, 0.90, 0.76)
	)


## 砂術の札。**砂時計の絵を持たない**ため、紋章を中央へ大きく置く(GameDesign.md 9章)。
func _draw_spell_plate(p_rect: Rect2, card: CardData) -> void:
	# 札は矩形なので、砂時計の絵(周りに余白がある)と同じ寸法だと大きく見える。
	var rect := Rect2(p_rect.position + p_rect.size * 0.07, p_rect.size * 0.86)
	var points := UiPaint.rounded_rect_points_uniform(rect, 5.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.20, 0.26, 0.40)], [1.0, Color(0.08, 0.11, 0.20)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, CardView.SPELL_BORDER, 2.2)
	if card.emblem != null:
		var side: float = rect.size.x * 0.62
		draw_texture_rect(
			card.emblem,
			Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)),
			false,
			Color(0.82, 0.90, 1.0)
		)


## カーソルを乗せている1本。**台座の輪を光らせるだけ**にして、絵そのものは覆わない。
func _draw_hover_glow(base: Vector2, art_w: float) -> void:
	for i in 3:
		var r := Vector2(art_w * (0.52 + 0.09 * i), art_w * (0.15 + 0.025 * i))
		UiPaint.draw_ellipse_ring(
			get_canvas_item(), base, r, Color(1.0, 0.88, 0.52, 0.55 - 0.15 * i), 2.0, 26
		)


## 枚数の増減。**カーソルを乗せている駒の真下にだけ出す**(GameDesign.md 9章)。
## 全部の駒へ常時載せると、駒は最小で40px程度まで縮むため絵がボタンで埋まる。
func _draw_steps(base: Vector2, art_h: float, count: int) -> void:
	for entry in _step_rects(base, art_h):
		var rect: Rect2 = entry["rect"]
		var enabled: bool = count < 2 if entry["kind"] == "plus" else true
		_hits.append({"rect": rect, "card": null, "kind": entry["kind"]})
		var points := UiPaint.rounded_rect_points_uniform(rect, 5.0, 5)
		var stops := [
			[0.0, UiPalette.BRASS_LIGHT],
			[0.55, UiPalette.BRASS_MID],
			[1.0, UiPalette.BRASS_DARK],
		]
		UiPaint.fill_gradient_polygon(
			get_canvas_item(), points, rect, stops if enabled else UiPaint.dim_gradient_stops(stops)
		)
		UiPaint.draw_bevel(
			get_canvas_item(), points, UiPalette.BRASS_HIGHLIGHT, UiPalette.OUTLINE_DARK, 1.6, false
		)
		draw_string(
			_font,
			Vector2(rect.position.x, rect.get_center().y + 7.0),
			"−" if entry["kind"] == "minus" else "＋",
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			17,
			Color(0.98, 0.93, 0.80) if enabled else Color(0.55, 0.52, 0.48)
		)


## 「−」「+」の置き場。**駒の真下**(名前の帯へ重ねる)に横並びで置く。
static func _step_rects(base: Vector2, _art_h: float) -> Array[Dictionary]:
	var total := STEP_BUTTON.x * 2.0 + STEP_GAP
	var left := base.x - total * 0.5
	var top := base.y + 6.0
	return [
		{"rect": Rect2(Vector2(left, top), STEP_BUTTON), "kind": "minus"},
		{
			"rect": Rect2(Vector2(left + STEP_BUTTON.x + STEP_GAP, top), STEP_BUTTON),
			"kind": "plus",
		},
	]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return
	var press := event as InputEventMouseButton
	if press == null or not press.pressed:
		return
	if _handle_wheel(press.button_index):
		return
	if press.button_index == MOUSE_BUTTON_LEFT:
		_press_at(press.position)


func _handle_wheel(button: int) -> bool:
	if button == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll += WHEEL_STEP
	elif button == MOUSE_BUTTON_WHEEL_UP:
		_scroll = maxf(_scroll - WHEEL_STEP, 0.0)
	else:
		return false
	queue_redraw()
	return true


func _press_at(at: Vector2) -> void:
	var hit := _hit_at(at)
	if hit.is_empty():
		return
	var card := _hovered_card()
	if card == null:
		return
	if hit["kind"] == "minus":
		card_removed.emit(card)
	elif hit["kind"] == "plus":
		card_added.emit(card)


## **「−」「+」の領域もホバーの判定に含める**(GameDesign.md 9章)。
## 駒からボタンへカーソルを移す途中でホバーが切れると、永久に押せない。
func _update_hover(at: Vector2) -> void:
	var hit := _hit_at(at)
	if hit.is_empty():
		if not _hover_id.is_empty():
			_hover_id = ""
			hover_left.emit()
			queue_redraw()
		return
	if hit["kind"] != "piece":
		return
	var card: CardData = hit["card"]
	if card.id == _hover_id:
		return
	_hover_id = card.id
	card_hovered.emit(card)
	queue_redraw()


## 当たり判定。**「−」「+」を先に見る**——駒の矩形と重なる位置にあるため、
## 駒を先に見るとボタンを押せない。
func _hit_at(at: Vector2) -> Dictionary:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i]["rect"] as Rect2).has_point(at):
			return _hits[i]
	return {}


func _hovered_card() -> CardData:
	for lane in _lanes:
		if lane["cards"].has(_hover_id):
			return lane["cards"][_hover_id]
	return null
