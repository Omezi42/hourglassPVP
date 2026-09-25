class_name MobileTextInput
extends RefCounted
## Web書き出し + タッチ端末では、`LineEdit` をタップしても仮想キーボードが開かない
## (Godot本体の既知の欠陥。`html/experimental_virtual_keyboard` を有効にしても直らない)。
## そのため対象の環境でだけ、タップを `window.prompt()` へ差し替える。
##
## デスクトップ・エディタでは何もせず、これまで通り `LineEdit` 自身の挙動に任せる。
## `TouchScroll` と同じく、`LineEdit` が内部で行う処理(空振りする側)には触れず、
## `gui_input` シグナルへ外側から1つ足すだけにする。


## `line_edit`(`LineEdit` か `TextEdit`)のタップで `window.prompt()` を開き、確定した
## 文字列を反映する。`title` はダイアログの見出し。呼ぶのは組み立てた直後の1箇所でよい。
static func wire(line_edit: Control, title: String) -> void:
	if not _needs_prompt():
		return
	line_edit.gui_input.connect(_on_gui_input.bind(line_edit, title))


## 対象の環境(Web書き出し + タッチ端末)かどうか。
static func _needs_prompt() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


static func _on_gui_input(event: InputEvent, line_edit: Control, title: String) -> void:
	if not ClickArea.is_primary_release(event):
		return
	_prompt(line_edit, title)


static func _prompt(input: Control, title: String) -> void:
	var current := str(input.get("text"))
	var js := 'window.prompt("%s", "%s")' % [title.json_escape(), current.json_escape()]
	var result: Variant = JavaScriptBridge.eval(js, true)
	if result == null:
		return
	var text := str(result)
	var text_edit := input as TextEdit
	if text_edit != null:
		text_edit.text = text
		text_edit.text_changed.emit()
		return
	var line_edit := input as LineEdit
	if line_edit.max_length > 0:
		text = text.substr(0, line_edit.max_length)
	line_edit.text = text
	line_edit.text_changed.emit(text)
	line_edit.text_submitted.emit(text)
