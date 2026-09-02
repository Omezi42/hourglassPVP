class_name PressTracker
extends RefCounted

## クリック可能な要素の「押し込み→離した位置で確定/取り消し」を共通で扱う。
## 各コンポーネントはメンバー変数として1個持ち、_gui_input()にイベントとサイズを渡して結果を受け取る。
## 押した場所の外で離した場合はキャンセル扱いとし、誤操作の取り消し手段にする。

enum Result { NONE, PRESSED, CONFIRMED, CANCELED }

## 指のブレ(タッチスロープ)の許容マージン(px)。
const SLOP_MARGIN := 8.0

var _is_pressed := false


func feed(event: InputEvent, local_size: Vector2) -> Result:
	if ClickArea.is_primary_click(event):
		_is_pressed = true
		return Result.PRESSED

	if _is_pressed and ClickArea.is_primary_release(event):
		_is_pressed = false
		var release_position := Vector2.ZERO
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			release_position = event.position
		var hit_rect := Rect2(
			-Vector2(SLOP_MARGIN, SLOP_MARGIN),
			local_size + Vector2(SLOP_MARGIN * 2.0, SLOP_MARGIN * 2.0)
		)
		var inside := hit_rect.has_point(release_position)
		return Result.CONFIRMED if inside else Result.CANCELED

	return Result.NONE


## ドラッグ開始など、離すイベントを経由せず押下状態を打ち切りたい場合に呼ぶ。
## 直前まで押されていた場合はtrueを返す(呼び出し側が見た目を元に戻す判断に使う)。
func cancel() -> bool:
	var was_pressed := _is_pressed
	_is_pressed = false
	return was_pressed
