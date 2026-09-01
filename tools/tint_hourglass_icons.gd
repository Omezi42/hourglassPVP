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
	["crack", "sand", 0.932, 1.05, 0.18, 0.0],
	["temper", "sand", 0.969, 0.55, 0.18, 0.0],
	["spike", "sand", 0.006, 1.05, 0.18, 0.0],
	["balm", "sand", 0.043, 0.55, 0.18, 0.0],
	["barb", "sand", 0.080, 1.05, 0.18, 0.0],
	["hour", "sand", 0.117, 0.55, 0.18, 0.0],
	["memory", "sand", 0.154, 1.05, 0.18, 0.0],
	["drip", "sand", 0.191, 0.55, 0.18, 0.0],
	["well", "sand", 0.228, 1.05, 0.18, 0.0],
	["tower", "sand", 0.265, 0.55, 0.18, 0.0],
	["gate", "sand", 0.302, 1.05, 0.18, 0.0],
	["watcher", "sand", 0.339, 0.55, 0.18, 0.0],
	["pebble", "sand", 0.376, 1.05, 0.18, 0.0],
	["shell", "sand", 0.413, 0.55, 0.18, 0.0],
	["bloom", "sand", 0.450, 1.05, 0.18, 0.0],
	["forge", "sand", 0.487, 0.55, 0.18, 0.0],
	["crown", "sand", 0.524, 1.05, 0.18, 0.0],
	["pike", "sand", 0.561, 0.55, 0.18, 0.0],
	["halo", "sand", 0.598, 1.05, 0.18, 0.0],
	["blank", "sand", 0.635, 0.55, 0.18, 0.0],
	["wheel", "sand", 0.672, 1.05, 0.18, 0.0],
	["page", "sand", 0.709, 0.55, 0.18, 0.0],
	["burst", "sand", 0.746, 1.05, 0.18, 0.0],
	["legacy", "sand", 0.783, 0.55, 0.18, 0.0],
	["pivot", "sand", 0.820, 1.05, 0.18, 0.0],
	["anchor", "sand", 0.857, 0.55, 0.18, 0.0],
	["flask", "sand", 0.894, 1.05, 0.18, 0.0],
	["sprout", "grain", 0.94, 1.0, 0.18, 0.0],
	# マナカーブ調整の8枚。sand基準の0.037刻みは50種で使い切ったため、
	# **元にする絵そのものを散らして**見分けを付ける(色相だけでは足りない。GameDesign.md 9章)。
	["husk", "wall", 0.35, 0.95, 0.04, 0.32],
	["seed", "grain", 0.60, 1.0, 0.18, 0.0],
	["wand", "echo", 0.45, 1.05, 0.18, 0.0],
	["glim", "shield", 0.70, 1.0, 0.18, 0.0],
	["tick", "dash", 0.55, 1.05, 0.18, 0.0],
	["salt", "mirror", 0.42, 0.9, 0.18, 0.0],
	["rattle", "judge", 0.92, 1.0, 0.18, 0.0],
	["obelisk", "king", 0.62, 0.95, 0.18, 0.0],
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
