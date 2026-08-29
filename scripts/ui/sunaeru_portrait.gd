class_name SunaeruPortrait
extends Control
## 誘導対局の指示の帯へ添える、すなえるの立ち絵(GameDesign.md 18章)。
##
## **絵を持つだけのノード**にしてある。何を言うかは `CardMatchTutorial` が持ち、
## こちらは「そこにいる」ことと「反応する」ことだけを受け持つ。
##
## **口を描かない設計のため表情の差分を持たない。**段階が進んだときの反応は、
## 絵の差し替えではなく跳ねる動きで見せる。

const TEXTURE_PATH := "res://assets/mascot/mascot_avatar.png"
## ふわふわと上下する幅。羽が生えているので、地に足を着けて立たせない。
const BOB_HEIGHT := 3.0
const BOB_SECONDS := 2.4
## 段階を達成したときに跳ねる高さと尺。
const CHEER_HEIGHT := 10.0
const CHEER_SECONDS := 0.45

var _texture: Texture2D
var _time := 0.0
var _cheer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TEXTURE_PATH):
		_texture = load(TEXTURE_PATH)


## 段階を1つ終えたときに1度だけ跳ねる。
func cheer() -> void:
	_cheer = CHEER_SECONDS


func _process(delta: float) -> void:
	_time += delta
	if _cheer > 0.0:
		_cheer = maxf(_cheer - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	# 縦横比のまま収め、下端で揃える(枠へ引き伸ばさない。Architecture.md 4.0節と同じ扱い)。
	var src := Vector2(_texture.get_width(), _texture.get_height())
	if src.x <= 0.0 or src.y <= 0.0:
		return
	var scale := minf(size.x / src.x, size.y / src.y)
	var drawn := src * scale
	var bob := sin(_time * TAU / BOB_SECONDS) * BOB_HEIGHT
	# 跳ねは、上がって落ちる1山ぶん(sin の半周)にする。
	var hop := sin((1.0 - _cheer / CHEER_SECONDS) * PI) * CHEER_HEIGHT if _cheer > 0.0 else 0.0
	var pos := Vector2((size.x - drawn.x) * 0.5, size.y - drawn.y - bob - hop)
	draw_texture_rect(_texture, Rect2(pos, drawn), false)
