extends SceneTree

## 一時スクリプト: scratchpad内のOGG候補の長さを測る。確認後に削除すること。

func _init() -> void:
	var base := "C:/Users/omezi/AppData/Local/Temp/claude/C--Users-omezi-Documents----pvp/b7245d0e-10fc-4a6e-9285-bfc7666049fe/scratchpad/audio/ex"
	var groups := {
		"impact": base + "/kenney_impact-sounds/Audio",
		"pizzi": base + "/kenney_music-jingles/Audio/Pizzicato jingles",
		"steel": base + "/kenney_music-jingles/Audio/Steel jingles",
	}
	for key in groups:
		var dir := DirAccess.open(groups[key])
		if dir == null:
			print("MISSING ", groups[key])
			continue
		for f in dir.get_files():
			if not f.ends_with(".ogg"):
				continue
			if key == "impact" and not f.begins_with("impactGlass"):
				continue
			var s := AudioStreamOggVorbis.load_from_file(groups[key] + "/" + f)
			if s == null:
				print("FAIL ", f)
				continue
			print("%s\t%s\t%.2f" % [key, f, s.get_length()])
	quit()
