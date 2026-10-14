extends SignatureMove
## 大合唱(GameDesign.md 9章):自分の情報帯から五線が味方の列を横切って伸び、五線上の音符が
## 通り過ぎた駒から順に返る。

const SWEEP := 0.7
## 五線の本数・間隔と、列の端からはみ出す量。
const LINES := 5
const LINE_GAP := 5.0
const MARGIN := 60.0
## 帯から列へ立ち上がる曲がりの細かさ。
const RISE_STEPS := 12
## 五線の先頭に乗る音符の数と間隔(道のりの画素)。
const NOTES := 3
const NOTE_GAP := 34.0
const NOTE_SIZE := 5.0

var _path := PackedVector2Array()
var _lengths := PackedFloat32Array()


func impact_at() -> float:
	return SWEEP


func reaches(index: int, t: float) -> bool:
	_ensure_path()
	return _front(t) >= _distance_at(targets[index].x)


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	_ensure_path()
	var alpha := fade_alpha(t)
	var front := _front(t)
	for line in range(LINES):
		var offset := (float(line) - float(LINES - 1) * 0.5) * LINE_GAP
		var stroke := _stroke(front, offset)
		if stroke.size() >= 2:
			var color := Color(SignaturePaint.SPIN, alpha * 0.75)
			item.draw_polyline(stroke, color, 1.4, true)
	for i in range(NOTES):
		var along := front - NOTE_GAP * i
		if along <= 0.0:
			continue
		var bob := sin(along * 0.08 + i) * LINE_GAP
		SignaturePaint.note(
			item, _point_at(along) + Vector2(0.0, bob), NOTE_SIZE, SignaturePaint.SPIN, alpha
		)


## 帯の中心から列の左端へ立ち上がり、列を右端まで横切る道。
func _ensure_path() -> void:
	if not _path.is_empty():
		return
	var row := 0.0
	var left := INF
	var right := -INF
	for target in targets:
		row += target.y
		left = minf(left, target.x)
		right = maxf(right, target.x)
	row /= float(targets.size())
	var corner := Vector2(left - MARGIN, row)
	var control := Vector2(from.x * 0.3 + corner.x * 0.7, from.y)
	for i in range(RISE_STEPS + 1):
		var u := float(i) / float(RISE_STEPS)
		_path.append(from.lerp(control, u).lerp(control.lerp(corner, u), u))
	_path.append(Vector2(right + MARGIN, row))
	var total := 0.0
	_lengths.append(0.0)
	for i in range(1, _path.size()):
		total += _path[i - 1].distance_to(_path[i])
		_lengths.append(total)


func _front(t: float) -> float:
	return _lengths[_lengths.size() - 1] * ease(phase(t, 0.0, SWEEP), -1.4)


## 列の上の x に届くまでの道のり。
func _distance_at(x: float) -> float:
	var last := _path.size() - 1
	return _lengths[last - 1] + (x - _path[last - 1].x)


func _point_at(along: float) -> Vector2:
	for i in range(1, _path.size()):
		if along <= _lengths[i]:
			var span := _lengths[i] - _lengths[i - 1]
			var k := (along - _lengths[i - 1]) / span if span > 0.0 else 0.0
			return _path[i - 1].lerp(_path[i], k)
	return _path[_path.size() - 1]


## 道のりの先頭 `front` までを、道から垂直に `offset` ずらした線。
func _stroke(front: float, offset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(_path.size()):
		var along := minf(_lengths[i], front)
		var at := _point_at(along)
		var next := _point_at(minf(along + 1.0, _lengths[_lengths.size() - 1]))
		var prev := _point_at(maxf(along - 1.0, 0.0))
		var normal := (next - prev).normalized().orthogonal()
		out.append(at + normal * offset)
		if _lengths[i] >= front:
			break
	return out
