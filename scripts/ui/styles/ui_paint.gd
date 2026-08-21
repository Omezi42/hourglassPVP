class_name UiPaint
extends RefCounted
## RenderingServerのRID経由描画APIのみを使う描画ユーティリティ(static関数のみ)。
## StyleBox._draw()はCanvasItemのdraw_*系を呼べずRIDしか受け取らないため、
## Control._draw()側からもRID(get_canvas_item())を渡せば同じ関数を共用できる。

## ボタン種別を示す紋章(エンブレム)の絵柄。CodedButtonStyle.emblemから参照される。
enum Emblem { NONE, HOURGLASS, SWAP_ARROWS, BENCH, CHECK, ADVANCE, AWAKEN }

const GRAIN_SIZE := 64
const GRAIN_SEED := 20240818

## 紋章の輪郭線・ハイライト線の太さ(いずれもCodedButtonStyleが渡すsize基準の絶対px)
const EMBLEM_OUTLINE_WIDTH := 3.0
const EMBLEM_HIGHLIGHT_WIDTH := 1.6
const EMBLEM_CHECK_WIDTH_RATIO := 0.22
const EMBLEM_CHECK_MIN_WIDTH := 3.0

static var _grain_texture: ImageTexture
static var _grain_rid: RID

## 紋章の図形定義(単位座標系、原点中心・概ね-1.0〜1.0の範囲)。すべて浮き彫り表現の
## 「太い暗色輪郭+真鍮グラデーション塗り+上側ハイライト線」で仕上げる。GDScriptの制約上
## Vector2を含む配列リテラルはconst初期化できないため、static varで持つ(値自体は不変)。
static var _hourglass_points := PackedVector2Array(
	[
		Vector2(-0.85, -0.85),
		Vector2(0.85, -0.85),
		Vector2(0.16, 0.0),
		Vector2(0.85, 0.85),
		Vector2(-0.85, 0.85),
		Vector2(-0.16, 0.0),
	]
)
static var _hourglass_highlight := PackedVector2Array([Vector2(-0.7, -0.72), Vector2(0.7, -0.72)])

## 「移動」= 盤上の2駒を入れ替える操作を示す、上下逆向きの2本の矢印
static var _swap_arrow_top_points := PackedVector2Array(
	[
		Vector2(-0.8, -0.5),
		Vector2(0.1, -0.5),
		Vector2(0.1, -0.66),
		Vector2(0.75, -0.34),
		Vector2(0.1, -0.02),
		Vector2(0.1, -0.18),
		Vector2(-0.8, -0.18),
	]
)
static var _swap_arrow_top_highlight := PackedVector2Array(
	[Vector2(-0.7, -0.42), Vector2(0.05, -0.42)]
)
## 加速(スキル):砂を一気に落とすことを示す下向きの二重シェブロン。
static var _advance_upper_points := PackedVector2Array(
	[
		Vector2(-0.72, -0.72),
		Vector2(0.0, -0.16),
		Vector2(0.72, -0.72),
		Vector2(0.72, -0.42),
		Vector2(0.0, 0.14),
		Vector2(-0.72, -0.42),
	]
)
static var _advance_upper_highlight := PackedVector2Array(
	[Vector2(-0.6, -0.6), Vector2(0.0, -0.14)]
)
static var _advance_lower_points := PackedVector2Array(
	[
		Vector2(-0.72, -0.08),
		Vector2(0.0, 0.48),
		Vector2(0.72, -0.08),
		Vector2(0.72, 0.22),
		Vector2(0.0, 0.78),
		Vector2(-0.72, 0.22),
	]
)
static var _advance_lower_highlight := PackedVector2Array([Vector2(-0.6, 0.04), Vector2(0.0, 0.5)])
## 目覚め(スキル):砂時計が起き上がることを示す、上向きの光の閃光(四芒星)。
static var _awaken_points := PackedVector2Array(
	[
		Vector2(0.0, -0.85),
		Vector2(0.19, -0.22),
		Vector2(0.8, -0.02),
		Vector2(0.19, 0.18),
		Vector2(0.0, 0.85),
		Vector2(-0.19, 0.18),
		Vector2(-0.8, -0.02),
		Vector2(-0.19, -0.22),
	]
)
static var _awaken_highlight := PackedVector2Array(
	[Vector2(-0.12, -0.32), Vector2(0.0, -0.7), Vector2(0.12, -0.32)]
)
static var _swap_arrow_bottom_points := PackedVector2Array(
	[
		Vector2(0.8, 0.5),
		Vector2(-0.1, 0.5),
		Vector2(-0.1, 0.66),
		Vector2(-0.75, 0.34),
		Vector2(-0.1, 0.02),
		Vector2(-0.1, 0.18),
		Vector2(0.8, 0.18),
	]
)
static var _swap_arrow_bottom_highlight := PackedVector2Array(
	[Vector2(0.7, 0.42), Vector2(-0.05, 0.42)]
)

