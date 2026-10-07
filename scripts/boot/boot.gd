extends Control
## 起動シーン(GameDesign.md 9章「タイトル」、Architecture.md 4.0.6節)。タイトルだけを先に出し、
## 残りのスクリプトをタイトルを見ている間に少しずつ読み込んでから `Main` へ引き渡す。
## Godot は class_name を参照するたびに参照先を解析し直すため、全画面を一度に読むと起動が十数秒止まる。
##
## 読み終える前に押された開始・アカウントは預かり、引き渡した後にタイトルから出し直す。

const LOAD_ORDER := preload("res://scripts/boot/script_load_order.gd")
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
## 1フレームで読み込みに使う時間。超えたら次のフレームへ回す(タイトルの動きを止めないため)。
const FRAME_BUDGET_MSEC := 12

var _title: TitleScreen
var _next := 0
## 読み終える前に押されたタイトルのシグナル名。空なら押されていない。
var _pending := ""
var _gesture_seen := false
var _on_start := _on_title_pressed.bind("start_requested")
var _on_account := _on_title_pressed.bind("account_requested")


func _ready() -> void:
	_title = (load(TITLE_SCENE) as PackedScene).instantiate()
	add_child(_title)
	_title.start_requested.connect(_on_start)
	_title.account_requested.connect(_on_account)


func _process(_delta: float) -> void:
	var paths: Array[String] = LOAD_ORDER.PATHS
	var started := Time.get_ticks_msec()
	while _next < paths.size() and Time.get_ticks_msec() - started < FRAME_BUDGET_MSEC:
		load(paths[_next])
		_next += 1
	if not _pending.is_empty():
		# 最後の1段(`main.tscn` の読み込みと組み立て)のぶん、100%には届かせない。
		_title.show_loading(float(_next) / float(paths.size() + 1))
	if _next >= paths.size():
		set_process(false)
		_hand_over()


## ブラウザの音声は最初の操作まで鳴らせない。引き渡す前の操作も `Main` へ伝える。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey:
		_gesture_seen = true


func _on_title_pressed(signal_name: String) -> void:
	if _pending.is_empty():
		_pending = signal_name
		_title.show_loading(float(_next) / float(LOAD_ORDER.PATHS.size() + 1))


func _hand_over() -> void:
	# `Main` の型をここで書くと、このスクリプトを読んだ時点で全画面のコンパイルが走る。
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	_title.start_requested.disconnect(_on_start)
	_title.account_requested.disconnect(_on_account)
	remove_child(_title)
	main.call("adopt_title", _title)
	var tree := get_tree()
	tree.root.add_child(main)
	tree.current_scene = main
	if _gesture_seen:
		main.call("note_user_gesture")
	if not _pending.is_empty():
		_title.show_loading(1.0)
		_title.emit_signal(_pending)
	queue_free()
