class_name TutorialSkip
extends Control
## 誘導対局の帯の右上に置く「スキップ」(GameDesign.md 18章)。押すと確かめたうえで、
## `CardMatchScreen.abandon_match()` → `back_pressed` という、待っている間のCPU戦を
## 打ち切る経路(11章)と同じ形でホームへ抜ける。勝敗・砂金・戦績・リプレイのいずれも
## 残らず、`UiState.mark_tutorial_done()` も呼ばない(スキップは「終えた」扱いにしないため)。
##
## `card_match_tutorial.gd` が行数の上限に近いため別に持ち、帯(`_band`)の子として
## 足すだけにする。

const BUTTON_SIZE := Vector2(72, 22)
const FONT_SIZE := 12
const MARGIN := 6.0
const CONFIRM_SCENE := "res://scenes/confirm_modal.tscn"
const TITLE := "誘導対局を飛ばしますか?"
const BODY := "おぼえるタブからいつでも遊べます"

var _screen: CardMatchScreen
var _confirm: ConfirmModal


func _init(screen: CardMatchScreen, band_size: Vector2) -> void:
	_screen = screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = band_size

	var button := CodedButton.make("スキップ", BUTTON_SIZE)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.position = Vector2(band_size.x - BUTTON_SIZE.x - MARGIN, MARGIN)
	button.pressed.connect(_on_skip_pressed)
	add_child(button)

	_confirm = load(CONFIRM_SCENE).instantiate()
	_confirm.confirmed.connect(_on_skip_confirmed)
	_screen.add_child(_confirm)


func _on_skip_pressed() -> void:
	_confirm.open_confirm(TITLE, BODY, "飛ばす", "もどる")


func _on_skip_confirmed() -> void:
	FunnelService.reach(FunnelService.TUTORIAL_SKIP)
	_screen.abandon_match()
	_screen.back_pressed.emit()
