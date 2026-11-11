class_name CardMatchLogBlock
extends RefCounted
## 対局ログの1ターンぶんの区画を組む(GameDesign.md 9章「結果とログ」)。
## 見出し(ターン番号・誰の番・減ったHP)、種類の札つきの行、原因の下へ字下げした結果の行。
## 行のカード名のホバー・タップは `CardMatchLog` が `wire` で受け持つ。

## 手番の色: 自分 = 砂 / 相手 = 朱(青はコスト・マナの色。9章)。
const FIRST_COLOR := UiPalette.SAND
const SECOND_COLOR := UiPalette.FOE
const DAMAGE_COLOR := UiPalette.HEALTH
const CARD_NAME_COLOR := UiPalette.GOLD
const NAME_OPEN := "「"
const NAME_CLOSE := "」"

## 原因の行の下へ字下げして続ける種別。
const CONSEQUENCES := ["death", "damage", "heal"]
## 種別 → [札の字, 札の色]。ダメージと回復は数値を札にする。
const BADGES := {
	"play": ["出", Color(0.44, 0.31, 0.24)],
	"cast": ["術", Color(0.36, 0.3, 0.55)],
	"flip": ["反", Color(0.25, 0.42, 0.45)],
	"flip_right": ["反", Color(0.25, 0.42, 0.45)],
	"attack": ["攻", Color(0.55, 0.28, 0.2)],
	"death": ["砕", Color(0.3, 0.27, 0.27)],
	"time_up": ["時", Color(0.35, 0.35, 0.38)],
	"end": ["決", Color(0.55, 0.4, 0.12)],
	"note": ["・", Color(0.3, 0.3, 0.32)],
}

const HEADER_FONT := UiPalette.T_SMALL
const WHO_FONT := UiPalette.T_BODY
const ACTION_FONT := UiPalette.T_BODY
const RESULT_FONT := UiPalette.T_SMALL
const BADGE_SIZE := Vector2(30, 26)
const INDENT := 36.0
const ACCENT_WIDTH := 4.0
const ROW_GAP := 4
## 区画の内側の余白(左, 右, 上, 下)。
const PAD_LEFT := 14.0
const PAD_RIGHT := 12.0
const PAD_TOP := 8.0
const PAD_BOTTOM := 10.0
## 数値の宝石の色の明るい側へ寄せる量。
const BADGE_LIGHTEN := 0.25


## `turn` は {number, side, rows}。`names` は手番 → 「あなた」等、`accents` は手番 → 色。
## `wire(label, cards)` は行の `RichTextLabel` にカード名の操作をつなぐ。
static func build(
	turn: Dictionary,
	names: Dictionary,
	accents: Dictionary,
	latest: bool,
	scale: float,
	wire: Callable
) -> Control:
	var side: int = turn["side"]
	var accent: Color = accents.get(side, UiPalette.MUTED)
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_left", int(PAD_LEFT * scale))
	box.add_theme_constant_override("margin_right", int(PAD_RIGHT * scale))
	box.add_theme_constant_override("margin_top", int(PAD_TOP * scale))
	box.add_theme_constant_override("margin_bottom", int(PAD_BOTTOM * scale))
	box.draw.connect(func() -> void: _draw_block(box, accent, latest, scale))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(ROW_GAP * scale))
	box.add_child(column)
	column.add_child(_header(turn, names, accent, scale))
	var rows: Array = turn["rows"]
	if rows.is_empty() and latest:
		column.add_child(_label("まだ行動していない", RESULT_FONT * scale, UiPalette.MUTED))
	for entry in rows:
		column.add_child(_row(entry, scale, wire))
	return box


## 区画の背面。いまのターンは彫り込みに沈め、過去のターンは下の罫線だけで区切る。
## 左の縦の帯は手番の色(自分 = 砂 / 相手 = 朱)。
static func _draw_block(box: Control, accent: Color, latest: bool, scale: float) -> void:
	var ci := box.get_canvas_item()
	var rect := Rect2(Vector2.ZERO, box.size)
	if latest:
		UiKit.well(ci, rect, UiKit.radius(rect) * 0.5)
	else:
		UiKit.rule(ci, Vector2(0.0, rect.size.y), rect.size)
	var bar := Rect2(
		rect.position + Vector2(0.0, PAD_TOP * scale * 0.5),
		Vector2(ACCENT_WIDTH * scale, rect.size.y - PAD_TOP * scale)
	)
	UiKit.fill(ci, UiKit.rr(bar, bar.size.x * 0.5), accent)


