extends RefCounted
## コード描画の外周点列(UiPaint)が、三角形分割できる形になっていることを見る
## (Architecture.md 4章)。見た目そのものは非ヘッドレスで確認するが、
## **分割に失敗した面はブラウザのコンソールへ
## 「Invalid polygon data, triangulation failed」を出したまま描かれずに消える**ため、
## 形が壊れていないことだけはここで押さえる。

## HPバー(240x24・角丸6)の残量。半径は幅の半分で頭打ちにするため、
## 幅が12pxを下回ると隣り合う角が同じ中心を共有する。
const HP_BAR_HEIGHT := 24.0
const HP_BAR_RADIUS := 6.0


func run(assert_true: Callable) -> void:
	_test_rounded_rect_survives_every_width(assert_true)
	_test_fully_rounded_shapes_have_no_duplicate_points(assert_true)
	_test_chevron_survives_a_zero_corner_radius(assert_true)
	_test_gradient_sweep_matches_every_edge_scan(assert_true)
	_test_shape_cache_keeps_only_repeated_shapes(assert_true)


## **HPバーの残量が12px以下になった瞬間に、実際に分割へ失敗していた**回の回帰テスト。
## 半径が辺の半分に達すると上下の角が中心を共有し、境目の頂点が重なるため、
## 浮動小数点誤差しだいで分割が通ったり通らなかったりする。
func _test_rounded_rect_survives_every_width(assert_true: Callable) -> void:
	var failed := 0
	var checked := 0
	for step in range(1, 2401):
		var width := float(step) * 0.1
		var rect := Rect2(Vector2(162.0, 16.0), Vector2(width, HP_BAR_HEIGHT))
		var points := UiPaint.rounded_rect_points_uniform(rect, minf(HP_BAR_RADIUS, width * 0.5), 5)
		checked += 1
		if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty():
			failed += 1
	assert_true.call(checked > 0, "HPバーの残量を全幅ぶん試している")
	assert_true.call(failed == 0, "どの残量でも角丸矩形を三角形分割できる")


## 半径が短辺の半分に達する形(ピル・丸ボタン)でも頂点が重ならないこと。
func _test_fully_rounded_shapes_have_no_duplicate_points(assert_true: Callable) -> void:
	var duplicated := 0
	var failed := 0
	for size in range(2, 200):
		var side := float(size)
		var rect := Rect2(Vector2(7.3, 11.1), Vector2(side, side * 0.5))
		var points := UiPaint.rounded_rect_points_uniform(rect, side, 6)
		for i in points.size():
			if points[i].is_equal_approx(points[(i + 1) % points.size()]):
				duplicated += 1
		if Geometry2D.triangulate_polygon(points).is_empty():
			failed += 1
	assert_true.call(duplicated == 0, "完全に丸めた形でも隣り合う頂点が重ならない")
	assert_true.call(failed == 0, "完全に丸めた形も三角形分割できる")


## 角丸の半径が0へ潰れる場合(戻るボタンを小さく置いたとき)も同じ問題が起きる。
func _test_chevron_survives_a_zero_corner_radius(assert_true: Callable) -> void:
	var points := UiPaint.chevron_left_points(Rect2(Vector2.ZERO, Vector2(40, 40)), 0.0, 5, 0.35)
	assert_true.call(not Geometry2D.triangulate_polygon(points).is_empty(), "半径0の五角形も三角形分割できる")


## 縦のグラデーションの横幅を、高さの昇順に鎖を歩いて求める形にした(辺を毎回すべて調べると
## 頂点数の2乗かかり、宝石1つで数千回回っていた)。全辺を調べる素朴な求め方と同じ幅になること。
func _test_gradient_sweep_matches_every_edge_scan(assert_true: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var shapes: Array[PackedVector2Array] = [
		UiKit.ellipse(Vector2(10, 10), Vector2(13, 13)),
		UiKit.ellipse(Vector2(10, 10), Vector2(40, 9), 48),
		PackedVector2Array([Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)]),
		UiPaint.rounded_rect_points_uniform(Rect2(0, 0, 60, 20), 6.0, 4),
	]
	for k in 100:
		var cloud := PackedVector2Array()
		for p in rng.randi_range(3, 30):
			cloud.append(Vector2(rng.randf_range(0, 100), rng.randf_range(0, 100)))
		var hull := Geometry2D.convex_hull(cloud)
		hull.remove_at(hull.size() - 1)
		if k % 2 == 0:
			hull.reverse()
		shapes.append(hull)
	var mismatched := 0
	for points in shapes:
		var cuts := PackedFloat32Array()
		for p in points:
			cuts.append(p.y)
		cuts.sort()
		var chains := ShapePaint._monotone_chains(points)
		var walk := [0, 0]
		for y in cuts:
			if ShapePaint._chains_span(chains, walk, y).distance_to(_scan_span(points, y)) > 0.01:
				mismatched += 1
	assert_true.call(mismatched == 0, "グラデーションの横幅が全辺を調べた幅と一致する")


func _scan_span(points: PackedVector2Array, y: float) -> Vector2:
	var left := INF
	var right := -INF
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		if (p.y > y and q.y > y) or (p.y < y and q.y < y):
			continue
		if is_equal_approx(p.y, q.y):
			left = minf(left, minf(p.x, q.x))
			right = maxf(right, maxf(p.x, q.x))
			continue
		var x := p.x + (q.x - p.x) * (y - p.y) / (q.y - p.y)
		left = minf(left, x)
		right = maxf(right, x)
	return Vector2(left, right)


## 形の控え(`ShapeCache`)は2回目に描かれた形だけをメッシュにする。動きの途中の値(1回しか描かれない形)まで
## 控えると、Web版でGLの番号を使い捨てるため。三角形にできない線が混じった形は控えない。
func _test_shape_cache_keeps_only_repeated_shapes(assert_true: Callable) -> void:
	var ci := RenderingServer.canvas_item_create()
	var gem := func(at: Vector2) -> void:
		UiKit._gem_shape(ci, at, 13.0, Color.RED, Color.DARK_RED, Color.WHITE)
	var key := [&"test_gem", 13.0]
	ShapeCache.draw(ci, key, Vector2(5, 5), gem)
	assert_true.call(ShapeCache._meshes.get(key) == null, "1回目に描いた形はまだ控えない")
	ShapeCache.draw(ci, key, Vector2(40, 5), gem)
	assert_true.call(ShapeCache._meshes.get(key) is ArrayMesh, "2回目に描いた形をメッシュに控える")
	var line := func(at: Vector2) -> void:
		ShapePaint.polyline(ci, PackedVector2Array([at, at + Vector2(9, 0)]), Color.WHITE)
	var line_key := [&"test_line"]
	ShapeCache.draw(ci, line_key, Vector2.ZERO, line)
	ShapeCache.draw(ci, line_key, Vector2.ZERO, line)
	assert_true.call(ShapeCache._meshes.get(line_key) == null, "線を含む形は控えない")
	assert_true.call(not ShapePaint._recording, "記録の後は通常の描画へ戻る")
	RenderingServer.free_rid(ci)
