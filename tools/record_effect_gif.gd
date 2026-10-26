extends Control
## カードの能力の実演(CardEffectPreview)をGIFの素材フレームとして書き出す。
## 図鑑で動いているもの(本物の対局画面の切り抜き)をそのまま録るため、ゲーム内と実演が食い違わない。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を必ず付ける):
##   godot --path . --write-movie scratchpad/fx/f.png --fixed-fps 10
##     res://tools/record_effect_gif.tscn -- poison scratchpad/fx/crop.txt
##
## 2つ目の引数のファイルへ「切り抜く矩形(magick の WxH+X+Y)」と「録り始めのコマ番号」を
## 1行ずつ書く。GIFへの変換は tools/discord/build_effect_gif.sh が行う。

## 実演の幅。高さは盤面の切り抜きの比率から決める。
const PREVIEW_WIDTH := 480.0
## 実演が枠へ最初の絵を映すまでに要るフレーム数(それより前は灰色の空のコマ)。
const WARMUP_FRAMES := 3

var _preview: CardEffectPreview


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	anchor_right = 1.0
	anchor_bottom = 1.0
	var args := OS.get_cmdline_user_args()
	var card: CardData = CardLibrary.find_by_id(args[0] if args.size() > 0 else "sand")
	if card == null:
		push_error("カードが見つかりません: %s" % args)
		get_tree().quit(1)
		return
	var info_path: String = args[1] if args.size() > 1 else ""
	# 色変換の焼き付けを待ってから組む(Pitfalls.md / HourglassArt 冒頭のコメント)。
	await HourglassArt.ensure_ready_and_wait(self)
	SoundBank.ensure_ready(self)

	_preview = CardEffectPreview.new()
	add_child(_preview)
	var crop := _preview._crop()
	var preview_size := Vector2(PREVIEW_WIDTH, PREVIEW_WIDTH * crop.size.y / crop.size.x).floor()
	_preview.custom_minimum_size = preview_size
	_preview.size = preview_size
	_preview.position = ((Vector2(1280.0, 720.0) - preview_size) * 0.5).floor()
	_preview.cycle_finished.connect(get_tree().quit)
	_preview.show_card(card)
	# 実演の局面は次のフレームで組まれ、その次で初めて枠へ映る。それより前の空のコマを録らない。
	for i in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	if not info_path.is_empty():
		var file := FileAccess.open(info_path, FileAccess.WRITE)
		file.store_line(
			(
				"%dx%d+%d+%d"
				% [preview_size.x, preview_size.y, _preview.position.x, _preview.position.y]
			)
		)
		file.store_line(str(Engine.get_frames_drawn()))