static func _header(turn: Dictionary, names: Dictionary, accent: Color, scale: float) -> Control:
	var head := HBoxContainer.new()
	var number: int = turn["number"]
	if number > 0:
		head.add_child(_label("ターン%d  " % number, HEADER_FONT * scale, UiPalette.MUTED))
		var who := _label("%sの番" % names.get(turn["side"], "?"), WHO_FONT * scale, accent)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(who)
	else:
		var start := _label("対局開始", WHO_FONT * scale, UiPalette.MUTED)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(start)
	var losses := {}
	for entry in turn["rows"]:
		if entry["kind"] == "damage":
			losses[entry["side"]] = losses.get(entry["side"], 0) + int(entry["amount"])
	for loser in losses:
		head.add_child(
			_label(
				"  %s −%d" % [names.get(loser, "?"), losses[loser]],
				HEADER_FONT * scale,
				DAMAGE_COLOR
			)
		)
	return head


static func _row(entry: Dictionary, scale: float, wire: Callable) -> Control:
	var kind: String = entry["kind"]
	var result := CONSEQUENCES.has(kind)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * scale))
	if result:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(INDENT * scale, 0)
		row.add_child(spacer)
		row.add_child(_label("└", RESULT_FONT * scale, UiPalette.MUTED))
	row.add_child(_badge(entry, scale))
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.meta_underlined = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_font_size_override(
		"normal_font_size", int((RESULT_FONT if result else ACTION_FONT) * scale)
	)
	var color := UiPalette.MUTED if result else UiPalette.IVORY
	text.text = (
		"[color=#%s]%s[/color]" % [color.to_html(false), markup(entry["line"], entry["cards"])]
	)
	wire.call(text, entry["cards"])
	row.add_child(text)
	return row


static func _badge(entry: Dictionary, scale: float) -> Control:
	var kind: String = entry["kind"]
	var glyph: String
	var fill: Color
	match kind:
		"damage":
			glyph = "−%d" % int(entry["amount"])
			fill = UiPalette.HEALTH_DEEP
		"heal":
			glyph = "+%d" % int(entry["amount"])
			fill = UiPalette.GOOD.darkened(0.45)
		_:
			var badge: Array = BADGES.get(kind, BADGES["note"])
			glyph = badge[0]
			fill = badge[1]
	var plate := Control.new()
	plate.custom_minimum_size = BADGE_SIZE * scale
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(func() -> void: _draw_badge(plate, glyph, fill))
	return plate


## 種類の札: 数値の宝石の面に字を載せる(行の先頭の目印)。
static func _draw_badge(plate: Control, glyph: String, fill: Color) -> void:
	var ci := plate.get_canvas_item()
	var rad := minf(plate.size.x, plate.size.y) * 0.5
	var center := plate.size * 0.5
	UiKit.gem(ci, center, rad, fill.lightened(BADGE_LIGHTEN), fill)
	UiKit.gem_text(ci, plate.get_theme_default_font(), center, rad, glyph, UiPalette.IVORY)


static func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(font_size))
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## 「」で囲んだカード名を、出現順に `cards` と対応させて色付きのリンクにする。
## 控えより多い「」(カード以外の引用)は色を付けずにそのまま出す。
static func markup(line: String, cards: Array) -> String:
	var out := ""
	var rest := line
	var index := 0
	while index < cards.size():
		var open := rest.find(NAME_OPEN)
		var close := rest.find(NAME_CLOSE, open + 1)
		if open < 0 or close < 0:
			break
		var card_name := rest.substr(open, close - open + 1)
		out += _escape(rest.left(open))
		out += (
			"[url=%d][color=#%s]%s[/color][/url]"
			% [index, CARD_NAME_COLOR.to_html(false), _escape(card_name)]
		)
		rest = rest.substr(close + 1)
		index += 1
	return out + _escape(rest)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
