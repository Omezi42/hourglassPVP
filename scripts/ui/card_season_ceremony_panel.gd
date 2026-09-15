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

var _dim: ColorRect
var _panel: PanelContainer
var _tier_label: Label
var _reward_label: Label
var _pop_tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


## `result`は`RankProgress.ensure_current_season()`の戻り値をそのまま渡す。
func open(result: Dictionary) -> void:
	var peak_tier := str(result.get("peak_tier", RankRules.INITIAL_TIER))
	_tier_label.text = "前シーズンの最高到達: %s" % RankRules.display_name(peak_tier)
	var reward := int(result.get("reward", 0))
	_reward_label.text = "+%d %s" % [reward, CurrencyRules.CURRENCY_NAME] if reward > 0 else ""
	_reward_label.visible = reward > 0
	visible = true
	_play_pop_in()


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

	var note := Label.new()
	note.text = "今シーズンはブロンズ1から新しく始まります"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = PANEL_SIZE.x - 60.0
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(note)

	var close := CodedButton.make("閉じる", Vector2(180, 48))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: _on_close())
	box.add_child(close)


## 拡大しながら現れる(GameDesign.md 9章の手触り方針と同じ、既存の反応の語彙を使う)。
func _play_pop_in() -> void:
	_dim.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(_dim, "modulate:a", 1.0, POP_IN_DURATION * 0.6)
	_pop_tween.tween_property(_panel, "modulate:a", 1.0, POP_IN_DURATION * 0.6)
	(
		_pop_tween
		. tween_property(_panel, "scale", Vector2.ONE, POP_IN_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _on_close() -> void:
	visible = false
	closed.emit()
