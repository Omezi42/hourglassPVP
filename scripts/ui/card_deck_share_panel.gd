class_name CardDeckSharePanel
extends Control
## デッキの受け渡し(GameDesign.md 9章)。**デッキ表の画像とデッキコードを1つのパネルに
## まとめる**。どちらも「自分の構築を人へ渡す」ための手段であり、別々の場所へ置くと
## 渡す方法が2つあること自体に気づけないため。
##
## **コードは8桁の数字で、中身はサーバーへ預ける**(`DeckCodeService`)。
## **発行はボタンを押したときだけ行う**。画面を開くたびに預けると、使われない
## コードが際限なく増えるため。
##
## デッキ表は `SubViewport` の中の `CardDeckSheet` として組み、その `ViewportTexture` を
## そのまま左へ映す。**書き出す画像と画面に見えているものが同じ実体**になる。

signal loaded(deck: Array)

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_WIDTH := 1060.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## コードは8桁の数字しか入らないため、欄は短くてよい。
const FIELD_SIZE := Vector2(196, 44)
const BUTTON_SIZE := Vector2(160, 48)
const ROW_BUTTON_SIZE := Vector2(132, 44)
## 見本の幅。デッキ表(1280x900)を等倍で縮めて置く。
const PREVIEW_WIDTH := 560.0

var _own_field: LineEdit
var _input_field: LineEdit
var _message: Label
var _issue_button: Button
var _load_button: Button
var _copy_image_button: Button
var _save_image_button: Button
var _preview: TextureRect
var _viewport: SubViewport
var _sheet: CardDeckSheet
var _deck: Array = []
var _deck_name := ""
## 発行済みのコード。**画像を出すためだけに発行はしない**(通信が要るため)。
var _code := ""
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()


func open(deck: Array, deck_name: String) -> void:
	_deck = deck
	_deck_name = deck_name
	_code = ""
	_own_field.text = ""
	_input_field.text = ""
	_message.text = ""
	_set_busy(false)
	visible = true
	_refresh_sheet()


func close() -> void:
	visible = false


## 表を組み直し、1フレームだけ描かせる。見本も書き出しもこの結果を使う。
func _refresh_sheet() -> void:
	_sheet.show_deck(_deck, _deck_name, _code)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _sheet_image() -> Image:
	_refresh_sheet()
	await RenderingServer.frame_post_draw
	var texture := _viewport.get_texture()
	if texture == null:
		return null
	return texture.get_image()


func _file_name() -> String:
	var stem := _deck_name.strip_edges()
	if stem == "":
		stem = "deck"
	return "hourglass_%s.png" % stem


func _on_copy_image_pressed() -> void:
	await _write_image(true)


func _on_save_image_pressed() -> void:
	await _write_image(false)


func _write_image(prefer_clipboard: bool) -> void:
	if _busy:
		return
	_set_busy(true)
	_message.text = "画像を作成中"
	var image: Image = await _sheet_image()
	ImageShare.share_png(image, _file_name(), prefer_clipboard, _on_image_done)


func _on_image_done(_ok: bool, message: String) -> void:
	_set_busy(false)
	_message.text = message


## 発行はここでだけ行う。同じ構築なら `DeckCodeService` が同じ番号を返すため、
## 続けて押しても預けたものが増えることはない。
func _on_issue_pressed() -> void:
	if _busy:
		return
	if _deck.size() != MatchState.DECK_SIZE:
		_message.text = "デッキが%d枚のときだけコードを発行できます" % MatchState.DECK_SIZE
		return
	_set_busy(true)
	_message.text = "コードを発行中"
	if not await NetSession.sign_in():
		_fail("通信に失敗しました。接続を確認してください")
		return
	var code: String = await DeckCodeService.publish(NetSession.client, _deck)
	if code == "":
		_fail("コードを発行できませんでした")
		return
	_own_field.text = code
	_code = code
	# 発行した番号は画像にも載せる(GameDesign.md 9章)。
	_refresh_sheet()
	_message.text = "このコードを渡してください"
	_set_busy(false)


func _on_copy_pressed() -> void:
	if _own_field.text == "":
		_message.text = "先にコードを発行してください"
		return
	DisplayServer.clipboard_set(_own_field.text)
	_message.text = "コピーしました"