## 「交代」= 控えから場へ出す操作を示す、脚付きベンチ(長椅子)のシルエット。
## 「座面板」「座面を支える内側の2本脚」「下段の桟(レール)」「レールを支える
## 接地側の2本脚」の4パーツ・計6ポリゴン構成。横棒+2本脚だけだとギリシャ文字の
## Πや鳥居に見えてしまうため、板を上下2段に分けて間に脚を挟むことで
## 「座って使う家具」のシルエットとして認識できるようにしている。
## 接地側の脚だけわずかに外側へハの字に開かせ、家具としての安定感を出す。
static var _bench_seat_points := PackedVector2Array(
	[Vector2(-0.72, -0.85), Vector2(0.72, -0.85), Vector2(0.72, -0.58), Vector2(-0.72, -0.58)]
)
static var _bench_seat_highlight := PackedVector2Array(
	[Vector2(-0.58, -0.78), Vector2(0.58, -0.78)]
)
static var _bench_seat_leg_left_points := PackedVector2Array(
	[Vector2(-0.34, -0.58), Vector2(-0.14, -0.58), Vector2(-0.14, -0.02), Vector2(-0.34, -0.02)]
)
static var _bench_seat_leg_right_points := PackedVector2Array(
	[Vector2(0.14, -0.58), Vector2(0.34, -0.58), Vector2(0.34, -0.02), Vector2(0.14, -0.02)]
)
static var _bench_rail_points := PackedVector2Array(
	[Vector2(-0.85, -0.02), Vector2(0.85, -0.02), Vector2(0.85, 0.22), Vector2(-0.85, 0.22)]
)
static var _bench_rail_highlight := PackedVector2Array([Vector2(-0.7, 0.05), Vector2(0.7, 0.05)])
static var _bench_floor_leg_left_points := PackedVector2Array(
	[Vector2(-0.68, 0.22), Vector2(-0.46, 0.22), Vector2(-0.4, 0.85), Vector2(-0.62, 0.85)]
)
static var _bench_floor_leg_right_points := PackedVector2Array(
	[Vector2(0.46, 0.22), Vector2(0.68, 0.22), Vector2(0.62, 0.85), Vector2(0.4, 0.85)]
)


## 4隅の半径を個別指定できる角丸矩形の外周点列を返す(TAB形状などの非対称角丸に対応)。
## 半径0の角は丸めず矩形の頂点そのものになる(その角のsegments+1点が同一座標に潰れるだけで、
## 他の角と同じ構築ロジックを使い回せるため特別扱いしない)。
static func rounded_rect_points(
	rect: Rect2,
	top_left: float,
	top_right: float,
	bottom_right: float,
	bottom_left: float,
	segments: int
) -> PackedVector2Array:
	var max_r: float = min(rect.size.x, rect.size.y) * 0.5
	var tl: float = clampf(top_left, 0.0, max_r)
	var tr: float = clampf(top_right, 0.0, max_r)
	var br: float = clampf(bottom_right, 0.0, max_r)
	var bl: float = clampf(bottom_left, 0.0, max_r)

	var corners := [
		[Vector2(rect.position.x + tl, rect.position.y + tl), PI, 1.5 * PI, tl],
		[Vector2(rect.end.x - tr, rect.position.y + tr), 1.5 * PI, 2.0 * PI, tr],
		[Vector2(rect.end.x - br, rect.end.y - br), 0.0, 0.5 * PI, br],
		[Vector2(rect.position.x + bl, rect.end.y - bl), 0.5 * PI, PI, bl],
	]

	var points := PackedVector2Array()
	for corner in corners:
		var center: Vector2 = corner[0]
		var a0: float = corner[1]
		var a1: float = corner[2]
		var r: float = corner[3]
		for i in range(segments + 1):
			var t: float = a0 + (a1 - a0) * float(i) / float(segments)
			points.append(center + Vector2(cos(t), sin(t)) * r)
	return points


