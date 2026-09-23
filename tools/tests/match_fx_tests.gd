extends RefCounted
## 対局中の演出のうち、**描画を伴わずに検証できるもの**(GameDesign.md 9章)。
## 揺れの累積・減衰と、効果音の高さの取り違えを見る。
## 見た目そのものは非ヘッドレスのレンダリングで確認する(Architecture.md 11章)。


func run(assert_true: Callable) -> void:
	_test_shake_returns_to_its_base_position(assert_true)
	_test_shake_takes_the_larger_amount_instead_of_stacking(assert_true)
	_test_shake_does_nothing_without_targets(assert_true)
	_test_every_sound_has_its_own_file(assert_true)
	_test_hover_sound_is_throttled(assert_true)


## 揺れは必ず元の位置へ戻る。**基準を控えずに position へ足すと戻らなくなる**ため、
## 盤面が少しずつずれていく不具合の回帰テストにあたる。
func _test_shake_returns_to_its_base_position(assert_true: Callable) -> void:
	var target := Control.new()
	target.position = Vector2(190, 74)
	var shake := CardMatchShake.new()
	var targets: Array[Control] = [target]
	shake.bind(targets)
	shake.hit(5)
	shake.tick(0.05)
	assert_true.call(target.position != Vector2(190, 74), "揺れている間は基準の位置から動いている")
	# 尺を超えて進めれば、何回に分けて進めても元へ戻る。
	shake.tick(CardMatchShake.DURATION)
	assert_true.call(target.position.is_equal_approx(Vector2(190, 74)), "揺れが収まると元の位置へ戻る")
	shake.tick(0.5)
	assert_true.call(target.position.is_equal_approx(Vector2(190, 74)), "収まった後は動かし続けない")
	target.free()


## 連撃や6枠が並ぶ中盤で揺れが累積しないこと(GameDesign.md 9章)。
func _test_shake_takes_the_larger_amount_instead_of_stacking(assert_true: Callable) -> void:
	var target := Control.new()
	var shake := CardMatchShake.new()
	var targets: Array[Control] = [target]
	shake.bind(targets)
	# 上限に達する強さで2回続けて当てても、振れ幅は上限を超えない。
	shake.hit(99)
	shake.hit(99)
	var worst := 0.0
	for i in 20:
		shake.tick(0.005)
		worst = maxf(worst, absf(target.position.x))
	assert_true.call(worst <= CardMatchShake.MAX_AMOUNT + 0.001, "揺れは足し合わせず上限で頭打ちになる")
	assert_true.call(worst > 0.0, "上限の範囲では実際に揺れている")
	target.free()


## 対象を登録する前に当たっても落ちないこと(パズル・リプレイの入口で起こりうる)。
func _test_shake_does_nothing_without_targets(assert_true: Callable) -> void:
	var shake := CardMatchShake.new()
	shake.hit(4)
	shake.tick(0.1)
	assert_true.call(true, "対象が無くても揺れの呼び出しで落ちない")


## 出来事ごとに専用の音を持つ(GameDesign.md 9章)。**同じ音源を指していたら
## 音だけで出来事を聞き分けられない**ため、全種が別々の実在するファイルを指すことを見る。
func _test_every_sound_has_its_own_file(assert_true: Callable) -> void:
	var seen := {}
	for sfx: int in SoundBank.Sfx.values():
		var path: String = SoundBank.SFX_PATHS.get(sfx, "")
		assert_true.call(ResourceLoader.load(path) != null, "音源が読める: %s" % path)
		assert_true.call(not seen.has(path), "音源が他と重ならない: %s" % path)
		seen[path] = true


## ホバー音は短い間隔では重ねない(手札をなぞったときに連打にしない)。
func _test_hover_sound_is_throttled(assert_true: Callable) -> void:
	SoundBank.play_log.clear()
	SoundBank.play(SoundBank.Sfx.HOVER)
	SoundBank.play(SoundBank.Sfx.HOVER)
	var hovers := SoundBank.play_log.count(SoundBank.Sfx.HOVER)
	assert_true.call(SoundBank.get_sfx_volume() <= 0.0 or hovers == 1, "続けて乗ってもホバー音は1回")
	SoundBank.play_log.clear()
