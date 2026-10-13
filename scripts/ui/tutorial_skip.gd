class_name TutorialSkip
extends Control
## 誘導対局の間、画面の左下(手札の左の空き)に固定して出す「スキップ」(GameDesign.md 18章)。押すと確かめたうえで、
## `CardMatchScreen.abandon_match()` → `back_pressed` という、待っている間のCPU戦を
## 打ち切る経路(11章)と同じ形でホームへ抜ける。勝敗・砂金・戦績・リプレイのいずれも
## 残らず、`UiState.mark_tutorial_done()` も呼ばない(スキップは「終えた」扱いにしないため)。
##
## `card_match_tutorial.gd` が行数の上限に近いため別に持つ。帯の子にするとマリガン中に帯ごと
## 動くため、`CardMatchTutorial` の子として画面座標へ置く。

const BUTTON_SIZE := Vector2(112, 32)
const FONT_SIZE := 14
## 自分の名前の下・バージョン表記の上の空き(手札より左)。
const BUTTON_POSITION := Vector2(44, 620)
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
const TITLE := "誘導対局を飛ばしますか?"
const BODY := "おぼえるタブからいつでも遊べます"

var _screen: CardMatchScreen
## 今の手順の番号を返す(通過数へ飛ばした手順を残すため)。
var _step_index: Callable
var _confirm: ConfirmModal
var _button: Button


func _init(screen: CardMatchScreen, screen_size: Vector2, step_index: Callable) -> void:
	_screen = screen
	_step_index = step_index
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = screen_size

	var button := CodedButton.make("スキップ", BUTTON_SIZE)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.position = BUTTON_POSITION
	button.pressed.connect(_on_skip_pressed)
	add_child(button)
	_button = button

	_confirm = load(CONFIRM_SCENE).instantiate()
	_confirm.confirmed.connect(_on_skip_confirmed)
	_screen.add_child(_confirm)


# ボタンは木へ入るときに文字の大きさを替える前の大きさへ広がり、自分では縮まないため戻す。
func _ready() -> void:
	_button.size = BUTTON_SIZE


func _on_skip_pressed() -> void:
	_confirm.open_confirm(TITLE, BODY, "飛ばす", "もどる")


func _on_skip_confirmed() -> void:
	FunnelService.reach_tutorial_skip(_step_index.call())
	_screen.abandon_match()
	_screen.back_pressed.emit()
