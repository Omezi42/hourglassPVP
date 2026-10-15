class_name ReplayListCard
extends Control

signal card_pressed(match_id: String)

## 一覧のカードへ並べるデッキのアイコンの数(重複を除いた先頭から)。
const DECK_PREVIEW := 5
const ICON_SIZE := 40.0
## 縦画面(GameDesign.md 9章「縦画面」)。1列で画面の幅を使い、文字と紋章を目安まで大きくする。
## 日時と相手の行は折り返す(幅に収まらないため)。
const PORTRAIT_BADGE_FONT := 24
const PORTRAIT_BADGE_SIZE := Vector2(96, 40)
const PORTRAIT_INFO_FONT := 24
const PORTRAIT_CAPTION_FONT := 20
const PORTRAIT_ICON_SIZE := 52.0
## 情報の行の幅から引く量(左右の余白・勝敗のバッジ・間隔)。
const PORTRAIT_INFO_INSET := PORTRAIT_BADGE_SIZE.x + 40.0

var match_id: String = ""

var _press_tracker := PressTracker.new()
var _hovering := false
var _rest_position := Vector2.ZERO
var _portrait := false

## ホバー/押下のTween先。コンテナ(ListContainer)の直接の子である自分自身の
## position/scaleを外部から動かすと再レイアウト時に崩れるため、見た目専用の
## VisualRootへ逃がす。
@onready var visual_root: Control = $VisualRoot
@onready var background_panel: Panel = $VisualRoot/BackgroundPanel
@onready var result_badge: Label = $VisualRoot/Margin/VBox/HeaderRow/ResultBadge
@onready var info_label: Label = $VisualRoot/Margin/VBox/HeaderRow/InfoLabel
@onready var own_deck_row: HBoxContainer = $VisualRoot/Margin/VBox/Rows/OwnGroup/OwnDeckRow
@onready
var opponent_deck_row: HBoxContainer = $VisualRoot/Margin/VBox/Rows/OpponentGroup/OpponentDeckRow


func _ready() -> void:
	for label in [result_badge, info_label, $VisualRoot/Margin/VBox/Rows/OwnGroup/OwnCaption]:
		label.set_meta("landscape_font", label.get_theme_font_size("font_size"))
	$VisualRoot/Margin/VBox/Rows/OpponentGroup/OpponentCaption.set_meta(
		"landscape_font",
		$VisualRoot/Margin/VBox/Rows/OwnGroup/OwnCaption.get_meta("landscape_font")
	)
	result_badge.set_meta("landscape_size", result_badge.custom_minimum_size)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rest_position = visual_root.position
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(visual_root, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(visual_root, false)
			card_pressed.emit(match_id)
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(visual_root, false)


func _on_resized() -> void:
	visual_root.pivot_offset = visual_root.size / 2.0
	if not _hovering:
		_rest_position = visual_root.position


func _on_mouse_entered() -> void:
	_hovering = true
	ClickArea.animate_hover(visual_root, true, _rest_position)


func _on_mouse_exited() -> void:
	_hovering = false
	ClickArea.animate_hover(visual_root, false, _rest_position)


## 縦横に合わせて文字と紋章の大きさを切り替える。`width` は縦の1列の幅。
func set_portrait(portrait: bool, width: float) -> void:
	_portrait = portrait
	result_badge.custom_minimum_size = (
		PORTRAIT_BADGE_SIZE if portrait else result_badge.get_meta("landscape_size")
	)
	_set_font(result_badge, PORTRAIT_BADGE_FONT)
	_set_font(info_label, PORTRAIT_INFO_FONT)
	for caption in [
		$VisualRoot/Margin/VBox/Rows/OwnGroup/OwnCaption,
		$VisualRoot/Margin/VBox/Rows/OpponentGroup/OpponentCaption
	]:
		_set_font(caption, PORTRAIT_CAPTION_FONT)
	# 折り返す行には幅を与える(幅が決まる前の1文字ずつの高さが残るため。Pitfalls.md)。
	info_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART if portrait else TextServer.AUTOWRAP_OFF
	)
	info_label.custom_minimum_size.x = width - PORTRAIT_INFO_INSET if portrait else 0.0
	for row in [own_deck_row, opponent_deck_row]:
		for icon in row.get_children():
			(icon as Control).custom_minimum_size = Vector2.ONE * _icon_size()


