class_name CardLabScreen
extends Control
## 掲示板〈ラボ〉画面(GameDesign.md 29章)。ホーム画面5つ目のタブ「つくる」から開く。
##
## ヘッダーの3タブ(募集中/自分の投稿/過去の回)で表示を切り替える。帯・一覧の1件・
## 詳細パネル・投稿フォームはそれぞれ別のクラスが描き、ここは取得と切り替えだけを持つ。
## お題の作成・非表示・採用の確定は管理ツールの役目(Architecture.md 10.17節)。

signal back_pressed

enum View { OPEN, MINE, PAST }

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const TAB_LABELS := ["募集中", "自分の投稿", "過去の回"]
const TAB_SIZE := Vector2(150, 48)
const BAND_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, 140)
const BAND_GAP := 16.0
const LIST_LEFT := 24.0
const LIST_WIDTH := 1232.0
const COLUMN_GAP := 24
const ROW_GAP := 14
const REGISTER_NOTE := "投稿・投票は登録済みアカウントのみ"

var _header: ScreenHeader
var _tabs: Array[Button] = []
var _band: LabThemeBand
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: EmptyState
var _detail: LabProposalDetail
var _submit_panel: LabSubmitPanel
var _view := View.OPEN
## 取得の世代。タブを素早く切り替えたとき、古い取得の結果で上書きしないため。
var _serial := 0
var _rounds: Array = []
var _current: Dictionary = {}
var _closed: Array = []
var _past_index := 0
var _ballot: Dictionary = {}
var _own: Dictionary = {}
var _rows_by_id: Dictionary = {}
var _cards_by_id: Dictionary = {}


func _ready() -> void:
	_build()


func open() -> void:
	_select(View.OPEN)


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.VAULT
	add_child(backdrop)
	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.set_title("掲示板〈ラボ〉")
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	for i in TAB_LABELS.size():
		var tab := CodedButton.make(TAB_LABELS[i], TAB_SIZE)
		tab.toggle_mode = true
		tab.pressed.connect(_select.bind(i))
		_header.add_action(tab)
		_tabs.append(tab)

	_band = LabThemeBand.new()
	_band.position = BAND_RECT.position
	_band.size = BAND_RECT.size
	_band.submit_requested.connect(func() -> void: _submit_panel.open(_current))
	_band.step_requested.connect(_on_step_requested)
	add_child(_band)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_scroll)
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", COLUMN_GAP)
	_grid.add_theme_constant_override("v_separation", ROW_GAP)
	_scroll.add_child(_grid)

	_empty = EmptyState.new()
	_empty.visible = false
	add_child(_empty)

	_detail = LabProposalDetail.new()
	_detail.vote_requested.connect(_on_vote_requested)
	add_child(_detail)
	_submit_panel = LabSubmitPanel.new()
	_submit_panel.submitted.connect(func() -> void: _select(View.OPEN))
	add_child(_submit_panel)


## 帯を出すかどうかで一覧の置き場を変える。
func _layout(with_band: bool) -> void:
	_band.visible = with_band
	var top := BAND_RECT.end.y + BAND_GAP if with_band else ScreenHeader.CONTENT_TOP
	var list_rect := Rect2(
		LIST_LEFT, top, LIST_WIDTH, ScreenHeader.CONTENT_TOP + ScreenHeader.CONTENT_HEIGHT - top
	)
	_scroll.position = list_rect.position
	_scroll.size = list_rect.size
	_empty.position = list_rect.position
	_empty.size = list_rect.size


func _select(view: int) -> void:
	_view = view as View
	for i in _tabs.size():
		var selected := i == view
		_tabs[i].button_pressed = selected
		for slot in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			if selected:
				_tabs[i].add_theme_color_override(slot, UiPalette.GLOW_AMBER)
			else:
				_tabs[i].remove_theme_color_override(slot)
	_past_index = 0
	_load()


