class_name ImageShare
extends RefCounted
## 画像をクリップボードへ置く / ファイルへ保存する(GameDesign.md 9章)。
##
## **画像をクリップボードへ置けるのは Web だけ**である。Godot 4.6 の `DisplayServer` は
## `clipboard_get_image()` しか持たず、**書き込む側の関数が存在しない**(実測で確認済み)。
## そのため Web では `JavaScriptBridge` から `navigator.clipboard.write()` を呼び、
## **断られたらダウンロードへ落とす**。それ以外の環境では `user://` へ保存する。
##
## `SoundBank` と同じ「Autoloadを使わずstaticで持つ」流儀。

## 保存先(Web以外)。`user://` はブラウザでは仮想の領域であり、この経路は使わない。
const SAVE_DIR := "user://shared"

## クリップボードは断られることがあるため、必ずダウンロードへ落とせるようにしておく。
## `navigator.clipboard.write()` は押した操作から数秒のあいだしか通らない。
const _JS_TEMPLATE := """
(function () {
	var bin = atob("%s");
	var buf = new Uint8Array(bin.length);
	for (var i = 0; i < bin.length; i++) { buf[i] = bin.charCodeAt(i); }
	var blob = new Blob([buf], { type: "image/png" });
	var name = "%s";
	var wantCopy = %s;
	function report(kind) {
		if (window.godotDeckShareDone) { window.godotDeckShareDone(kind); }
	}
	function download(kind) {
		try {
			var url = URL.createObjectURL(blob);
			var a = document.createElement("a");
			a.href = url;
			a.download = name;
			document.body.appendChild(a);
			a.click();
			document.body.removeChild(a);
			setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
			report(kind);
		} catch (e) {
			report("failed");
		}
	}
	if (!wantCopy) { download("downloaded"); return; }
	try {
		if (navigator.clipboard && window.ClipboardItem) {
			navigator.clipboard.write([new ClipboardItem({ "image/png": blob })])
				.then(function () { report("copied"); })
				.catch(function () { download("saved"); });
		} else {
			download("saved");
		}
	} catch (e) {
		download("saved");
	}
})();
"""

## **`create_callback()` の戻り値は持ち続ける。**その場で捨てると、JS から呼び戻される
## 前に解放されて結果が返らない。
static var _js_callback: JavaScriptObject = null
static var _pending: Callable = Callable()


## 画像を渡す。`on_done(ok: bool, message: String)` で結果を返す。
##
## `prefer_clipboard` が false のときは、Web でもクリップボードを試さず保存へ回す
## (「画像を保存」のボタン用)。
static func share_png(
	image: Image, file_name: String, prefer_clipboard: bool, on_done: Callable
) -> void:
	if image == null:
		on_done.call(false, "画像を作れませんでした")
		return
	var bytes := image.save_png_to_buffer()
	if bytes.is_empty():
		on_done.call(false, "画像を作れませんでした")
		return
	if OS.has_feature("web"):
		_share_web(bytes, file_name, prefer_clipboard, on_done)
		return
	_save_local(bytes, file_name, on_done)


## ブラウザ以外では画像をクリップボードへ置けないため、この文言を添えてボタンを出す側が
## 期待を作らないようにする。
static func can_copy() -> bool:
	return OS.has_feature("web")


static func _save_local(bytes: PackedByteArray, file_name: String, on_done: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := "%s/%s" % [SAVE_DIR, file_name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		on_done.call(false, "画像を保存できませんでした")
		return
	file.store_buffer(bytes)
	file.close()
	on_done.call(true, "保存しました: %s" % ProjectSettings.globalize_path(path))


static func _share_web(
	bytes: PackedByteArray, file_name: String, prefer_clipboard: bool, on_done: Callable
) -> void:
	_pending = on_done
	if _js_callback == null:
		_js_callback = JavaScriptBridge.create_callback(_on_js_done)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		on_done.call(false, "この環境では画像を書き出せません")
		return
	window.godotDeckShareDone = _js_callback
	var script := (
		_JS_TEMPLATE
		% [
			Marshalls.raw_to_base64(bytes),
			file_name.json_escape(),
			str(prefer_clipboard).to_lower()
		]
	)
	JavaScriptBridge.eval(script, true)


static func _on_js_done(args: Array) -> void:
	if not _pending.is_valid():
		return
	var result: String = str(args[0]) if not args.is_empty() else ""
	var done := _pending
	_pending = Callable()
	match result:
		"copied":
			done.call(true, "画像をコピーしました。そのまま貼り付けられます")
		"saved":
			done.call(true, "画像を保存しました(コピーはブラウザに断られました)")
		"downloaded":
			done.call(true, "画像を保存しました")
		_:
			done.call(false, "画像を書き出せませんでした")
