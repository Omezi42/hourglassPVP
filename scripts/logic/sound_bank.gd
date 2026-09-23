class_name SoundBank
extends RefCounted

## 効果音の再生と、効果音・BGM双方の音量設定を1箇所に集約する薄いクラス。
## MatchSetup/DeckSave/NetSessionと同じ「Autoloadを使わずstaticで持つ」流儀に揃える。
## ensure_ready()は起動時にMainから1度だけ呼び、AudioStreamPlayerのプールを
## 常駐ノードとして生成する(staticクラス自体はNodeではないため、再生には実ノードが要る)。
## BGMの再生自体はMusicPlayerが担当し、こちらは音量の単一情報源としてのみ関わる
## (設定の読み書きを2クラスへ分散させると、同じJSONファイルを互いに上書きし合うため)。

## 音源はすべて `tools/build_sfx.py` がコードで合成した自作の音(GameDesign.md 9章)。
## **出来事ごとに専用の音を持ち、音量は音源の側で揃えてある**ため、再生時に高さや
## 音量比をいじらない。ユーザーの音量はバス(SFX / BGM)の音量で効かせる。
## 並びは保存データではないが、テストの `play_log` と突き合わせるため末尾へ足す。
enum Sfx {
	FLIP,
	PLACE,
	CLASH,
	DAMAGE,
	RESULT_WIN,
	RESULT_LOSE,
	BUTTON,
	UNIT_BREAK,
	GLASS_BREAK,
	HOVER,
	TURN_END,
	TURN_START,
}

const SETTINGS_PATH := "user://sound_settings.json"
const SFX_BUS := &"SFX"
const BGM_BUS := &"BGM"
## 被弾・破壊・決着が重なっても鳴っている音を途中で切らないための同時再生数。
const PLAYER_POOL_SIZE := 8
## ホバー音をなぞって連続で鳴らさないための間隔。手札を横切ると数十msおきに乗り換えるため。
const HOVER_MIN_INTERVAL_MS := 70
const MIN_AUDIBLE_VOLUME := 0.0001
const SILENT_DB := -80.0
const DEFAULT_SFX_VOLUME := 0.8
const DEFAULT_BGM_VOLUME := 0.7

const SFX_PATHS := {
	Sfx.FLIP: "res://assets/sfx/flip.wav",
	Sfx.PLACE: "res://assets/sfx/place.wav",
	Sfx.CLASH: "res://assets/sfx/clash.wav",
	Sfx.DAMAGE: "res://assets/sfx/damage.wav",
	Sfx.RESULT_WIN: "res://assets/sfx/result_win.wav",
	Sfx.RESULT_LOSE: "res://assets/sfx/result_lose.wav",
	Sfx.BUTTON: "res://assets/sfx/press.wav",
	Sfx.UNIT_BREAK: "res://assets/sfx/unit_break.wav",
	Sfx.GLASS_BREAK: "res://assets/sfx/glass_break.wav",
	Sfx.HOVER: "res://assets/sfx/hover.wav",
	Sfx.TURN_END: "res://assets/sfx/turn_end.wav",
	Sfx.TURN_START: "res://assets/sfx/turn_start.wav",
}

static var _players: Array[AudioStreamPlayer] = []
static var _next_player_index := 0
## ホバー音は専用の1本で鳴らす。プールを使うと、鳴っている被弾や決着の音を
## ホバーが途中で奪ってしまう。
static var _hover_player: AudioStreamPlayer = null
static var _last_hover_ms := -HOVER_MIN_INTERVAL_MS
## static varの初期化式はクラスへの初回アクセス時に一度だけ評価されるため、
## ensure_ready()(AudioStreamPlayerを配置できるNodeが要る)を待たずに、
## 音量設定を早期に確定できる。ホーム画面の設定ボタンはMainより先に
## _ready()が走るため、ここで読み込んでおかないと初期表示が反映されない。
static var _sfx_volume := _load_volume("sfx_volume", DEFAULT_SFX_VOLUME)
static var _bgm_volume := _load_volume("bgm_volume", DEFAULT_BGM_VOLUME)
## 実際に音を鳴らせない(ensure_ready未実行/ヘッドレス等)環境でも呼び出し履歴を追えるよう、
## 再生要求(音量0時は除く)を記録する。UIの見た目確認に加え、自動テストでの検証にも使う。
static var play_log: Array[Sfx] = []


