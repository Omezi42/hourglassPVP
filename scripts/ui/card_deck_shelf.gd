class_name CardDeckShelf
extends Control
## 編成中のデッキを**30枠の決まった棚**として描く(GameDesign.md 9章)。
##
## **枠の形が先にあり、そこへ砂時計をセットしていく。**コスト帯ごとに段の長さが変わる
## 形は、1枚動かすたびに棚そのものが組み変わり、駒の大きさまで段の詰まり方で変わっていた。
## 30枠を固定にすると次の3つが同時に片付く。
##
## - **空いている枠がそのまま「あと何枚」になる**(別に帯を出す必要が無い)
## - **1枠=1枚なので「−」「+」が要らない**(枠を押せばその1枚が戻る)
## - **駒の大きさが常に同じ**になる
##
## **1つの `Control` が全枠を `_draw()` で描き、当たり判定を矩形の表として持つ。**
## 30個のノードを並べると、枚数を1枚動かすたびに生成と破棄が走る。
##
## **共有用のデッキ表(`CardDeckSheet`)も、横の枠数だけ変えてこれを使う。**
## 画面で見た形と貼られた画像が一致していることを優先する(GameDesign.md 9章)ため、
## 共有のためだけに似た並べ方をもう1つ書かない。

## カーソルが乗っている1枠。詳細パネルを出すために画面側が拾う。
signal card_hovered(card: CardData)
signal hover_left
signal card_removed(card: CardData)

## 既定の横の枠数(工房)。縦は「デッキの枚数 ÷ これ」で決まる(30枚なら5段)。
const DEFAULT_COLUMNS := 6
## 棚板の厚みと、その下へ置く名前の取り分。
const LEDGE_HEIGHT := 7.0
const NAME_BAND := 17.0
## 絵の縦横比(砂時計の絵は 1 : 1.30)。
const ART_RATIO := 1.30

const COST_TOP := Color(0.46, 0.70, 0.98)
const COST_BOTTOM := Color(0.11, 0.24, 0.52)
const TOTAL_TOP := Color(1.0, 0.84, 0.46)
const TOTAL_BOTTOM := Color(0.72, 0.44, 0.12)
const SPELL_TOP := Color(0.72, 0.80, 1.0)
const SPELL_BOTTOM := Color(0.28, 0.36, 0.68)
const NAME_COLOR := Color(0.88, 0.82, 0.70)
const SOCKET_DARK := Color(0.045, 0.030, 0.020)
const BACK_TOP := Color(0.10, 0.068, 0.048)
const BACK_BOTTOM := Color(0.16, 0.105, 0.072)

## 表示するデッキ(CardData の配列。同名は重複して入る)。
var deck: Array = []:
	set(value):
		deck = value
		_rebuild()

## 横の枠数。共有用のデッキ表は横長にしたいため10を渡す。
var columns := DEFAULT_COLUMNS:
	set(value):
		columns = maxi(value, 1)
		queue_redraw()
## 読むだけの棚(共有用のデッキ表)。ホバーも押下も受けない。
var readonly := false:
	set(value):
		readonly = value
		mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP

var _font: Font
## 枠に収まった順。**1枠=1枚**なので、2枚積みは隣り合う2枠を占める。
var _slots: Array = []
## 押せる場所。1要素 = {"rect":, "index":}
var _hits: Array[Dictionary] = []
var _hover_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if readonly else Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _notification(what: int) -> void:
	# **大きさが決まったら描き直す。**枠の大きさは自分の `size` から決めるため、
	# レイアウトの確定を受け取らないと最初に描いた小さい高さのまま残る。
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
		return
	if what == NOTIFICATION_MOUSE_EXIT and _hover_index >= 0:
		_hover_index = -1
		hover_left.emit()
		queue_redraw()


func _rebuild() -> void:
	# 並びはカードを並べるすべての画面と同じにする(GameDesign.md 9章)。
	_slots = deck.duplicate()
	_slots.sort_custom(CardLibrary.compare_by_cost)
	_hover_index = -1
	queue_redraw()


## 枠の総数。**デッキの枚数に追従させる**(2章の枚数を動かしても棚が食い違わない)。
static func _slot_count() -> int:
	return MatchState.DECK_SIZE


func _rows() -> int:
	return int(ceil(float(_slot_count()) / float(columns)))


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

	var rows := _rows()
	var cell := Vector2(size.x / float(columns), size.y / float(rows))
	# **横で頭打ちになったら高さも一緒に詰める。**幅だけを切り詰めると絵が縦へ伸びる
	# (共有用の横長の表で実際にそうなった)。縦横比は必ず保つ。
	var art_w: float = minf((cell.y - LEDGE_HEIGHT - NAME_BAND - 4.0) / ART_RATIO, cell.x - 12.0)
	var art_h: float = art_w * ART_RATIO
	for row in rows:
		_draw_ledge(row, cell)
	for index in _slot_count():
		_draw_slot(index, cell, Vector2(art_w, art_h))
	if _slots.is_empty():
		_draw_hint()


## 棚板。**厚みのある帯として段ごとに渡す**。1本線だと段が分かれて見えず、
## 30枠が1枚の面へ貼り付いているように読める。
func _draw_ledge(row: int, cell: Vector2) -> void:
	var y: float = (row + 1) * cell.y - NAME_BAND - LEDGE_HEIGHT
	var ledge := Rect2(6.0, y, size.x - 12.0, LEDGE_HEIGHT)
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


