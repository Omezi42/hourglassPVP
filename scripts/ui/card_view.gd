class_name CardView
extends Control
## 砂時計1体の表示(GameDesign.md 9章「対局画面」)。
##
## **手札と場で見た目が違う**。手札はまだ手に持っている札なのでカードの枠を持つが、
## 場に出た瞬間に枠を捨て、台座の上に立つ砂時計そのものになる。砂時計はそれ自体が
## 状態を表示する器(上の砂=体力 / 下の砂=攻撃力)であり、枠へ閉じ込めると絵が小さくなって
## 砂の量という最も重要な情報チャネルが潰れるため。
##
## 数値の配置は既存のDCGの慣習に合わせる。手札=コスト左上 / 総量右下、
## 場=攻撃力左下 / 体力右下(場ではコストを出さない)。

signal pressed(view: CardView)

## 砂の動きの演出。**消える砂と落ちる砂は必ず描き分ける**(GameDesign.md 9章)。
## この2つを取り違えるとルールを誤解するため、演出上もっとも重要な区別として扱う。
enum Effect {
	NONE,
	## ダメージ。砂は消える(総量が減る)ので、砕けて外へ散る。
	SHATTER,
	## ターン終了の1粒。砂は落ちる(総量は変わらない)ので、下の部屋へ流れる。
	DROP,
}

enum Mode {
	## 場に出ている砂時計。枠を持たず、台座の上に立つ物体として描く。
	BOARD,
	## 手札。カードの枠を持ち、コストと総量(=場に出たときの体力)を出す。
	HAND,
}

const BOARD_SIZE_PX := Vector2(128, 168)
const HAND_SIZE_PX := Vector2(118, 158)
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const ATTACK_ORANGE := Color(0.95, 0.62, 0.2, 1.0)
const HEALTH_RED := Color(0.9, 0.3, 0.26, 1.0)
## 選択中の枠。守護の真鍮色と取り違えないよう、別系統の色にする。
const SELECT_CYAN := Color(0.55, 0.9, 1.0, 1.0)
const SAND_AMBER := Color(0.93, 0.78, 0.42, 1.0)
const SHATTER_DURATION := 0.42
const DROP_DURATION := 0.45
const SHARD_COUNT := 9
## 文字を描くときに空ける左右の余白と、縮められる下限のフォントサイズ。
const TEXT_MARGIN := 5.0
const MIN_FONT_SIZE := 9

const STAT_RADIUS := 15.0
const GUARD_BORDER := 4.0
const NORMAL_BORDER := 2.0

## 場の砂時計。台座は扁平な楕円として描き、その上に絵を載せる。
const PEDESTAL_CENTER_Y := 122.0
const PEDESTAL_RADIUS := Vector2(54.0, 13.0)
const PEDESTAL_RING_WIDTH := 2.0
const PEDESTAL_GUARD_RING_WIDTH := 4.5
const BOARD_ART_SIDE := 112.0
## 出したターンの砂時計は僅かに沈んで見せる(GameDesign.md 9章)。
const SUMMONED_SINK := 3.0
## 紋章(GameDesign.md 9章)。砂時計の絵は全種で共通の1枚を色違いにしたものなので、
## **どのカードかを見分けているのはこの紋章**になる。台座の正面へ真鍮のメダルとして
## 据える。駒の背後へ大きな透かしを敷く案もあったが、128x168の枠では砂時計の絵が
## ほぼ全面を占めるため、はみ出した縁だけが見えて散らかった(実際に描いて確認した)。
const EMBLEM_PLAQUE_RADIUS := 16.0
const EMBLEM_PLAQUE_SIDE := 21.0
## 反転の演出(GameDesign.md 9章)。**反転はゲームの中心となる行動であるため、
## 演出は他より作り込む。**場のカードが枠を持たない物体になったことで、
## 砂時計そのものを持ち上げて裏返す動きが素直に描ける。
const FLIP_DURATION := 0.5
const FLIP_LIFT := 28.0
## 着地の衝撃波を出し始める進捗。
const FLIP_LAND_AT := 0.82