func _on_load_pressed() -> void:
	if _busy:
		return
	if DeckCodeService.normalize(_input_field.text) == "":
		_message.text = "コードは%d桁の数字です" % DeckCodeService.CODE_LENGTH
		return
	_set_busy(true)
	_message.text = "読み込み中"
	if not await NetSession.sign_in():
		_fail("通信に失敗しました。接続を確認してください")
		return
	var deck: Array = await DeckCodeService.fetch(NetSession.client, _input_field.text)
	if deck.is_empty():
		_fail("このコードは読み込めませんでした")
		return
	_set_busy(false)
	loaded.emit(deck)
	close()


func _fail(message: String) -> void:
	_set_busy(false)
	_message.text = message


func _set_busy(busy: bool) -> void:
	_busy = busy
	_issue_button.disabled = busy
	_load_button.disabled = busy
	_copy_image_button.disabled = busy or not ImageShare.can_copy()
	_save_image_button.disabled = busy
	_input_field.editable = not busy


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_make_label("デッキを共有する", 26))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	body.add_child(_build_preview())
	body.add_child(_build_controls())

	_message = _make_label("", 18)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = PANEL_WIDTH - 40.0
	column.add_child(_message)

	var close_button := CodedButton.make("閉じる", BUTTON_SIZE)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	column.add_child(close_button)


## 表そのもの。`SubViewport` は画面に見えず、その中身だけを `TextureRect` で映す。
func _build_preview() -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 8)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CardDeckSheet.SHEET_SIZE)
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sheet = CardDeckSheet.new()
	_viewport.add_child(_sheet)
	holder.add_child(_viewport)

	_preview = TextureRect.new()
	_preview.texture = _viewport.get_texture()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var height := PREVIEW_WIDTH * CardDeckSheet.SHEET_SIZE.y / CardDeckSheet.SHEET_SIZE.x
	_preview.custom_minimum_size = Vector2(PREVIEW_WIDTH, height)
	holder.add_child(_preview)
	return holder


func _build_controls() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size.x = 400.0

	column.add_child(_make_label("画像として渡す", 20))
	var image_row := HBoxContainer.new()
	image_row.add_theme_constant_override("separation", 10)
	_copy_image_button = CodedButton.make("画像をコピー", Vector2(180, 48))
	_copy_image_button.pressed.connect(_on_copy_image_pressed)
	_copy_image_button.disabled = not ImageShare.can_copy()
	image_row.add_child(_copy_image_button)
	_save_image_button = CodedButton.make("画像を保存", Vector2(160, 48))
	_save_image_button.pressed.connect(_on_save_image_pressed)
	image_row.add_child(_save_image_button)
	column.add_child(image_row)
	if not ImageShare.can_copy():
		# ブラウザ以外では画像をクリップボードへ置けない(Architecture.md 10.6.1節)。
		column.add_child(_make_label("この環境ではコピーできません。保存を使ってください", 15))

	column.add_child(_make_label("コードとして渡す", 20))
	_own_field = _make_field(true)
	var own_row := _make_row(_own_field, "コピー", _on_copy_pressed)
	_issue_button = CodedButton.make("発行", Vector2(110, FIELD_SIZE.y))
	_issue_button.pressed.connect(_on_issue_pressed)
	own_row.add_child(_issue_button)
	column.add_child(own_row)

	column.add_child(_make_label("受け取ったコードを読み込む", 20))
	_input_field = _make_field(false)
	_input_field.max_length = DeckCodeService.CODE_LENGTH
	_input_field.placeholder_text = "%d桁の数字" % DeckCodeService.CODE_LENGTH
	var load_row := _make_row(_input_field, "読み込む", _on_load_pressed)
	_load_button = load_row.get_child(1)
	column.add_child(load_row)
	return column


func _make_row(field: LineEdit, label: String, handler: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(field)
	var button := CodedButton.make(label, ROW_BUTTON_SIZE)
	button.pressed.connect(handler)
	row.add_child(button)
	return row


func _make_field(read_only: bool) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size = FIELD_SIZE
	field.editable = not read_only
	# 渡す側の欄も選択してコピーできるようにするため、read_only は使うが無効化はしない。
	field.select_all_on_focus = true
	return field


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	return label
