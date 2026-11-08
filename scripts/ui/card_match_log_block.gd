class_name CardMatchLogBlock
extends RefCounted
## 対局ログの1ターンぶんの区画を組む(GameDesign.md 9章「結果とログ」)。
## 見出し(ターン番号・誰の番・減ったHP)、種類の札つきの行、原因の下へ字下げした結果の行。
## 行のカード名のホバー・タップは `CardMatchLog` が `wire` で受け持つ。

const FIRST_COLOR := UiPalette.GLOW_AMBER
const SECOND_COLOR := Color(0.5, 0.66, 0.9)
const DAMAGE_COLOR := Color(0.95, 0.42, 0.36)
const CARD_NAME_COLOR := UiPalette.GLOW_AMBER
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
const DAMAGE_BADGE := Color(0.5, 0.14, 0.12)
const HEAL_BADGE := Color(0.2, 0.42, 0.22)

const HEADER_FONT := 15
const WHO_FONT := 17
const ACTION_FONT := 17
const RESULT_FONT := 15
const BADGE_FONT := 14
const BADGE_SIZE := Vector2(30, 26)
const INDENT := 36.0
const ACCENT_WIDTH := 4
const CORNER := 6
const ROW_GAP := 4
const LATEST_FILL := Color(1, 1, 1, 0.07)
const PAST_FILL := Color(1, 1, 1, 0.035)
const BADGE_EDGE := Color(1, 1, 1, 0.18)


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
	var accent: Color = accents.get(side, UiPalette.TEXT_MUTED)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _block_style(accent, latest, scale))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(ROW_GAP * scale))
	box.add_child(column)
	column.add_child(_header(turn, names, accent, scale))
	var rows: Array = turn["rows"]
	if rows.is_empty() and latest:
		column.add_child(_label("まだ行動していない", RESULT_FONT * scale, UiPalette.TEXT_MUTED))
	for entry in rows:
		column.add_child(_row(entry, scale, wire))
	return box


static func _block_style(accent: Color, latest: bool, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = LATEST_FILL if latest else PAST_FILL
	style.border_color = accent
	style.border_width_left = int(ACCENT_WIDTH * scale)
	style.set_corner_radius_all(int(CORNER * scale))
	style.content_margin_left = 14 * scale
	style.content_margin_right = 12 * scale
	style.content_margin_top = 8 * scale
	style.content_margin_bottom = 10 * scale
	return style


static func _header(turn: Dictionary, names: Dictionary, accent: Color, scale: float) -> Control:
	var head := HBoxContainer.new()
	var number: int = turn["number"]
	if number > 0:
		head.add_child(_label("ターン%d  " % number, HEADER_FONT * scale, UiPalette.TEXT_MUTED))
		var who := _label("%sの番" % names.get(turn["side"], "?"), WHO_FONT * scale, accent)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(who)
	else:
		var start := _label("対局開始", WHO_FONT * scale, UiPalette.TEXT_MUTED)
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
		row.add_child(_label("└", RESULT_FONT * scale, UiPalette.TEXT_MUTED))
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
	var color := UiPalette.TEXT_MUTED if result else UiPalette.TEXT_OFFWHITE
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
			fill = DAMAGE_BADGE
		"heal":
			glyph = "+%d" % int(entry["amount"])
			fill = HEAL_BADGE
		_:
			var badge: Array = BADGES.get(kind, BADGES["note"])
			glyph = badge[0]
			fill = badge[1]
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = BADGE_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(5 * scale))
	plate.add_theme_stylebox_override("panel", style)
	plate.custom_minimum_size = BADGE_SIZE * scale
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := _label(glyph, BADGE_FONT * scale, UiPalette.TEXT_OFFWHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(label)
	return plate


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
