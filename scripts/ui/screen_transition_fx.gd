class_name ScreenTransitionFx
extends RefCounted
## `Main._show_only()` の横移動を1箇所へ持つ(GameDesign.md 9章「メニュー画面群の手触り」)。
## フェードと同時に、次の画面を進行方向から・前の画面を進行方向の逆へ、それぞれ
## 数十px分ずらしてから0へ寄せる。ハードカットではないという既存の方針は変えず、
## フェードへ横移動を重ねるだけに留める。

## ずらす量。フェード(0.18秒)の短さに合わせ、大きく動かさない。
const OFFSET_PX := 28.0


## entering(次の画面)・leaving(前の画面。無ければnull)へ横移動をtweenへ足す。
## going_back が真なら「進行方向」を反転する(戻る操作は左右が入れ替わる)。
static func apply(
	tween: Tween, entering: Control, leaving: Control, going_back: bool, duration: float
) -> void:
	var direction := -1.0 if going_back else 1.0
	entering.position.x = OFFSET_PX * direction
	tween.tween_property(entering, "position:x", 0.0, duration)
	if leaving != null:
		leaving.position.x = 0.0
		tween.tween_property(leaving, "position:x", -OFFSET_PX * direction, duration)


## 遷移が終わったら両者を0位置へ戻す。画面は使い回すため、位置がずれたまま
## 残ると次に表示したときの初期位置まで狂う。
static func reset(entering: Control, leaving: Control) -> void:
	entering.position.x = 0.0
	if leaving != null:
		leaving.position.x = 0.0