## 手札のカード。
const HAND_CORNER := 10.0
const HAND_ART_SIDE := 92.0
## 手札は紙の札なので、紋章は台座ではなく**封蝋の印**として押す。
const HAND_SEAL_RADIUS := 13.0
const HAND_SEAL_SIDE := 16.0

var mode: int = Mode.BOARD
## 表示するカード。手札はこれだけ、盤面は unit も併せて持つ。
var card: CardData
var unit: CardInstance
## 出せる/選べる状態か。false なら暗く表示する。
var enabled := true
## 選択中(枠・台座の輪を強調する)。
var selected := false
## このターンに行動を終えている(彩度を落とす)。
var exhausted := false
## 右上へ出す小さな添え字(デッキ編集の「2/2」など)。空なら出さない。
var badge := ""

var _font: Font
var _hovering := false
var _tracker := PressTracker.new()
var _effect: int = Effect.NONE
var _effect_progress := 0.0
var _effect_amount := 0
var _effect_tween: Tween
## 反転の進捗(0.0〜1.0)。負のときは反転していない。
var _flip_progress := -1.0
var _flip_tween: Tween


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var theme_font := get_theme_default_font()
	if theme_font != null:
		_font = theme_font
	custom_minimum_size = HAND_SIZE_PX if mode == Mode.HAND else BOARD_SIZE_PX
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## 場の砂時計として表示する。
func show_unit(p_unit: CardInstance) -> void:
	mode = Mode.BOARD
	unit = p_unit
	card = null if p_unit == null else p_unit.data
	custom_minimum_size = BOARD_SIZE_PX
	queue_redraw()


## 手札のカードとして表示する。
func show_card(p_card: CardData, p_enabled: bool) -> void:
	mode = Mode.HAND
	unit = null
	card = p_card
	enabled = p_enabled
	custom_minimum_size = HAND_SIZE_PX
	queue_redraw()


## ダメージを受けた:砂が砕けて散る。
func play_shatter(amount: int) -> void:
	_effect_amount = amount
	_start_effect(Effect.SHATTER, SHATTER_DURATION)


## 反転した:持ち上がって裏返り、着地する。
func play_flip() -> void:
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_progress = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_method(_set_flip_progress, 0.0, 1.0, FLIP_DURATION)
	_flip_tween.finished.connect(_on_flip_finished)


func _set_flip_progress(value: float) -> void:
	_flip_progress = value
	queue_redraw()


func _on_flip_finished() -> void:
	_flip_progress = -1.0
	queue_redraw()


## ターン終了の1粒:砂が下の部屋へ流れる。
func play_drop() -> void:
	_start_effect(Effect.DROP, DROP_DURATION)


func _start_effect(kind: int, duration: float) -> void:
	if _effect_tween != null and _effect_tween.is_valid():
		_effect_tween.kill()
	_effect = kind
	_effect_progress = 0.0
	_effect_tween = create_tween()
	_effect_tween.tween_method(_set_effect_progress, 0.0, 1.0, duration)
	_effect_tween.finished.connect(_on_effect_finished)


func _set_effect_progress(value: float) -> void:
	_effect_progress = value
	queue_redraw()


func _on_effect_finished() -> void:
	_effect = Effect.NONE
	queue_redraw()


func clear() -> void:
	card = null
	unit = null
	queue_redraw()


func is_empty() -> bool:
	return card == null


func _on_mouse_entered() -> void:
	_hovering = true
	if enabled:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovering = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# **場の空き枠も押せなければならない。**カードを出す先はまさに空き枠であり、
	# ここで弾くと対局開始時(場が全て空)に1枚も出せなくなる。手札の空きスロットは
	# 呼び出し側が visible = false にしているため、そもそも入力が届かない。
	if card == null and mode == Mode.HAND:
		return
	var result := _tracker.feed(event, size)
	if result == PressTracker.Result.CONFIRMED:
		pressed.emit(self)


func _draw() -> void:
	if mode == Mode.BOARD:
		_draw_board_unit()
	else:
		_draw_hand_card()
	if _effect != Effect.NONE:
		_draw_effect()


func _tint() -> Color:
	if not enabled or exhausted:
		return Color(0.55, 0.55, 0.6, 1)
	return Color(1, 1, 1, 1)


