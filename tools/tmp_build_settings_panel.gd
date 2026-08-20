extends SceneTree

## 一時ビルドスクリプト: settings_panel.tscnの音量行を「効果音」「BGM」の2行へ組み替える。
## .tscnをテキストとして直接編集しないためのもの。適用後にこのファイル自体を削除すること。

const SCENE_PATH := "res://scenes/settings_panel.tscn"
const CAPTION_WIDTH := Vector2(96, 0)


func _init() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	var root: Node = packed.instantiate()
	var vbox: Node = root.get_node("CenterBox/Panel/Margin/VBox")

	var sfx_row: Control = vbox.get_node("VolumeRow")
	sfx_row.name = "SfxRow"
	var caption: Label = sfx_row.get_node("VolumeCaption")
	caption.name = "Caption"
	caption.text = "効果音"
	caption.custom_minimum_size = CAPTION_WIDTH
	sfx_row.get_node("VolumeSlider").name = "Slider"
	sfx_row.get_node("VolumeValueLabel").name = "ValueLabel"

	var bgm_row: Control = sfx_row.duplicate()
	bgm_row.name = "BgmRow"
	bgm_row.get_node("Caption").text = "BGM"
	vbox.add_child(bgm_row)
	vbox.move_child(bgm_row, sfx_row.get_index() + 1)
	_own_recursive(bgm_row, root)

	var out := PackedScene.new()
	var err := out.pack(root)
	if err != OK:
		printerr("pack failed: ", err)
		quit(1)
		return
	err = ResourceSaver.save(out, SCENE_PATH)
	print("saved: ", err)
	for child in vbox.get_children():
		print(" - ", child.name)
	quit()


func _own_recursive(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own_recursive(child, owner_node)
