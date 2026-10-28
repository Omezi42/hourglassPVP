extends SceneTree
## 遠征の画面の合格基準(機械で測れるもの)を全状態・縦横で確かめる。見た目の良し悪しは人が判定する。
##   1. 押せるボタンは指カーソル・押下音とホバー音・ホバーで変わる見た目を持つ(GameDesign.md 9章「操作の手触り」)
##   2. 押せるボタンの高さ: 横は MIN_TAP_LANDSCAPE、縦は実寸で MIN_TAP_PORTRAIT 以上(9章「縦画面」)
##   3. 文字の実寸: 横は MIN_FONT_LANDSCAPE、縦は MIN_FONT_PORTRAIT 以上
##   4. 文字は画面の中に収まり、ほかの文字・ボタンと重ならない
## `scripts/ui/` を読むため `run_tests.gd` とは別に `tools/check.sh` から起動する。
## 引数 `-- landscape` / `-- portrait` で向きを絞る(省略で両方)。

const STATES: Array[String] = [
	"departure",
	"route",
	"route_mid",
	"route_deck",
	"dest_battle",
	"dest_gate",
	"dest_spring",
	"dest_workshop",
	"bundle",
	"boon",
	"workshop",
	"workshop_pick",
	"summary_lost",
	"summary_cleared",
]
const MIN_TAP_LANDSCAPE := 40.0
const MIN_TAP_PORTRAIT := 72.0
const MIN_FONT_LANDSCAPE := 13.0
const MIN_FONT_PORTRAIT := 20.0
## 文字の矩形どうしの重なりをこれ以下なら見逃す(字形の余白ぶん)。
const OVERLAP_TOLERANCE := 2.0
const SETTLE_FRAMES := 3

var _problems: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_spring_label()
	var args := OS.get_cmdline_user_args()
	var orientations: Array[bool] = [false, true]
	if args.has("landscape"):
		orientations = [false]
	elif args.has("portrait"):
		orientations = [true]
	for portrait in orientations:
		for state in STATES:
			await _audit(state, portrait)
	ScreenOrientation.force_portrait_for_test(false)
	if _problems.is_empty():
		print("solo ui audit passed")
	else:
		for line in _problems:
			print(line)
		print("solo ui audit FAILED: %d" % _problems.size())
	quit()


## 道の泉のラベルは深さと恩恵「深い泉」を合わせた回復量を出す(固定の8ではない。GameDesign.md 27章)。
func _check_spring_label() -> void:
	var run := SoloRun.create(CardCpuDecks.deck_ids()[0], 2, RandomNumberGenerator.new())
	run.boons.append("deep_spring")
	var view := SoloRouteView.new()
	root.add_child(view)
	view.show_data(run.route, run.floor, run.chosen, run.expert_from_floor(), run.spring_amount())
	var label := view._detail_label({"kind": SoloRun.Kind.SPRING})
	if label != "HP +%d" % run.spring_amount():
		_problems.append("泉のラベル「%s」が回復量 %d と合わない" % [label, run.spring_amount()])
	view.queue_free()


func _audit(state: String, portrait: bool) -> void:
	ScreenOrientation.force_portrait_for_test(portrait)
	var screen_size := Vector2(ScreenOrientation.base_size())
	var screen := SoloCaptureFixture.new()
	screen.size = screen_size
	root.add_child(screen)
	# `Main` は起動時に一度だけ全ボタンへ音をつなぐ。後から作る部品は自分でつなぐ必要がある。
	SoundBank.wire_tree(screen)
	screen.apply_orientation(portrait)
	screen.open()
	screen.stage(state)
	for i in SETTLE_FRAMES:
		await process_frame
	var tag := "%s/%s" % ["portrait" if portrait else "landscape", state]
	var texts: Array[Dictionary] = []
	var buttons: Array[Button] = []
	for layer in _front_layers(screen):
		_collect(layer, texts, buttons)
	if _front_layers(screen) == [screen]:
		texts = _without_hidden_route_labels(screen, texts)
	for button in buttons:
		_check_button(tag, button, portrait)
	var screen_rect := Rect2(Vector2.ZERO, screen_size)
	for t in texts:
		_check_text(tag, t, portrait, screen_rect)
	_check_overlaps(tag, texts)
	screen.queue_free()
	await process_frame


## 暗幕のオーバーレイ・縦の山札の板が出ていれば、その下は押せず読めないので測らない。
func _front_layers(screen: SoloCaptureFixture) -> Array[Node]:
	for overlay: Control in [screen._summary, screen._boon, screen._bundle, screen._workshop]:
		if overlay.visible:
			return [overlay]
	if screen._sheet_shade.visible:
		return [screen._status, screen._sheet_close]
	return [screen]


## 道の文字のうち、切り抜きの外・縦の詳細の板の後ろにあるものは見えないので測らない。
func _without_hidden_route_labels(
	screen: SoloCaptureFixture, texts: Array[Dictionary]
) -> Array[Dictionary]:
	var seen := screen.route_visible_rect().grow(1.0)
	var kept: Array[Dictionary] = []
	for t in texts:
		if t.has("node") or seen.encloses(t["rect"]):
			kept.append(t)
	return kept