func _draw_slot(index: int, cell: Vector2, art: Vector2) -> void:
	var col: int = index % columns
	var row: int = index / columns
	var base := Vector2((col + 0.5) * cell.x, (row + 1) * cell.y - NAME_BAND - LEDGE_HEIGHT)
	var hit := Rect2(Vector2(col * cell.x, row * cell.y), cell)
	_hits.append({"rect": hit, "index": index})
	if index >= _slots.size():
		_draw_socket(base, art.x)
		return

	var card: CardData = _slots[index]
	if index == _hover_index:
		_draw_hover_glow(base, art.x)
	UiPaint.fill_ellipse(
		get_canvas_item(), base, Vector2(art.x * 0.40, 5.0), Color(0, 0, 0, 0.5), 20
	)
	var art_rect := Rect2(base - Vector2(art.x * 0.5, art.y - 2.0), art)
	if card.is_spell:
		_draw_spell_plate(art_rect, card)
	else:
		var icon := card.icon_upright
		if icon != null:
			draw_texture_rect(icon, art_rect, false)
	var badge_r: float = clampf(art.x * 0.20, 8.0, 13.0)
	_draw_diamond(art_rect.position + Vector2(badge_r * 0.4, badge_r), card.cost, badge_r)
	_draw_total(Vector2(art_rect.end.x - badge_r * 0.4, art_rect.end.y - badge_r), card, badge_r)
	# **紋章は絵の左下へ印として押す**(手札の封蝋と同じ置き場。GameDesign.md 9章)。
	EmblemSeal.brass(
		self,
		Vector2(art_rect.position.x + badge_r * 0.6, art_rect.end.y - badge_r * 0.5),
		card.emblem,
		badge_r * 0.86
	)
	draw_string(
		_font,
		Vector2(col * cell.x, (row + 1) * cell.y - 4.0),
		card.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		cell.x,
		12,
		NAME_COLOR
	)


## 空いている枠。**棚に彫った受け皿**として描き、そこへ薄い砂時計の影を落とす。
## 何枚足りないかは、この空きの数がそのまま示す。
func _draw_socket(base: Vector2, art_w: float) -> void:
	UiPaint.fill_ellipse(get_canvas_item(), base, Vector2(art_w * 0.34, 5.5), SOCKET_DARK, 22)
	UiPaint.draw_ellipse_ring(
		get_canvas_item(), base, Vector2(art_w * 0.34, 5.5), Color(0.52, 0.42, 0.26, 0.35), 1.4, 22
	)
	var h: float = art_w * 0.80
	var half: float = art_w * 0.24
	var neck: float = art_w * 0.045
	var top: float = base.y - h
	var mid: float = base.y - h * 0.5
	var outline := PackedVector2Array(
		[
			Vector2(base.x - half, top),
			Vector2(base.x + half, top),
			Vector2(base.x + neck, mid),
			Vector2(base.x + half, base.y),
			Vector2(base.x - half, base.y),
			Vector2(base.x - neck, mid),
			Vector2(base.x - half, top),
		]
	)
	draw_polyline(outline, Color(0.48, 0.38, 0.24, 0.20), 1.6)


## デッキが1枚も無いときだけ、棚の中ほどへ1行を置く。**受け皿の上へ文字を直に
## 重ねない**——空の枠と同じ薄さで並ぶと、どちらも読み取りにくくなる。木札として置く。
func _draw_hint() -> void:
	var plate := Rect2(size.x * 0.5 - 190.0, size.y * 0.5 - 22.0, 380.0, 44.0)
	var points := UiPaint.rounded_rect_points_uniform(plate, 8.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		plate,
		[[0.0, Color(0.26, 0.175, 0.10)], [1.0, Color(0.13, 0.085, 0.05)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.58, 0.46, 0.30), 1.8)
	draw_string(
		_font,
		Vector2(plate.position.x, plate.get_center().y + 6.0),
		"左の在庫棚から選ぶと、ここへ収まります",
		HORIZONTAL_ALIGNMENT_CENTER,
		plate.size.x,
		16,
		Color(0.90, 0.82, 0.66)
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
		center - Vector2(20, -5),
		str(value),
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		int(r + 2),
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
		int(r + 1),
		Color(0.14, 0.08, 0.03)
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


## カーソルを乗せている1枠。**受け皿の輪を光らせるだけ**にして、絵そのものは覆わない。
func _draw_hover_glow(base: Vector2, art_w: float) -> void:
	for i in 3:
		var r := Vector2(art_w * (0.52 + 0.09 * i), art_w * (0.15 + 0.025 * i))
		UiPaint.draw_ellipse_ring(
			get_canvas_item(), base, r, Color(1.0, 0.88, 0.52, 0.55 - 0.15 * i), 2.0, 26
		)


func _gui_input(event: InputEvent) -> void:
	if readonly:
		return
	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)
		return
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	# **枠を押すとその1枚が在庫へ戻る。**1枠=1枚なので、増減のボタンは要らない。
	var index := _index_at(press.position)
	if index >= 0 and index < _slots.size():
		card_removed.emit(_slots[index])


func _update_hover(at: Vector2) -> void:
	var index := _index_at(at)
	if index >= _slots.size():
		index = -1
	if index == _hover_index:
		return
	_hover_index = index
	if index < 0:
		hover_left.emit()
	else:
		card_hovered.emit(_slots[index])
	queue_redraw()


func _index_at(at: Vector2) -> int:
	for hit in _hits:
		if (hit["rect"] as Rect2).has_point(at):
			return int(hit["index"])
	return -1