# --- 場の砂時計(枠なし) -----------------------------------------------


func _draw_board_unit() -> void:
	_draw_pedestal_base()
	if card == null:
		_draw_pedestal_ring()
		return
	var tint := _tint()
	var sink := SUMMONED_SINK if unit != null and unit.summoned_this_turn else 0.0
	_draw_board_art(tint, sink)
	# 輪は絵の後に描く。守護(太い真鍮の輪)と選択中(水色の輪)は駒が立っていても
	# 必ず見えなければならないため、絵の下へ隠してはいけない。
	_draw_pedestal_ring()
	_draw_pedestal_plaque(tint)
	if _hovering and enabled:
		_draw_pedestal_glow(Color(1, 1, 1, 0.1))
	_draw_board_stats()
	_draw_board_labels(tint)


## 台座。空き枠でも常に描き、そこへ砂時計が立つ場所であることを示す。
func _draw_pedestal_base() -> void:
	var ci := get_canvas_item()
	var center := Vector2(size.x * 0.5, PEDESTAL_CENTER_Y)
	UiPaint.fill_ellipse(ci, center, PEDESTAL_RADIUS * 1.12, Color(0.04, 0.03, 0.05, 0.3), 32)
	UiPaint.fill_ellipse(ci, center, PEDESTAL_RADIUS, Color(0.24, 0.19, 0.18, 0.45), 32)
	UiPaint.fill_ellipse(
		ci, center, PEDESTAL_RADIUS * 0.66, Color(UiPalette.PEDESTAL_DEFAULT_ACCENT, 0.14), 32
	)


## 台座の輪。守護は太い真鍮にする(手札の「枠を太くする」に対応。GameDesign.md 9章)。
func _draw_pedestal_ring() -> void:
	var center := Vector2(size.x * 0.5, PEDESTAL_CENTER_Y)
	var guard := card != null and card.has_keyword(CardEnums.Keyword.GUARD)
	var color := UiPalette.BRASS_MID
	var width := PEDESTAL_RING_WIDTH
	if selected:
		color = SELECT_CYAN
		width = PEDESTAL_GUARD_RING_WIDTH
	elif guard:
		color = UiPalette.BRASS_HIGHLIGHT
		width = PEDESTAL_GUARD_RING_WIDTH
	elif card == null:
		color = Color(UiPalette.BRASS_MID, 0.6)
	UiPaint.draw_ellipse_ring(get_canvas_item(), center, PEDESTAL_RADIUS, color, width, 40)


func _draw_pedestal_glow(color: Color) -> void:
	UiPaint.fill_ellipse(
		get_canvas_item(),
		Vector2(size.x * 0.5, PEDESTAL_CENTER_Y),
		PEDESTAL_RADIUS * 0.9,
		color,
		32
	)


## 台座の正面に彫り込んだ銘板。ここだけは濃く出し、近づいたときに
## 「この駒が何者か」を確定できるようにする。
func _draw_pedestal_plaque(tint: Color) -> void:
	if card == null or card.emblem == null:
		return
	var ci := get_canvas_item()
	# 台座の輪より少し上へ据える。下げると名前の行に掛かる。
	var center := Vector2(size.x * 0.5, PEDESTAL_CENTER_Y - 4.0)
	UiPaint.fill_circle(ci, center, EMBLEM_PLAQUE_RADIUS, Color(0.08, 0.06, 0.05, 0.85), 24)
	UiPaint.fill_circle(ci, center, EMBLEM_PLAQUE_RADIUS - 1.5, UiPalette.BRASS_MID * tint, 24)
	var half := Vector2(EMBLEM_PLAQUE_SIDE, EMBLEM_PLAQUE_SIDE) * 0.5
	# 影を1pxずらして重ね、真鍮へ彫り込まれたように見せる。
	draw_texture_rect(
		card.emblem,
		Rect2(center - half + Vector2(0.0, 1.0), half * 2.0),
		false,
		Color(0.08, 0.06, 0.04, 0.7)
	)
	draw_texture_rect(
		card.emblem,
		Rect2(center - half, half * 2.0),
		false,
		Color(UiPalette.BRASS_HIGHLIGHT, 0.95) * tint
	)
	UiPaint.draw_ring(ci, center, EMBLEM_PLAQUE_RADIUS, UiPalette.BRASS_HIGHLIGHT * tint, 1.0, 24)


