extends RefCounted

## フェーズ20 Y-3: 音量設定(効果音/BGMの2系統)の保存・読み出しと、
## 効果音のみだった旧形式(単一キー"volume")からの移行を検証する。
## run_tests.gdが1000行の上限に達したため、そこから切り出したテスト。
## 判定はハーネス側の_assert_trueをCallableで受け取って共有する。


## user://の実データを壊さないよう、DeckSaveのテストと同じバックアップ→復元の往復を使う。
func run(assert_true: Callable) -> void:
	var backup: Variant = _backup()

	_write({"volume": 0.4})
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("sfx_volume", 1.0), 0.4),
		"legacy volume should seed the sfx volume"
	)
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("bgm_volume", SoundBank.DEFAULT_BGM_VOLUME), 0.4),
		"legacy volume should seed the bgm volume too"
	)

	_write({"sfx_volume": 0.3, "bgm_volume": 0.8})
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("sfx_volume", 1.0), 0.3),
		"new format should load the sfx volume"
	)
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("bgm_volume", 1.0), 0.8),
		"new format should load the bgm volume"
	)

	if FileAccess.file_exists(SoundBank.SETTINGS_PATH):
		DirAccess.remove_absolute(SoundBank.SETTINGS_PATH)
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("bgm_volume", SoundBank.DEFAULT_BGM_VOLUME), 0.6),
		"missing settings should fall back to the default bgm volume"
	)

	# set_*_volume()は保存まで行うため、新形式で書き戻されることを往復で確かめる
	SoundBank.set_sfx_volume(0.55)
	SoundBank.set_bgm_volume(0.15)
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("sfx_volume", 1.0), 0.55),
		"set_sfx_volume should persist"
	)
	assert_true.call(
		is_equal_approx(SoundBank._load_volume("bgm_volume", 1.0), 0.15),
		"set_bgm_volume should persist"
	)

	_restore(backup)


func _write(data: Dictionary) -> void:
	var file := FileAccess.open(SoundBank.SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))


func _backup() -> Variant:
	if not FileAccess.file_exists(SoundBank.SETTINGS_PATH):
		return null
	var file := FileAccess.open(SoundBank.SETTINGS_PATH, FileAccess.READ)
	var content := file.get_as_text()
	file = null
	return content


func _restore(backup: Variant) -> void:
	if backup == null:
		if FileAccess.file_exists(SoundBank.SETTINGS_PATH):
			DirAccess.remove_absolute(SoundBank.SETTINGS_PATH)
		return
	var file := FileAccess.open(SoundBank.SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(str(backup))
