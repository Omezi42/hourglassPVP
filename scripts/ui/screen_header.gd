class_name ScreenHeader
extends Control

## 対局画面を除く全画面が共通で使うヘッダー(GameDesign.md 9章)。
## 左=戻るボタン / 中央=画面タイトル / 右=その画面の主アクション。
## 高さ・余白をこの1箇所で決め、画面ごとに個別の値を持たせない。

signal back_pressed

## 画面の外周余白。コンテンツ側のマージンもこの値に揃える。
const OUTER_MARGIN := 24.0
## ヘッダー自体の高さ。
const HEADER_HEIGHT := 88.0
## ヘッダーの下端からコンテンツ開始までの余白。
const CONTENT_GAP := 24.0
## 各画面のコンテンツ領域の開始y座標(OUTER_MARGIN + HEADER_HEIGHT + CONTENT_GAP)。
const CONTENT_TOP := OUTER_MARGIN + HEADER_HEIGHT + CONTENT_GAP

@onready var back_button: Button = $Row/BackButton
@onready var title_label: Label = $TitleLabel
@onready var action_slot: HBoxContainer = $Row/ActionSlot


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_pressed.emit())


func set_title(text: String) -> void:
	title_label.text = text


func set_back_visible(value: bool) -> void:
	back_button.visible = value


## 主アクションのボタンを右側へ寄せる。既に別の親を持つノードもそのまま渡せる。
func add_action(button: Control) -> void:
	var parent: Node = button.get_parent()
	if parent != null:
		parent.remove_child(button)
	action_slot.add_child(button)
