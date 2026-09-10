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
