extends SceneTree
## 実行時に焼いた砂時計の絵が、これまで配っていた絵と一致するかを確かめる。
## ヘッドレスでは描画器がダミーで焼けないため、必ず画面ありで回すこと。
##   Godot --path . --script res://tools/tests/verify_hourglass_art.gd

const REFERENCE := "res://assets/hourglasses/processed/%s/%s.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	HourglassArt.ensure_ready(host)
	await _wait_for_bake()
	var table: HourglassTintTable = load(HourglassArt.TABLE_PATH)
	var worst_mean := 0.0
	var worst_max := 0.0
	var worst_id := ""
	var checked := 0
	var per_id := {}
	for art_id in table.entries.keys():
		for state in HourglassArt.STATE_FILES.size():
			var got: Texture2D = HourglassArt.texture(String(art_id), state)
			var reference := _load_reference(String(art_id), state)
			if got == null or reference == null:
				printerr("読めません: ", art_id, " ", state)
				quit(1)
				return
			var scores := _compare(got.get_image(), reference)
			checked += 1
			per_id[String(art_id)] = maxf(float(per_id.get(art_id, 0.0)), scores[0])
			if scores[0] > worst_mean:
				worst_mean = scores[0]
				worst_id = String(art_id)
			worst_max = maxf(worst_max, scores[1])
	var ranked := []
	for art_id in per_id:
		ranked.append([per_id[art_id], art_id])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(8, ranked.size()):
		print("  %-9s %.2f/255" % [ranked[i][1], ranked[i][0]])
	# 原本そのものにも誤差が出る。非可逆(WebP)で取り込んでいるためで、
	# これは焼き付けではなく現行の配布物にも同じだけ乗っている。基準として差し引く。
	var baseline := float(per_id.get(HourglassArt.MASTER_ID, 0.0))
	print(
		(
			"%d枚を突き合わせた  最悪 %.2f/255 (%s)  取り込みの誤差 %.2f/255  差し引き %.2f/255"
			% [checked, worst_mean, worst_id, baseline, worst_mean - baseline]
		)
	)
	if worst_mean - baseline > 4.0:
		printerr("差が大きすぎます。色変換の数値かシェーダを疑うこと")
		quit(1)
		return
	quit()


func _wait_for_bake() -> void:
	for i in 400:
		await process_frame
		if not HourglassArt._baking:
			return


func _load_reference(art_id: String, state: int) -> Image:
	var path := REFERENCE % [art_id, HourglassArt.STATE_FILES[state]]
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _compare(got: Image, reference: Image) -> Array:
	if got.get_size() != reference.get_size():
		return [999.0, 999.0]
	var total := 0.0
	var worst := 0.0
	var counted := 0
	for y in range(0, got.get_height(), 3):
		for x in range(0, got.get_width(), 3):
			var a := got.get_pixel(x, y)
			var b := reference.get_pixel(x, y)
			if a.a < 0.99 or b.a < 0.99:
				continue
			counted += 1
			for channel in [absf(a.r - b.r), absf(a.g - b.g), absf(a.b - b.b)]:
				total += channel * 255.0 / 3.0
				worst = maxf(worst, channel * 255.0)
	if counted == 0:
		return [999.0, 999.0]
	return [total / float(counted), worst]
