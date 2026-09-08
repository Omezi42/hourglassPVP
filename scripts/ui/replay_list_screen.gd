class_name ReplayListScreen
extends Control

signal back_pressed
signal replay_selected(match_id: String)

const REPLAY_CARD_SCENE := preload("res://scenes/replay_list_card.tscn")
const PANEL_STYLE := "res://resources/theme/content_panel.tres"

var _empty_state: EmptyState

@onready var list_container: GridContainer = $ScrollContainer/ListContainer
@onready var screen_header: ScreenHeader = $ScreenHeader
@onready var empty_label: Label = $EmptyLabel


func _ready() -> void:
	# 背景イラストの上に一覧が直接浮いていて、カードも案内文も読みにくかったため、
	# 他画面と共通のコンテンツパネルを下地として敷く。
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		list_container.get_parent().add_theme_stylebox_override("panel", style)
	screen_header.set_title("リプレイ")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	# 案内は他の一覧と同じ組み立て(印 / 見出し / 1行)にする。.tscn の Label は
	# 位置と大きさをそのまま使いたいので、隠したうえで同じ矩形へ重ねる。
	empty_label.visible = false
	_empty_state = EmptyState.new()
	_empty_state.position = empty_label.position
	_empty_state.size = empty_label.size
	_empty_state.visible = false
	add_child(_empty_state)


## オンライン対戦(Firestore)・CPU戦(user://ローカル)の両方のリプレイを取得し、
## finished_at降順にマージして1つの一覧として表示する(K-2)。CPU戦はローカル対局のため、
## オンライン側のサインインが失敗してもCPU戦のリプレイだけは表示できるようにする。
func refresh() -> void:
	for child in list_container.get_children():
		child.queue_free()
	# サインインと一覧の取得に数秒かかることがある。何も出さないと「履歴が無い」のか
	# 「まだ読んでいる」のか区別できないため、待っている間はその旨を出す。
	_show_empty("記録を読み込んでいます", "", true)

	# CPU戦のリプレイもアカウントに紐づくため、先にサインインしてuidを確定させる。
	# サインインできなかった場合、LocalReplayServiceは絞り込まずに全件返す
	var ok: bool = await NetSession.sign_in()
	var uid: String = NetSession.auth.uid if ok else ""
	var local_replays: Array[Dictionary] = LocalReplayService.list_replays(uid)

	var online_replays: Array[Dictionary] = []
	if ok:
		online_replays = await ReplayService.list_replays(NetSession.client, NetSession.auth.uid)
	elif local_replays.is_empty():
		_show_empty("記録を読み込めませんでした", "通信できませんでした(%s)" % NetSession.last_error)
		return

	# v5.0の棋譜だけを残す。v1.0の棋譜(位相制・配置フェーズあり)は再生できないため、
	# 一覧の時点で除く。見分けは `seed` を持つかどうか(Architecture.md 4.0節)。
	var combined: Array[Dictionary] = []
	for doc in online_replays + local_replays:
		if (doc["fields"] as Dictionary).has("seed"):
			combined.append(doc)
	if combined.is_empty():
		_show_empty("まだ対局の記録がありません", "対局を終えると、直近30件までここへ残ります")
		return

	combined.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["fields"].get("finished_at", 0)) > int(b["fields"].get("finished_at", 0))
	)

	_empty_state.hide_message()
	for doc in combined:
		var card: ReplayListCard = REPLAY_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_container.add_child(card)
		var opponent_name := ""
		if ok:
			opponent_name = await AccountService.fetch_display_name(
				NetSession.client, _opponent_uid_of(doc, uid)
			)
		card.show_replay(doc, uid, opponent_name)
		card.card_pressed.connect(func(match_id: String) -> void: replay_selected.emit(match_id))


## そのリプレイでの対戦相手のuid。CPU戦は相手が存在しないため空文字を返す。
## 同じ相手が何度も出てもAccountService側がキャッシュするため、通信は1人につき1回で済む。
static func _opponent_uid_of(doc: Dictionary, my_uid: String) -> String:
	var fields: Dictionary = doc["fields"]
	if str(fields.get("source", "")) == "cpu":
		return ""
	var player_a := str(fields.get("player_a", ""))
	var player_b := str(fields.get("player_b", ""))
	return player_b if player_a == my_uid else player_a


func _show_empty(title: String, hint := "", waiting := false) -> void:
	_empty_state.show_message(title, hint, waiting)
