extends Control
## カードの能力の実演(CardEffectPreview)をGIFの素材フレームとして書き出す。
## 詳細パネルで動いているものをそのまま録るため、ゲーム内と実演が食い違わない。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を必ず付ける):
##   godot --path . --write-movie scratchpad/fx/f.png --fixed-fps 15
##     res://tools/record_effect_gif.tscn -- poison
##
## GIFへの変換(1280x720で書き出されるため中央のパネルを切り抜く):
##   magick -delay 6.67 -loop 0 scratchpad/fx/f0*.png -crop 600x340+340+190 +repage
##     -colors 64 -layers OptimizeFrame effect.gif

const PANEL := Vector2(600.0, 340.0)
const PREVIEW := Vector2(520.0, 250.0)
## CardEffectPreview.DEFAULT_DURATION と同じ。1段あたりの尺
const STAGE_SECONDS := 4.4

var _t := 0.0
var _end := STAGE_SECONDS


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = PANEL
	position = ((Vector2(1280.0, 720.0) - PANEL) * 0.5).floor()

	var args := OS.get_cmdline_user_args()
	var card_id: String = args[0] if args.size() > 0 else "sand"
	var card: CardData = load("res://data/cards/%s.tres" % card_id)
	if card == null:
		push_error("カードが見つかりません: %s" % card_id)
		get_tree().quit(1)
		return

	# 1周ぶんだけ録る。GIFを繋いだときに継ぎ目が出ないようにするため
	_end = STAGE_SECONDS * maxf(1.0, float(_stage_count(card)))

	var preview := CardEffectPreview.new()
	preview.custom_minimum_size = PREVIEW
	preview.size = PREVIEW
	preview.position = ((PANEL - PREVIEW) * 0.5).floor()
	add_child(preview)
	preview.show_card(card)


## show_card() が組む台本の段数を数える(尺を決めるためだけに使う)。
func _stage_count(card: CardData) -> int:
	var count := card.keywords.size()
	for effect in card.effects:
		if effect == null:
			continue
		count += 1
		if effect.trigger == CardEnums.Trigger.ON_FLIP:
			count += 1
	return maxi(count, 1)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _end:
		get_tree().quit()


func _draw() -> void:
	# ゲームの詳細パネルと同じ地(スレートのグラデーション + 真鍮の枠)
	var rect := Rect2(Vector2.ZERO, PANEL)
	for i in 48:
		var t := float(i) / 47.0
		var band := Rect2(0.0, t * PANEL.y, PANEL.x, PANEL.y / 48.0 + 1.0)
		draw_rect(band, UiPalette.PANEL_SLATE_TOP.lerp(UiPalette.PANEL_SLATE_BOTTOM, t))
	draw_rect(rect, UiPalette.BRASS_DARK, false, 6.0)
	draw_rect(rect.grow(-6.0), UiPalette.BRASS_HIGHLIGHT, false, 2.0)
