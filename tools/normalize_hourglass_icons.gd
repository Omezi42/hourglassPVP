extends SceneTree

const TARGET_ASPECT := 0.78  # width / height、hourglass_card.tscnの140x180に合わせる
const FILL_RATIO := 0.92  # 絵柄の実寸がキャンバスに占める割合
const NAMES := ["dash", "echo", "eye", "judge", "king", "mirror", "sand", "shield", "sword", "wall"]
const STATES := ["state_full", "state_falling", "state_empty"]


func _init() -> void:
	for hourglass_name in NAMES:
		for state in STATES:
			_process_one("res://assets/hourglasses/processed/%s/%s.png" % [hourglass_name, state])
	print("all done")
	quit(0)


func _process_one(path: String) -> void:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		printerr("failed to load: ", path)
		return

	var used_rect := img.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		printerr("empty content: ", path)
		return
	var cropped := img.get_region(used_rect)
	var content_w := cropped.get_width()
	var content_h := cropped.get_height()

	var canvas_h := int(ceil(content_h / FILL_RATIO))
	var canvas_w := int(ceil(canvas_h * TARGET_ASPECT))
	var needed_w := int(ceil(content_w / FILL_RATIO))
	if needed_w > canvas_w:
		canvas_w = needed_w
		canvas_h = int(ceil(canvas_w / TARGET_ASPECT))

	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var offset_x := (canvas_w - content_w) / 2
	var offset_y := (canvas_h - content_h) / 2
	canvas.blit_rect(
		cropped, Rect2i(Vector2i.ZERO, Vector2i(content_w, content_h)), Vector2i(offset_x, offset_y)
	)

	if canvas.save_png(path) != OK:
		printerr("save failed: ", path)
		return
	print(
		"ok: ", path, " -> ", canvas_w, "x", canvas_h, " (content ", content_w, "x", content_h, ")"
	)
