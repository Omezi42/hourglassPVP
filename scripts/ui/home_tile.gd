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
const BADGE_FONT_SIZE := 17
## ホバー浮き(GameDesign.md 9章)。紋章の透かしをわずかに明るく・上へ浮かせる。
const HOVER_RISE_PX := 3.0
const HOVER_ALPHA_BOOST := 0.45
const HOVER_DURATION := 0.16

## 縦画面の文字の大きさ(GameDesign.md 9章「縦画面」: 本文24px以上)。
const PORTRAIT_SUBTITLE_SIZE := 24
const PORTRAIT_SUBTITLE_LINES := 2
const PORTRAIT_PADDING := 20.0
const PORTRAIT_EMBLEM_SIDE := 64.0
const PORTRAIT_BADGE_SCALE := 1.4
## 副題を折り返したときの行の送り(文字の大きさに対する比)。
const SUBTITLE_LINE_HEIGHT := 1.2

var title := ""
var subtitle := ""
var title_size := 26
var emblem: Texture2D
## 塗りつぶした真鍮の面にする(そのタブでいちばんやってほしいこと1つだけ)。
var primary := false
## 副題を琥珀で出す(まだ済ませていない「今日の」ものがあるとき。GameDesign.md 24章)。
var subtitle_accent := false:
	set(value):
		subtitle_accent = value
		queue_redraw()
## 縦画面(GameDesign.md 9章「縦画面」)で文字を大きくするための値。既定は横の見た目のまま。
var padding := PADDING
## 副題の大きさ。0 なら見出しから求める。
var subtitle_size := 0
## 副題を折り返してよい行数。
var subtitle_lines := 1
var emblem_max_side := EMBLEM_MAX_SIDE
var badge_scale := 1.0
## 0 より大きいとき、紋章のぶん文字から空ける幅(既定は札の高さから求める)。
var emblem_reserve := 0.0
## 0 より大きいとき、右上へ数の印を打つ。
var badge_count := 0:
	set(value):
		badge_count = value
		queue_redraw()

var _font: Font
## 見出しの書体。**主役の面(`primary`)だけ**明朝体(`UiFonts.display_font()`)にする。
## 3段の強弱(GameDesign.md 9章)のうち、いちばん強い1枚だけへ格を足すためで、
## 並んだタイルすべてを明朝体にすると強弱そのものが埋もれる。副題は常に本文書体のまま。
var _title_font: Font
## ホバー浮きの進み(0〜1)。
var _hover := 0.0
var _hover_tween: Tween
## 副題が外部要因で変わった瞬間に立て、減衰させながら短く光らせる。
var _subtitle_flash := 0.0
var _flash_tween: Tween


## 縦横に合わせて文字の大きさを切り替える。横は作ったときの値へ戻す。
static func set_portrait_text(
	tile: HomeTile, portrait: bool, portrait_title: int, landscape_title: int
) -> void:
	tile.title_size = portrait_title if portrait else landscape_title
	tile.subtitle_size = PORTRAIT_SUBTITLE_SIZE if portrait else 0
	tile.subtitle_lines = PORTRAIT_SUBTITLE_LINES if portrait else 1
	tile.padding = PORTRAIT_PADDING if portrait else PADDING
	tile.emblem_max_side = PORTRAIT_EMBLEM_SIDE if portrait else EMBLEM_MAX_SIDE
	tile.emblem_reserve = PORTRAIT_EMBLEM_SIDE if portrait else 0.0
	tile.badge_scale = PORTRAIT_BADGE_SCALE if portrait else 1.0
	tile.queue_redraw()


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
	_title_font = UiFonts.display_font(_font) if primary else _font
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))


## 副題だけを差し替える(残高や枚数は画面へ戻るたびに変わる)。
func set_subtitle(text_line: String) -> void:
	subtitle = text_line
	queue_redraw()


## 副題が外部要因(砂金の増減・ミッションの進捗)で変わった瞬間に呼ぶ。押さなくても
## 「何かが変わった」と分かるよう、その行だけ短く光らせる(GameDesign.md 9章)。
func flash_subtitle() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_subtitle_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_subtitle_flash, 1.0, 0.0, 0.6)


func _set_subtitle_flash(value: float) -> void:
	_subtitle_flash = value
	queue_redraw()


