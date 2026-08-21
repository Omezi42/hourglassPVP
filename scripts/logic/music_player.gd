class_name MusicPlayer
extends RefCounted

## BGMの再生を担当するstaticクラス。SoundBank(効果音)と同じ
## 「Autoloadを使わずstaticで持つ」流儀に揃える。
## 効果音が「1発鳴らして終わり」なのに対し、BGMはクロスフェード・ループ・
## 自動再生制限の解除といった継続的な状態を持つため、クラスを分けている。
## 音量の単一情報源はSoundBank側にあり、こちらへは一方向にプッシュされる。

enum Track { TITLE, HOME, MATCH }

const TRACK_PATHS := {
	Track.TITLE: "res://assets/bgm/title.ogg",
	Track.HOME: "res://assets/bgm/home.ogg",
	Track.MATCH: "res://assets/bgm/match.ogg",
}

## 曲を切り替えるときのクロスフェード時間。画面遷移(0.18秒)よりかなり長くとり、
## 画面が変わった後もしばらく前の曲が残ることで切り替えの唐突さをなくす。
const FADE_DURATION := 1.4
## クラシックは楽曲として完結しておりシームレスにループしないため、
## 終わりまで再生したら一度間を置いてから頭へ戻す(GameDesign.md 9章)。
const LOOP_GAP := 3.0
## 曲の終わりを鳴りっぱなしで断ち切らず、末尾をこの秒数かけて絞る。
## タイトル曲のように途中で切り出した音源でも、切れ目が唐突に聞こえないようにするため。
const TAIL_FADE := 3.0
## クロスフェード用に2本持つ。1本だけだと切り替え時に無音が挟まる。
const PLAYER_COUNT := 2
const SILENT_DB := -80.0
const MIN_AUDIBLE_VOLUME := 0.0001
## トラック未指定を表す。enumの値と衝突しない負値を使う。
const NO_TRACK := -1

static var _players: Array[AudioStreamPlayer] = []
static var _fades: Array[Tween] = []
## 末尾フェード中かどうか。この間の音量は曲の終わりへ向けて絞っている途中であり、
## 設定変更(set_volume)で元の音量へ戻してはいけない。
static var _tail_fading: Array[bool] = []
static var _active_index := 0
static var _volume := 0.0
static var _current := NO_TRACK
## ブラウザは最初のユーザー操作より前の音声再生を許さないため、操作を検知するまでは
## 要求されたトラックを覚えておくだけにし、notify_user_gesture()で実際に鳴らし始める。
static var _unlocked := false
static var _pending := NO_TRACK
static var _host: Node = null


static func ensure_ready(parent: Node) -> void:
	if not _players.is_empty():
		return
	_host = parent
	for i in range(PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		parent.add_child(player)
		player.finished.connect(_on_finished.bind(i))
		_players.append(player)
		_fades.append(null)
		_tail_fading.append(false)


## 指定トラックへ切り替える。既に同じ曲が鳴っていれば何もしない
## (画面遷移のたびに呼ばれるため、頭から鳴り直さないようにする)。
static func play(track: Track) -> void:
	if _players.is_empty():
		return
	if _current == track and _players[_active_index].playing:
		return
	if not _unlocked:
		_pending = track
		return
	_start(track)


## 最初のクリック/タップで呼ぶ。ブラウザの自動再生制限で保留していた曲をここから鳴らし始める。
static func notify_user_gesture() -> void:
	if _unlocked:
		return
	_unlocked = true
	if _pending != NO_TRACK:
		_start(_pending)
		_pending = NO_TRACK


static func stop() -> void:
	_current = NO_TRACK
	_pending = NO_TRACK
	for i in range(_players.size()):
		if _players[i].playing:
			_fade_out_and_stop(i)


## SoundBank.set_bgm_volume()から呼ばれる。自前で永続化はしない。
static func set_volume(value: float) -> void:
	_volume = clampf(value, 0.0, 1.0)
	if _players.is_empty():
		return
	if not _players[_active_index].playing:
		return
	if _tail_fading[_active_index]:
		return
	_kill_fade(_active_index)
	_players[_active_index].volume_db = _target_db()


static func _start(track: int) -> void:
	var stream: AudioStream = load(TRACK_PATHS[track])
	if stream == null:
		return
	# インポート設定でループを有効にするとfinishedが発火せず、
	# 「終わりまで鳴らしてから間を置いて頭へ戻す」制御ができなくなる。
	stream.loop = false
	var previous_index := _active_index
	_active_index = (_active_index + 1) % _players.size()
	_current = track
	var next := _players[_active_index]
	_kill_fade(_active_index)
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_tail_fading[_active_index] = false
	_fade_to(_active_index, _target_db())
	_schedule_tail_fade(_active_index, track, stream.get_length())
	if previous_index != _active_index and _players[previous_index].playing:
		_fade_out_and_stop(previous_index)


static func _fade_to(index: int, to_db: float, duration := FADE_DURATION) -> void:
	var player := _players[index]
	_kill_fade(index)
	if _host == null:
		player.volume_db = to_db
		return
	var tween := _host.create_tween()
	tween.tween_property(player, "volume_db", to_db, duration)
	_fades[index] = tween


## 曲の終わりのTAIL_FADE秒前から音量を絞り始めるよう予約する。
static func _schedule_tail_fade(index: int, track: int, length: float) -> void:
	if _host == null or length <= TAIL_FADE * 2.0:
		return
	var timer := _host.get_tree().create_timer(length - TAIL_FADE)
	timer.timeout.connect(_begin_tail_fade.bind(index, track))


static func _begin_tail_fade(index: int, track: int) -> void:
	if _current != track or index != _active_index:
		return
	if not _players[index].playing:
		return
	_tail_fading[index] = true
	_fade_to(index, SILENT_DB, TAIL_FADE)


static func _fade_out_and_stop(index: int) -> void:
	var player := _players[index]
	_kill_fade(index)
	if _host == null:
		player.stop()
		return
	var tween := _host.create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, FADE_DURATION)
	tween.tween_callback(player.stop)
	_fades[index] = tween


static func _kill_fade(index: int) -> void:
	if index < 0 or index >= _fades.size():
		return
	var tween := _fades[index]
	if tween != null and tween.is_valid():
		tween.kill()
	_fades[index] = null


## 曲が最後まで鳴り終わったときの「アルバム再生」ループ。フェードアウト中に終端へ達した
## 旧プレイヤーからも発火するため、今鳴らしている本体からの通知だけを受け付ける。
static func _on_finished(index: int) -> void:
	if index != _active_index or _current == NO_TRACK or _host == null:
		return
	var track := _current
	var timer := _host.get_tree().create_timer(LOOP_GAP)
	timer.timeout.connect(_replay_if_unchanged.bind(track, index))


static func _replay_if_unchanged(track: int, index: int) -> void:
	if _current != track or index != _active_index:
		return
	var player := _players[index]
	if player.playing:
		return
	_tail_fading[index] = false
	player.volume_db = _target_db()
	player.play()
	_schedule_tail_fade(index, track, player.stream.get_length())


static func _target_db() -> float:
	if _volume <= MIN_AUDIBLE_VOLUME:
		return SILENT_DB
	return linear_to_db(_volume)
