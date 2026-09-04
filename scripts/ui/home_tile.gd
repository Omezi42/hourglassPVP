class_name HomeTile
extends Button
## ホーム画面の入口1つ(GameDesign.md 9章)。**見出しだけの板ではなく、いまの状態を
## 1行添えた札**として出す。
##
## 以前はどのタブも文字だけの灰色の板が並んでおり、押すまで中身が分からなかった。
## デッキなら「いま選んでいるデッキと枚数」、ショップなら「砂金の残高」のように、
## **押す前に分かるべきことをその場に出す**ほうが、板を大きくするより効く。
##
## `Button` を継承しているのは、既存のタブが `Button` として参照している枠を
## そのまま置き換えられるようにするため(押下・無効・ホバーの扱いも native のまま使える)。
## **文言は `text` へ入れず自前で描く**——見出しと副題を上下に置くため、
## native の中央揃え1行では収まらない。

const EMBLEM_ALPHA := 0.17
const TITLE_COLOR := Color(0.96, 0.94, 0.89)
const TITLE_DIM := Color(0.58, 0.55, 0.52)
const SUB_COLOR := Color(0.96, 0.82, 0.45)
const SUB_DIM := Color(0.52, 0.48, 0.42)
const PADDING := 26.0

var title := ""
var subtitle := ""
var title_size := 26
var emblem: Texture2D

var _font: Font


## 見出し・副題・紋章・大きさを与えて1枚作る(`CodedButton.make()` と同じ流儀)。
static func make(
	tile_title: String,
	tile_subtitle: String,
	emblem_id: String,
	tile_size: Vector2,
	font_size := 26
) -> HomeTile:
	var tile := HomeTile.new()
	tile.title = tile_title
	tile.subtitle = tile_subtitle
	tile.title_size = font_size
	tile.emblem = UserProfileLibrary.get_icon_texture(emblem_id)
	tile.custom_minimum_size = tile_size
	tile.size = tile_size
	return tile


func _init() -> void:
	# **native の文字は使わない**(見出しと副題を上下に置くため)。
	text = ""
	CodedButton.apply_styles(self, "wide_text")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


## 副題だけを差し替える(残高や枚数は画面へ戻るたびに変わる)。
func set_subtitle(text_line: String) -> void:
	subtitle = text_line
	queue_redraw()


## 文字に使える幅。**右の紋章の透かしへ食い込ませない**(食い込むと副題が切れる)。
func _text_width() -> float:
	var reserved: float = size.y * 0.62 if emblem != null else 0.0
	return maxf(size.x - PADDING * 2.0 - reserved, 40.0)


## 紋章を敷く矩形。**額縁の内側(暗く凹んだパネル)に必ず収める。**
## ボタンの矩形を基準に置くと、透かしが額縁へ載り上がって外へはみ出す。
func _emblem_rect() -> Rect2:
	var panel := CodedButtonStyle.inner_rect(Rect2(Vector2.ZERO, size))
	var side: float = minf(panel.size.y * 0.94, panel.size.x * 0.5)
	return Rect2(
		Vector2(panel.end.x - side - panel.size.y * 0.06, panel.get_center().y - side * 0.5),
		Vector2(side, side)
	)


func _draw() -> void:
	if _font == null:
		return
	var dim := disabled
	# 紋章は右側の透かし。**押す先が何なのかを絵でも示す**が、文字を邪魔しない濃さに留める。
	if emblem != null:
		draw_texture_rect(
			emblem,
			_emblem_rect(),
			false,
			Color(UiPalette.BRASS_HIGHLIGHT, EMBLEM_ALPHA * (0.4 if dim else 1.0))
		)
	var has_sub := not subtitle.is_empty()
	var center: float = size.y * (0.48 if has_sub else 0.5)
	var title_y: float = center + float(title_size) * 0.36
	draw_string(
		_font,
		Vector2(PADDING, title_y),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		_text_width(),
		title_size,
		TITLE_DIM if dim else TITLE_COLOR
	)
	if has_sub:
		draw_string(
			_font,
			Vector2(PADDING, title_y + float(title_size) * 0.92),
			subtitle,
			HORIZONTAL_ALIGNMENT_LEFT,
			_text_width(),
			maxi(title_size - 10, 13),
			SUB_DIM if dim else SUB_COLOR
		)
