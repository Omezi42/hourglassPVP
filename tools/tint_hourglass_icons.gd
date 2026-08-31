extends SceneTree
## 既存の砂時計イラストの**色相だけを回して**新しいカードのイラストを作る。
##
## 生成AIで1枚ずつ描き起こす代わりに、既にある絵を色違いとして当てはめる運用
## (ユーザー判断)。**絵柄そのものは元のカードと同じ**になるため、あとから固有の
## イラストを用意したくなった場合は `assets/hourglasses/processed/{id}/` を差し替えるだけでよい。
##
## 使い方:
##   Godot --headless --path . --script tools/tint_hourglass_icons.gd
##
## 出力先が既にある場合は上書きする(色の当たりを見ながら何度でも回せるようにするため)。

const PROCESSED := "res://assets/hourglasses/processed/%s"
const STATES: Array[String] = ["state_full", "state_falling", "state_empty"]
## [新しいid, 元にするid, 色相の回転量(0〜1), 彩度の倍率, 対象にする彩度の下限, 彩度の下駄]
##
## 元の絵が鋼や石のようにほぼ無彩色だと、色相をいくら回しても色が付かない。
## その場合は下限を下げて対象に含め、下駄で最低限の彩度を与える(ドリル・ツイン・
## ロック・スイープがこれにあたる)。逆に色の付いた絵が元なら下駄は不要。
const VARIANTS: Array = [
	["glass", "mirror", 0.52, 0.85, 0.18, 0.0],
	["drill", "sword", 0.58, 1.0, 0.04, 0.45],
	["vamp", "eye", 0.86, 1.1, 0.18, 0.0],
	["lock", "wall", 0.12, 0.9, 0.04, 0.28],
	["twin", "sword", 0.30, 1.0, 0.04, 0.40],
	["lance", "dash", 0.14, 1.05, 0.18, 0.0],
	["swarm", "judge", 0.42, 1.0, 0.18, 0.0],
	["poison", "eye", 0.24, 1.15, 0.18, 0.0],
	["hammer", "king", 0.70, 0.95, 0.18, 0.0],
	["sweep", "wall", 0.62, 1.1, 0.04, 0.38],
	["grain", "sand", 0.28, 1.05, 0.18, 0.0],
	["dust", "sand", 0.80, 0.28, 0.18, 0.0],
	["sprout", "grain", 0.94, 1.0, 0.18, 0.0],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for variant in VARIANTS:
		_make(variant[0], variant[1], variant[2], variant[3], variant[4], variant[5])
	print("done")
	quit()


func _make(
	new_id: String,
	source_id: String,
	hue_shift: float,
	saturation: float,
	threshold: float,
	floor_saturation: float
) -> void:
	var out_dir := PROCESSED % new_id
	DirAccess.make_dir_recursive_absolute(out_dir)
	for state in STATES:
		var source_path := "%s/%s.png" % [PROCESSED % source_id, state]
		var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if image == null:
			printerr("cannot read ", source_path)
			return
		_tint(image, hue_shift, saturation, threshold, floor_saturation)
		image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [out_dir, state]))
	print("%s <- %s (hue %+.2f)" % [new_id, source_id, hue_shift])


func _tint(
	image: Image, hue_shift: float, saturation: float, threshold: float, floor_saturation: float
) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0 or pixel.s < threshold:
				continue
			var tinted := clampf(pixel.s * saturation, 0.0, 1.0)
			tinted = maxf(tinted, floor_saturation)
			pixel = Color.from_hsv(fposmod(pixel.h + hue_shift, 1.0), tinted, pixel.v, pixel.a)
			image.set_pixel(x, y, pixel)