## 全角同じ半径の簡易版。
static func rounded_rect_points_uniform(
	rect: Rect2, radius: float, segments: int
) -> PackedVector2Array:
	return rounded_rect_points(rect, radius, radius, radius, radius, segments)


## 左辺が尖った五角形(左向き矢印型、back_navボタン用)の外周点列を返す。
## 左端中央に頂点(tip)を置き、そこから上下の肩(shoulder、rect幅に対しshoulder_ratioの
## 位置)へ斜辺で繋ぎ、右側の上下2隅だけを通常の角丸コーナーとして丸める。
static func chevron_left_points(
	rect: Rect2, corner_radius: float, segments: int, shoulder_ratio: float
) -> PackedVector2Array:
	var shoulder_x: float = rect.position.x + rect.size.x * shoulder_ratio
	var tip := Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5)
	var shoulder_top := Vector2(shoulder_x, rect.position.y)
	var shoulder_bottom := Vector2(shoulder_x, rect.end.y)
	var r: float = clampf(
		corner_radius, 0.0, min(rect.size.y * 0.5, (rect.end.x - shoulder_x) * 0.5)
	)
	var top_right_center := Vector2(rect.end.x - r, rect.position.y + r)
	var bottom_right_center := Vector2(rect.end.x - r, rect.end.y - r)

	var points := PackedVector2Array()
	points.append(tip)
	points.append(shoulder_top)
	for i in range(segments + 1):
		var t: float = 1.5 * PI + (0.5 * PI) * float(i) / float(segments)
		points.append(top_right_center + Vector2(cos(t), sin(t)) * r)
	for i in range(segments + 1):
		var t2: float = (0.5 * PI) * float(i) / float(segments)
		points.append(bottom_right_center + Vector2(cos(t2), sin(t2)) * r)
	points.append(shoulder_bottom)
	return points


## 左右の端を中央(高さの半分の位置)へ向けて尖らせた六角形(タグ札/バナー形状)の
## 外周点列を返す(CodedNameplateStyle用)。notchは尖端から肩(上下の角)までの
## 水平距離を絶対pxで指定する(rect幅に対する比率ではない)。名札はコンテナに合わせて
## 横幅だけが大きく伸びる使われ方をするため、幅に比例させると伸びるほど尖端が
## 不自然に長くなる。rect幅の半分を超える場合はそこでクランプする。
static func banner_points(rect: Rect2, notch: float) -> PackedVector2Array:
	var clamped_notch: float = clampf(notch, 0.0, rect.size.x * 0.49)
	var left_x: float = rect.position.x + clamped_notch
	var right_x: float = rect.end.x - clamped_notch
	var mid_y: float = rect.position.y + rect.size.y * 0.5
	return PackedVector2Array(
		[
			Vector2(rect.position.x, mid_y),
			Vector2(left_x, rect.position.y),
			Vector2(right_x, rect.position.y),
			Vector2(rect.end.x, mid_y),
			Vector2(right_x, rect.end.y),
			Vector2(left_x, rect.end.y),
		]
	)


## 単一中心のN角形として円周上の点列を作る。rounded_rect_points_uniform(半径=正方形の
## 半辺)を円として流用すると、4隅の弧の中心がすべて同一点へ縮退し、極小サイズでは
## 浮動小数点誤差で頂点が重複して三角形分割に失敗することがあるため、円専用に別で持つ。
## fill_circle/draw_ring/BoardTableの円描画(メダリオン等)が共通で使う。
static func circle_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 単色で塗りつぶした円を描く。リベット(鋲)のような小さな円形装飾に使う。
static func fill_circle(
	ci: RID, center: Vector2, radius: float, color: Color, segments: int
) -> void:
	var points := circle_points(center, radius, segments)
	var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	fill_gradient_polygon(ci, points, rect, [[0.0, color], [1.0, color]])