func _draw_board_art(tint: Color, sink: float) -> void:
	var texture := _icon()
	if texture == null:
		return
	var pos := Vector2((size.x - BOARD_ART_SIDE) * 0.5, PEDESTAL_CENTER_Y + 4.0 - BOARD_ART_SIDE)
	var rect := Rect2(pos + Vector2(0, sink), Vector2(BOARD_ART_SIDE, BOARD_ART_SIDE))
	if _flip_progress >= 0.0:
		_draw_flipping_art(texture, rect, tint)
	else:
		draw_texture_rect(texture, rect, false, tint)
	# 硝子は枠ではなくガラスそのものへ膜を掛ける(GameDesign.md 9章)。
	if unit != null and unit.glass_intact:
		UiPaint.fill_ellipse(
			get_canvas_item(), rect.get_center(), rect.size * 0.42, Color(0.6, 0.85, 1.0, 0.16), 28
		)


## 反転中の絵。持ち上げながら縦に潰していき、真横を向いた瞬間(進捗0.5)に
## 厚みだけの線になり、そこから裏返って戻る。同時にガラスと砂の反射を重ねる。
func _draw_flipping_art(texture: Texture2D, rect: Rect2, tint: Color) -> void:
	var turn := absf(cos(PI * _flip_progress))
	var lift := sin(PI * _flip_progress) * FLIP_LIFT
	var center := rect.get_center() - Vector2(0.0, lift)
	var half := Vector2(rect.size.x * 0.5, rect.size.y * 0.5 * maxf(turn, 0.02))
	draw_texture_rect(texture, Rect2(center - half, half * 2.0), false, tint)
	var sheen := sin(PI * _flip_progress)
	UiPaint.fill_ellipse(
		get_canvas_item(), center, half * 0.9, Color(1.0, 0.94, 0.78, 0.3 * sheen), 28
	)
	if _flip_progress >= FLIP_LAND_AT:
		_draw_flip_landing()


## 着地の衝撃波。台座と同じ扁平な楕円を外へ広げる。
func _draw_flip_landing() -> void:
	var ratio := (_flip_progress - FLIP_LAND_AT) / (1.0 - FLIP_LAND_AT)
	var radius := PEDESTAL_RADIUS * (1.0 + 0.5 * ratio)
	UiPaint.draw_ellipse_ring(
		get_canvas_item(),
		Vector2(size.x * 0.5, PEDESTAL_CENTER_Y),
		radius,
		Color(UiPalette.PEDESTAL_DEFAULT_ACCENT, 0.7 * (1.0 - ratio)),
		3.0,
		40
	)


## 攻撃力=左下 / 体力=右下。台座の高さに合わせて左右へ振り分ける。
func _draw_board_stats() -> void:
	if unit == null:
		return
	var y := PEDESTAL_CENTER_Y + 6.0
	_stat(Vector2(STAT_RADIUS + 2.0, y), unit.attack, ATTACK_ORANGE)
	_stat(Vector2(size.x - STAT_RADIUS - 2.0, y), unit.health, HEALTH_RED)


func _draw_board_labels(tint: Color) -> void:
	_centered_text(card.display_name, 14, size.y - 18.0, UiPalette.TEXT_OFFWHITE * tint)
	var note := _keyword_text()
	if not note.is_empty():
		_centered_text(note, 12, size.y - 3.0, UiPalette.BRASS_HIGHLIGHT * tint)


# --- 手札のカード -------------------------------------------------------


