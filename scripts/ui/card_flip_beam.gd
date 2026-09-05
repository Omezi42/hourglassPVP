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
## 反転の筋だけが引く砂粒の数と、1粒ぶんの間隔(進捗)。
const GRAIN_COUNT := 11
const GRAIN_SPACING := 0.035
## 着弾で四方へ伸びる光条の本数と長さ。
const RAY_COUNT := 7
const RAY_REACH := 46.0

## 出ている筋。{"from":..., "to":..., "color":..., "progress":..., "grand":...}
var _beams: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	size = SCREEN_SIZE


## 反転を見せる。**行った側の情報帯から対象の駒へ光の筋を伸ばし、届いた瞬間に裏返す**
## (GameDesign.md 9章)。通常の反転は自分の駒しか対象に取れないため、
## 筋の出どころ(`actor_side`)は駒の持ち主(`side`)と一致する。
## **反転権(GameDesign.md 2章)は敵味方どちらの駒も対象に取れる**ため、
## 手を出した側(`actor_side`)と駒の持ち主(`side`)を別々に受け取れるようにしている。
func play_flip(screen: CardMatchScreen, side: int, slot: int, actor_side: int = side) -> void:
	var view := screen.view_at(side, slot)
	var bar_y: float = (
		CardMatchScreen.OWN_BAR_TOP if actor_side == screen.my_side else CardMatchScreen.FOE_BAR_TOP
	)
	var from := Vector2(screen.size.x * 0.5, bar_y + PlayerInfoBar.BAR_HEIGHT * 0.5)
	# 反転だけは砂粒と光条を伴う(GameDesign.md 9章)。設置効果と同じ筋を使う以上、
	# 色を変えるだけでは「ゲームの中心となる行動」に見えないため。
	await play(from, unit_center(view), COLOR, true)
	view.play_flip()


## 駒の中心。筋の行き先として使う。
static func unit_center(view: CardView) -> Vector2:
	return (
		view.position
		+ Vector2(view.size.x * 0.5, CardView.PEDESTAL_CENTER_Y - CardView.BOARD_ART_SIDE * 0.5)
	)


## `grand` は反転のときだけ true。砂粒の尾と着弾の光条が付く。
func play(from: Vector2, to: Vector2, color: Color = COLOR, grand := false) -> void:
	# **ラムダは外側のローカル変数を値でキャプチャする**(Architecture.md 11章)ため、
	# 進捗は Dictionary(参照)の要素として持つ。
	var beam := {"from": from, "to": to, "color": color, "progress": 0.0, "grand": grand}
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
	if beam["grand"]:
		_draw_grains(from, to, color, progress)
	if progress <= BURST_AT:
		return
	var burst := (progress - BURST_AT) / (1.0 - BURST_AT)
	draw_circle(to, 10.0 + 28.0 * burst, Color(color, 0.5 * (1.0 - burst)))
	if beam["grand"]:
		_draw_rays(to, color, burst)


## 筋の後ろを追う砂粒。**筋に沿ってではなく、左右へ散らしながら遅れて付いてくる**。
## 一直線に並べると線が太くなっただけに見え、砂が舞っているように読めない。
func _draw_grains(from: Vector2, to: Vector2, color: Color, progress: float) -> void:
	var along := (to - from).normalized()
	var across := Vector2(-along.y, along.x)
	for i in GRAIN_COUNT:
		var back := progress - GRAIN_SPACING * float(i + 1)
		if back <= 0.0:
			continue
		var fade := 1.0 - float(i) / float(GRAIN_COUNT)
		# 位相をずらした正弦で散らす。毎フレーム乱数を引くと粒がちらつく。
		var spread := sin(float(i) * 2.4 + progress * 16.0) * (2.5 + float(i) * 0.9)
		var at := from.lerp(to, back) + across * spread
		draw_circle(at, 1.0 + 2.0 * fade, Color(color, 0.75 * fade))


## 着弾の光条。**閃光の円だけでは「届いた」ことしか伝わらない**ため、
## 四方へ伸びる線を重ねて衝撃そのものを見せる。
func _draw_rays(at: Vector2, color: Color, burst: float) -> void:
	var fade := 1.0 - burst
	for i in RAY_COUNT:
		var angle := TAU * float(i) / float(RAY_COUNT) + burst * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			at + direction * (8.0 + 10.0 * burst),
			at + direction * (8.0 + RAY_REACH * burst),
			Color(color, 0.85 * fade),
			1.0 + 2.6 * fade
		)
