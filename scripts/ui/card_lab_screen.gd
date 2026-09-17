class_name CardLabScreen
extends Control
## 掲示板〈ラボ〉画面(GameDesign.md 29章)。ホーム画面5つ目のタブ「つくる」の入口。
##
## 一覧(横2列規約に沿った縦積みの札)+ ヘッダー主アクションに「投稿する」と
## 「今月/過去ログ」の切り替えを置く(9章・29章)。承認・却下・月末の採用判断は
## この画面では行わない(開発側の管理ツールの役目。Architecture.md 10.17節)。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const COLUMN_WIDTH := 616.0
const ROW_GAP := 12.0

var _header: ScreenHeader
var _toggle_button: Button
var _submit_button: Button
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: EmptyState
var _submit_panel: LabSubmitPanel
var _showing_history := false
var _fetching := false
## このセッション内で投票済みの投稿id(サーバー側は`votes/{uid}`が唯一の真実)。
var _voted_ids: Dictionary = {}


func _ready() -> void:
	_build()


func open() -> void:
	_showing_history = false
	_refresh_toggle_label()
	# 未登録の間は暗くして無反応にする(GameDesign.md 29章。21章のショップと同じ扱い)。
	var registered := AccountService.is_registered()
	_submit_button.disabled = not registered
	_submit_button.tooltip_text = "" if registered else "投稿には登録済みアカウントが必要です"
	_fetch()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.VAULT
	add_child(backdrop)
	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.set_title("掲示板〈ラボ〉")
	_header.back_pressed.connect(func() -> void: back_pressed.emit())

	_toggle_button = CodedButton.make("過去ログ", Vector2(150, 48))
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_header.add_action(_toggle_button)

	_submit_button = CodedButton.make("投稿する", Vector2(150, 48))
	CodedButton.apply_styles(_submit_button, "primary_action")
	_submit_button.pressed.connect(_on_submit_pressed)
	_header.add_action(_submit_button)

	_scroll = ScrollContainer.new()
	_scroll.position = LIST_RECT.position
	_scroll.size = LIST_RECT.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_scroll)
	add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", int(ROW_GAP))
	_scroll.add_child(_grid)

	_empty = EmptyState.new()
	_empty.position = LIST_RECT.position
	_empty.size = LIST_RECT.size
	_empty.visible = false
	add_child(_empty)

	_submit_panel = LabSubmitPanel.new()
	_submit_panel.submitted.connect(_on_submitted)
	add_child(_submit_panel)


func _on_toggle_pressed() -> void:
	_showing_history = not _showing_history
	_refresh_toggle_label()
	_fetch()


func _refresh_toggle_label() -> void:
	_toggle_button.text = "今月" if _showing_history else "過去ログ"


func _on_submit_pressed() -> void:
	if not AccountService.is_registered():
		_empty.show_message("投稿には登録済みアカウントが必要です", "アカウント画面で登録してください")
		_empty.visible = true
		return
	_submit_panel.open()


func _on_submitted() -> void:
	_showing_history = false
	_refresh_toggle_label()
	_fetch()


func _fetch() -> void:
	if _fetching:
		return
	for child in _grid.get_children():
		child.queue_free()
	if NetSession.client == null:
		_empty.show_message("読み込めませんでした", "通信状況を確認してください")
		_empty.visible = true
		return
	_fetching = true
	_empty.show_message("読み込んでいます", "", true)
	_empty.visible = true

	var rows: Array
	if _showing_history:
		rows = await _fetch_history()
	else:
		rows = await LabProposalService.list_approved(
			NetSession.client, LabProposalService.current_month()
		)
	_fetching = false

	if rows.is_empty():
		_empty.show_message("まだ今月の投稿がありません" if not _showing_history else "まだ結果が出た投稿がありません", "")
		_empty.visible = true
		return
	_empty.visible = false
	var can_vote := AccountService.is_registered()
	for fields in rows:
		var card := LabProposalCard.new()
		card.custom_minimum_size.x = COLUMN_WIDTH
		var id := str(fields.get("id", ""))
		card.setup(id, fields, _voted_ids.has(id), can_vote)
		card.voted.connect(_on_vote_pressed)
		_grid.add_child(card)
	ListRevealFx.stagger(_grid.get_children())


## 過去ログ:結果が出た投稿(却下は含めない。GameDesign.md 29章)。
func _fetch_history() -> Array:
	var months: Array[String] = _recent_months()
	var rows: Array = []
	for month in months:
		var docs: Array = await NetSession.client.query_two_fields_equal(
			LabProposalService.COLLECTION, "status", "approved", "month", month, 100
		)
		for doc in docs:
			var fields: Dictionary = doc.get("fields", {})
			if str(fields.get("result", "")).is_empty():
				continue
			fields["id"] = doc.get("id", "")
			rows.append(fields)
	rows.sort_custom(func(a, b): return int(a.get("good_count", 0)) > int(b.get("good_count", 0)))
	return rows


## 直近12か月ぶんの月キーを新しい順で返す(過去ログの検索範囲)。
func _recent_months() -> Array[String]:
	var months: Array[String] = []
	var base := Time.get_unix_time_from_system() + 9 * 3600.0
	for i in range(12):
		var dict := Time.get_datetime_dict_from_unix_time(int(base))
		months.append("%04d-%02d" % [int(dict["year"]), int(dict["month"])])
		base -= 30.0 * 24.0 * 3600.0
	return months


func _on_vote_pressed(proposal_id: String) -> void:
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var result: Dictionary = await LabProposalService.vote(NetSession.client, uid, proposal_id)
	if not bool(result.get("ok", false)):
		return
	_voted_ids[proposal_id] = true
	for child in _grid.get_children():
		var card := child as LabProposalCard
		if card != null and card.proposal_id == proposal_id:
			# 得票数は再取得せず、その場で+1して見せる(正確な値は次に開いたときに揃う)。
			card.mark_voted(card.good_count() + 1)
