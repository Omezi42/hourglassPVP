class_name CardMatchShake
extends RefCounted
## 攻撃が当たった瞬間に盤面を揺らす(GameDesign.md 9章)。
##
## **揺らすのは卓と場の駒だけ**で、上下の情報帯・手札・画面右の行動の列は動かさない。
## HP・マナ・山札は判断のために読み続けるものであり、攻撃のたびに揺れると読めなくなる。
##
## `CardMatchStrike` と同じく、対局画面から切り出した進行役の1つ
## (`card_match_screen.gd` が1000行の上限に近いため)。

## 揺れが収まるまで。**短く保つ**——長いと打撃ではなく地震に見える。
const DURATION := 0.22
## 1秒あたりの往復。高いほど硬いものを叩いた音の見た目になる。
const FREQUENCY := 52.0
## 攻撃力に関わらず必ず出る最小の振れ幅(px)。
const BASE_AMOUNT := 2.0
## 攻撃力1あたりの上乗せ(px)。
const PER_POWER := 0.55
## 振れ幅の上限(px)。大型どうしがぶつかっても画面が壊れて見えないところで止める。
const MAX_AMOUNT := 7.0
## 縦の揺れは横より控えめにする。横だけだと平面的に見え、同じ量だと画面が回って見える。
const VERTICAL_RATIO := 0.55

## 揺らす対象と、その基準位置。**基準を控えるのは、揺れが累積しないようにするため**
## (毎フレーム position へ足すと戻らなくなる)。
var _targets: Array[Control] = []
var _bases: PackedVector2Array = PackedVector2Array()
var _amount := 0.0
var _left := 0.0


## 揺らす対象を登録する。対局画面の `_build()` から1度だけ呼ぶ。
## **位置が後から変わらないものだけ**を渡すこと(手札は毎ターン並べ替わるため対象外)。
func bind(targets: Array[Control]) -> void:
	_targets = targets
	_bases.clear()
	for target in _targets:
		_bases.append(target.position)


## 当たった。`power` は当てた駒の攻撃力。
## **揺れている最中に次の攻撃が当たったら、振れ幅を足さずに大きいほうで上書きする**
## (連撃や6枠が並ぶ中盤で揺れが累積し、盤面がぶれ続けるのを防ぐ。GameDesign.md 9章)。
func hit(power: int) -> void:
	if _targets.is_empty():
		return
	_amount = maxf(_amount, minf(BASE_AMOUNT + float(maxi(power, 0)) * PER_POWER, MAX_AMOUNT))
	_left = DURATION


func tick(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	if _left <= 0.0:
		_amount = 0.0
		_apply(Vector2.ZERO)
		return
	# 二乗で減衰させる。線形だと最後まで同じ勢いで揺れて、収まった感じが出ない。
	var decay := _left / DURATION
	var strength := _amount * decay * decay
	var phase := (DURATION - _left) * FREQUENCY
	# 横と縦で周期をずらす。同じだと斜めの直線を往復するだけになる。
	_apply(Vector2(sin(phase) * strength, cos(phase * 1.37) * strength * VERTICAL_RATIO))


func _apply(offset: Vector2) -> void:
	for i in _targets.size():
		_targets[i].position = _bases[i] + offset