func _load() -> void:
	_serial += 1
	var serial := _serial
	_clear_list()
	_layout(false)
	if NetSession.client == null:
		_show_empty("読み込めませんでした", "通信状況を確認してください")
		return
	_empty.show_message("読み込んでいます", "", true)
	_empty.visible = true

	_rounds = await LabProposalService.fetch_rounds(NetSession.client)
	if serial != _serial:
		return
	var now := Time.get_unix_time_from_system()
	_current = LabRules.current_round(_rounds, now)
	_closed = LabRules.closed_rounds(_rounds, now)
	match _view:
		View.OPEN:
			await _load_open(serial)
		View.MINE:
			await _load_mine(serial)
		View.PAST:
			await _load_past(serial)


func _load_open(serial: int) -> void:
	if _current.is_empty():
		_show_empty("いまは募集していません", "次のお題を準備しています。これまでの回は「過去の回」で見られます")
		return
	var round_id := str(_current.get("id", ""))
	var uid := _uid()
	var rows: Array = await LabProposalService.list_round(NetSession.client, round_id)
	var ballot: Dictionary = await LabProposalService.fetch_ballot(NetSession.client, round_id, uid)
	var own: Dictionary = await LabProposalService.fetch_own(NetSession.client, round_id, uid)
	if serial != _serial:
		return
	_ballot = ballot
	_own = own
	_layout(true)
	_refresh_open_band()
	if rows.is_empty():
		_show_empty("まだ案がありません", "お題に沿った案を出してみましょう")
		return
	_empty.visible = false
	var voted := LabRules.voted_ids(_ballot)
	for row in LabRules.viewer_order(rows, uid):
		_add_card(row).show_open(row, voted.has(row["id"]))
	_reveal()


func _refresh_open_band() -> void:
	var registered := AccountService.is_registered()
	var label := "投稿済み" if not _own.is_empty() else "案を出す"
	_band.show_open(
		str(_current.get("title", "")),
		str(_current.get("detail", "")),
		LabRules.deadline_text(float(_current.get("ends_at", 0)), Time.get_unix_time_from_system()),
		LabRules.votes_left(_ballot),
		label,
		registered and _own.is_empty(),
		"" if registered else REGISTER_NOTE
	)


func _load_mine(serial: int) -> void:
	var rows: Array = await LabProposalService.list_mine(NetSession.client, _uid())
	if serial != _serial:
		return
	if rows.is_empty():
		_show_empty("まだ投稿がありません", "募集中の回に案を出すと、ここに並びます")
		return
	_empty.visible = false
	var now := Time.get_unix_time_from_system()
	for row in rows:
		var round := _round_by_id(str(row.get("round_id", "")))
		var status := LabRules.status_of(row, round, now)
		var theme := str(round.get("title", ""))
		var caption := "" if theme.is_empty() else "お題:%s" % theme
		_add_card(row).show_mine(row, _status_text(status, row), _status_color(status), caption)
	_reveal()


func _load_past(serial: int) -> void:
	if _closed.is_empty():
		_show_empty("締め切った回はまだありません", "")
		return
	var round: Dictionary = _closed[_past_index]
	var rows: Array = await LabProposalService.list_round(
		NetSession.client, str(round.get("id", ""))
	)
	if serial != _serial:
		return
	var fixed := bool(round.get("results_fixed", false))
	var adopted_count := (
		rows
		. filter(func(row: Dictionary) -> bool: return str(row.get("result", "")) == "adopted")
		. size()
	)
	var result_text := "検討中"
	if fixed:
		result_text = "採用%d件" % adopted_count if adopted_count > 0 else "採用なし"
	_layout(true)
	_band.show_closed(
		str(round.get("title", "")),
		str(round.get("detail", "")),
		LabRules.period_text(round),
		result_text,
		_past_index < _closed.size() - 1,
		_past_index > 0
	)
	if rows.is_empty():
		_show_empty("この回には案がありませんでした", "")
		return
	_empty.visible = false
	var rank := 0
	var last_count := -1
	var ranked := LabRules.ranked(rows)
	for i in ranked.size():
		var row: Dictionary = ranked[i]
		var count := int(row.get("good_count", 0))
		if count != last_count:
			rank = i + 1
			last_count = count
		_add_card(row).show_ranked(row, rank, fixed and str(row.get("result", "")) == "adopted")
	_reveal()


