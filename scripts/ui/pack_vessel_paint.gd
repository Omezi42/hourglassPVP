class_name PackVesselPaint
extends RefCounted
## パックの姿: 封をした砂時計(真鍮の蓋と柱・封蝋。GameDesign.md 21章「開封」)。
## ショップのタイル・詳細と開封の画面が同じ姿を大きさ違いで描く。
## 寸法は `BULB`(片側のガラスの高さ)を1とした比で持ち、`scale` で拡げる。

const BULB := 92.0
const BULB_W := 62.0
const NECK := 5.0
const SAND_AMOUNT := 66.0
const CAP_OVERHANG := 18.0
const CAP_THICK := 18.0
const PILLAR_W := 8.0
const SEAL_RADIUS := 14.0
const OUTLINE_SAMPLES := 10


## 片側のガラスの、首からの深さ `d` における半幅。
static func half_width(d: float) -> float:
	var u := clampf(d / BULB, 0.0, 1.0)
	return lerpf(NECK, BULB_W, pow(sin(u * PI * 0.5), 0.75)) * (1.0 - 0.22 * pow(u, 10.0))


## 片側(`sign_y` が1なら下、-1なら上)のガラスの、深さ d0〜d1 の帯。
static func region(sign_y: float, d0: float, d1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in OUTLINE_SAMPLES + 1:
		var d := lerpf(d0, d1, float(i) / OUTLINE_SAMPLES)
		pts.append(Vector2(-half_width(d) + 3.0, sign_y * d))
	for i in range(OUTLINE_SAMPLES, -1, -1):
		var d := lerpf(d0, d1, float(i) / OUTLINE_SAMPLES)
		pts.append(Vector2(half_width(d) - 3.0, sign_y * d))
	return pts


## 封をした砂時計を描く。`xf` は中心・回転・拡大を持つ変換(局所座標は首が原点)。
## `fall` は上から下へ落ちた量(0〜1。返す前は下に積もった姿)、`seal` は封蝋を出すか、
## `specks` は積もった砂へ混ぜるレアリティの色の粒([位置0〜1, Color] の配列)。
## `settle` は返した直後に上の砂が首の側へ寄る進み(0=奥に張り付いたまま、1=首に寄った)。
static func draw(
	ci: RID,
	xf: Transform2D,
	fall := 1.0,
	seal := true,
	specks: Array = [],
	alpha := 1.0,
	settle := 1.0
) -> void:
	var glass := Color(UiPalette.GLASS_TINT, 0.13 * alpha)
	UiKit.fill(ci, xf * region(1.0, 0.0, BULB), glass)
	UiKit.fill(ci, xf * region(-1.0, 0.0, BULB), glass)
	var top_amount := SAND_AMOUNT * (1.0 - fall)
	var pile := SAND_AMOUNT * fall
	var sand := [[0.0, Color(UiPalette.SAND_DEEP, alpha)], [1.0, Color(UiPalette.SAND_HI, alpha)]]
	if top_amount > 0.5:
		var near := lerpf(BULB - 6.0 - SAND_AMOUNT, 4.0, settle)
		UiKit.vgrad(ci, xf * region(-1.0, near, near + top_amount), sand)
	if pile > 0.5:
		UiKit.vgrad(ci, xf * region(1.0, BULB - 6.0 - pile, BULB - 6.0), sand)
		for speck in specks:
			var at: float = speck[0]
			if fall < at:
				continue
			var d: float = BULB - 6.0 - SAND_AMOUNT * at * 0.9
			var x: float = sin(at * 40.0) * half_width(d) * 0.5
			var hue: Color = speck[1]
			var pos := xf * Vector2(x, d)
			var r := 2.6 * xf.get_scale().x
			UiKit.glow(ci, pos, Vector2(r * 5.0, r * 4.0), Color(hue, 0.8 * alpha))
			UiKit.fill(
				ci, UiKit.ellipse(pos, Vector2(r, r)), Color(hue.lerp(Color.WHITE, 0.4), alpha)
			)
	var rim := Color(UiPalette.GOLD_HI, 0.45 * alpha)
	UiKit.stroke(ci, xf * region(1.0, 0.0, BULB), rim, 1.4)
	UiKit.stroke(ci, xf * region(-1.0, 0.0, BULB), rim, 1.4)
	for sy in [-1.0, 1.0]:
		var shine := PackedVector2Array(
			[Vector2(-BULB_W * 0.55, sy * BULB * 0.75), Vector2(-BULB_W * 0.62, sy * BULB * 0.45)]
		)
		ShapePaint.polyline(ci, xf * shine, Color(Color.WHITE, 0.35 * alpha), 3.0, true)
	caps(ci, xf, alpha)
	if seal:
		var at := xf * Vector2(0, -BULB - CAP_THICK * 0.65)
		var r := SEAL_RADIUS * xf.get_scale().x
		UiKit.fill(ci, UiKit.ellipse(at, Vector2(r, r)), Color(UiPalette.SEAL_WAX, alpha))
		UiKit.fill(ci, RarityPaint.diamond(at, r * 0.45), Color(UiPalette.GOLD_HI, 0.9 * alpha))


## 真鍮の蓋と柱(割れたあとは蓋だけ別に飛ばすため分けてある)。
static func caps(ci: RID, xf: Transform2D, alpha := 1.0) -> void:
	var brass := [
		[0.0, Color(UiPalette.GOLD_HI, alpha)],
		[0.5, Color(UiPalette.BRASS, alpha)],
		[1.0, Color(UiPalette.BRASS_DEEP, alpha)]
	]
	for sy in [-1.0, 1.0]:
		cap(ci, xf * Transform2D(0.0, Vector2(0, sy * (BULB + CAP_THICK * 0.65))), alpha)
	for sx in [-1.0, 1.0]:
		var pillar := Rect2(
			sx * (BULB_W + PILLAR_W) - PILLAR_W * 0.5, -BULB - 4.0, PILLAR_W, BULB * 2.0 + 8.0
		)
		UiKit.vgrad(ci, xf * UiKit.rr(pillar, 3.0), brass)


## 蓋1枚(中心が原点)。
static func cap(ci: RID, xf: Transform2D, alpha := 1.0) -> void:
	var rect := Rect2(
		-BULB_W - CAP_OVERHANG, -CAP_THICK * 0.5, (BULB_W + CAP_OVERHANG) * 2.0, CAP_THICK
	)
	UiKit.vgrad(
		ci,
		xf * UiKit.rr(rect, 4.0),
		[
			[0.0, Color(UiPalette.GOLD_HI, alpha)],
			[0.5, Color(UiPalette.BRASS, alpha)],
			[1.0, Color(UiPalette.BRASS_DEEP, alpha)]
		]
	)


## 外形の高さ(蓋を含む)。絵を矩形へ収めるときの拡大率を決める。
static func full_height() -> float:
	return (BULB + CAP_THICK * 1.2) * 2.0


## `rect` の中央へ収まる変換。
static func fit(rect: Rect2, rotation := 0.0) -> Transform2D:
	var s := minf(rect.size.y / full_height(), rect.size.x / ((BULB_W + CAP_OVERHANG) * 2.2))
	return Transform2D(rotation, Vector2(s, s), 0.0, rect.get_center())
