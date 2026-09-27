class_name CardSoloMapScreen
extends Control
## 遠征(ソロモード)の画面(GameDesign.md 27章)。**仮の最小版**——本番の見た目は
## モックの承認待ち(Architecture.md 10.15節)。既存のヘッダー・ボタン部品だけで、
## 遠征の状態(出発・道・候補)を縦に並べて出す。

signal back_pressed
## いまの段の行き先で対局・関門を選んだ(`run.in_battle`が立った)。
signal battle_requested(run: SoloRun)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const CONTENT_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const BUTTON_SIZE := Vector2(420, 56)
const OFFER_BUTTON_SIZE := Vector2(260, 56)
const GAP := 12

var _scroll: ScrollContainer
var _box: VBoxContainer
var _run: SoloRun = null


func _ready() -> void:
	_build()


func open() -> void:
	_run = SoloProgress.load_run(_uid())
	_refresh()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("遠征")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_scroll = ScrollContainer.new()
	_scroll.position = CONTENT_RECT.position
	_scroll.size = CONTENT_RECT.size
	_scroll.custom_minimum_size = CONTENT_RECT.size
	TouchScroll.enable(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var centering := CenterContainer.new()
	centering.custom_minimum_size = CONTENT_RECT.size
	_scroll.add_child(centering)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", GAP)
	centering.add_child(_box)


func _refresh() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	if _run == null:
		_build_start()
	else:
		_build_in_progress()


func _build_start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_box.add_child(_label("作戦を選ぶ", 24, UiPalette.TEXT_OFFWHITE))
	for theme_id in SoloRun.theme_choices(rng):
		_box.add_child(_theme_button(theme_id))
	_box.add_child(_gap(10))
	var uid := _uid()
	_box.add_child(
		_label(
			"最多勝利数 %d ・ 踏破 %d回" % [SoloProgress.best_wins(uid), SoloProgress.clears(uid)],
			16,
			UiPalette.TEXT_MUTED
		)
	)


func _theme_button(theme_id: String) -> Button:
	var button := CodedButton.make_in_group(
		"%s ・ %s" % [CardCpuDecks.name_of(theme_id), CardCpuDecks.summary_of(theme_id)],
		BUTTON_SIZE,
		CodedButton.PRIMARY_ACTION_GROUP
	)
	button.pressed.connect(func() -> void: _start_run(theme_id))
	return button


func _start_run(theme_id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_run = SoloRun.create(theme_id, rng)
	SoloProgress.save_run(_uid(), _run)
	_refresh()


func _build_in_progress() -> void:
	_box.add_child(
		_label(
			"HP %d ・ %d勝 ・ 山札%d枚" % [_run.hp, _run.wins, _run.deck_ids.size()],
			18,
			UiPalette.TEXT_OFFWHITE
		)
	)
	_box.add_child(_gap(6))
	if not _run.offer.is_empty():
		_build_offer()
	else:
		_build_destinations()
	_box.add_child(_gap(16))
	var quit := CodedButton.make("遠征をやめる", BUTTON_SIZE)
	quit.pressed.connect(_abandon)
	_box.add_child(quit)


func _build_destinations() -> void:
	var options := _run.current_destinations()
	for i in options.size():
		_box.add_child(_destination_button(options[i], i))


func _destination_button(dest: Dictionary, index: int) -> Button:
	var button := CodedButton.make(_destination_label(dest), BUTTON_SIZE)
	button.pressed.connect(func() -> void: _choose(index))
	return button


func _destination_label(dest: Dictionary) -> String:
	var kind: int = int(dest.get("kind", SoloRun.Kind.BATTLE))
	var foe_name := CardCpuDecks.foe_name_of(str(dest.get("cpu_deck", "")))
	match kind:
		SoloRun.Kind.SPRING:
			return "泉 HP+%d" % SoloRun.SPRING_HEAL
		SoloRun.Kind.GATE:
			var gate := SoloGateLibrary.find_by_id(str(dest.get("gate", "")))
			var gate_name := "" if gate == null else gate.display_name
			return "関門 ・ %s ・ %s" % [gate_name, foe_name]
		_:
			return "対局 ・ %s" % foe_name


func _choose(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_run.choose(index, rng)
	if _run.in_battle:
		battle_requested.emit(_run)
		return
	SoloProgress.save_run(_uid(), _run)
	_refresh()


func _build_offer() -> void:
	_box.add_child(_label("候補から1枚を足す", 18, UiPalette.TEXT_OFFWHITE))
	for card_id in _run.offer:
		_box.add_child(_offer_button(card_id))
	var pass_button := CodedButton.make("見送る", OFFER_BUTTON_SIZE)
	pass_button.pressed.connect(_pass_offer)
	_box.add_child(pass_button)


func _offer_button(card_id: String) -> Button:
	var card := CardLibrary.find_by_id(card_id)
	var label := card_id if card == null else card.display_name
	var button := CodedButton.make(label, OFFER_BUTTON_SIZE)
	button.pressed.connect(func() -> void: _take(card_id))
	return button


func _take(card_id: String) -> void:
	_run.take(card_id)
	_after_offer_choice()


func _pass_offer() -> void:
	_run.pass_offer()
	_after_offer_choice()


func _after_offer_choice() -> void:
	if _run.over:
		SoloProgress.clear_run(_uid())
		_run = null
	else:
		SoloProgress.save_run(_uid(), _run)
	_refresh()


func _abandon() -> void:
	SoloProgress.clear_run(_uid())
	_run = null
	_refresh()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _uid() -> String:
	return StageReward.current_uid()
