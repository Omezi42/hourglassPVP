class_name AlmanacPage
extends Control
## 砂時計図鑑の右のページ(GameDesign.md 9章)。選んだ1枚の解説を紙へ刷る。
##
## **`CardDetailPanel` は使わない。**あちらは暗いスレートのパネルで、
## デッキ編集と対局画面が使い続ける。紙のページの上に置くとそこだけ浮く。
##
## 実演(`CardEffectPreview`)と用語ポップ(`KeywordPopup`)は共通のものを使う。
## **図鑑と辞書で図版を2種類持たない**(GameDesign.md 9章)。

signal keyword_pressed(entry: Dictionary)

const INK := Color(0.20, 0.135, 0.075)
const INK_SOFT := Color(0.40, 0.30, 0.19)
const TERM_COLOR := Color(0.45, 0.20, 0.10)
const ART_WIDTH := 128.0
## 絵と実演のあいだに置くデータ欄の左端(絵の右)。
const DATA_GAP := 28.0
const DEMO_HEIGHT := 172.0
## 下部に綴じる「あなたの記録」の高さ。
const LOG_HEIGHT := 96.0
## キーワードと効果の文を書き出す高さ。**データ欄の値の下から始める。**
## 値は26pxで y=102 まで伸びるため、そこへ掛からない位置に取る。
const TEXT_TOP := 132.0
const TERM_ROW_HEIGHT := 34.0

var card: CardData

var _font: Font
var _preview: CardEffectPreview
var _terms: VBoxContainer
## 絵を押すと裏返る(GameDesign.md 9章)。**操作を促す表示は置かない**——
## 触れば気づくもののために常時の案内を出すと、紙面がそのぶん汚れる。
var _flipped := false
var _press := PressTracker.new()
var _art_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_build()


func _build() -> void:
	_preview = CardEffectPreview.new()
	_preview.position = Vector2(0, _demo_top())
	_preview.custom_minimum_size = Vector2(size.x, DEMO_HEIGHT)
	_preview.size = _preview.custom_minimum_size
	add_child(_preview)
	# キーワードの語は押せるボタンにする(GameDesign.md 17章)。図鑑は
	# パネルが留まる画面なので、押しに行った途中で消える心配がない。
	_terms = VBoxContainer.new()
	# **データ欄(コスト・総量・分類)の下から始める。**同じ高さから書き出すと
	# 値の文字と重なる(実際に重なった)。
	_terms.position = Vector2(ART_WIDTH + DATA_GAP, TEXT_TOP)
	_terms.custom_minimum_size.x = size.x - ART_WIDTH - DATA_GAP
	_terms.add_theme_constant_override("separation", 4)
	_terms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_terms)


func show_card(new_card: CardData) -> void:
	card = new_card
	_flipped = false
	_rebuild_terms()
	if _preview != null:
		_preview.show_card(card)
	queue_redraw()


func _demo_top() -> float:
	return size.y - LOG_HEIGHT - DEMO_HEIGHT - 12.0


## キーワードの行。語のボタンと説明を並べる。
func _rebuild_terms() -> void:
	for child in _terms.get_children():
		_terms.remove_child(child)
		child.queue_free()
	if card == null:
		return
	for keyword in card.named_keywords():
		_terms.add_child(_make_term(KeywordEntries.keyword_entry(keyword)))
	for keyword in card.plain_keywords():
		_terms.add_child(_make_term(KeywordEntries.keyword_entry(keyword)))


