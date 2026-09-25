class_name CardDeckSharePanel
extends Control
## デッキの受け渡し(GameDesign.md 9章)。**「渡す」と「受け取る」の2つの面**を上の切り替えで出し分ける。
##
## 「渡す」は**デッキ表の画像とデッキコードを並べる**。どちらも自分の構築を人へ渡す手段であり、
## 並べておかないと渡す方法が2つあること自体に気づけないため。左の見本は `SubViewport` の中の
## `CardDeckSheet` の `ViewportTexture` そのもので、**書き出す画像と画面に見えているものが同じ実体**になる。
##
## **コードは8桁の数字で、中身はサーバーへ預ける**(`DeckCodeService`)。**発行はボタンを
## 押したときだけ行う**。画面を開くたびに預けると、使われないコードが際限なく増えるため。
##
## 「受け取る」は升と数字パッドを常に出す。読み込みは編集中のデッキを置き換える操作であり、
## 渡す操作と同じ面に並べると押し間違えるため面を分けている。

signal loaded(deck: Array)

enum Face { SEND, RECEIVE }

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_RECT := Rect2(40, 52, 1200, 616)
const TITLE_POS := Vector2(32, 24)
const TAB_SIZE := Vector2(150, 48)
const TAB_LEFT := 452.0
const TAB_TOP := 20.0
const CLOSE_RECT := Rect2(1036, 20, 132, 48)

const PREVIEW_RECT := Rect2(32, 96, 736, 414)
const PREVIEW_NOTE_POS := Vector2(32, 530)
const IMAGE_CARD_RECT := Rect2(796, 96, 372, 196)
const CODE_CARD_RECT := Rect2(796, 308, 372, 276)
const CARD_TITLE_POS := Vector2(24, 18)
const CARD_SUB_POS := Vector2(24, 54)
const CARD_BUTTON_LEFT := 24.0
const CARD_INNER_WIDTH := 324.0
const IMAGE_BUTTON_TOP := 92.0
const IMAGE_MESSAGE_POS := Vector2(24, 154)
const CODE_TILES_RECT := Rect2(24, 92, 324, 60)
const CODE_BUTTON_RECT := Rect2(24, 170, 324, 56)
const CODE_MESSAGE_POS := Vector2(24, 236)
const BUTTON_HEIGHT := 52.0
const BUTTON_GAP := 12.0

const RECEIVE_TITLE_POS := Vector2(180, 120)
const RECEIVE_SUB_POS := Vector2(180, 164)
const RECEIVE_TILES_RECT := Rect2(180, 216, 480, 88)
const LOAD_BUTTON_RECT := Rect2(180, 330, 480, 64)
const RECEIVE_MESSAGE_POS := Vector2(180, 412)
const RECEIVE_NOTE_POS := Vector2(180, 470)
const RECEIVE_TEXT_WIDTH := 480.0
const PAD_POS := Vector2(740, 150)
const PAD_KEY_SIZE := Vector2(84, 64)

const TITLE_FONT_SIZE := 28
const CARD_TITLE_FONT_SIZE := 22
const RECEIVE_TITLE_FONT_SIZE := 28
const SUB_FONT_SIZE := 16
const MESSAGE_FONT_SIZE := 17

const ISSUE_LABEL := "コードを発行してコピー"
const COPY_LABEL := "コードをコピー"
const RECEIVE_NOTE := "読み込むと編集中の内容が入れ替わります。保存するまで元のデッキは残ります"

var _face := Face.SEND
var _send_view: Control
var _receive_view: Control
var _tabs: Array[Button] = []
var _preview: TextureRect
var _viewport: SubViewport
var _sheet: CardDeckSheet
var _copy_image_button: Button
var _save_image_button: Button
var _image_message: Label
var _own_tiles: CodeTiles
var _code_button: Button
var _code_message: Label
var _input_tiles: CodeTiles
var _pad: NumberPad
var _load_button: Button
var _receive_message: Label
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
	_own_tiles.code = ""
	_input_tiles.input.text = ""
	_input_tiles.code = ""
	_image_message.text = ""
	_code_message.text = ""
	_receive_message.text = ""
	_set_busy(false)
	_show_face(Face.SEND)
	visible = true
	_refresh_sheet()


func close() -> void:
	visible = false


func _show_face(face: Face) -> void:
	_face = face
	_send_view.visible = face == Face.SEND
	_receive_view.visible = face == Face.RECEIVE
	for i in _tabs.size():
		CodedButton.apply_styles(
			_tabs[i], CodedButton.PRIMARY_ACTION_GROUP if i == face else CodedButton.WIDE_GROUP
		)
	if face == Face.RECEIVE and _input_tiles.input.editable:
		_input_tiles.input.grab_focus()


