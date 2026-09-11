class_name CardShopScreen
extends Control
## ショップ(GameDesign.md 21章、Architecture.md 10.8)。砂金を使う唯一の場所で、
## 売るのはアイコン・エモート・プレイマット・カードセット。共通のレイアウト規約
## (GameDesign.md 9章)に従い、`ScreenHeader` を使う。

signal back_pressed
## 買ったものはアカウント画面・ホームのヘッダーに効くため、購入のたびに通知する。
signal purchased

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT - 46)
## 品は横2列のグリッド(GameDesign.md 9章)。縦1列にすると1画面に数件しか入らない。
## **カードセットだけは1列**とする——対局の中身そのものを左右する特別な品であり
## (Architecture.md 10.8.1)、他の3種より詳しく見せたいため。
const COLUMNS := 2
const CARD_SIZE := Vector2(570, 100)
const GRID_SEPARATION := 14
const CARD_SET_SIZE := Vector2(570 * 2 + GRID_SEPARATION, 140)
const SECTION_SEPARATION := 22
const MESSAGE_TOP := ScreenHeader.CONTENT_TOP + ScreenHeader.CONTENT_HEIGHT - 34

## 品を並べる順とその見出し。`ShopCatalog.items()` はこの並びのまま返すため、
## 表示側はここで束ね直すだけでよい。
const SECTIONS: Array[Dictionary] = [
	{"kind": ShopCatalog.Kind.ICON, "heading": "アイコン"},
	{"kind": ShopCatalog.Kind.EMOTE, "heading": "エモート"},
	{"kind": ShopCatalog.Kind.PLAYMAT, "heading": "プレイマット"},
	{"kind": ShopCatalog.Kind.CARD_SET, "heading": "カードセット"},
]

var _list: VBoxContainer
var _balance: CurrencyChip
## 開いた直後は脈を出さない。買って減ったときも同じで、脈は増えたときだけ出る。
var _balance_seen := false
var _message: Label
var _confirm: ConfirmModal
var _preview: ShopSetPreview
var _busy := false
## 確認中の品。押した時点で控え、確定したときに買う。
var _pending: Dictionary = {}


func _ready() -> void:
	_build()


## 画面を開くたびにMainが呼ぶ。残高は購入で必ず動くため、開くたびに描き直す。
func open() -> void:
	_set_message("")
	_refresh()


func _refresh() -> void:
	_balance.set_amount(AccountService.currency(), _balance_seen)
	_balance_seen = true
	for child in _list.get_children():
		child.queue_free()
	var by_kind: Dictionary = {}
	for item in ShopCatalog.items():
		var kind: ShopCatalog.Kind = item["kind"]
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(str(item["id"]))
	for section in SECTIONS:
		var kind: ShopCatalog.Kind = section["kind"]
		var ids: Array = by_kind.get(kind, [])
		if ids.is_empty():
			continue
		_list.add_child(_build_section_header(str(section["heading"]), ids.size()))
		_list.add_child(_build_section_grid(kind, ids))


func _build_section_header(heading: String, count: int) -> Control:
	var header := ShopSectionHeader.new()
	header.label_text = heading
	header.item_count = count
	return header


