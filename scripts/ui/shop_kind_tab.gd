class_name ShopKindTab
extends Button
## ショップ左の品種タブ1つ(GameDesign.md 21章)。品種名と「所持 n / m」を出す。
## 選択中は塗りつぶした真鍮の面、それ以外は暗く凹んだパネル(9章の入口の強弱)。

const LABEL_FONT_SIZE := 19
const SUB_FONT_SIZE := 13
const TEXT_LEFT := 22.0
const LABEL_BASELINE_RATIO := 0.47
const SUB_BASELINE_RATIO := 0.78

var kind: ShopCatalog.Kind
var label_text := ""
var owned_count := 0
var total_count := 0
var active := false:
	set(value):
		active = value
		CodedButton.apply_styles(
			self, CodedButton.PRIMARY_ACTION_GROUP if active else CodedButton.WIDE_GROUP
		)
		queue_redraw()
var _font: Font


func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = get_theme_default_font()
	active = active


func _draw() -> void:
	if _font == null:
		return
	var main_color := UiPalette.OUTLINE_DARK if active else UiPalette.TEXT_OFFWHITE
	var sub_color := UiPalette.BRASS_PRESSED_DARK if active else UiPalette.TEXT_MUTED
	draw_string(
		_font,
		Vector2(TEXT_LEFT, size.y * LABEL_BASELINE_RATIO),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - TEXT_LEFT,
		LABEL_FONT_SIZE,
		main_color
	)
	draw_string(
		_font,
		Vector2(TEXT_LEFT, size.y * SUB_BASELINE_RATIO),
		"所持 %d / %d" % [owned_count, total_count],
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - TEXT_LEFT,
		SUB_FONT_SIZE,
		sub_color
	)
