extends SceneTree
## Discordの `/card` 用に、カード1枚ごとの詳細画像を静止画として書き出す。
## 実演と違って動きが無いため --write-movie は使わず、実際にレンダリングされた
## フレームを都度キャプチャして次のカードへ進む(GameDesign.md 26章)。
##
## 実行(非ヘッドレス。GPUで実際に描画する必要があるため --headless は付けない):
##   godot --path . --script tools/export_discord_card_art.gd

const OUTPUT_DIR := "res://functions/data/card_art"
## 描画が安定するまで数フレーム待ってから撮る。
const WAIT_FRAMES := 3

var _cards: Array[CardData] = []
var _art: DiscordCardArt


func _init() -> void:
	root.theme = load("res://resources/theme/main_theme.tres")
	_cards = CardLibrary.all_cards()
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_art = DiscordCardArt.new()
	root.add_child(_art)
	call_deferred("_run")


func _run() -> void:
	for card in _cards:
		_art.show_card(card)
		for i in WAIT_FRAMES:
			await process_frame
		_save(card)
	print("wrote %d card images to %s" % [_cards.size(), OUTPUT_DIR])
	quit()


func _save(card: CardData) -> void:
	var image := root.get_texture().get_image()
	var rect := Rect2i(_art.position, _art.size)
	image = image.get_region(rect)
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, card.id]))
	print(card.id)
