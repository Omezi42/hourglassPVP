extends Control
## 配信ページ(itch.io)の飾り画像を書き出す。
##   banner.png    960x300  ロゴのみ・透過(ページ背景の上に載せる)
##   embed_bg.png  1280x720 ゲーム枠の起動前の背景(中央に「Run game」が重なるため文字を置かない)
##   cover.png     630x500  一覧に出るカバー画像
##
## 実行(実際の描画結果を読むため --headless は付けない):
##   godot --path . res://tools/record_store_page_art.tscn -- <出力先フォルダ>

const BANNER_SIZE := Vector2i(960, 300)
const COVER_SIZE := Vector2i(630, 500)
const LOGO_HEIGHT := 290.0
const COVER_LOGO_SCALE := 0.72
const COVER_LOGO_TOP := 18.0
const COVER_FLOOR_Y := 470.0
const COVER_UNIT_HEIGHT := 230.0
## カバーに並べる駒(左から)。
const COVER_UNIT_IDS := ["lance", "sand", "poison"]
const COVER_UNIT_SPACING := 190.0
const BACKGROUND := preload("res://assets/backgrounds/processed/battle/background.png")
## 描き終えてから読み出すまでに待つコマ数(ロゴの金箔が子ノードとして描かれるのを待つ)。
const SETTLE_FRAMES := 4
const TITLE_SETTLE_SECONDS := 0.8

var _out_dir := ""


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if not args.is_empty() else "user://store_page_art"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	await HourglassArt.ensure_ready_and_wait(self)
	await _banner()
	await _cover()
	await _embed_bg()
	get_tree().quit()


func _viewport(view_size: Vector2i, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = view_size
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _save_viewport(vp: Viewport, name: String) -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(name)
	vp.get_texture().get_image().save_png(path)
	print("SAVED=%s" % path)


func _logo(width: float) -> TitleLogo:
	var logo := TitleLogo.new()
	logo.theme = theme
	logo.size = Vector2(width, LOGO_HEIGHT)
	return logo


func _banner() -> void:
	var vp := _viewport(BANNER_SIZE, true)
	var logo := _logo(BANNER_SIZE.x)
	logo.position.y = (BANNER_SIZE.y - LOGO_HEIGHT) * 0.5
	vp.add_child(logo)
	await _save_viewport(vp, "banner.png")
	vp.queue_free()


func _cover() -> void:
	var vp := _viewport(COVER_SIZE, false)
	var bg := TextureRect.new()
	bg.texture = BACKGROUND
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(COVER_SIZE)
	vp.add_child(bg)
	var center_x := COVER_SIZE.x * 0.5
	for i in COVER_UNIT_IDS.size():
		var tex := HourglassArt.texture(COVER_UNIT_IDS[i], HourglassArt.State.values()[0])
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size = Vector2(COVER_UNIT_HEIGHT, COVER_UNIT_HEIGHT)
		var x := center_x + (i - (COVER_UNIT_IDS.size() - 1) * 0.5) * COVER_UNIT_SPACING
		art.position = Vector2(x - COVER_UNIT_HEIGHT * 0.5, COVER_FLOOR_Y - COVER_UNIT_HEIGHT)
		vp.add_child(art)
	var logo := _logo(COVER_SIZE.x / COVER_LOGO_SCALE)
	logo.scale = Vector2.ONE * COVER_LOGO_SCALE
	logo.position.y = COVER_LOGO_TOP
	vp.add_child(logo)
	await _save_viewport(vp, "cover.png")
	vp.queue_free()


## 起動前の枠。タイトル画面から操作の案内を外したものをそのまま使う。
func _embed_bg() -> void:
	var title: TitleScreen = load("res://scenes/title_screen.tscn").instantiate()
	add_child(title)
	title.start_label.visible = false
	title.account_button.visible = false
	await get_tree().create_timer(TITLE_SETTLE_SECONDS).timeout
	await _save_viewport(get_viewport(), "embed_bg.png")