## 塗りつぶさない円(輪)を描く。BoardTableのメダリオン等、リング状の装飾に使う。
static func draw_ring(
	ci: RID, center: Vector2, radius: float, color: Color, width: float, segments: int
) -> void:
	var points := circle_points(center, radius, segments)
	var closed := points.duplicate()
	closed.append(points[0])
	_draw_polyline_solid(ci, closed, color, width)


## 縦横比を独立指定できる楕円の輪郭線。台座光と同じ扁平な円で衝撃波を広げるため、
## 真円のdraw_ring()とは別に用意する(HourglassSlotの反転演出で使う)。
static func draw_ellipse_ring(
	ci: RID, center: Vector2, radius: Vector2, color: Color, width: float, segments: int
) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	points.append(points[0])
	_draw_polyline_solid(ci, points, color, width)


## 縦横比を独立指定できる楕円を単色で塗りつぶす。BoardTableの隅飾り・HourglassSlotの
## 台座光のように、扁平な円(奥行き表現)を描く箇所で共通に使う。
static func fill_ellipse(
	ci: RID, center: Vector2, radius: Vector2, color: Color, segments: int
) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	var rect := Rect2(center - radius, radius * 2.0)
	fill_gradient_polygon(ci, points, rect, [[0.0, color], [1.0, color]])


## stops: [[位置0.0〜1.0, Color], ...](位置昇順)。tに応じた補間色を返す。
static func sample_gradient(stops: Array, t: float) -> Color:
	if stops.is_empty():
		return Color.WHITE
	if stops.size() == 1:
		return stops[0][1]
	var clamped: float = clampf(t, 0.0, 1.0)
	for i in range(stops.size() - 1):
		var pos_a: float = stops[i][0]
		var pos_b: float = stops[i + 1][0]
		if clamped <= pos_b or i == stops.size() - 2:
			var span: float = max(pos_b - pos_a, 0.0001)
			var local_t: float = clampf((clamped - pos_a) / span, 0.0, 1.0)
			var color_a: Color = stops[i][1]
			var color_b: Color = stops[i + 1][1]
			return color_a.lerp(color_b, local_t)
	return stops[-1][1]


## 多段階の縦グラデーションで角丸多角形を塗る(頂点ごとにy位置からstopsを補間する)。
## 同色2ストップを渡せば単色塗りとしても使える。
static func fill_gradient_polygon(
	ci: RID, points: PackedVector2Array, rect: Rect2, stops: Array
) -> void:
	var colors := PackedColorArray()
	colors.resize(points.size())
	for i in range(points.size()):
		var t: float = 0.0
		if rect.size.y > 0.0:
			t = (points[i].y - rect.position.y) / rect.size.y
		colors[i] = sample_gradient(stops, t)
	RenderingServer.canvas_item_add_polygon(ci, points, colors)


## 角丸輪郭の点列(rounded_rect_pointsの戻り値、上半分→下半分の順に並ぶ)を
## 上半分=明色・下半分=暗色のポリラインで引き、面取り(ベベル)を表現する。
## invertedがtrueなら明暗を反転する(押下時の沈み込み表現に使う)。
static func draw_bevel(
	ci: RID,
	points: PackedVector2Array,
	light_color: Color,
	dark_color: Color,
	width: float,
	inverted: bool
) -> void:
	if points.size() < 2:
		return
	var half: int = points.size() / 2
	var top_arc := points.slice(0, half + 1)
	var bottom_arc := points.slice(half, points.size())
	var top_color := dark_color if inverted else light_color
	var bottom_color := light_color if inverted else dark_color
	_draw_polyline_solid(ci, top_arc, top_color, width)
	_draw_polyline_solid(ci, bottom_arc, bottom_color, width)


static func _draw_polyline_solid(
	ci: RID, points: PackedVector2Array, color: Color, width: float
) -> void:
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	RenderingServer.canvas_item_add_polyline(ci, points, colors, width, true)


