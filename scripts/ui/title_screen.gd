class_name TitleScreen
extends Control
## 起動して最初に出るタイトル画面(GameDesign.md 9章)。
## 画面のどこかを押すとホーム画面へ移る。移るときの演出はMainのSandTransitionが担う。
##
## ロゴと背景は画像アセットを優先し、未配置ならコード描画(TitleLogo)と
## ホーム画面の背景で代替する。画像の生成はユーザーの手作業で行う運用のため、
## 画像が無い状態でも画面が成立している必要がある。

signal start_requested
## 右下の「アカウント」を押した(GameDesign.md 14章)。開始とは別の導線。
signal account_requested

## ロゴ画像を置く場所。ここにファイルがあれば、コード描画の代わりにこれを表示する。
const LOGO_PATH := "res://assets/title/logo.png"
## タイトル専用の背景。無ければホーム画面のものを流用する。
const BACKGROUND_PATH := "res://assets/backgrounds/processed/title/background.png"
const FALLBACK_BACKGROUND_PATH := "res://assets/backgrounds/processed/home/background.png"

## 起動直後にロゴが浮かび上がるまで。厳かに見せたいので、他のUIのフェード(0.18秒)より長い。
const INTRO_DURATION := 1.1
const INTRO_RISE := 26.0
## ロゴがゆっくり上下する幅と周期。静止画に見えないようにするためだけの微動。
const FLOAT_AMPLITUDE := 7.0
const FLOAT_PERIOD := 4.6
## 「クリックしてはじめる」の明滅。
const BLINK_PERIOD := 1.6
const BLINK_MIN_ALPHA := 0.28
## 押された瞬間の演出。ロゴが一瞬伸び上がって光る。
const LAUNCH_DURATION := 0.42
const LAUNCH_SCALE := 1.06

var _started := false
var _float_time := 0.0
var _logo_rest_y := 0.0

@onready var background: TextureRect = $Background
@onready var logo_holder: Control = $LogoHolder
@onready var logo_image: TextureRect = $LogoHolder/LogoImage
@onready var logo_drawn: TitleLogo = $LogoHolder/LogoDrawn
@onready var start_label: Label = $StartLabel
@onready var account_button: Button = $AccountButton


func _ready() -> void:
	background.texture = _load_texture(BACKGROUND_PATH, FALLBACK_BACKGROUND_PATH)
	var logo := _load_texture(LOGO_PATH, "")
	logo_image.texture = logo
	logo_image.visible = logo != null
	logo_drawn.visible = logo == null
	_logo_rest_y = logo_holder.position.y
	logo_holder.pivot_offset = logo_holder.size * 0.5
	account_button.pressed.connect(func() -> void: account_requested.emit())
	_play_intro()


func _process(delta: float) -> void:
	_float_time += delta
	if not _started:
		logo_holder.position.y = (
			_logo_rest_y + sin(_float_time * TAU / FLOAT_PERIOD) * FLOAT_AMPLITUDE
		)
	var blink := absf(sin(_float_time * PI / BLINK_PERIOD))
	start_label.modulate.a = lerpf(BLINK_MIN_ALPHA, 1.0, blink)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_begin_start()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or _started:
		return
	if event.is_pressed() and (event.is_action("ui_accept") or event.is_action("ui_select")):
		_begin_start()


## 押された瞬間の演出。Mainはこれを待ってから砂のトランジションへ入る。
func play_launch() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(logo_holder, "scale", Vector2.ONE * LAUNCH_SCALE, LAUNCH_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(
		logo_holder, "modulate", Color(1.35, 1.28, 1.1, 1.0), LAUNCH_DURATION * 0.6
	)
	tween.tween_property(start_label, "modulate:a", 0.0, LAUNCH_DURATION * 0.5)
	await tween.finished


## タイトルへ戻ってきた場合(将来ホームから戻す導線を足した場合)に備え、押せる状態へ戻す。
func reset() -> void:
	_started = false
	logo_holder.scale = Vector2.ONE
	logo_holder.modulate = Color.WHITE
	logo_holder.position.y = _logo_rest_y
	start_label.modulate.a = 1.0


func _begin_start() -> void:
	if _started:
		return
	_started = true
	SoundBank.play(SoundBank.Sfx.BUTTON)
	start_requested.emit()


func _play_intro() -> void:
	logo_holder.modulate.a = 0.0
	logo_holder.position.y = _logo_rest_y + INTRO_RISE
	start_label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(logo_holder, "modulate:a", 1.0, INTRO_DURATION)
	(
		tween
		. tween_property(logo_holder, "position:y", _logo_rest_y, INTRO_DURATION)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func _load_texture(path: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if fallback != "" and ResourceLoader.exists(fallback):
		return load(fallback) as Texture2D
	return null
