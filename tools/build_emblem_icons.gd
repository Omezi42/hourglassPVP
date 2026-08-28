extends SceneTree
## カードごとの紋章(モチーフのアイコン)を、取り込み元のSVGから実行時用のPNGへ焼き直す。
##
## 元データは icooon-mono(商用可・クレジット不要)から取得したSVGで、
## `assets/hourglasses/emblems/sources/` に `.gdignore` 付きで置いてある(実行時に読まない)。
## 出力は白のシルエット1枚で、色は描画側(CardView)が modulate で決める。
##
## 使い方:
##   Godot --headless --path . --script tools/build_emblem_icons.gd

const SOURCE_DIR := "res://assets/hourglasses/emblems/sources"
const OUTPUT_DIR := "res://assets/hourglasses/emblems"
## 紋章の最大の表示サイズは駒の背後の透かし(約86px)。2倍を持たせておく。
const SIDE := 192


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		printerr("cannot open ", SOURCE_DIR)
		quit(1)
		return
	for file in dir.get_files():
		if not file.ends_with(".svg"):
			continue
		_build(file.get_basename())
	print("done")
	quit()


func _build(id: String) -> void:
	var text := FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("%s/%s.svg" % [SOURCE_DIR, id])
	)
	var image := Image.new()
	if image.load_svg_from_string(text, 1.0) != OK:
		printerr("cannot rasterize ", id)
		return
	image.resize(SIDE, SIDE, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	_whiten(image)
	image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, id]))
	print(id)


## 色は描画側で決めるため、アルファだけを残して白へ塗り替える。
func _whiten(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
