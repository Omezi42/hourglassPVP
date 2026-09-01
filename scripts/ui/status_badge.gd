class_name StatusBadge
extends Control
## 文言の横へ添える丸い印(GameDesign.md 11章)。
##
## **押すものではなく、読むためのもの**として作る。募集をDiscordへ知らせたことのように
## 「起きたが、待っている人にできることは無い」出来事は、待機中の文言へ混ぜると
## 読ませる価値のない一文が居座る。印だけを置き、**知りたい人がカーソルを乗せた
## ときにだけ**説明を出す。
##
## 説明はGodotの標準のツールチップ(`tooltip_text`)へ委ねる。専用のパネルを作ると
## 画面ごとに出方が違うものが増えるため。

const DIAMETER := 22.0
const MARK := "!"
const MARK_FONT_SIZE := 16
## 円の中で「!」が上寄りに見えるため、視覚的な中心へ寄せる下駄。
const MARK_BASELINE_RATIO := 0.72

var _hovered := false


func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	visible = false


## 印を出し、カーソルを乗せたときに出す説明を差し替える。
func show_note(note: String) -> void:
	tooltip_text = note
	visible = true


func clear_note() -> void:
	visible = false


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := DIAMETER * 0.5
	var fill := UiPalette.GLOW_AMBER if _hovered else UiPalette.BRASS_HIGHLIGHT
	draw_circle(center, radius, UiPalette.OUTLINE_DARK)
	draw_circle(center, radius - 2.0, fill)
	var font := get_theme_default_font()
	if font == null:
		return
	var mark_size := font.get_string_size(MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE)
	var origin := Vector2(
		center.x - mark_size.x * 0.5, DIAMETER * MARK_BASELINE_RATIO + radius * 0.28
	)
	draw_string(
		font, origin, MARK, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE, UiPalette.OUTLINE_DARK
	)