static func ensure_ready(parent: Node) -> void:
	if _players.size() > 0:
		return
	_apply_bus_volume(SFX_BUS, _sfx_volume)
	_apply_bus_volume(BGM_BUS, _bgm_volume)
	# 音が重なったときに割れないよう、全体の出口で頭を押さえる。
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	for i in range(PLAYER_POOL_SIZE):
		_players.append(_make_player(parent))
	_hover_player = _make_player(parent)


static func play(sfx: Sfx) -> void:
	if _sfx_volume <= 0.0:
		return
	if sfx == Sfx.HOVER:
		var now := Time.get_ticks_msec()
		if now - _last_hover_ms < HOVER_MIN_INTERVAL_MS:
			return
		_last_hover_ms = now
	play_log.append(sfx)
	if _players.is_empty():
		return
	var stream: AudioStream = load(SFX_PATHS[sfx])
	if stream == null:
		return
	var player := _hover_player if sfx == Sfx.HOVER else _free_player()
	player.stream = stream
	player.play()


static func get_sfx_volume() -> float:
	return _sfx_volume


static func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(SFX_BUS, _sfx_volume)
	_save_settings()


## 0.0(無音)〜1.0(最大)のBGM音量。
static func get_bgm_volume() -> float:
	return _bgm_volume


static func set_bgm_volume(value: float) -> void:
	_bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BGM_BUS, _bgm_volume)
	_save_settings()


static func is_muted() -> bool:
	return _sfx_volume <= 0.0


## シーンツリーを走査し、全Buttonのpressedへボタン押下音、mouse_enteredへホバー音を
## 接続する(GameDesign.md 9章)。個別に繋ぐと数が多く漏れやすいため、
## Main起動時に一括で呼ぶ想定。
static func wire_buttons(root: Node) -> void:
	if root is Button:
		var press_callback := play.bind(Sfx.BUTTON)
		if not root.pressed.is_connected(press_callback):
			root.pressed.connect(press_callback)
		var hover_callback := _on_button_hovered.bind(root)
		if not root.mouse_entered.is_connected(hover_callback):
			root.mouse_entered.connect(hover_callback)
	for child in root.get_children():
		wire_buttons(child)


## 押せない(無効の)ボタンでは鳴らさない。ホバーの見た目も変わらないのに音だけ返ると、
## 押せるように聞こえる。
static func _on_button_hovered(button: Button) -> void:
	if not button.disabled:
		play(Sfx.HOVER)


static func _make_player(parent: Node) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS
	parent.add_child(player)
	return player


## 鳴り終わっている1本を選ぶ。すべて鳴っていれば、順番が最も古いものを譲ってもらう。
static func _free_player() -> AudioStreamPlayer:
	for i in range(_players.size()):
		var index := (_next_player_index + i) % _players.size()
		if not _players[index].playing:
			_next_player_index = (index + 1) % _players.size()
			return _players[index]
	var oldest := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	return oldest


## バスが無ければ作る。バスの構成をファイル(default_bus_layout.tres)で持たないのは、
## 2本しかないうえ、音量の単一情報源であるこのクラスの近くに置きたいため。
static func bus_index(bus: StringName) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")
	return index


static func _apply_bus_volume(bus: StringName, value: float) -> void:
	var index := bus_index(bus)
	AudioServer.set_bus_volume_db(index, volume_to_db(value))
	AudioServer.set_bus_mute(index, value <= MIN_AUDIBLE_VOLUME)


## スライダーの値を音量へ。**振幅の2乗で効かせる**と、耳の感じ方(対数)に近くなり、
## 半分へ下げたときに「半分くらいになった」と聞こえる。線形のままだと上半分がほぼ変わらない。
static func volume_to_db(value: float) -> float:
	if value <= MIN_AUDIBLE_VOLUME:
		return SILENT_DB
	return linear_to_db(value * value)


## 効果音・BGMを分ける前の保存データは音量を単一キー"volume"で持っていた。
## 見つかった場合は両系統の初期値として読み、次回保存時に新形式へ移行する。
static func _load_volume(key: String, fallback: float) -> float:
	var data := _read_settings()
	if data.has(key):
		return clampf(float(data[key]), 0.0, 1.0)
	if data.has("volume"):
		return clampf(float(data["volume"]), 0.0, 1.0)
	return fallback


static func _read_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"sfx_volume": _sfx_volume, "bgm_volume": _bgm_volume}))
