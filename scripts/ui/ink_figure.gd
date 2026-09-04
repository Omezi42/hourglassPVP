class_name InkFigure
extends RefCounted
## 能力の実演を、**紙に刷られた図版**として描く部品(GameDesign.md 9章)。
##
## 砂時計の絵も台座も使わず、インクの線画だけで組む。実演を出すのは砂時計図鑑と
## キーワード辞書だけであり、どちらも**盤面の再現ではなく理屈を読ませる場所**のため。
##
## `UiPaint` と同じく static だけを持つが、**第1引数は RID ではなく `CanvasItem`** を取る。
## 実演は `Control._draw()` からしか呼ばれず、`StyleBox` のような RID 経由の制約が無いため。
##
## **部品の組み合わせだけで図版を組めるようにしておく。**新しいキーワードが増えても、
## ここへ部品を1つ足せば台本を書ける状態を保つ(カードを毎日足す運用のため)。

const INK := Color(0.30, 0.21, 0.12, 0.95)
const INK_SOFT := Color(0.40, 0.30, 0.19, 1.0)
const SAND := Color(0.72, 0.55, 0.22, 0.8)
const RED := Color(0.63, 0.13, 0.11, 1.0)
const GREEN := Color(0.20, 0.44, 0.22, 1.0)
const BLUE := Color(0.24, 0.38, 0.58, 1.0)
const PAPER := Color(0.86, 0.80, 0.66, 1.0)

## 砂時計の見た目。**縦長に取る**(幅と高さを近づけると蝶ネクタイに見える)。
const GLASS_WIDTH_RATIO := 0.33


## 砂時計。`fill` は下の部屋へ落ちた砂の割合(0=出したて / 1=落ちきり)。
## `alpha` は消えかけ(破壊されて薄れていく駒)を描くために受ける。
static func hourglass(
	ci: CanvasItem, center: Vector2, height: float, fill: float, alpha := 1.0
) -> void:
	if alpha <= 0.01:
		return
	var w := height * GLASS_WIDTH_RATIO
	var h := height * 0.5
	var poured: float = clampf(fill, 0.0, 1.0)
	var left := 1.0 - poured
	var ink := Color(INK, INK.a * alpha)
	var sand := Color(SAND, SAND.a * alpha)
	# 上の部屋は頂点(くびれ)へ向かって溜まるため、そのまま三角形でよい。
	if left > 0.02:
		(
			ci
			. draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(-w * left, -h * left),
						center + Vector2(w * left, -h * left),
						center + Vector2(0, 0),
					]
				),
				sand
			)
		)
	# **下の部屋の砂は台形になる。**器が下へ広がっている以上、底は必ず満杯であり、
	# 三角形で描くと砂が宙に浮いた山のように見える。
	if poured > 0.02:
		var top_y := h * (1.0 - poured)
		var half := w * (1.0 - poured)
		(
			ci
			. draw_colored_polygon(
				PackedVector2Array(
					[
						center + Vector2(-w, h),
						center + Vector2(w, h),
						center + Vector2(half, top_y),
						center + Vector2(-half, top_y),
					]
				),
				sand
			)
		)
	var line: float = maxf(height * 0.03, 1.4)
	_stroke(
		ci,
		PackedVector2Array(
			[center + Vector2(-w, -h), center + Vector2(w, -h), center + Vector2(0, 0)]
		),
		ink,
		line
	)
	_stroke(
		ci,
		PackedVector2Array(
			[center + Vector2(-w, h), center + Vector2(w, h), center + Vector2(0, 0)]
		),
		ink,
		line
	)
	# 天板と底板。器として立っていることを示す。
	var cap := w + height * 0.06
	ci.draw_line(center + Vector2(-cap, -h), center + Vector2(cap, -h), ink, line * 1.4)
	ci.draw_line(center + Vector2(-cap, h), center + Vector2(cap, h), ink, line * 1.4)


## プレイヤーのHPバー。図版なので目盛りだけの簡素な形にする。
## `gain` を渡すと、その割合ぶんを緑で継ぎ足す(吸命の実演で使う)。
static func hp_bar(ci: CanvasItem, rect: Rect2, ratio: float, gain := 0.0) -> void:
	ci.draw_rect(rect, PAPER)
	ci.draw_rect(
		Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)),
		Color(0.63, 0.28, 0.16, 0.55)
	)
	if gain > 0.0:
		ci.draw_rect(
			Rect2(
				rect.position + Vector2(rect.size.x * ratio, 0),
				Vector2(rect.size.x * gain, rect.size.y)
			),
			Color(GREEN, 0.5)
		)
	ci.draw_rect(rect, INK, false, 1.6)


static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, color := INK) -> void:
	if from.is_equal_approx(to):
		return
	ci.draw_line(from, to, color, 1.8)
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x)
	ci.draw_colored_polygon(
		PackedVector2Array(
			[to, to - direction * 8.0 + side * 4.5, to - direction * 8.0 - side * 4.5]
		),
		color
	)


## 届かない攻撃。守護に阻まれる線などを破線で示す。
static func blocked_line(ci: CanvasItem, from: Vector2, to: Vector2) -> void:
	ci.draw_dashed_line(from, to, Color(RED, 0.45), 1.6, 5.0)


## 砕けた印。朱の×。
static func broken(ci: CanvasItem, center: Vector2, size := 13.0, alpha := 1.0) -> void:
	for pair in [[Vector2(-1, -1), Vector2(1, 1)], [Vector2(1, -1), Vector2(-1, 1)]]:
		ci.draw_line(
			center + (pair[0] as Vector2) * size,
			center + (pair[1] as Vector2) * size,
			Color(RED, 0.85 * alpha),
			2.2
		)


## 守護の輪。駒の足元を囲む太い輪として描く。
static func guard_ring(ci: CanvasItem, center: Vector2, radius: float, drop: float) -> void:
	UiPaint.draw_ellipse_ring(
		ci.get_canvas_item(),
		center + Vector2(0, drop),
		Vector2(radius, radius * 0.34),
		Color(BLUE, 0.9),
		3.0,
		26
	)


## 硝子の膜。駒を包む破線の楕円。割れた後は薄く残す。
static func glass_film(ci: CanvasItem, center: Vector2, radius: float, cracked: bool) -> void:
	var color := Color(BLUE, 0.35) if cracked else Color(BLUE, 0.85)
	var steps := 26
	for i in steps:
		if i % 2 == 1:
			continue
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		ci.draw_line(
			center + Vector2(cos(a0) * radius, sin(a0) * radius * 1.25),
			center + Vector2(cos(a1) * radius, sin(a1) * radius * 1.25),
			color,
			2.0
		)


## 空いた台座。トークンが現れる先を示す。
static func empty_socket(ci: CanvasItem, center: Vector2, radius: float) -> void:
	UiPaint.draw_ellipse_ring(
		ci.get_canvas_item(), center, Vector2(radius, radius * 0.34), Color(INK_SOFT, 0.5), 1.6, 24
	)


## 回転を示す弧。反転の実演で駒のあいだへ渡す。
static func turn_arc(ci: CanvasItem, center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	for i in 15:
		var a: float = PI * (1.05 + 0.9 * float(i) / 14.0)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	ci.draw_polyline(points, INK, 1.8)
	arrow(ci, points[points.size() - 2], points[points.size() - 1])


## 図版の注記。駒の下へ中央揃えで置く。
static func caption(
	ci: CanvasItem, font: Font, center: Vector2, text: String, color := INK_SOFT, size := 12
) -> void:
	ci.draw_string(
		font, Vector2(center.x - 82, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, 164, size, color
	)


static func _stroke(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, color, width)