func _draw_hand_card() -> void:
	if card == null:
		_draw_empty()
		return
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var tint := _tint()
	var points := UiPaint.rounded_rect_points_uniform(rect, HAND_CORNER, 6)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, Color(0.23, 0.2, 0.17, 1.0) * tint], [1.0, Color(0.11, 0.1, 0.09, 1.0) * tint]]
	)
	var guard := card.has_keyword(CardEnums.Keyword.GUARD)
	var border := UiPalette.BRASS_MID
	if selected:
		border = SELECT_CYAN
	elif guard:
		border = UiPalette.BRASS_HIGHLIGHT
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border, GUARD_BORDER if guard or selected else NORMAL_BORDER, true)
	_draw_hand_art(tint)
	_draw_hand_seal(tint)
	_draw_hand_labels(tint)
	_draw_hand_stats()
	if not badge.is_empty():
		_draw_badge(rect)
	if _hovering and enabled:
		UiPaint.fill_gradient_polygon(
			ci, points, rect, [[0.0, Color(1, 1, 1, 0.07)], [1.0, Color(1, 1, 1, 0.03)]]
		)


func _draw_hand_art(tint: Color) -> void:
	var texture := _icon()
	if texture == null:
		return
	var pos := Vector2((size.x - HAND_ART_SIDE) * 0.5, 9.0)
	draw_texture_rect(texture, Rect2(pos, Vector2(HAND_ART_SIDE, HAND_ART_SIDE)), false, tint)


## 封蝋の印。手札は紙の札であるため、台座の銘板ではなく蝋で押した印として出す。
func _draw_hand_seal(tint: Color) -> void:
	if card.emblem == null:
		return
	var ci := get_canvas_item()
	var center := Vector2(HAND_SEAL_RADIUS + 4.0, size.y - HAND_SEAL_RADIUS - 4.0)
	UiPaint.fill_circle(ci, center, HAND_SEAL_RADIUS + 1.0, Color(0.08, 0.05, 0.04, 0.8), 24)
	UiPaint.fill_circle(ci, center, HAND_SEAL_RADIUS, UiPalette.BRASS_MID * tint, 24)
	var half := Vector2(HAND_SEAL_SIDE, HAND_SEAL_SIDE) * 0.5
	draw_texture_rect(
		card.emblem,
		Rect2(center - half + Vector2(0.0, 1.0), half * 2.0),
		false,
		Color(0.08, 0.05, 0.03, 0.7)
	)
	draw_texture_rect(
		card.emblem, Rect2(center - half, half * 2.0), false, UiPalette.BRASS_HIGHLIGHT * tint
	)


func _draw_hand_labels(tint: Color) -> void:
	_centered_text(card.display_name, 14, 118.0, UiPalette.TEXT_OFFWHITE * tint)
	var note := _keyword_text()
	if not note.is_empty():
		_centered_text(note, 12, 134.0, UiPalette.BRASS_HIGHLIGHT * tint)


## コスト=左上 / 総量=右下。
func _draw_hand_stats() -> void:
	_stat(Vector2(STAT_RADIUS + 3.0, STAT_RADIUS + 3.0), card.cost, MANA_BLUE)
	_stat(
		Vector2(size.x - STAT_RADIUS - 3.0, size.y - STAT_RADIUS - 3.0), card.total_sand, HEALTH_RED
	)


# --- 共通 ---------------------------------------------------------------


## 名前の下の1行。**語として見せるキーワードだけを語で出し**、それ以外は短い言い換えで
## 書く(GameDesign.md 6章)。1行しか無いので、全文は詳細パネルに任せる。
func _keyword_text() -> String:
	var words: PackedStringArray = []
	for keyword in card.named_keywords():
		words.append(CardEnums.keyword_name(keyword))
	for keyword in card.plain_keywords():
		words.append(CardEnums.keyword_short_text(keyword))
	if words.is_empty() and not card.rules_text.is_empty():
		words.append(CardEnums.trigger_name(card.effects[0].trigger))
	return " ".join(words)


## 体力と攻撃力の比で3枚を切り替える(GameDesign.md 9章)。手札は常に上向き。
func _icon() -> Texture2D:
	if unit == null:
		return card.icon_upright
	if unit.attack > unit.health:
		return card.icon_fallen
	if unit.attack >= unit.health - 1:
		return card.icon_falling
	return card.icon_upright


