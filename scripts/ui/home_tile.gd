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
## 紋章の透かしの上限。**比率だけで決めると、大きな札(そろえるタブのデッキ編集は
## 600x306px)で紋章が文字より主張する**(モックで実際に起きた)。比率で求めたうえで
## ここで止める。
const EMBLEM_MAX_SIDE := 96.0
const TITLE_COLOR := Color(0.96, 0.94, 0.89)
const TITLE_DIM := Color(0.58, 0.55, 0.52)
const SUB_COLOR := Color(0.96, 0.82, 0.45)
const SUB_DIM := Color(0.52, 0.48, 0.42)
## 塗りつぶした真鍮の面(`primary`)へ載せる副題。琥珀のままだと明るい面に沈む。
const SUB_ON_BRASS := Color(0.30, 0.20, 0.07)
const PADDING := 26.0
## 未受取の印(GameDesign.md 9章)。
const BADGE_COLOR := Color(0.86, 0.24, 0.19)
const BADGE_RADIUS := 15.0

var title := ""
var subtitle := ""
var title_size := 26
var emblem: Texture2D
## 塗りつぶした真鍮の面にする(そのタブでいちばんやってほしいこと1つだけ)。
var primary := false
## 0 より大きいとき、右上へ数の印を打つ。
var badge_count := 0:
	set(value):
		badge_count = value
		queue_redraw()

var _font: Font


## 見出し・副題・紋章・大きさを与えて1枚作る(`CodedButton.make()` と同じ流儀)。
static func make(
	tile_title: String,
	tile_subtitle: String,
	emblem_id: String,
	tile_size: Vector2,
	font_size := 26,
	is_primary := false
) -> HomeTile:
	var tile := HomeTile.new()
	tile.title = tile_title
	tile.subtitle = tile_subtitle
	tile.title_size = font_size
	tile.emblem = UserProfileLibrary.get_icon_texture(emblem_id)
	# **主役の面はここで当てる。**タブごとに外から `apply_styles()` を呼ぶ形にすると、
	# 呼び忘れた画面だけ強弱が崩れる(GameDesign.md 9章の3段)。
	if is_primary:
		tile.primary = true
		CodedButton.apply_styles(tile, "primary_action")
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
	side = minf(side, EMBLEM_MAX_SIDE)
	return Rect2(
		Vector2(panel.end.x - side - panel.size.y * 0.06, panel.get_center().y - side * 0.5),
		Vector2(side, side)
	)


## 見出しの基準線。**小さな札では中央、大きな札では上寄せにする。**中央のまま背を
## 高くすると、文字が札の真ん中へ沈んで「余白の中に置き忘れた」ように見える
## (モックでそろえるタブのデッキ編集がそうなった)。
func _title_center() -> float:
	var centered: float = size.y * (0.48 if not subtitle.is_empty() else 0.5)
	return minf(centered, PADDING + float(title_size) * 1.5)


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
	var title_y: float = _title_center() + float(title_size) * 0.36
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
		var sub_color := SUB_ON_BRASS if primary else SUB_COLOR
		draw_string(
			_font,
			Vector2(PADDING, title_y + float(title_size) * 0.92),
			subtitle,
			HORIZONTAL_ALIGNMENT_LEFT,
			_text_width(),
			maxi(title_size - 10, 13),
			SUB_DIM if dim else sub_color
		)
	if badge_count > 0:
		draw_badge(self, Vector2(size.x - BADGE_RADIUS - 4.0, BADGE_RADIUS + 4.0), badge_count)


## 未受取の数の印(GameDesign.md 9章)。**札と下部タブの両方へ同じ形で打つ**ため
## static にしてある——タブのボタンは `HomeTile` ではなく `CodedButton` で作られており、
## そこへも同じ印が要る。
static func draw_badge(target: CanvasItem, at: Vector2, count: int) -> void:
	var font := ThemeDB.fallback_font
	if target is Control:
		var theme_font := (target as Control).get_theme_default_font()
		if theme_font != null:
			font = theme_font
	target.draw_circle(at, BADGE_RADIUS + 2.0, Color(0.10, 0.07, 0.05, 0.9))
	target.draw_circle(at, BADGE_RADIUS, BADGE_COLOR)
	var text := str(count)
	var font_size := 17
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	target.draw_string(
		font,
		at + Vector2(-width * 0.5, float(font_size) * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(1, 1, 1)
	)