## 凹みの落ち込み影。指定rectの内側に、上端が濃く下へ行くほど薄くなる多重の角丸ポリラインを
## 重ねて凹みを表現する(頂点ごとのalphaをy位置から、層ごとのalphaを層番号から減衰させる)。
static func draw_inner_shadow(
	ci: RID, rect: Rect2, radius: float, segments: int, layers: int, color: Color, max_alpha: float
) -> void:
	for i in range(layers):
		var inset: float = 1.0 + float(i) * 2.0
		var layer_rect: Rect2 = rect.grow(-inset)
		if layer_rect.size.x <= 0.0 or layer_rect.size.y <= 0.0:
			break
		var layer_radius: float = max(radius - inset, 0.0)
		var points := rounded_rect_points_uniform(layer_rect, layer_radius, segments)
		var layer_scale: float = 1.0 - float(i) / float(layers)
		var colors := PackedColorArray()
		colors.resize(points.size())
		for p in range(points.size()):
			var t: float = 0.0
			if layer_rect.size.y > 0.0:
				t = (points[p].y - layer_rect.position.y) / layer_rect.size.y
			var alpha: float = max_alpha * (1.0 - clampf(t, 0.0, 1.0)) * layer_scale
			colors[p] = Color(color.r, color.g, color.b, alpha)
		RenderingServer.canvas_item_add_polyline(ci, points, colors, 1.0, true)


