class_name CardMatchStatus
extends Control
## 対局画面の状態表示(通信待ちの文言と、設置効果の対象選択の案内)。
##
## どちらも盤面の駒より手前へ出す必要があるが、`Control._draw()` は自分の子より
## 背面に描かれるため、対局画面そのものの `_draw()` で描くと卓と駒に隠れる。
## 独立したオーバーレイのノードとして持つ(`CardFlipBeam` と同じ理由)。
## `card_match_screen.gd` が1000行の上限に達しているため切り出した、という事情もある。

const SCREEN_SIZE := Vector2(1280, 720)
## 対象選択の案内。**行動ボタンの列へ出す**(盤面へ重ねると、選ばせたい相手の
## カードそのものを隠してしまう)。
const PROMPT_RECT := Rect2(1108, 240, 148, 52)
const WAITING_FONT_SIZE := 26
const WAITING_OFFSET := Vector2(-180, 0)
## 不具合の報告と突き合わせるためのバージョン表示(GameDesign.md 11章)。
## 行動の列のいちばん下、投了ボタンより下の空きへ小さく出す。
const VERSION_POS := Vector2(1108, 678)
const VERSION_FONT_SIZE := 12

var waiting_text := ""
var targeting := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE


func set_waiting(text: String) -> void:
	waiting_text = text
	queue_redraw()


func set_targeting(value: bool) -> void:
	if targeting == value:
		return
	targeting = value
	queue_redraw()


func _draw() -> void:
	draw_string(
		get_theme_default_font(),
		VERSION_POS,
		GameVersion.display(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		VERSION_FONT_SIZE,
		Color(UiPalette.TEXT_OFFWHITE, 0.45)
	)
	if targeting:
		_draw_target_prompt()
	if waiting_text.is_empty():
		return
	draw_string(
		get_theme_default_font(),
		SCREEN_SIZE * 0.5 + WAITING_OFFSET,
		waiting_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		WAITING_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)


func _draw_target_prompt() -> void:
	var font := get_theme_default_font()
	draw_rect(PROMPT_RECT, Color(0.08, 0.12, 0.14, 0.95))
	draw_rect(PROMPT_RECT, CardView.SELECT_CYAN, false, 2.0)
	draw_string(
		font,
		PROMPT_RECT.position + Vector2(12, 24),
		"対象を選ぶ",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		CardView.SELECT_CYAN
	)
	draw_string(
		font,
		PROMPT_RECT.position + Vector2(12, 44),
		"他を押すと取消",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		UiPalette.TEXT_OFFWHITE
	)
