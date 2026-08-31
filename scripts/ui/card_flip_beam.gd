class_name CardFlipBeam
extends Control
## 盤面へ伸びる光の筋(GameDesign.md 9章)。**誰がその駒に手を出したのかが分かる演出にする。**
## 反転では行った側の情報帯から、設置効果では出した駒から、対象へ筋が伸びる。
##
## 盤面の駒より手前へ重ねる必要があるため、対局画面の `_draw()` ではなく
## 独立したオーバーレイとして持つ(`Control._draw()` は自分の子より背面に描かれるため、
## 画面側で描くと卓と駒に隠れて筋がほとんど見えない)。
##
## **筋は同時に何本でも出せる**。全体に効く効果(スイープ)は対象の数だけ同時に伸ばすため。
## 色で用途を分ける(反転=金 / 効果=対象に応じた色)。

const SCREEN_SIZE := Vector2(1280, 720)

const DURATION := 0.2
## 反転。ゲームの中心となる行動のため、他と混ざらない金で通す。
const COLOR := Color(1.0, 0.86, 0.5, 1.0)
## 設置効果が相手を狙ったとき。
const EFFECT_HOSTILE := Color(1.0, 0.52, 0.42, 1.0)
## 設置効果が自分側を狙ったとき(回復・強化)。
const EFFECT_FRIENDLY := Color(0.6, 1.0, 0.72, 1.0)
## 着弾の閃光を出し始める進捗。
const BURST_AT := 0.85

## 出ている筋。{"from":..., "to":..., "color":..., "progress":...}
var _beams: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	size = SCREEN_SIZE


## 反転を見せる。**行った側の情報帯から対象の駒へ光の筋を伸ばし、届いた瞬間に裏返す**
## (GameDesign.md 9章)。自分の駒しか反転できないため、筋が上から来るか下から来るかが
## そのまま「どちらが手を出したか」になる。筋と裏返りの段取りをこの1箇所へ収めている。
func play_flip(screen: CardMatchScreen, side: int, slot: int) -> void:
	var view := screen.view_at(side, slot)
	var bar_y: float = (
		CardMatchScreen.OWN_BAR_TOP if side == screen.my_side else CardMatchScreen.FOE_BAR_TOP
	)
	var from := Vector2(screen.size.x * 0.5, bar_y + PlayerInfoBar.BAR_HEIGHT * 0.5)
	await play(from, unit_center(view))
	view.play_flip()


## 駒の中心。筋の行き先として使う。
static func unit_center(view: CardView) -> Vector2:
	return (
		view.position
		+ Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - CardView.BOARD_ART_SIDE * 0.5)
	)


func play(from: Vector2, to: Vector2, color: Color = COLOR) -> void:
	# **ラムダは外側のローカル変数を値でキャプチャする**(Architecture.md 11章)ため、
	# 進捗は Dictionary(参照)の要素として持つ。
	var beam := {"from": from, "to": to, "color": color, "progress": 0.0}
	_beams.append(beam)
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			beam["progress"] = value
			queue_redraw(),
		0.0,
		1.0,
		DURATION
	)
	await tween.finished
	_beams.erase(beam)
	queue_redraw()


func _draw() -> void:
	for beam in _beams:
		_draw_beam(beam)


func _draw_beam(beam: Dictionary) -> void:
	var from: Vector2 = beam["from"]
	var to: Vector2 = beam["to"]
	var color: Color = beam["color"]
	var progress: float = beam["progress"]
	var head: Vector2 = from.lerp(to, progress)
	draw_line(from, head, Color(color, 0.3), 7.0)
	draw_line(from, head, Color(color, 0.95), 2.0)
	draw_circle(head, 7.0, Color(color, 0.9))
	if progress <= BURST_AT:
		return
	var burst := (progress - BURST_AT) / (1.0 - BURST_AT)
	draw_circle(to, 10.0 + 28.0 * burst, Color(color, 0.5 * (1.0 - burst)))
