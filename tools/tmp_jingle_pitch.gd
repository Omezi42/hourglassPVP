extends SceneTree

## 一時スクリプト: ジングル候補を実際に再生し、スペクトル重心の時間変化から
## 「音程が上がって終わる(勝利向き)」か「下がって終わる(敗北向き)」かを判定する。
## 確認後にこのファイル自体を削除すること。

const BANDS := [
	[80.0, 160.0], [160.0, 320.0], [320.0, 640.0],
	[640.0, 1280.0], [1280.0, 2560.0], [2560.0, 5120.0], [5120.0, 10240.0],
]

var _files: Array[String] = []
var _index := -1
var _player: AudioStreamPlayer
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _centroids: Array[float] = []
var _root: Node


func _init() -> void:
	var base := "C:/Users/omezi/AppData/Local/Temp/claude/C--Users-omezi-Documents----pvp/b7245d0e-10fc-4a6e-9285-bfc7666049fe/scratchpad/audio/ex/kenney_music-jingles/Audio"
	for sub in ["Pizzicato jingles", "Steel jingles"]:
		var dir := DirAccess.open(base + "/" + sub)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".ogg"):
				_files.append(base + "/" + sub + "/" + f)
	_files.sort()

	var bus := AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(bus, AudioEffectSpectrumAnalyzer.new())
	_spectrum = AudioServer.get_bus_effect_instance(bus, AudioServer.get_bus_effect_count(bus) - 1)

	_root = Node.new()
	root.add_child(_root)
	_player = AudioStreamPlayer.new()
	_root.add_child(_player)
	process_frame.connect(_on_frame)
	_next()


func _next() -> void:
	if _index >= 0:
		_report()
	_index += 1
	if _index >= _files.size():
		quit()
		return
	_centroids.clear()
	var stream := AudioStreamOggVorbis.load_from_file(_files[_index])
	stream.loop = false
	_player.stream = stream
	_player.play()


func _on_frame() -> void:
	if _index < 0 or _index >= _files.size():
		return
	if not _player.playing:
		_next()
		return
	var total := 0.0
	var weighted := 0.0
	for band in BANDS:
		var mag := _spectrum.get_magnitude_for_frequency_range(band[0], band[1]).length()
		var center: float = (band[0] + band[1]) * 0.5
		total += mag
		weighted += mag * center
	if total > 0.0005:
		_centroids.append(weighted / total)


func _report() -> void:
	var name := _files[_index].get_file()
	if _centroids.size() < 6:
		print("%s\tSAMPLES_TOO_FEW\t%d" % [name, _centroids.size()])
		return
	var half := _centroids.size() / 2
	var first := 0.0
	var second := 0.0
	for i in range(half):
		first += _centroids[i]
	for i in range(half, _centroids.size()):
		second += _centroids[i]
	first /= float(half)
	second /= float(_centroids.size() - half)
	var ratio := second / maxf(first, 1.0)
	var verdict := "FLAT"
	if ratio > 1.12:
		verdict = "RISING"
	elif ratio < 0.89:
		verdict = "FALLING"
	print("%s\t%s\t%.3f\t%.0f->%.0f" % [name, verdict, ratio, first, second])