func _build_section_grid(kind: ShopCatalog.Kind, ids: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 1 if kind == ShopCatalog.Kind.CARD_SET else COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for id in ids:
		var card := ShopItemCard.new(kind, str(id))
		card.owned = AccountService.owns(kind, str(id))
		card.affordable = AccountService.currency() >= ShopCatalog.price(kind, str(id))
		card.pressed.connect(func() -> void: _on_item_pressed(kind, str(id)))
		card.set_preview_requested.connect(func(set_id: String) -> void: _preview.open_set(set_id))
		grid.add_child(card)
	return grid


func _on_item_pressed(kind: ShopCatalog.Kind, id: String) -> void:
	if _busy or AccountService.owns(kind, id):
		return
	var cost := ShopCatalog.price(kind, id)
	if AccountService.currency() < cost:
		_set_message(
			(
				"%sが足りません(あと%s)。"
				% [
					CurrencyRules.CURRENCY_NAME,
					CurrencyRules.amount_text(cost - AccountService.currency())
				]
			)
		)
		return
	_pending = {"kind": kind, "id": id}
	_confirm.open_confirm(
		"購入の確認",
		(
			"%s「%s」を %s で購入します。"
			% [
				ShopCatalog.kind_name(kind),
				ShopCatalog.item_name(kind, id),
				CurrencyRules.label_text(cost)
			]
		),
		"購入する"
	)


func _on_confirmed() -> void:
	if _busy or _pending.is_empty():
		return
	_busy = true
	_set_message("購入しています…")
	var ok: bool = await NetSession.sign_in()
	var result: Dictionary
	if ok:
		var uid := NetSession.auth.uid if NetSession.auth != null else ""
		result = await AccountService.purchase(
			NetSession.client, uid, _pending["kind"], str(_pending["id"])
		)
	else:
		result = {"ok": false, "message": "接続できないため購入できません。"}
	_busy = false
	_pending = {}
	_set_message(str(result.get("message", "")))
	_refresh()
	if bool(result.get("ok", false)):
		purchased.emit()


func _set_message(text: String) -> void:
	_message.text = text


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.SHOP
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ショップ")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	# 残高はここでの購入で必ず動くため、ヘッダーの主アクションの位置へ常時出す
	# (GameDesign.md 21章)。押すものではないのでボタンにはしない。
	_balance = CurrencyChip.new()
	_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_action(_balance)

	var panel := PanelContainer.new()
	panel.position = LIST_RECT.position
	panel.custom_minimum_size = LIST_RECT.size
	panel.size = LIST_RECT.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	panel.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", SECTION_SEPARATION)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_message = Label.new()
	_message.position = Vector2(24, MESSAGE_TOP)
	_message.size = Vector2(1232, 28)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	add_child(_message)

	_confirm = load(CONFIRM_SCENE).instantiate()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func() -> void: _pending = {})

	_preview = ShopSetPreview.new()
	add_child(_preview)


