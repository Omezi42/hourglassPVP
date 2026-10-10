extends SceneTree
## 原本の砂時計3状態から、砂・枠・ガラスの内側を分けた領域マスクを焼く(Architecture.md 4.1節)。
##
## 原本の砂と木枠はほぼ同じ色で、色だけでは分けられない。ガラスの中央から暗い輪郭で
## 止まる塗りつぶしで「ガラスの内側」を求め、内側の有彩色を砂、外側の有彩色を枠とする。
## 原本を差し替えたら1度回し直す。
##
##   Godot --headless --path . --script res://tools/build_hourglass_regions.gd

const MASTER_DIR := "res://assets/hourglasses/master"
const STATES: Array[String] = ["state_full", "state_falling", "state_empty"]
## これより暗い画素と半透明の画素を、塗りつぶしを止める輪郭とみなす。
const WALL_VALUE := 0.42
const WALL_ALPHA := 0.5
## 塗りつぶしを始める高さ(キャンバスの高さに対する比)。上下の球の中を通る中央の縦線上に取る。
const SEED_HEIGHTS: Array[float] = [0.25, 0.3, 0.35, 0.65, 0.7, 0.75, 0.8]
## 彩度がこの範囲を超えるにつれて砂 / 枠とみなす(ガラスの彩度は0.07以下、砂と枠は0.5以上)。
const SAND_SATURATION := Vector2(0.15, 0.35)
const FRAME_SATURATION := Vector2(0.25, 0.4)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for state in STATES:
		_build(state)
	quit()


func _build(state: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s.png" % [MASTER_DIR, state])
	var art := Image.load_from_file(path)
	if art == null:
		printerr("cannot read ", path)
		return
	art.convert(Image.FORMAT_RGBA8)
	var inside := _flood_inside(art)
	var width := art.get_width()
	var height := art.get_height()
	var region := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var pixel := art.get_pixel(x, y)
			var is_inside := inside[y * width + x] == 1
			var sand := 0.0
			var frame := 0.0
			if is_inside:
				sand = smoothstep(SAND_SATURATION.x, SAND_SATURATION.y, pixel.s)
			elif pixel.a >= WALL_ALPHA:
				frame = smoothstep(FRAME_SATURATION.x, FRAME_SATURATION.y, pixel.s)
			region.set_pixel(x, y, Color(sand, frame, 1.0 if is_inside else 0.0, 1.0))
	var out := "%s/region_%s.png" % [MASTER_DIR, state]
	region.save_png(ProjectSettings.globalize_path(out))
	print("%s (%dx%d)" % [out, width, height])


func _flood_inside(art: Image) -> PackedByteArray:
	var width := art.get_width()
	var height := art.get_height()
	var seen := PackedByteArray()
	seen.resize(width * height)
	var queue: Array[Vector2i] = []
	var center := width / 2
	for ratio in SEED_HEIGHTS:
		var seed := Vector2i(center, int(ratio * height))
		if not _is_wall(art, seed):
			seen[seed.y * width + seed.x] = 1
			queue.append(seed)
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			var index := next.y * width + next.x
			if seen[index] == 1 or _is_wall(art, next):
				continue
			seen[index] = 1
			queue.append(next)
	return seen


func _is_wall(art: Image, at: Vector2i) -> bool:
	var pixel := art.get_pixelv(at)
	return pixel.v < WALL_VALUE or pixel.a < WALL_ALPHA
