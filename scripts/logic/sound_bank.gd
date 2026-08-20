class_name SoundBank
extends RefCounted

## 効果音の再生と、効果音・BGM双方の音量設定を1箇所に集約する薄いクラス。
## MatchSetup/DeckSave/NetSessionと同じ「Autoloadを使わずstaticで持つ」流儀に揃える。
## ensure_ready()は起動時にMainから1度だけ呼び、AudioStreamPlayerのプールを
## 常駐ノードとして生成する(staticクラス自体はNodeではないため、再生には実ノードが要る)。
## BGMの再生自体はMusicPlayerが担当し、こちらは音量の単一情報源としてのみ関わる
## (設定の読み書きを2クラスへ分散させると、同じJSONファイルを互いに上書きし合うため)。

enum Sfx { FLIP, MOVE, SWAP, DAMAGE, RESULT_WIN, RESULT_LOSE, BUTTON }

const SETTINGS_PATH := "user://sound_settings.json"
## 被弾直後に決着音が続く等、複数の効果音がほぼ同時に鳴っても途切れないための同時再生数。
const PLAYER_POOL_SIZE := 4
## 音量0%を無音(ミュート)として扱うための下限。0より下はlinear_to_db()が-infを返すため避ける。
const MIN_AUDIBLE_VOLUME := 0.0001
## BGMは効果音より控えめから始める。クラシックを最大音量で流すと操作音がかき消されるため。
const DEFAULT_BGM_VOLUME := 0.6

const SFX_PATHS := {
	Sfx.FLIP: "res://assets/sfx/flip.wav",
	Sfx.MOVE: "res://assets/sfx/move.wav",
	Sfx.SWAP: "res://assets/sfx/swap.wav",
	Sfx.DAMAGE: "res://assets/sfx/damage.ogg",
	Sfx.RESULT_WIN: "res://assets/sfx/result_win.ogg",
	Sfx.RESULT_LOSE: "res://assets/sfx/result_lose.ogg",
	Sfx.BUTTON: "res://assets/sfx/button.wav",
}

static var _players: Array[AudioStreamPlayer] = []
static var _next_player_index := 0
## static varの初期化式はクラスへの初回アクセス時に一度だけ評価されるため、
## ensure_ready()(AudioStreamPlayerを配置できるNodeが要る)を待たずに、
## 音量設定を早期に確定できる。ホーム画面の設定ボタンはMainより先に
## _ready()が走るため、ここで読み込んでおかないと初期表示が反映されない。
static var _sfx_volume := _load_volume("sfx_volume", 1.0)
static var _bgm_volume := _load_volume("bgm_volume", DEFAULT_BGM_VOLUME)
## 実際に音を鳴らせない(ensure_ready未実行/ヘッドレス等)環境でも呼び出し履歴を追えるよう、
## 再生要求(音量0時は除く)を記録する。UIの見た目確認に加え、自動テストでの検証にも使う。
static var play_log: Array[Sfx] = []


static func ensure_ready(parent: Node) -> void:
	if _players.size() > 0:
		return
	for i in range(PLAYER_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = _volume_to_db(_sfx_volume)
		parent.add_child(player)
		_players.append(player)


static func play(sfx: Sfx) -> void:
	if _sfx_volume <= 0.0:
		return
	play_log.append(sfx)
	if _players.is_empty():
		return
	var stream: AudioStream = load(SFX_PATHS[sfx])
	if stream == null:
		return
	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.volume_db = _volume_to_db(_sfx_volume)
	player.play()


## 0.0(無音)〜1.0(最大)の効果音音量。
static func get_sfx_volume() -> float:
	return _sfx_volume


static func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	for player in _players:
		player.volume_db = _volume_to_db(_sfx_volume)
	_save_settings()


## 0.0(無音)〜1.0(最大)のBGM音量。
static func get_bgm_volume() -> float:
	return _bgm_volume


static func set_bgm_volume(value: float) -> void:
	_bgm_volume = clampf(value, 0.0, 1.0)
	MusicPlayer.set_volume(_bgm_volume)
	_save_settings()


static func is_muted() -> bool:
	return _sfx_volume <= 0.0


## シーンツリーを走査し、全Buttonのpressedへボタン押下音を接続する。
## 個別に繋ぐと数が多く漏れやすいため、Main起動時に一括で呼ぶ想定。
## 反転/移動/交代の専用音を持つActionMenuのボタンは、二重に鳴らさないため対象外にする。
static func wire_buttons(root: Node) -> void:
	if root is ActionMenu:
		return
	if root is Button:
		var callback := play.bind(Sfx.BUTTON)
		if not root.pressed.is_connected(callback):
			root.pressed.connect(callback)
	for child in root.get_children():
		wire_buttons(child)


static func _volume_to_db(value: float) -> float:
	if value <= MIN_AUDIBLE_VOLUME:
		return -80.0
	return linear_to_db(value)


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
