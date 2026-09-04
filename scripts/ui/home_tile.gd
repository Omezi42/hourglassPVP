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
## 札の中へ小さく並べる砂時計(選んでいるデッキの中身など)。空でよい。
var preview: Array[Texture2D] = []

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


## 札の中へ並べる砂時計を差し替える。
func set_preview(art: Array[Texture2D]) -> void:
	preview = art
	queue_redraw()


## 文字に使える幅。**右の紋章の透かしへ食い込ませない**(食い込むと副題が切れる)。
func _text_width() -> float:
	var reserved: float = size.y * 0.62 if emblem != null else 0.0
	return maxf(size.x - PADDING * 2.0 - reserved, 40.0)


func _draw() -> void:
	if _font == null:
		return
	var dim := disabled
	# 紋章は右側の透かし。**押す先が何なのかを絵でも示す**が、文字を邪魔しない濃さに留める。
	if emblem != null:
		var side: float = size.y * 0.86
		var at := Vector2(size.x - side * 0.72, (size.y - side) * 0.5)
		draw_texture_rect(
			emblem,
			Rect2(at, Vector2(side, side)),
			false,
			Color(UiPalette.BRASS_HIGHLIGHT, EMBLEM_ALPHA * (0.4 if dim else 1.0))
		)
	var has_sub := not subtitle.is_empty()
	# 砂時計を並べる札は、文字を上へ寄せてその下を絵の場所にする。
	var has_art := not preview.is_empty()
	var center: float = size.y * (0.24 if has_art else (0.48 if has_sub else 0.5))
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
	if has_art:
		_draw_preview(dim)


## 中身をちらりと見せる。**並べるのは数枚だけ**——ここは一覧ではなく入口であり、
## 全部を見たければ押せばよい。
func _draw_preview(dim: bool) -> void:
	var art_h: float = size.y * 0.36
	var art_w: float = art_h / 1.30
	var step: float = art_w * 0.78
	var top: float = size.y - art_h - 14.0
	var tint := Color(1, 1, 1, 0.35 if dim else 0.92)
	for i in preview.size():
		var art: Texture2D = preview[i]
		if art == null:
			continue
		draw_texture_rect(
			art, Rect2(Vector2(PADDING + float(i) * step, top), Vector2(art_w, art_h)), false, tint
		)