## 表を組み直し、1フレームだけ描かせる。見本も書き出しもこの結果を使う。
func _refresh_sheet() -> void:
	_sheet.show_deck(_deck, _deck_name, _code)
	_viewport.size = Vector2i(_sheet.sheet_size())
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
	_image_message.text = "画像を作成中"
	var image: Image = await _sheet_image()
	ImageShare.share_png(image, _file_name(), prefer_clipboard, _on_image_done)


func _on_image_done(_ok: bool, message: String) -> void:
	_set_busy(false)
	_image_message.text = message


## 発行済みならコピーだけ、未発行なら発行してそのままコピーする(渡すまでを1回の押下で終える)。
## 同じ構築なら `DeckCodeService` が同じ番号を返すため、押し直しても預けたものは増えない。
func _on_code_pressed() -> void:
	if _busy:
		return
	if _code != "":
		_copy_code()
		return
	_set_busy(true)
	_code_message.text = "コードを発行中"
	if not await NetSession.sign_in():
		_fail(_code_message, "通信に失敗しました。接続を確認してください")
		return
	var code: String = await DeckCodeService.publish(NetSession.client, _deck)
	if code == "":
		_fail(_code_message, "コードを発行できませんでした")
		return
	_code = code
	_own_tiles.code = code
	# 発行した番号は画像にも載せる(GameDesign.md 9章)。
	_refresh_sheet()
	_set_busy(false)
	_copy_code()


func _copy_code() -> void:
	DisplayServer.clipboard_set(_code)
	_code_message.text = "コピーしました。画像にも番号が載ります"


func _on_load_pressed() -> void:
	if _busy:
		return
	if DeckCodeService.normalize(_input_tiles.code) == "":
		_receive_message.text = "コードは%d桁の数字です" % DeckCodeService.CODE_LENGTH
		return
	_set_busy(true)
	_receive_message.text = "読み込み中"
	if not await NetSession.sign_in():
		_fail(_receive_message, "通信に失敗しました。接続を確認してください")
		return
	var deck: Array = await DeckCodeService.fetch(NetSession.client, _input_tiles.code)
	if deck.is_empty():
		_fail(_receive_message, "このコードは読み込めませんでした")
		return
	_set_busy(false)
	loaded.emit(deck)
	close()


func _fail(label: Label, message: String) -> void:
	_set_busy(false)
	label.text = message


func _set_busy(busy: bool) -> void:
	_busy = busy
	var complete := _deck.size() == MatchState.DECK_SIZE
	_code_button.disabled = busy or not complete
	_code_button.text = COPY_LABEL if _code != "" else ISSUE_LABEL
	if not complete:
		_code_message.text = "%d枚そろうと発行できます" % MatchState.DECK_SIZE
	_copy_image_button.disabled = busy
	_save_image_button.disabled = busy
	_load_button.disabled = busy
	_input_tiles.set_editable(not busy)
	_pad.set_disabled(busy)