func _on_step_requested(delta: int) -> void:
	_past_index = clampi(_past_index + delta, 0, _closed.size() - 1)
	_serial += 1
	var serial := _serial
	_clear_list()
	await _load_past(serial)


func _add_card(row: Dictionary) -> LabProposalCard:
	var card := LabProposalCard.new()
	_grid.add_child(card)
	card.opened.connect(_on_card_opened)
	_rows_by_id[row["id"]] = row
	_cards_by_id[row["id"]] = card
	return card


func _clear_list() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_rows_by_id.clear()
	_cards_by_id.clear()
	_scroll.scroll_vertical = 0


func _reveal() -> void:
	ListRevealFx.stagger(_grid.get_children())


func _show_empty(title: String, hint: String) -> void:
	_empty.show_message(title, hint)
	_empty.visible = true


func _on_card_opened(proposal_id: String) -> void:
	var row: Dictionary = _rows_by_id.get(proposal_id, {})
	if row.is_empty():
		return
	match _view:
		View.OPEN:
			_open_vote_detail(row)
		View.MINE:
			var round := _round_by_id(str(row.get("round_id", "")))
			var status := LabRules.status_of(row, round, Time.get_unix_time_from_system())
			_detail.open(row, "", false, _status_text(status, row))
		View.PAST:
			_detail.open(row, "", false, "%d票" % int(row.get("good_count", 0)))


func _open_vote_detail(row: Dictionary) -> void:
	if not AccountService.is_registered():
		_detail.open(row, "この案に投票する", false, REGISTER_NOTE)
		return
	var block := LabRules.vote_block(
		row, _ballot, _uid(), _current, Time.get_unix_time_from_system()
	)
	match block:
		LabRules.VoteBlock.NONE:
			_detail.open(row, "この案に投票する", true, "残り%d票・投票は取り消せません" % LabRules.votes_left(_ballot))
		LabRules.VoteBlock.OWN:
			_detail.open(row, "自分の案です", false, "")
		LabRules.VoteBlock.ALREADY:
			_detail.open(row, "投票済み", false, "")
		LabRules.VoteBlock.NO_VOTES_LEFT:
			_detail.open(row, "票が残っていません", false, "この回の%d票はすべて使いました" % LabRules.VOTES_PER_ROUND)
		_:
			_detail.open(row, "", false, "この回の投票は締め切られました")


func _on_vote_requested(proposal_id: String) -> void:
	_detail.set_busy(true)
	var result: Dictionary = await LabProposalService.vote(
		NetSession.client, _uid(), _current, proposal_id
	)
	_detail.set_busy(false)
	if result.has("ballot"):
		_ballot = result["ballot"]
		_refresh_open_band()
	if not bool(result.get("ok", false)):
		_detail.show_note(str(result.get("message", "")))
		return
	var card: LabProposalCard = _cards_by_id.get(proposal_id)
	if card != null:
		card.mark_voted()
	_detail.close()


func _round_by_id(round_id: String) -> Dictionary:
	for round in _rounds:
		if str(round.get("id", "")) == round_id:
			return round
	return {}


func _status_text(status: LabRules.Status, row: Dictionary) -> String:
	match status:
		LabRules.Status.TOURNAMENT:
			return "大会優勝作"
		LabRules.Status.HIDDEN:
			return "非表示"
		LabRules.Status.REVIEWING:
			return "検討中"
		LabRules.Status.ADOPTED:
			return "採用"
		LabRules.Status.RESULT:
			return "%d票" % int(row.get("good_count", 0))
	return "掲載中"


func _status_color(status: LabRules.Status) -> Color:
	match status:
		LabRules.Status.TOURNAMENT, LabRules.Status.ADOPTED:
			return UiPalette.GLOW_AMBER
		LabRules.Status.HIDDEN:
			return UiPalette.WARNING_RED
		LabRules.Status.REVIEWING:
			return UiPalette.TEXT_MUTED
	return UiPalette.TEXT_OFFWHITE


func _uid() -> String:
	return NetSession.auth.uid if NetSession.auth != null else ""
