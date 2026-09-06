class_name CardCpuDifficultySave
extends RefCounted
## CPU戦の思考レベル(GameDesign.md 13章「CPU戦の思考レベル」)の選択値を持つ
## (Autoloadを使わずstaticで持つ流儀。CardDeckSave / UiState と同じ)。
##
## 「対局のたびに選び直せるが、前回選んだ値を初期値として引き継ぐ」ための永続化だけを担う。

const SAVE_PATH := "user://cpu_difficulty.json"
const KEY_DIFFICULTY := "difficulty"

static var _loaded := false
static var _difficulty: CardCpuStrategy.Difficulty = CardCpuStrategy.Difficulty.NORMAL


static func get_difficulty() -> CardCpuStrategy.Difficulty:
	_ensure_loaded()
	return _difficulty


static func set_difficulty(value: CardCpuStrategy.Difficulty) -> void:
	_ensure_loaded()
	if _difficulty == value:
		return
	_difficulty = value
	_save()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has(KEY_DIFFICULTY):
		var raw: int = int(parsed[KEY_DIFFICULTY])
		if raw >= 0 and raw <= CardCpuStrategy.Difficulty.EXPERT:
			_difficulty = raw as CardCpuStrategy.Difficulty


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({KEY_DIFFICULTY: int(_difficulty)}))
	file.close()