func _draw_effect() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if mode == Mode.BOARD:
		rect = Rect2(
			Vector2((size.x - BOARD_ART_SIDE) * 0.5, PEDESTAL_CENTER_Y + 4.0 - BOARD_ART_SIDE),
			Vector2(BOARD_ART_SIDE, BOARD_ART_SIDE)
		)
	if _effect == Effect.SHATTER:
		_draw_shatter(rect)
	else:
		_draw_drop(rect)


## 砕けて散る:中心から破片が外へ飛び、赤みを帯びて消える。
func _draw_shatter(rect: Rect2) -> void:
	var center := rect.position + rect.size * Vector2(0.5, 0.45)
	var fade := 1.0 - _effect_progress
	var reach := rect.size.x * (0.18 + 0.42 * _effect_progress)
	var shards: int = SHARD_COUNT + mini(_effect_amount, 6)
	for i in shards:
		var angle := TAU * float(i) / float(shards)
		var to := center + Vector2(cos(angle), sin(angle) * 0.8) * reach
		var shard_size := 4.0 * fade + 1.0
		draw_circle(to, shard_size, Color(0.95, 0.5, 0.4, fade * 0.9))
	draw_rect(rect, Color(1.0, 0.35, 0.3, fade * 0.18))


## 下の部屋へ流れる:中央を細い砂の筋が下りていく。総量は変わらない。
func _draw_drop(rect: Rect2) -> void:
	var x := rect.position.x + rect.size.x * 0.5
	var top := rect.position.y + rect.size.y * 0.2
	var bottom := rect.position.y + rect.size.y * 0.78
	var head: float = lerpf(top, bottom, _effect_progress)
	draw_line(Vector2(x, top), Vector2(x, head), Color(SAND_AMBER, 0.55), 3.0)
	for i in 3:
		var offset := float(i) * 6.0
		var y: float = head - offset
		if y < top:
			continue
		draw_circle(Vector2(x, y), 3.0 - i * 0.6, Color(SAND_AMBER, 0.9 - i * 0.25))
	if _effect_progress > 0.85:
		var glow := (_effect_progress - 0.85) / 0.15
		draw_circle(Vector2(x, bottom), 8.0 * glow, Color(SAND_AMBER, 0.35 * (1.0 - glow)))


func _draw_badge(rect: Rect2) -> void:
	var width := _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12.0
	var chip := Rect2(rect.size.x - width - 5, 5, width, 22)
	draw_rect(chip, Color(0.08, 0.07, 0.06, 0.92))
	draw_rect(chip, UiPalette.BRASS_HIGHLIGHT, false, 1.0)
	draw_string(
		_font,
		chip.position + Vector2(6, 17),
		badge,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		UiPalette.BRASS_HIGHLIGHT
	)


func _draw_empty() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color := SELECT_CYAN if selected else Color(0.3, 0.28, 0.3, 0.5)
	_dashed_rect(rect, color)


func _stat(center: Vector2, value: int, color: Color) -> void:
	draw_circle(center, STAT_RADIUS, Color(0.08, 0.07, 0.06, 0.95))
	draw_arc(center, STAT_RADIUS, 0.0, TAU, 24, color, 2.5)
	var text := str(value)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(
		_font, center + Vector2(-width * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color
	)


## カードの幅に収まらない文字列は、収まるまでフォントを縮めて描く。
## 語にしないキーワードは短い言い換えとはいえ語より長く、カードの幅は118pxしかないため。
func _centered_text(text: String, font_size: int, baseline: float, color: Color) -> void:
	var limit := size.x - TEXT_MARGIN * 2.0
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width > limit and font_size > MIN_FONT_SIZE:
		font_size -= 1
		width = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		_font,
		Vector2((size.x - width) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var x := rect.position.x
	while x < rect.end.x:
		var to := minf(x + 5, rect.end.x)
		draw_line(Vector2(x, rect.position.y), Vector2(to, rect.position.y), color, 2.0)
		draw_line(Vector2(x, rect.end.y), Vector2(to, rect.end.y), color, 2.0)
		x += 10.0
	var y := rect.position.y
	while y < rect.end.y:
		var to := minf(y + 5, rect.end.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, to), color, 2.0)
		draw_line(Vector2(rect.end.x, y), Vector2(rect.end.x, to), color, 2.0)
		y += 10.0
