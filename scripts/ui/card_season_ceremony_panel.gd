class_name CardSeasonCeremonyPanel
extends Control
## 月初の表彰演出(GameDesign.md 28章「月初に表彰演出(表彰式)を行う案がある」への
## 答え。2026-09-15、ユーザー判断で「モーダル表彰式」を採用)。
##
## `DailyMissionPanel`と同じ「暗幕 + 中央パネル + 閉じる」の型を使うが、これは
## 日課の確認ではなく**前シーズンの到達を1回だけ讃える**ための画面のため、
## 開いた瞬間に短い"ポップイン"(拡大しながら現れる)を添えて式典らしさを出す。
##
## トリガーは`RankProgress.ensure_current_season()`が`transitioned: true`を
## 返したときだけ(初めてランクマッチへ触れるプレイヤーへ「ブロンズに到達しました」
## のような空虚な表彰を出さないため。詳細は`RankProgress`側の注記を参照)。

signal closed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(560, 400)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const EMBLEM_SIZE := 96.0
const POP_IN_DURATION := 0.32
const NOTE_INSET := 60.0
const CLOSE_SIZE := Vector2(180, 48)
## 縦(GameDesign.md 9章「縦画面」)。`PortraitModal` の論理幅で組み、中身ごと拡大する。
const PORTRAIT_PANEL_SIZE := Vector2(PortraitModal.WIDTH, 400)
const PORTRAIT_CLOSE_SIZE := Vector2(180, 56)
const NOTE_FONT := 15
## 拡大しても本文の目安(24px)に届かない注記だけ縦の大きさを持つ。
const PORTRAIT_NOTE_FONT := 17

var _dim: ColorRect
var _panel: PanelContainer
var _tier_label: Label
var _reward_label: Label
var _pop_tween: Tween
var _note: Label
var _close: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(self, _layout)


## `result`は`RankProgress.ensure_current_season()`の戻り値をそのまま渡す。
func open(result: Dictionary) -> void:
	var peak_tier := str(result.get("peak_tier", RankRules.INITIAL_TIER))
	_tier_label.text = "前シーズンの最高到達: %s" % RankRules.display_name(peak_tier)
	var reward := int(result.get("reward", 0))
	_reward_label.text = "+%d %s" % [reward, CurrencyRules.CURRENCY_NAME] if reward > 0 else ""
	_reward_label.visible = reward > 0
	_layout()
	visible = true
	_play_pop_in()


## 出てくる途中で向きが変わったら演出を打ち切る(残すと前の向きの倍率へ戻してしまう)。
func _layout() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
		_dim.modulate.a = 1.0
		_panel.modulate.a = 1.0
	var portrait := ScreenOrientation.is_portrait()
	var panel_size := PORTRAIT_PANEL_SIZE if portrait else PANEL_SIZE
	size = PortraitModal.screen_size()
	_dim.size = size
	# 中身の最小幅を先に変える(パネルは中身より狭くならないため)。
	_note.custom_minimum_size.x = panel_size.x - NOTE_INSET
	_note.add_theme_font_size_override("font_size", PORTRAIT_NOTE_FONT if portrait else NOTE_FONT)
	_close.custom_minimum_size = PORTRAIT_CLOSE_SIZE if portrait else CLOSE_SIZE
	_panel.size = panel_size
	_panel.position = (size - panel_size) * 0.5
	PortraitModal.fit(_panel)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.75)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE * 0.5
	_panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	var emblem := TextureRect.new()
	emblem.texture = UserProfileLibrary.get_icon_texture("crown")
	emblem.custom_minimum_size = Vector2(EMBLEM_SIZE, EMBLEM_SIZE)
	emblem.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.modulate = UiPalette.GLOW_AMBER
	box.add_child(emblem)

	var title := Label.new()
	title.text = "シーズン表彰式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	box.add_child(title)

	_tier_label = Label.new()
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 24)
	_tier_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	box.add_child(_tier_label)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 20)
	_reward_label.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	box.add_child(_reward_label)

	_note = Label.new()
	_note.text = "今シーズンはブロンズ1から新しく始まります"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = PANEL_SIZE.x - NOTE_INSET
	_note.add_theme_font_size_override("font_size", NOTE_FONT)
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(_note)

	_close = CodedButton.make("閉じる", CLOSE_SIZE)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func() -> void: _on_close())
	box.add_child(_close)


## 拡大しながら現れる(GameDesign.md 9章の手触り方針と同じ、既存の反応の語彙を使う)。
func _play_pop_in() -> void:
	_dim.modulate.a = 0.0
	var settled := _panel.scale
	_panel.scale = settled * 0.85
	_panel.modulate.a = 0.0
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(_dim, "modulate:a", 1.0, POP_IN_DURATION * 0.6)
	_pop_tween.tween_property(_panel, "modulate:a", 1.0, POP_IN_DURATION * 0.6)
	(
		_pop_tween
		. tween_property(_panel, "scale", settled, POP_IN_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _on_close() -> void:
	visible = false
	closed.emit()