func _make_term(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var button := Button.new()
	button.text = "【%s】" % KeywordEntries.title(entry)
	button.flat = true
	button.custom_minimum_size = Vector2(96, 30)
	button.add_theme_color_override("font_color", TERM_COLOR)
	button.add_theme_color_override("font_hover_color", Color(0.72, 0.30, 0.14))
	button.add_theme_font_size_override("font_size", 18)
	_flatten_ink(button)
	button.pressed.connect(func() -> void: keyword_pressed.emit(entry))
	row.add_child(button)
	var text := Label.new()
	text.text = KeywordEntries.description(entry)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = size.x - ART_WIDTH - DATA_GAP - 106.0
	text.add_theme_color_override("font_color", INK)
	text.add_theme_font_size_override("font_size", 16)
	_flatten_ink(text)
	row.add_child(text)
	return row


## **紙の上の文字から縁取りを外す。**共通テーマはボタンへ3px・ラベルへ2pxの暗い
## 縁取りを掛けており、暗い画面では文字を浮かせるために要るが、**紙へ刷った濃い
## インクの文字に同じ縁取りを掛けると、字の内側が潰れて読めなくなる**。
static func _flatten_ink(control: Control) -> void:
	control.add_theme_constant_override("outline_size", 0)


func _gui_input(event: InputEvent) -> void:
	# 砂術は盤面へ出ないため裏返らない(反転できるのは砂時計だけ)。
	if card == null or card.is_spell:
		return
	if not _art_rect.has_point(_local_of(event)):
		return
	if _press.feed(event, size) == PressTracker.Result.CONFIRMED:
		_flipped = not _flipped
		queue_redraw()


static func _local_of(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		return event.position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	return Vector2(-1, -1)


func _draw() -> void:
	if card == null:
		return
	draw_string(_font, Vector2(0, 32), card.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, INK)
	_draw_rule(Vector2(0, 44), size.x)

	var art_h := ART_WIDTH * 1.30
	_art_rect = Rect2(Vector2(4, 58), Vector2(ART_WIDTH, art_h))
	UiPaint.fill_ellipse(
		get_canvas_item(),
		Vector2(_art_rect.get_center().x, _art_rect.end.y - 4),
		Vector2(ART_WIDTH * 0.34, 7.0),
		Color(0.42, 0.33, 0.20, 0.35),
		24
	)
	# **砂術は砂時計の絵を持たない**(GameDesign.md 9章)。`icon_upright` は砂術でも
	# 砂時計を返すため、ここで分けないと「盤面へ出ない札」が駒の姿で載ってしまう。
	if card.is_spell:
		_draw_spell_plate(_art_rect)
	else:
		# 標本の絵。**押すとひっくり返る**ため、落ちきりの絵と入れ替える。
		var icon: Texture2D = card.icon_fallen if _flipped else card.icon_upright
		if icon != null:
			draw_texture_rect(icon, _art_rect, false)

	var data_x := ART_WIDTH + DATA_GAP
	_draw_field(Vector2(data_x, 58), "コスト", str(card.cost))
	_draw_field(Vector2(data_x + 118, 58), "総量", "—" if card.is_spell else str(card.total_sand))
	_draw_field(Vector2(data_x + 236, 58), "分類", "砂術" if card.is_spell else "砂時計")
	if not card.rules_text.is_empty():
		draw_multiline_string(
			_font,
			Vector2(data_x, TEXT_TOP + _terms.get_child_count() * TERM_ROW_HEIGHT),
			card.rules_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - data_x,
			16,
			3,
			INK
		)
	_draw_log()


## 砂術の札。紙の上でも「置くカードではない」と分かるよう、藍の枠へ紋章を大きく置く。
func _draw_spell_plate(rect: Rect2) -> void:
	var points := UiPaint.rounded_rect_points_uniform(rect.grow(-4), 6.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.34, 0.40, 0.56)], [1.0, Color(0.18, 0.22, 0.36)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.20, 0.26, 0.42), 2.4)
	if card.emblem != null:
		var side: float = rect.size.x * 0.66
		draw_texture_rect(
			card.emblem,
			Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)),
			false,
			Color(0.92, 0.95, 1.0)
		)


## **図鑑にその人自身の記録を綴じる**(GameDesign.md 9章)。集めた札を眺めるだけの
## 場所にしない。数字は戦績(19章)が既に持っているものを引くだけで、新しく数えない。
func _draw_log() -> void:
	var top := size.y - LOG_HEIGHT
	_draw_rule(Vector2(0, top), size.x)
	draw_string(
		_font, Vector2(0, top + 25), "あ な た の 記 録", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, TERM_COLOR
	)
	# **戦績はカード別の行から引くだけ**にする(新しく数えるものを足さない)。
	var games := 0
	var wins := 0
	for row in MatchStats.cards(_uid()):
		if String(row.get("id", "")) == card.id:
			games = int(row.get("games", 0))
			wins = int(row.get("wins", 0))
			break
	_draw_field(Vector2(0, top + 34), "共に戦った", "%d 戦" % games)
	var rate := "—" if games <= 0 else "%d %%" % int(round(float(wins) / float(games) * 100.0))
	_draw_field(Vector2(150, top + 34), "勝率", rate)
	# **紙の右端で折り返す。**左端からの絶対位置で置くと、ページの幅が変わったときに
	# はみ出す(実際にはみ出した)。
	draw_string(
		_font,
		Vector2(0, top + 82),
		"※ カードの強さそのものではありません",
		HORIZONTAL_ALIGNMENT_RIGHT,
		size.x,
		14,
		INK_SOFT
	)


## 見出しつきの1項目。値を大きく、ラベルを小さく。
func _draw_field(at: Vector2, label: String, value: String) -> void:
	draw_string(_font, at + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK_SOFT)
	draw_string(_font, at + Vector2(0, 44), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)


## 戦績はアカウントごとに数える(GameDesign.md 19章)。サインインしていなければ空。
static func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid


func _draw_rule(at: Vector2, width: float) -> void:
	draw_line(at + Vector2(8, 0), at + Vector2(width - 8, 0), Color(0.45, 0.33, 0.18, 0.6), 1.4)
	for x in [at.x + 2.0, at.x + width - 2.0]:
		var c := Vector2(x, at.y)
		draw_colored_polygon(
			PackedVector2Array(
				[c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]
			),
			Color(0.45, 0.33, 0.18, 0.8)
		)