func _on_hover_changed(hovering: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(_set_hover, _hover, 1.0 if hovering else 0.0, HOVER_DURATION)


func _set_hover(value: float) -> void:
	_hover = value
	queue_redraw()


## 文字に使える幅。**右の紋章の透かしへ食い込ませない**(食い込むと副題が切れる)。
func _text_width() -> float:
	var reserved := 0.0
	if emblem != null:
		reserved = emblem_reserve if emblem_reserve > 0.0 else size.y * 0.62
	return maxf(size.x - padding * 2.0 - reserved, 40.0)


## 紋章を敷く矩形。**額縁の内側(暗く凹んだパネル)に必ず収める。**
## ボタンの矩形を基準に置くと、透かしが額縁へ載り上がって外へはみ出す。
## ホバー中はわずかに浮かせる(GameDesign.md 9章)。
func _emblem_rect() -> Rect2:
	var panel := CodedButtonStyle.inner_rect(Rect2(Vector2.ZERO, size))
	var side: float = minf(panel.size.y * 0.94, panel.size.x * 0.5)
	side = minf(side, emblem_max_side)
	return Rect2(
		Vector2(
			panel.end.x - side - panel.size.y * 0.06,
			panel.get_center().y - side * 0.5 - HOVER_RISE_PX * _hover
		),
		Vector2(side, side)
	)


## 見出しの基準線。**小さな札では中央、大きな札では上寄せにする。**中央のまま背を
## 高くすると、文字が札の真ん中へ沈んで「余白の中に置き忘れた」ように見える
## (モックでそろえるタブのデッキ編集がそうなった)。
func _title_center() -> float:
	var centered: float = size.y * (0.48 if not subtitle.is_empty() else 0.5)
	var lines := _subtitle_rows().size()
	if lines > 1:
		# 折り返した副題まで含めた一群を札の上下の中央へ置く。
		var title_h := float(title_size)
		var sub_h := float(_subtitle_font_size())
		var block := (
			title_h * 0.8 + title_h * 0.92 + sub_h * (SUBTITLE_LINE_HEIGHT * (lines - 1) + 0.25)
		)
		return size.y * 0.5 - block * 0.5 + title_h * 0.8 - title_h * 0.36
	return minf(centered, padding + float(title_size) * 1.5)


func _subtitle_font_size() -> int:
	return subtitle_size if subtitle_size > 0 else maxi(title_size - 10, 13)


## 副題を行に分ける。**区切り(空白・「・」)があればそこで折る**(日本語は文字の間のどこでも折れるため、
## 幅で詰めると「まだ解い / ていません」のように語の途中で切れる)。
func _subtitle_rows() -> PackedStringArray:
	if subtitle_lines <= 1 or _font == null or _fits(subtitle):
		return PackedStringArray([subtitle])
	for separator in [" ", "・"]:
		var cut := subtitle.rfind(separator)
		while cut > 0:
			var head := subtitle.substr(0, cut).strip_edges()
			if _fits(head):
				var rest := subtitle.substr(cut + separator.length()).strip_edges()
				if separator != " ":
					head += separator
				return PackedStringArray([head, rest])
			cut = subtitle.rfind(separator, cut - 1)
	var count := subtitle.length()
	while count > 1 and not _fits(subtitle.substr(0, count)):
		count -= 1
	return PackedStringArray([subtitle.substr(0, count), subtitle.substr(count)])


func _fits(text_line: String) -> bool:
	var width := (
		_font.get_string_size(text_line, HORIZONTAL_ALIGNMENT_LEFT, -1, _subtitle_font_size()).x
	)
	return width <= _text_width()


func _draw() -> void:
	if _font == null:
		return
	var dim := disabled
	# 紋章は右側の透かし。**押す先が何なのかを絵でも示す**が、文字を邪魔しない濃さに留める。
	# ホバー中はわずかに明るく浮く(GameDesign.md 9章)。
	if emblem != null:
		draw_texture_rect(
			emblem,
			_emblem_rect(),
			false,
			Color(
				UiPalette.BRASS_HIGHLIGHT,
				EMBLEM_ALPHA * (0.4 if dim else 1.0) * (1.0 + HOVER_ALPHA_BOOST * _hover)
			)
		)
	var has_sub := not subtitle.is_empty()
	var title_y: float = _title_center() + float(title_size) * 0.36
	draw_string(
		_title_font if _title_font != null else _font,
		Vector2(padding, title_y),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		_text_width(),
		title_size,
		TITLE_DIM if dim else TITLE_COLOR
	)
	if has_sub:
		# 副題が変わった直後は光らせる(GameDesign.md 9章)。押さなくても変化が分かるように。
		var sub_color := SUB_ON_BRASS if primary else SUB_COLOR
		if subtitle_accent:
			sub_color = UiPalette.GLOW_AMBER
		sub_color = sub_color.lerp(Color(1, 1, 1), _subtitle_flash * 0.7)
		var sub_at := Vector2(padding, title_y + float(title_size) * 0.92)
		for row in _subtitle_rows():
			draw_string(
				_font,
				sub_at,
				row,
				HORIZONTAL_ALIGNMENT_LEFT,
				_text_width(),
				_subtitle_font_size(),
				SUB_DIM if dim else sub_color
			)
			sub_at.y += float(_subtitle_font_size()) * SUBTITLE_LINE_HEIGHT
	if badge_count > 0:
		var inset := BADGE_RADIUS * badge_scale + 4.0
		draw_badge(self, Vector2(size.x - inset, inset), badge_count, badge_scale)


## 未受取の数の印(GameDesign.md 9章)。右上の角へ赤い丸で数を打つ。
static func draw_badge(
	target: CanvasItem, at: Vector2, count: int, badge_scale_factor := 1.0
) -> void:
	var radius := BADGE_RADIUS * badge_scale_factor
	var font := ThemeDB.fallback_font
	if target is Control:
		var theme_font := (target as Control).get_theme_default_font()
		if theme_font != null:
			font = theme_font
	ShapePaint.circle(target.get_canvas_item(), at, radius + 2.0, Color(0.10, 0.07, 0.05, 0.9))
	ShapePaint.circle(target.get_canvas_item(), at, radius, BADGE_COLOR)
	var text := str(count)
	var font_size := roundi(BADGE_FONT_SIZE * badge_scale_factor)
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