## 質感ノイズ(グレイン)をrect全体へタイル状に薄く重ねる。フラットベクター感を消す最重要要素。
## 64x64のノイズ画像は初回呼び出し時にのみ生成しキャッシュする(以降は使い回す)。
## デフォルトのバイリニア補間のままだと1px単位の乱数が滲んで「細かい粒状感」ではなく
## 「もやついた斑点」になってしまうため、描画直前だけ最近傍補間へ切り替えて元に戻す。
static func apply_grain(ci: RID, rect: Rect2, alpha: float) -> void:
	_ensure_grain()
	RenderingServer.canvas_item_set_default_texture_filter(
		ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	RenderingServer.canvas_item_add_texture_rect(
		ci, rect, _grain_rid, true, Color(1.0, 1.0, 1.0, alpha)
	)
	RenderingServer.canvas_item_set_default_texture_filter(
		ci, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_DEFAULT
	)


## 紋章を1個描画する。centerを中心に、概ね半径sizeへ収まるよう正規化された図形を敷く。
## 太い暗色輪郭+真鍮グラデーション塗り+上側ハイライト線の「浮き彫り」で統一する。
static func draw_emblem(ci: RID, emblem: Emblem, center: Vector2, size: float) -> void:
	match emblem:
		Emblem.HOURGLASS:
			_emblem_fill(ci, center, size, _hourglass_points, _hourglass_highlight)
		Emblem.SWAP_ARROWS:
			_emblem_fill(ci, center, size, _swap_arrow_top_points, _swap_arrow_top_highlight)
			_emblem_fill(ci, center, size, _swap_arrow_bottom_points, _swap_arrow_bottom_highlight)
		Emblem.BENCH:
			_emblem_fill(ci, center, size, _bench_seat_points, _bench_seat_highlight)
			_emblem_fill(ci, center, size, _bench_seat_leg_left_points, PackedVector2Array())
			_emblem_fill(ci, center, size, _bench_seat_leg_right_points, PackedVector2Array())
			_emblem_fill(ci, center, size, _bench_rail_points, _bench_rail_highlight)
			_emblem_fill(ci, center, size, _bench_floor_leg_left_points, PackedVector2Array())
			_emblem_fill(ci, center, size, _bench_floor_leg_right_points, PackedVector2Array())
		Emblem.CHECK:
			_emblem_check(ci, center, size)
		Emblem.ADVANCE:
			_emblem_fill(ci, center, size, _advance_upper_points, _advance_upper_highlight)
			_emblem_fill(ci, center, size, _advance_lower_points, _advance_lower_highlight)
		Emblem.AWAKEN:
			_emblem_fill(ci, center, size, _awaken_points, _awaken_highlight)
		_:
			pass


## 単位座標系の閉多角形(local_points)をcenter/sizeへ変換して塗り+輪郭+ハイライトを描く。
static func _emblem_fill(
	ci: RID,
	center: Vector2,
	size: float,
	local_points: PackedVector2Array,
	local_highlight: PackedVector2Array
) -> void:
	var points := PackedVector2Array()
	for p in local_points:
		points.append(center + p * size)
	var top_y := points[0].y
	var bottom_y := points[0].y
	for p in points:
		top_y = minf(top_y, p.y)
		bottom_y = maxf(bottom_y, p.y)
	var bounds := Rect2(center.x - size, top_y, size * 2.0, maxf(bottom_y - top_y, 0.001))
	var fill_stops := [
		[0.0, UiPalette.BRASS_HIGHLIGHT], [0.5, UiPalette.BRASS_MID], [1.0, UiPalette.BRASS_DARK]
	]
	fill_gradient_polygon(ci, points, bounds, fill_stops)

	var closed := points.duplicate()
	closed.append(points[0])
	_draw_polyline_solid(ci, closed, UiPalette.OUTLINE_DARK, EMBLEM_OUTLINE_WIDTH)

	if local_highlight.size() >= 2:
		var highlight := PackedVector2Array()
		for p in local_highlight:
			highlight.append(center + p * size)
		_draw_polyline_solid(ci, highlight, UiPalette.BRASS_HIGHLIGHT, EMBLEM_HIGHLIGHT_WIDTH)


## チェックマークは細い形状のため塗り多角形ではなく、太さの異なる3本のポリラインを
## 重ねて(暗色の縁取り→真鍮の芯→明色のハイライト)浮き彫りに見せる。
static func _emblem_check(ci: RID, center: Vector2, size: float) -> void:
	var path := PackedVector2Array(
		[
			center + Vector2(-0.62, 0.05) * size,
			center + Vector2(-0.12, 0.55) * size,
			center + Vector2(0.85, -0.55) * size,
		]
	)
	var width: float = maxf(size * EMBLEM_CHECK_WIDTH_RATIO, EMBLEM_CHECK_MIN_WIDTH)
	_draw_polyline_solid(ci, path, UiPalette.OUTLINE_DARK, width + EMBLEM_OUTLINE_WIDTH)
	_draw_polyline_solid(ci, path, UiPalette.BRASS_MID, width)

	var highlight := PackedVector2Array(
		[center + Vector2(-0.55, -0.02) * size, center + Vector2(-0.12, 0.42) * size]
	)
	_draw_polyline_solid(ci, highlight, UiPalette.BRASS_HIGHLIGHT, EMBLEM_HIGHLIGHT_WIDTH)


## 無効/後退(disabled・読み取り専用等)状態の色変換。色自身の輝度へ寄せて彩度を落とした
## うえで暗くする(UiPalette.DISABLED_DESATURATE/DISABLED_DARKEN参照)。単純に中間グレーへ
## lerpすると暗い元色ほど明るくなってしまう(無効なのに目立つ)ため、必ず暗くなる方向のみへ
## 寄せる。CodedButtonStyle(DISABLED状態)/CodedPanelStyle(dimmed)双方から共通利用する。
static func disabled_tone(color: Color) -> Color:
	var luma: float = (color.r + color.g + color.b) / 3.0
	var desaturated := color.lerp(Color(luma, luma, luma, color.a), UiPalette.DISABLED_DESATURATE)
	return desaturated.darkened(UiPalette.DISABLED_DARKEN)


## グラデーションのstops配列(sample_gradient/fill_gradient_polygonが受け取る形式)の
## 各色へdisabled_toneを適用した新しい配列を返す。
static func dim_gradient_stops(stops: Array) -> Array:
	var result := []
	for stop in stops:
		var color: Color = stop[1]
		result.append([stop[0], disabled_tone(color)])
	return result


static func _ensure_grain() -> void:
	if _grain_texture != null:
		return
	var image := Image.create(GRAIN_SIZE, GRAIN_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = GRAIN_SEED
	for y in range(GRAIN_SIZE):
		for x in range(GRAIN_SIZE):
			var v: float = rng.randf()
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, v))
	_grain_texture = ImageTexture.create_from_image(image)
	_grain_rid = _grain_texture.get_rid()
