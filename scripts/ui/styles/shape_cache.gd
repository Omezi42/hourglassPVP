class_name ShapeCache
extends RefCounted
## 同じ形を何度も描く飾り(宝石・紋章の印・コストの菱形)を、三角形の列ごと1枚のメッシュに控えて
## 2回目からは1回の命令で描く(Architecture.md 10.10.3節)。三角形は `ShapePaint` が描くものと同じなので、
## 見た目は変わらない。
##
## 1つの宝石でも `ShapePaint` の三角形は100を超え、GDScriptから1つずつ渡すと、カードを並べる画面で
## 描き直すたびに数百msかかる。メッシュは作るときに1度だけGLのバッファを取るため、
## 動きの途中の値(毎フレーム違う大きさ・色)まで控えると Web版でGLの番号を使い捨てる(Pitfalls.md)。
## そのため **2回以上描かれた形だけ** を、数の上限まで控える。

## この回数目に描かれたときにメッシュへ控える。
const REPEATS_BEFORE_CACHE := 2
## 控えるメッシュの上限。超えたら控えずに毎回描く。
const MAX_MESHES := 768
## 描かれた回数を数える表の上限。動きの途中の値で膨らんだら数え直す。
const MAX_SEEN := 4096

static var _meshes: Dictionary = {}
static var _seen: Dictionary = {}


## `paint` は原点を受け取って形を描く(`ShapePaint` 経由の面と線だけを描くこと)。
## `key` は形を決める値をすべて含める(位置は含めない)。
static func draw(ci: RID, key: Array, origin: Vector2, paint: Callable) -> void:
	var mesh: ArrayMesh = _meshes.get(key, null)
	if mesh != null:
		RenderingServer.canvas_item_add_mesh(ci, mesh.get_rid(), Transform2D(0.0, origin))
		return
	if not _should_cache(key):
		paint.call(origin)
		return
	ShapePaint.begin_record()
	paint.call(Vector2.ZERO)
	var recorded := ShapePaint.end_record()
	var points: PackedVector2Array = recorded.get("points", PackedVector2Array())
	if points.is_empty():
		_meshes[key] = null
		paint.call(origin)
		return
	mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = recorded["colors"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	RenderingServer.canvas_item_add_mesh(ci, mesh.get_rid(), Transform2D(0.0, origin))


static func _should_cache(key: Array) -> bool:
	if _meshes.has(key) or _meshes.size() >= MAX_MESHES:
		return false
	if _seen.size() >= MAX_SEEN:
		_seen.clear()
	var count: int = _seen.get(key, 0) + 1
	_seen[key] = count
	return count >= REPEATS_BEFORE_CACHE