func _set_font(label: Label, portrait_font: int) -> void:
	label.add_theme_font_size_override(
		"font_size", portrait_font if _portrait else int(label.get_meta("landscape_font"))
	)


func _icon_size() -> float:
	return PORTRAIT_ICON_SIZE if _portrait else ICON_SIZE


## CPU戦(source == "cpu")は自分が常に先手(側A)のローカル対局のため、player_a/player_bの
## uid比較は行わず常にis_a=trueとして扱う(GameDesign.md 13章)。
func show_replay(doc: Dictionary, my_uid: String, opponent_name: String = "") -> void:
	match_id = str(doc["id"])
	var fields: Dictionary = doc["fields"]
	var is_cpu: bool = str(fields.get("source", "")) == "cpu"
	var is_a: bool = true if is_cpu else str(fields.get("player_a", "")) == my_uid
	var side_text := "先手" if is_a else "後手"
	var winner := str(fields.get("winner", ""))
	var won: bool = (winner == "a" and is_a) or (winner == "b" and not is_a)
	var type_text := "CPU戦" if is_cpu else "オンライン"
	var dt := Time.get_datetime_dict_from_unix_time(int(fields.get("finished_at", 0)))
	var date_text := (
		"%04d/%02d/%02d %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]
	)
	# 相手の表示名が分かるならそれを出す。CPU戦は相手が固定のため「CPU」とする
	var versus := "CPU" if is_cpu else opponent_name
	if versus == "":
		info_label.text = "%s　%s　[%s]" % [date_text, side_text, type_text]
	else:
		info_label.text = ("%s　%s　vs %s　[%s]" % [date_text, side_text, versus, type_text])
	_apply_result(won)

	_fill_row(own_deck_row, fields.get("deck_a" if is_a else "deck_b", []))
	_fill_row(opponent_deck_row, fields.get("deck_b" if is_a else "deck_a", []))


## 勝敗が`info_label`の文中に埋もれて一目で分からなかったため、専用のバッジ(ResultBadge)と
## カード枠の色の両方で示す。色はUiPaletteの既存色(HPバーの残量表現と同じ、
## 安全=琥珀/危険=赤の意味付け)をそのまま流用し、新しい色は増やさない。
func _apply_result(won: bool) -> void:
	var accent := UiPalette.GLOW_AMBER if won else UiPalette.WARNING_RED

	result_badge.text = "勝利" if won else "敗北"
	var badge_style := (result_badge.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	badge_style.border_color = accent
	badge_style.bg_color = Color(accent, 0.28)
	result_badge.add_theme_stylebox_override("normal", badge_style)

	var card_style := (background_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	card_style.border_color = accent
	background_panel.add_theme_stylebox_override("panel", card_style)


## デッキは30枚あるため、重複を除いた先頭 DECK_PREVIEW 種だけを並べる。
## 30個のアイコンを並べるとカードの幅に収まらず、見比べる役にも立たないため。
func _fill_row(row: HBoxContainer, ids: Array) -> void:
	for child in row.get_children():
		child.queue_free()
	var shown: Array = []
	for id in ids:
		if shown.size() >= DECK_PREVIEW:
			break
		if shown.has(id):
			continue
		shown.append(id)
	for id in shown:
		var data: CardData = CardLibrary.find_by_id(str(id))
		if data == null:
			continue
		var icon := TextureRect.new()
		icon.texture = data.icon_upright
		icon.custom_minimum_size = Vector2.ONE * _icon_size()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
