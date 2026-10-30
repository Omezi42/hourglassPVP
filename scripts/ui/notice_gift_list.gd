class_name NoticeGiftList
extends ScrollContainer
## お知らせのモーダルの「プレゼント」タブの中身(GameDesign.md 33章)。1件ごとに 絵・名前・説明・期限・「受け取る」。
## 受け取れるもの → 受け取り済みの順で並べ、受け取り済みは沈めた色で残す。

## 砂金を受け取った瞬間、押したボタンの位置と額を運ぶ(ヘッダーの残高へ飛ばすのは `HomeScreen`)。
signal reward_claimed(from_rect: Rect2, amount: int)
signal claimed

const ROW_GAP := 10
const ART_SIDE := 56.0
const CLAIM_SIZE := Vector2(150, 48)
const PORTRAIT_CLAIM_SIZE := Vector2(150, 56)
const TITLE_FONT := 20
const SMALL_FONT := 15
const PORTRAIT_SMALL_FONT := 17
const ROW_STYLE := "res://resources/theme/buttons/img_wide_text_disabled.tres"
const OFFLINE_TEXT := "通信できるときに受け取れます"
const FAILED_TEXT := "いま受け取れませんでした。接続を確かめてください"
const EMPTY_TEXT := "いま受け取れるプレゼントはありません"
const CLAIMED_SET_TEXT := "受け取りました。デッキ編集ですぐ使えます"

var _rows: VBoxContainer
var _note: Label
var _busy := false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", ROW_GAP)
	add_child(box)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", ROW_GAP)
	box.add_child(_rows)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(_note)


func refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var online := not _uid().is_empty()
	var gifts := GiftLibrary.listed(DailyMissionService.today())
	for gift in gifts:
		_rows.add_child(_make_row(gift, online))
	_note.add_theme_font_size_override("font_size", _small_font())
	if gifts.is_empty():
		_note.text = EMPTY_TEXT
	elif not online and GiftLibrary.unclaimed_count(DailyMissionService.today()) > 0:
		_note.text = OFFLINE_TEXT
	else:
		_note.text = ""


func _make_row(gift: GiftData, online: bool) -> Control:
	var done := GiftLibrary.is_claimed(gift)
	var panel := PanelContainer.new()
	var style: StyleBox = load(ROW_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	panel.add_child(line)
	line.add_child(_make_art(gift))

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var title := Label.new()
	title.text = gift.title
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	column.add_child(title)
	var detail := Label.new()
	detail.text = _detail_text(gift)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.x = ART_SIDE * 3.0
	detail.add_theme_font_size_override("font_size", _small_font())
	detail.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(detail)

	if done:
		panel.modulate = Color(1, 1, 1, 0.55)
		var mark := Label.new()
		mark.text = "受け取り済み"
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
		line.add_child(mark)
		return panel
	var button := CodedButton.make(
		"受け取る", PORTRAIT_CLAIM_SIZE if ScreenOrientation.is_portrait() else CLAIM_SIZE
	)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not online
	button.pressed.connect(func() -> void: _on_claim(gift, button))
	line.add_child(button)
	return panel


## カードセットは収録カードの紋章、砂金は砂金のチップ(GameDesign.md 33章)。
func _make_art(gift: GiftData) -> Control:
	if gift.kind == GiftData.Kind.CURRENCY:
		var chip := CurrencyChip.new()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.set_amount(gift.amount, false)
		return chip
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(ART_SIDE, ART_SIDE)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = UiPalette.BRASS_HIGHLIGHT
	var ids := CardSetLibrary.card_ids(gift.set_id)
	var card := CardLibrary.find_by_id(ids[0]) if not ids.is_empty() else null
	if card != null:
		art.texture = card.emblem
	return art


func _detail_text(gift: GiftData) -> String:
	if gift.expires.is_empty():
		return gift.description
	var parts := gift.expires.split("-")
	return "%s(%d月%d日まで)" % [gift.description, int(parts[1]), int(parts[2])]


func _on_claim(gift: GiftData, button: Button) -> void:
	if _busy:
		return
	_busy = true
	button.disabled = true
	var rect := button.get_global_rect()
	var ok: bool = await GiftService.claim(NetSession.client, _uid(), gift)
	_busy = false
	refresh()
	if not ok:
		_note.text = FAILED_TEXT if not GiftLibrary.is_claimed(gift) else ""
		return
	if gift.kind == GiftData.Kind.CURRENCY:
		reward_claimed.emit(rect, gift.amount)
	else:
		_note.text = CLAIMED_SET_TEXT
	claimed.emit()


func _small_font() -> int:
	return PORTRAIT_SMALL_FONT if ScreenOrientation.is_portrait() else SMALL_FONT


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
