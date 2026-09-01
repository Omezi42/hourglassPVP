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
## 各画面のコンテンツ領域の高さ。下端にも外周余白を残す。**画面ごとに数えない**
## (数え直すと、ヘッダーの高さを変えたときに追随しない画面が残る)。
const CONTENT_HEIGHT := 720.0 - CONTENT_TOP - OUTER_MARGIN

## タイトルの後ろへ敷く暗幕。背景イラストが賑やかな画面でも画面名が読めるようにする。
## 中央は濃く、左右へ向かって消える(端まで一様に敷くと帯が1本乗ったように見えるため)。
const SCRIM_CORE_WIDTH := 420.0
const SCRIM_FADE_WIDTH := 170.0
const SCRIM_COLOR := Color(0.05, 0.04, 0.06, 0.55)
## ヘッダーの下端に通す真鍮の細線。全画面で同じ位置に出て、ヘッダーの帯を構造として示す。
const RULE_COLOR := Color(0.85, 0.62, 0.22, 0.35)

@onready var back_button: Button = $Row/BackButton
@onready var title_label: Label = $TitleLabel
@onready var action_slot: HBoxContainer = $Row/ActionSlot


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_pressed.emit())


## `Control._draw()` は自分の子より背面に描かれるため、ここで敷いたものは
## タイトル・戻るボタン・主アクションのいずれにも被らない。
func _draw() -> void:
	var center := size.x * 0.5
	var core := SCRIM_CORE_WIDTH * 0.5
	var clear := Color(SCRIM_COLOR, 0.0)
	draw_rect(Rect2(center - core, 0.0, SCRIM_CORE_WIDTH, size.y), SCRIM_COLOR)
	for direction in [-1.0, 1.0]:
		var inner: float = center + core * direction
		var outer: float = inner + SCRIM_FADE_WIDTH * direction
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(inner, 0.0),
					Vector2(outer, 0.0),
					Vector2(outer, size.y),
					Vector2(inner, size.y)
				]
			),
			PackedColorArray([SCRIM_COLOR, clear, clear, SCRIM_COLOR])
		)
	draw_line(Vector2(0.0, size.y), Vector2(size.x, size.y), RULE_COLOR, 2.0)


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