# --- 組み立て -----------------------------------------------------------


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := _make_panel(self, PANEL_RECT)
	_place_label(panel, "デッキを共有", TITLE_POS, TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	var faces := ["渡す", "受け取る"]
	for i in faces.size():
		var tab := CodedButton.make(faces[i], TAB_SIZE)
		tab.position = Vector2(TAB_LEFT + i * TAB_SIZE.x, TAB_TOP)
		tab.pressed.connect(_show_face.bind(i))
		panel.add_child(tab)
		_tabs.append(tab)
	var close_button := CodedButton.make("閉じる", CLOSE_RECT.size)
	close_button.position = CLOSE_RECT.position
	close_button.pressed.connect(close)
	panel.add_child(close_button)

	_send_view = _make_layer(panel)
	_build_preview()
	_build_image_card()
	_build_code_card()
	_receive_view = _make_layer(panel)
	_build_receive()


## 表そのもの。`SubViewport` は画面に見えず、その中身だけを `TextureRect` で映す。
func _build_preview() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sheet = CardDeckSheet.new()
	_viewport.add_child(_sheet)
	_send_view.add_child(_viewport)

	_preview = TextureRect.new()
	_preview.texture = _viewport.get_texture()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.position = PREVIEW_RECT.position
	_preview.size = PREVIEW_RECT.size
	_send_view.add_child(_preview)
	_place_label(
		_send_view, "この画像がそのまま書き出されます", PREVIEW_NOTE_POS, SUB_FONT_SIZE, UiPalette.TEXT_MUTED
	)


func _build_image_card() -> void:
	var card := _make_panel(_send_view, IMAGE_CARD_RECT)
	_place_label(card, "画像で渡す", CARD_TITLE_POS, CARD_TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_place_label(card, "XやDiscordへそのまま貼れます", CARD_SUB_POS, SUB_FONT_SIZE, UiPalette.TEXT_MUTED)
	# ブラウザ以外では画像をクリップボードへ置けない(Architecture.md 10.6.1節)。
	# 押せないボタンを見せず、保存を主の操作として幅いっぱいに出す。
	var can_copy := ImageShare.can_copy()
	var half := (CARD_INNER_WIDTH - BUTTON_GAP) / 2.0
	_copy_image_button = _make_button(
		card, "画像をコピー", Rect2(CARD_BUTTON_LEFT, IMAGE_BUTTON_TOP, half, BUTTON_HEIGHT), true
	)
	_copy_image_button.pressed.connect(_on_copy_image_pressed)
	_copy_image_button.visible = can_copy
	var save_rect := Rect2(
		CARD_BUTTON_LEFT + half + BUTTON_GAP, IMAGE_BUTTON_TOP, half, BUTTON_HEIGHT
	)
	if not can_copy:
		save_rect = Rect2(CARD_BUTTON_LEFT, IMAGE_BUTTON_TOP, CARD_INNER_WIDTH, BUTTON_HEIGHT)
	_save_image_button = _make_button(card, "画像を保存", save_rect, not can_copy)
	_save_image_button.pressed.connect(_on_save_image_pressed)
	_image_message = _make_message(card, IMAGE_MESSAGE_POS, CARD_INNER_WIDTH)


func _build_code_card() -> void:
	var card := _make_panel(_send_view, CODE_CARD_RECT)
	_place_label(card, "コードで渡す", CARD_TITLE_POS, CARD_TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_place_label(
		card,
		"%d桁の番号を送ると、相手が読み込めます" % DeckCodeService.CODE_LENGTH,
		CARD_SUB_POS,
		SUB_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
	_own_tiles = _make_tiles(card, CODE_TILES_RECT)
	_code_button = _make_button(card, ISSUE_LABEL, CODE_BUTTON_RECT, true)
	_code_button.pressed.connect(_on_code_pressed)
	_code_message = _make_message(card, CODE_MESSAGE_POS, CARD_INNER_WIDTH)


func _build_receive() -> void:
	_place_label(
		_receive_view,
		"受け取ったコードを読み込む",
		RECEIVE_TITLE_POS,
		RECEIVE_TITLE_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	_place_label(
		_receive_view,
		"%d桁の番号を入力します。貼り付けもできます" % DeckCodeService.CODE_LENGTH,
		RECEIVE_SUB_POS,
		SUB_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
	_input_tiles = _make_tiles(_receive_view, RECEIVE_TILES_RECT)
	_input_tiles.make_editable("デッキコード")
	_input_tiles.submitted.connect(_on_load_pressed)
	_load_button = _make_button(_receive_view, "読み込む", LOAD_BUTTON_RECT, true)
	_load_button.pressed.connect(_on_load_pressed)
	_receive_message = _make_message(_receive_view, RECEIVE_MESSAGE_POS, RECEIVE_TEXT_WIDTH)
	var note := _make_message(_receive_view, RECEIVE_NOTE_POS, RECEIVE_TEXT_WIDTH)
	note.text = RECEIVE_NOTE
	note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	note.add_theme_font_size_override("font_size", SUB_FONT_SIZE)
	# 確定は「読み込む」が持つため、パッドに「決定」は置かない(GameDesign.md 9章)。
	_pad = NumberPad.make(_input_tiles.input, PAD_KEY_SIZE, false)
	_pad.position = PAD_POS
	_receive_view.add_child(_pad)


func _make_layer(parent: Control) -> Control:
	var layer := Control.new()
	layer.size = PANEL_RECT.size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _make_panel(parent: Control, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _make_tiles(parent: Control, rect: Rect2) -> CodeTiles:
	var tiles := CodeTiles.new()
	tiles.digits = DeckCodeService.CODE_LENGTH
	tiles.position = rect.position
	tiles.size = rect.size
	parent.add_child(tiles)
	return tiles


## primary: 主要な操作は塗りつぶした真鍮、副次的な操作は凹んだパネル。
func _make_button(parent: Control, text: String, rect: Rect2, primary: bool) -> Button:
	var group := CodedButton.PRIMARY_ACTION_GROUP if primary else CodedButton.WIDE_GROUP
	var button := CodedButton.make_in_group(text, rect.size, group)
	button.position = rect.position
	parent.add_child(button)
	return button


func _make_message(parent: Control, at: Vector2, width: float) -> Label:
	var label := _place_label(parent, "", at, MESSAGE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	# 折り返しは size より先に立てる(Pitfalls.md)。
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(width, 0)
	return label


func _place_label(
	parent: Control, text: String, at: Vector2, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