## 品の区分ごとの見出し。**真鍮の細い罫線 + 見出し + 件数**の1行で、地の暗い
## パネルの上でも読める(GameDesign.md 9章のホーム画面の見出しプレートより軽い扱いに
## 留める——ここは一覧の区切りであり、押せる入口ではないため)。
class ShopSectionHeader:
	extends Control
	const HEIGHT := 34.0
	const RULE_Y_INSET := 11.0
	const RULE_LEAD := 22.0
	const RULE_GAP := 14.0

	var label_text := ""
	var item_count := 0
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_font = get_theme_default_font()
		if _font == null:
			_font = ThemeDB.fallback_font
		queue_redraw()

	func _draw() -> void:
		if _font == null:
			return
		var y := size.y - RULE_Y_INSET
		draw_line(Vector2(0.0, y), Vector2(RULE_LEAD, y), UiPalette.BRASS_HIGHLIGHT, 2.0, true)
		var label := "%s(%d)" % [label_text, item_count]
		var text_width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(
			_font,
			Vector2(RULE_LEAD + 10.0, y + 6.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			18,
			UiPalette.TEXT_OFFWHITE
		)
		var rule_start := RULE_LEAD + 10.0 + text_width + RULE_GAP
		if rule_start < size.x:
			draw_line(Vector2(rule_start, y), Vector2(size.x, y), UiPalette.BRASS_DARK, 1.0, true)


## 品1件。アイコンはその絵を、エモートは実際に出る文言をそのまま出す
## (GameDesign.md 21章)。買えない品は暗くして押しても何も起こさない。
##
## 地の面は `CodedButtonStyle`(真鍮の額縁+暗く凹んだ中央パネル)を流用する
## (`HomeTile` と同じ流儀)。手描きの単色グラデーションより、他の画面と揃った
## 質感(ベベル・グレイン・ホバーの発光)が自動で付く。
class ShopItemCard:
	extends Button
	## カードセットのみ。「内容を見る」を押したときに、確認先(画面側)へ通知する。
	## 押しても購入確認は開かない——子 `Button` が `MOUSE_FILTER_STOP` で入力を奪う。
	signal set_preview_requested(set_id: String)

	## エモートのサムネイルを収める矩形。
	const EMOTE_THUMB_RECT := Rect2(16, 16, 84, 68)
	const EMOTE_THUMB_TEXT_MARGIN := Vector2(8, 18)
	const EMOTE_THUMB_FONT_SIZE := 11
	const EMOTE_THUMB_MAX_LINES := 3
	## カードセットの中身を紹介する紋章の並び。多すぎると読みにくいため上限を設ける。
	const CARD_SET_EMBLEM_LIMIT := 5
	const CARD_SET_EMBLEM_RADIUS := 20.0
	const CARD_SET_EMBLEM_STEP := 34.0

	var kind: ShopCatalog.Kind
	var id: String
	var owned := false:
		set(value):
			owned = value
			disabled = value
	var affordable := true
	var _font: Font

	## プレイマットの見本を敷く層。切り抜きの効く子として持つ。
	func _build_swatch(rect: Rect2) -> void:
		var layer := BoardTable.MatLayer.new()
		layer.mat_id = id
		layer.position = rect.position
		layer.size = rect.size
		add_child(layer)

	func _init(p_kind: ShopCatalog.Kind, p_id: String) -> void:
		kind = p_kind
		id = p_id
		custom_minimum_size = CARD_SET_SIZE if kind == ShopCatalog.Kind.CARD_SET else CARD_SIZE
		size = custom_minimum_size
		CodedButton.apply_styles(self, "icon_square")
		text = ""

	func _ready() -> void:
		_font = get_theme_default_font()
		if _font == null:
			_font = ThemeDB.fallback_font
		if kind == ShopCatalog.Kind.PLAYMAT:
			_build_swatch(_thumb_rect())
		mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if owned or not affordable else Control.CURSOR_POINTING_HAND
		)
		# **`modulate`で丸ごと暗くする。**自前の`_draw()`より後に描かれる子
		# (プレイマットの見本)は、`_draw()`内で塗った暗幕の上に乗ってしまい
		# 効かないため(子は常に親のCanvasItemより手前に描かれる)。`modulate`なら
		# 背景・文字・子のいずれも一括で暗くでき、描画順を気にしなくてよい。
		if owned or not affordable:
			modulate = Color(0.7, 0.68, 0.65, 1.0)
		if kind == ShopCatalog.Kind.CARD_SET:
			_build_preview_link()
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	## **買う前に中身を確認できる場所は、この品自身が持つ**(GameDesign.md 21章)。
	## デッキ編集・砂時計一覧は未所有カードをロック/シルエットで隠すため、それ以外の
	## どこかで確認できるという前提は成立しない。所有の有無に関わらず常に押せる。
	func _build_preview_link() -> void:
		var inner := _inner_rect()
		var link_size := Vector2(172.0, 26.0)
		var link := Button.new()
		link.flat = true
		link.text = "内容を見る →"
		link.add_theme_font_size_override("font_size", 14)
		link.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
		link.add_theme_color_override("font_hover_color", UiPalette.TEXT_OFFWHITE)
		link.mouse_filter = Control.MOUSE_FILTER_STOP
		link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		link.position = Vector2(inner.end.x - link_size.x, inner.end.y - link_size.y - 2.0)
		link.size = link_size
		link.pressed.connect(func() -> void: set_preview_requested.emit(id))
		add_child(link)

	## 額縁の内側(暗く凹んだパネル)。中身はここへ収める(`CodedButtonStyle` と同じ規則)。
	func _inner_rect() -> Rect2:
		return CodedButtonStyle.inner_rect(Rect2(Vector2.ZERO, size))

	## サムネイルを収める正方形。左端へ、高さいっぱいに置く。
	func _thumb_rect() -> Rect2:
		var inner := _inner_rect()
		var side: float = inner.size.y
		return Rect2(inner.position, Vector2(side, side))

	## 未購入かつ残高が足りないとき。地の上への暗幕は `_ready()` の `modulate` が
	## 一括でかけるため、ここは文字色などの判定にだけ使う
	## (GameDesign.md 21章「買えないことは行を暗くすることで示す」)。
	func _unaffordable() -> bool:
		return not owned and not affordable

	func _draw() -> void:
		if _font == null:
			return
		var inner := _inner_rect()
		_draw_thumb(inner)
		var text_left: float = inner.position.x + inner.size.y + 18.0
		var text_width: float = inner.end.x - text_left - 152.0
		var dim := owned or _unaffordable()
		var text_color := UiPalette.TEXT_MUTED if dim else UiPalette.TEXT_OFFWHITE
		draw_string(
			_font,
			Vector2(text_left, inner.position.y + 26.0),
			ShopCatalog.item_name(kind, id),
			HORIZONTAL_ALIGNMENT_LEFT,
			text_width,
			20,
			text_color
		)
		draw_multiline_string(
			_font,
			Vector2(text_left, inner.position.y + 48.0),
			ShopCatalog.item_detail(kind, id),
			HORIZONTAL_ALIGNMENT_LEFT,
			text_width,
			14,
			2,
			UiPalette.TEXT_MUTED
		)
		_draw_price(inner)

	## アイコンは真鍮の印に紋章、**エモートは実際に出る文言そのもの**、
	## プレイマットは実際に敷いた縮小見本、**カードセットは中身のカードの紋章を
	## 数個並べたもの**を出す(GameDesign.md 21章)。名前だけでは何を買うのか
	## 分からない品ほど、実物に近いものをそのまま見せる。
	func _draw_thumb(inner: Rect2) -> void:
		if kind == ShopCatalog.Kind.PLAYMAT:
			# 見本は子の層(_build_swatch)へ描く。模様は矩形の外まで伸びるため
			# 切り抜きが要る(`BoardTable` と同じ理由)。
			return
		if kind == ShopCatalog.Kind.EMOTE:
			_draw_emote_thumb()
			return
		if kind == ShopCatalog.Kind.CARD_SET:
			_draw_card_set_thumb(inner)
			return
		var thumb := _thumb_rect()
		var tex := UserProfileLibrary.get_icon_texture(id)
		EmblemSeal.brass(self, thumb.get_center(), tex, thumb.size.y * 0.42)

	## カードセットの中身のカードから、上限ぶんの紋章を横一列に並べる。
	## 収まらない残りは「+N」の数字だけで示す。
	func _draw_card_set_thumb(inner: Rect2) -> void:
		var ids := CardSetLibrary.card_ids(id)
		var shown: int = mini(ids.size(), CARD_SET_EMBLEM_LIMIT)
		var center_y: float = inner.position.y + inner.size.y * 0.5
		var x: float = inner.position.x + CARD_SET_EMBLEM_RADIUS
		for i in shown:
			var card := CardLibrary.find_by_id(str(ids[i]))
			if card != null:
				EmblemSeal.brass(self, Vector2(x, center_y), card.emblem, CARD_SET_EMBLEM_RADIUS)
			x += CARD_SET_EMBLEM_STEP
		var remaining: int = ids.size() - shown
		if remaining > 0 and _font != null:
			draw_string(
				_font,
				Vector2(x - CARD_SET_EMBLEM_STEP + CARD_SET_EMBLEM_RADIUS + 4.0, center_y + 6.0),
				"+%d" % remaining,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				16,
				UiPalette.TEXT_MUTED
			)

	## 対局中の吹き出し(`EmoteBubble`)と同じ質感の真鍮枠パネルに文言を収める。
	func _draw_emote_thumb() -> void:
		var rect := EMOTE_THUMB_RECT
		var ci := get_canvas_item()
		var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 5)
		UiPaint.fill_gradient_polygon(
			ci,
			points,
			rect,
			[[0.0, Color(0.16, 0.13, 0.1, 0.95)], [1.0, Color(0.08, 0.06, 0.05, 0.95)]]
		)
		var dim := owned or _unaffordable()
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, UiPalette.BRASS_DARK if dim else UiPalette.BRASS_LIGHT, 1.2, true)
		draw_multiline_string(
			_font,
			rect.position + EMOTE_THUMB_TEXT_MARGIN,
			EmoteLibrary.get_emote_text(id),
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - EMOTE_THUMB_TEXT_MARGIN.x * 2.0,
			EMOTE_THUMB_FONT_SIZE,
			EMOTE_THUMB_MAX_LINES,
			UiPalette.TEXT_MUTED if dim else UiPalette.TEXT_OFFWHITE
		)

	## 価格は小さな真鍮の札(ピル)に載せる。**買えないことは行を暗くすることだけで
	## 示し、価格を赤では書かない**(GameDesign.md 21章)。
	func _draw_price(inner: Rect2) -> void:
		var label := "所有済み" if owned else CurrencyRules.label_text(ShopCatalog.price(kind, id))
		var pill_size := Vector2(132.0, 30.0)
		var pill := Rect2(
			Vector2(inner.end.x - pill_size.x, inner.get_center().y - pill_size.y * 0.5), pill_size
		)
		var ci := get_canvas_item()
		var points := UiPaint.rounded_rect_points_uniform(pill, pill_size.y * 0.5, 5)
		var top := UiPalette.BRASS_LIGHT
		var bottom := UiPalette.BRASS_DARK
		if owned:
			top = Color(0.16, 0.16, 0.15, 1.0)
			bottom = Color(0.09, 0.09, 0.08, 1.0)
		elif not affordable:
			top = Color(0.15, 0.12, 0.1, 1.0)
			bottom = Color(0.08, 0.06, 0.05, 1.0)
		UiPaint.fill_gradient_polygon(ci, points, pill, [[0.0, top], [1.0, bottom]])
		var outline := points.duplicate()
		outline.append(points[0])
		var rim := UiPalette.BRASS_HIGHLIGHT if (not owned and affordable) else UiPalette.BRASS_MID
		draw_polyline(outline, rim, 1.4, true)
		var color := UiPalette.TEXT_MUTED
		if not owned and affordable:
			color = UiPalette.BRASS_HIGHLIGHT
		draw_string(
			_font,
			pill.position + Vector2(0.0, pill_size.y * 0.68),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			pill_size.x,
			16,
			color
		)
