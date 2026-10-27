class_name SignatureMove
extends RefCounted
## カードの演出1つぶん(GameDesign.md 9章)。カードごとにこのクラスを継いだスクリプトを
## `scripts/ui/signature/moves/` へ1つ置き、`SignatureLibrary` の表へ1行足す。
##
## 時間は「通常の尺」の秒で受け取る。短縮版(2回目以降)は `SignatureFxPlayer` が
## 時間の進みを速めるだけで、ここは尺の違いを知らない。
## 変えるのは**効果が届くまでの見せ方だけ**。結果(砂の飛散・破壊・砂の移動)は
## 進行役が `impact_at()` の瞬間に出す。

## 上限(GameDesign.md 9章)。`signature_tests.gd` が見張る。
const MAX_DURATION := 1.2
const FADE := 0.22

## 効果:出どころ(駒の中心・情報帯など)/ 登場:台座の上面の中心。画面の座標。
var from := Vector2.ZERO
## 効果の対象の中心。登場では空。
var targets: Array[Vector2] = []
## 効果を起こした側から見た相手の駒の中心。相手の駒の数で量が決まる効果(リリーフ)が
## 1体ずつから届く様子を描くのに使う。登場では空。
var foes: Array[Vector2] = []
## 効果を呼んだ型(`CardEnums.EffectVisualStyle`)。型の違う効果を2つ持つカード(砂葬の
## 破壊とドロー)が描き分けに使う。登場では使わない。
var style := CardEnums.EffectVisualStyle.STRIKE


## 着弾の瞬間(秒)。登場では駒が台座へ落ちきった瞬間。
func impact_at() -> float:
	return 0.0


## 全体の尺(秒)。既定は着弾の後に消えていくぶんを足した長さ。
func duration() -> float:
	return impact_at() + FADE


## 登場で、駒を通常より高くから重く落とすか。
func heavy_land() -> bool:
	return false


## 専用の効果音(`SoundBank.Sfx`)。持たなければ -1(GameDesign.md 9章:登場とコスト6以上だけ)。
func sound() -> int:
	return -1


## 対象 `index` へ届いたか。波紋・砂の帯のように順に届く演出だけが上書きし、
## 届いた対象から先に結果を見せる。
func reaches(_index: int, t: float) -> bool:
	return t >= impact_at()


func draw(_item: CanvasItem, _t: float) -> void:
	pass


## 区間 [start, start + length] の中での進み(0→1)。
static func phase(t: float, start: float, length: float) -> float:
	return clampf((t - start) / length, 0.0, 1.0)


## 終わりの `FADE` 秒で1→0へ消える量。
func fade_alpha(t: float) -> float:
	return 1.0 - phase(t, duration() - FADE, FADE)


## 少し行き過ぎてから戻る(歯車が噛み合う・天秤が傾ききる手応え)。
static func back_out(x: float) -> float:
	const OVERSHOOT := 1.70158
	var y := x - 1.0
	return 1.0 + (OVERSHOOT + 1.0) * y * y * y + OVERSHOOT * y * y