func _collect(node: Node, texts: Array[Dictionary], buttons: Array[Button]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is CardView:
		return
	if node is Label:
		var label := node as Label
		if not label.text.is_empty():
			texts.append(_label_entry(label))
	elif node is Button:
		var button := node as Button
		if not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			buttons.append(button)
		if not button.text.is_empty():
			texts.append(_button_entry(button))
	if node is SoloRouteView:
		texts.append_array((node as SoloRouteView).label_boxes())
	for child in node.get_children():
		_collect(child, texts, buttons)


func _label_entry(label: Label) -> Dictionary:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var xf := label.get_global_transform()
	var zoom := xf.get_scale().y
	var line_h := font.get_height(font_size)
	var rect: Rect2
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var h := line_h * float(label.get_line_count())
		var top := 0.0
		if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
			top = (label.size.y - h) * 0.5
		rect = Rect2(0.0, top, label.size.x, h)
	else:
		var w := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var left := 0.0
		if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			left = (label.size.x - w) * 0.5
		elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			left = label.size.x - w
		var top := 0.0
		if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
			top = (label.size.y - line_h) * 0.5
		rect = Rect2(left, top, w, line_h)
	return {
		"name": label.text.left(16),
		"rect": Rect2(xf * rect.position, rect.size * zoom),
		"font_px": float(font_size) * zoom,
		"node": label,
	}


func _button_entry(button: Button) -> Dictionary:
	var xf := button.get_global_transform()
	return {
		"name": button.text,
		"rect": Rect2(xf.origin, button.size * xf.get_scale().y),
		"font_px": float(button.get_theme_font_size("font_size")) * xf.get_scale().y,
		"node": button,
	}


func _check_button(tag: String, button: Button, portrait: bool) -> void:
	var label := "%s: ボタン「%s」" % [tag, button.text if not button.text.is_empty() else button.name]
	if button.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_problems.append("%s が指カーソルにならない" % label)
	if not _has_sound(button.pressed) or not _has_sound(button.mouse_entered):
		_problems.append("%s に押下音・ホバー音がつながっていない" % label)
	var hover := button.get_theme_stylebox("hover")
	if hover is StyleBoxEmpty and not button.has_meta(SoloUiPaint.HOVER_VISUAL_META):
		_problems.append("%s はホバーで見た目が変わらない" % label)
	var height := button.size.y * button.get_global_transform().get_scale().y
	var need := MIN_TAP_PORTRAIT if portrait else MIN_TAP_LANDSCAPE
	if height + 0.5 < need:
		_problems.append("%s の高さ %.0fpx < %.0fpx" % [label, height, need])


func _has_sound(sig: Signal) -> bool:
	for c in sig.get_connections():
		var callable: Callable = c["callable"]
		if callable.get_method() in [&"play", &"_on_button_hovered"]:
			return true
	return false


func _check_text(tag: String, t: Dictionary, portrait: bool, screen_rect: Rect2) -> void:
	var need := MIN_FONT_PORTRAIT if portrait else MIN_FONT_LANDSCAPE
	if float(t["font_px"]) + 0.5 < need:
		_problems.append("%s: 文字「%s」が %.0fpx < %.0fpx" % [tag, t["name"], t["font_px"], need])
	var rect: Rect2 = t["rect"]
	if not screen_rect.grow(1.0).encloses(rect):
		_problems.append("%s: 文字「%s」が画面からはみ出す %s" % [tag, t["name"], rect])
	var node: Variant = t.get("node")
	# 収まらないぶんを「…」で切る文字は、幅を超えても読める形で出る。
	if (
		node is Label
		and (node as Label).autowrap_mode == TextServer.AUTOWRAP_OFF
		and (node as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
	):
		var label := node as Label
		var font := label.get_theme_font("font")
		var w := (
			font
			. get_string_size(
				label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")
			)
			. x
		)
		if w > label.size.x + 1.0:
			_problems.append("%s: 文字「%s」が枠の幅を超える" % [tag, t["name"]])


func _check_overlaps(tag: String, texts: Array[Dictionary]) -> void:
	for i in texts.size():
		var a: Rect2 = (texts[i]["rect"] as Rect2).grow(-OVERLAP_TOLERANCE)
		for j in range(i + 1, texts.size()):
			var b: Rect2 = (texts[j]["rect"] as Rect2).grow(-OVERLAP_TOLERANCE)
			if a.intersects(b) and not _nested(texts[i], texts[j]):
				_problems.append(
					"%s: 文字「%s」%s と「%s」%s が重なる" % [tag, texts[i]["name"], a, texts[j]["name"], b]
				)


## ボタンの文字とそのボタン自身は重なってよい。
func _nested(a: Dictionary, b: Dictionary) -> bool:
	return a.get("node") == b.get("node")
