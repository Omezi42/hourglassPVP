class_name TextCopy
extends RefCounted
## 文字列をクリップボードへ置く(GameDesign.md 9章・11章)。
##
## **Web では `DisplayServer.clipboard_set()` を使わない。**中身は `navigator.clipboard.writeText()`
## だけで、iframe(unityroom 等)の中では拒否され、しかも失敗が呼び出し側へ返らない。
## そのため Web では JS から `writeText()` を試し、断られたら `execCommand("copy")` で写し直す
## (こちらは iframe の権限設定に縛られない)。
##
## `ImageShare` と同じ「Autoloadを使わずstaticで持つ」流儀。

const _JS_TEMPLATE := """
(function () {
	var text = %s;
	function report(ok) {
		if (window.godotTextCopyDone) { window.godotTextCopyDone(ok); }
	}
	function fallback() {
		var canvas = document.activeElement;
		var area = document.createElement("textarea");
		area.value = text;
		area.setAttribute("readonly", "");
		area.style.position = "fixed";
		area.style.top = "0";
		area.style.left = "0";
		area.style.opacity = "0";
		document.body.appendChild(area);
		area.select();
		var ok = false;
		try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
		document.body.removeChild(area);
		if (canvas && canvas.focus) { canvas.focus(); }
		report(ok);
	}
	try {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text)
				.then(function () { report(true); })
				.catch(function () { fallback(); });
		} else {
			fallback();
		}
	} catch (e) {
		fallback();
	}
})();
"""

## **`create_callback()` の戻り値は持ち続ける**(`ImageShare` と同じ理由)。
static var _js_callback: JavaScriptObject = null
static var _pending: Callable = Callable()


## `on_done(ok: bool)` で結果を返す。結果を見ない呼び出し側は `on_done` を省いてよい。
static func copy(text: String, on_done: Callable = Callable()) -> void:
	if not OS.has_feature("web"):
		DisplayServer.clipboard_set(text)
		if on_done.is_valid():
			on_done.call(true)
		return
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		if on_done.is_valid():
			on_done.call(false)
		return
	_pending = on_done
	if _js_callback == null:
		_js_callback = JavaScriptBridge.create_callback(_on_js_done)
	window.godotTextCopyDone = _js_callback
	JavaScriptBridge.eval(_JS_TEMPLATE % JSON.stringify(text), true)


static func _on_js_done(args: Array) -> void:
	var done := _pending
	_pending = Callable()
	if done.is_valid():
		done.call(not args.is_empty() and bool(args[0]))
