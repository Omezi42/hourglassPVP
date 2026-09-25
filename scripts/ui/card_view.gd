class_name CardView
extends Control
## 砂時計1体の表示(GameDesign.md 9章「対局画面」)。
##
## **手札と場で見た目が違う**。手札はまだ手に持っている札なのでカードの枠を持つが、
## 場に出た瞬間に枠を捨て、台座の上に立つ砂時計そのものになる。砂時計はそれ自体が
## 状態を表示する器(上の砂=体力 / 下の砂=攻撃力)であり、枠へ閉じ込めると絵が小さくなって
## 砂の量という最も重要な情報チャネルが潰れるため。
##
## 数値の配置は既存のDCGの慣習に合わせる。手札=コスト左上 / 総量右下、
## 場=攻撃力左下 / 体力右下(場ではコストを出さない)。

signal pressed(view: CardView)
## マウスを乗せたとき。デッキ編集は、クリック(=編成へ加える)と切り離して
## 詳細の表示だけをホバーで切り替えるためにこれを使う。
signal hovered(view: CardView)
## ドラッグで掴んだとき。場の駒なら攻撃の対象選択に入る(GameDesign.md 9章)。
signal drag_started(view: CardView)
## ドラッグを放した/取り消した(GameDesign.md 9章「対局画面の手触り」)。
## `_notification(NOTIFICATION_DRAG_END)` から出す。
signal drag_ended(view: CardView)
## 攻撃の演出が対象へ当たった瞬間。ダメージの見せ方はここへ合わせる。
signal strike_impact
## 攻撃の演出が終わって台座へ戻りきった。
signal strike_finished

enum Mode {
	## 場に出ている砂時計。枠を持たず、台座の上に立つ物体として描く。
	BOARD,
	## 手札。カードの枠を持ち、コストと総量(=場に出たときの体力)を出す。
	HAND,
}

const BOARD_SIZE_PX := Vector2(128, 168)
const HAND_SIZE_PX := Vector2(118, 158)
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const ATTACK_ORANGE := Color(0.95, 0.62, 0.2, 1.0)
const HEALTH_RED := Color(0.9, 0.3, 0.26, 1.0)
## 選択中の枠。守護の真鍮色と取り違えないよう、別系統の色にする。
const SELECT_CYAN := Color(0.55, 0.9, 1.0, 1.0)
const SAND_AMBER := Color(0.93, 0.78, 0.42, 1.0)
## 文字を描くときに空ける左右の余白と、縮められる下限のフォントサイズ。
const TEXT_MARGIN := 5.0
const MIN_FONT_SIZE := 9

const STAT_RADIUS := 15.0
## 取り消しの戻る動き(GameDesign.md 9章「対局画面の手触り」)。フッと消すのではなく
## 短く縮んで消える。`selected` はすぐ false へ戻るため、この値だけで描く。
const UNSELECT_DURATION := 0.1
const UNSELECT_SHRINK := 0.78
const UNSELECT_INSET := 6.0
## バッジの跳ね(GameDesign.md 9章)。体力・攻撃力が変わった瞬間、その側のバッジだけ
## 小さく跳ねる。
const STAT_PUNCH_DURATION := 0.25
const STAT_PUNCH_SCALE := 0.3
## 身構え(GameDesign.md 9章「対局画面の手触り」)。狙える相手にカーソルを乗せたら
## わずかに縮み、輪郭(既存の選択の輪郭色)がゆっくり脈打つ。
const BRACE_SCALE := 0.96
const BRACE_SCALE_DURATION := 0.12
const BRACE_PULSE_SPEED := 3.4
const BRACE_PULSE_MIN := 0.35
const BRACE_PULSE_MAX := 0.85
## 攻撃の予測。体力のバッジの真下へ、結果だけを小さく出す。
const PREVIEW_RADIUS := 14.0
const PREVIEW_GAP := 15.0
const PREVIEW_ALIVE := Color(0.55, 0.85, 1.0)
const PREVIEW_DEAD := Color(1.0, 0.42, 0.36)
const GUARD_BORDER := 4.0
const NORMAL_BORDER := 2.0

## 場の砂時計。台座は「上面の楕円+側面の帯」を持つ高さのある真鍮の器として描く
## (GameDesign.md 9章「対局画面の再構築」)。
const PEDESTAL_CENTER_Y := 122.0
const PEDESTAL_RADIUS := Vector2(54.0, 13.0)
const PEDESTAL_HEIGHT := 9.0
const PEDESTAL_RING_WIDTH := 2.0
const PEDESTAL_GUARD_RING_WIDTH := 4.5
const BOARD_ART_SIDE := 112.0
## 出したターンの砂時計は僅かに沈んで見せる(GameDesign.md 9章)。
const SUMMONED_SINK := 3.0
## 紋章(GameDesign.md 9章)。砂時計の絵は全種で共通の1枚を色違いにしたものなので、
## **どのカードかを見分けているのはこの紋章**になる。台座の正面へ真鍮のメダルとして
## 据える。駒の背後へ大きな透かしを敷く案もあったが、128x168の枠では砂時計の絵が
## ほぼ全面を占めるため、はみ出した縁だけが見えて散らかった(実際に描いて確認した)。
const EMBLEM_PLAQUE_RADIUS := 16.0
const EMBLEM_PLAQUE_SIDE := 21.0
## 反転の演出(GameDesign.md 9章)。**反転はゲームの中心となる行動であるため、
## 演出は他より作り込む。**場のカードが枠を持たない物体になったことで、
## 砂時計そのものを持ち上げて裏返す動きが素直に描ける。
const FLIP_DURATION := 0.44
const FLIP_LIFT := 28.0
## 着地の衝撃波を出し始める進捗。
const FLIP_LAND_AT := 0.82
## **半回転をわずかに行き過ぎてから戻す**(GameDesign.md 9章)。ちょうど半分で止めると
## 機械が回したように見え、手でひっくり返した手応えが出ない。1.0 を超えると
## 持ち上げ量(`sin`)が負になるため、行き過ぎと同時に着地の沈み込みも出る。
const FLIP_OVERSHOOT := 1.07
const FLIP_SETTLE := 0.12

## 手札の絵を収める正方形の一辺。札の面の作りは `HandCardPaint` が持つ。
const HAND_ART_SIDE := 92.0
## 砂術の枠の色。砂時計と変え、手札を見た時点で「置くカードではない」と分かるようにする。
const SPELL_BORDER := Color(0.58, 0.72, 0.95, 1.0)

## 攻撃の演出(GameDesign.md 9章)。「寄る → 溜める → 当てる → 戻る」の4段。
const STRIKE_APPROACH := 0.28
const STRIKE_WIND_UP := 0.14
const STRIKE_HIT := 0.1
const STRIKE_RETURN := 0.3
## 同じターンの2回目以降は尺を詰める。連撃や6枠が並ぶ中盤で1ターンが冗長になるため。
const STRIKE_QUICK_SCALE := 0.6
## 対象から見て斜め上のどこへ立つか。真上だと振り下ろす余地が無く、真横だと横殴りに見える。
const STRIKE_STANDOFF := Vector2(64.0, 40.0)
## 当てたところ。めり込ませず、触れる位置で止める。
const STRIKE_CONTACT := Vector2(26.0, 12.0)
const STRIKE_WIND_ANGLE := 0.42
const STRIKE_HIT_ANGLE := 0.3
## 寄っている間、慣性で下端が遅れて振れる量。
const STRIKE_LAG_ANGLE := 0.16
## つまむ位置。絵の上端から少し下げる。
## 貫通で対象を通り抜けて相手プレイヤーまで届く区間。
const STRIKE_PIERCE := 0.2
const STRIKE_PIVOT_Y := 8.0
## 演出中は他の枠より手前へ出す。台座や隣の駒に潜ると渡っていく様子が見えない。
const STRIKE_Z_INDEX := 20
## 相打ちの反撃(GameDesign.md 9章)。`play_shatter()` だけでは防御側が一方的に受けて
## いるようにしか見えないため、台座正面の紋章を攻撃側へ向けて短く突き出し、すぐ戻す。
## 全身が渡っていく攻撃側の演出とは別枠の、紋章だけの軽い一撃として作る。
## ドローを起こした合図の光の輪(GameDesign.md 9章)。反撃より少し長く残す
## (突き出す動きが無いぶん、輪だけで「起きたこと」を伝える必要があるため)。
const SPARK_RADIUS := 24.0
## 手札のカードは小さく効果の文が読めないため、カーソルを乗せている間だけ拡大する
## (GameDesign.md 9章)。位置ではなく scale だけを動かし、下端中央を軸に上へ伸ばす。
## 画面側は毎フレーム position を置き直すため、位置を動かすと取り合いになる。
const HAND_HOVER_SCALE := 1.14
const HAND_HOVER_DURATION := 0.12

var mode: int = Mode.BOARD
## 表示するカード。手札はこれだけ、盤面は unit も併せて持つ。
var card: CardData
var unit: CardInstance
## 出せる/選べる状態か。false なら暗く表示する。
var enabled := true
## 選択中(枠・台座の輪を強調する)。
var selected := false
## このターンに行動を終えている(彩度を落とす)。
var exhausted := false
## まだ攻撃できる自分の駒(GameDesign.md 9章)。攻撃済みを彩度で落とすだけでは
## その逆が示せず、6枠が並ぶと押し忘れるため、控えめな印を出す。
var ready_mark := false
## 右上へ出す小さな添え字(デッキ編集の「2/2」など)。空なら出さない。
var badge := ""
## 手札でホバーしたときに拡大するか。対局画面の手札だけが true。
var hover_zoom := false
## ドラッグで掴めるか(GameDesign.md 9章)。手札は空き枠へ出す、場の駒は相手を攻撃する。
var draggable := false
## ドラッグを受ける枠なら、放されたときに呼ぶ処理を持つ。空なら受けない。
var drop_handler := Callable()
## 攻撃の対象を選んでいる間だけ出す予測(GameDesign.md 9章)。
## 負のときは出さない。`preview_dead` なら破壊されることを示す。
var preview_health := -1
var preview_dead := false
## 攻撃の演出の状態(GameDesign.md 9章)。**段取りは CardViewStrike が書き換える**ため
## 公開している。絵だけをこのぶんずらし、上端を支点にこの角度だけ回す。
var striking := false
var strike_offset := Vector2.ZERO
var strike_angle := 0.0
var strike_flash := 0.0
var strike_tween: Tween
## 相打ちの反撃(GameDesign.md 9章)。紋章の描画位置へこのぶんだけ足す。
var counter_offset := Vector2.ZERO
## 効果を持つ駒が発火した合図(GameDesign.md 9章)。ドローを起こす設置効果・
## トリガーが盤面上の駒から起きたとき、紋章の周りへ短い光の輪を出す。
var spark_amount := 0.0
## 取り消しの戻る動き(GameDesign.md 9章「対局画面の手触り」)。`play_unselect()` が
## 1.0にして0へ戻す。0の間は何も描かない。
var unselect_amount := 0.0
## バッジの跳ね(GameDesign.md 9章)。体力・攻撃力のどちらが変わったかで別々に持つ
## (変わった側のバッジだけ跳ねるため)。
var health_punch := 0.0
var attack_punch := 0.0
## 身構え(GameDesign.md 9章「対局画面の手触り」)。`CardMatchTargets` が、狙える
## (=`selected`)相手へカーソルが乗ったときだけ true にする。対象選択が終わったら
## (`refresh()` で光りが消えるとき)必ず false へ戻す。
var brace: bool = false:
	set(value):
		if brace == value:
			return
		brace = value
		_animate_brace(value)
		set_process(value)
		if not value:
			_brace_pulse = 0.0
			queue_redraw()

var _font: Font
var _hovering := false
var _tracker := PressTracker.new()
var _sand: CardViewSandFx
## 反転の進捗(0.0〜1.0)。負のときは反転していない。
var _art_reference_cache := 0.0
var _art_reference_card: CardData
var _flip_progress := -1.0
var _flip_tween: Tween
var _zoom_tween: Tween
## 設置の着地・破壊の崩落・硝子の割れる閃光。駒の上へ重ねて描く子ノード。
var _fx: CardUnitFx
var _strike: CardViewStrike
var _flourish: CardViewFlourish
var _unselect_tween: Tween
## バッジの跳ねの判定用。前回 `show_unit()` に渡された体力・攻撃力(GameDesign.md 9章)。
var _prev_health := -1
var _prev_attack := -1
var _health_punch_tween: Tween
var _attack_punch_tween: Tween
## 身構えの脈打ち(GameDesign.md 9章)。`brace` の間だけ `_process` で進める。
var _brace_pulse := 0.0
var _brace_tween: Tween


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var theme_font := get_theme_default_font()
	if theme_font != null:
		_font = theme_font
	custom_minimum_size = HAND_SIZE_PX if mode == Mode.HAND else BOARD_SIZE_PX
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sand = CardViewSandFx.new(self)
	_fx = CardUnitFx.new()
	_fx.size = size
	add_child(_fx)
	# 身構えの脈打ちだけが継続的な再描画を要る(GameDesign.md 9章「対局画面の手触り」)。
	# `brace` が立つまでは `_process` を止めておく。
	set_process(false)


## 場の砂時計として表示する。**同じ駒が居続けているあいだ**、体力・攻撃力が前回から
## 変わっていればバッジを跳ねさせる(GameDesign.md 9章)。駒が入れ替わった(出た/
## 破壊された)ときは前回値が無関係になるため跳ねない。
func show_unit(p_unit: CardInstance) -> void:
	mode = Mode.BOARD
	if p_unit != null and unit == p_unit:
		if p_unit.health != _prev_health:
			_punch_health()
		if p_unit.attack != _prev_attack:
			_punch_attack()
	unit = p_unit
	card = null if p_unit == null else p_unit.data
	_prev_health = -1 if p_unit == null else p_unit.health
	_prev_attack = -1 if p_unit == null else p_unit.attack
	custom_minimum_size = BOARD_SIZE_PX
	queue_redraw()


func _punch_health() -> void:
	health_punch = 1.0
	if _health_punch_tween != null and _health_punch_tween.is_valid():
		_health_punch_tween.kill()
	_health_punch_tween = create_tween()
	_health_punch_tween.set_ease(Tween.EASE_OUT)
	_health_punch_tween.tween_method(_set_health_punch, 1.0, 0.0, STAT_PUNCH_DURATION)


func _punch_attack() -> void:
	attack_punch = 1.0
	if _attack_punch_tween != null and _attack_punch_tween.is_valid():
		_attack_punch_tween.kill()
	_attack_punch_tween = create_tween()
	_attack_punch_tween.set_ease(Tween.EASE_OUT)
	_attack_punch_tween.tween_method(_set_attack_punch, 1.0, 0.0, STAT_PUNCH_DURATION)


func _set_health_punch(value: float) -> void:
	health_punch = value
	queue_redraw()


func _set_attack_punch(value: float) -> void:
	attack_punch = value
	queue_redraw()


## 身構えのわずかな縮み(GameDesign.md 9章)。ノード全体の `scale` を使う
## (手札のホバー拡大 `_zoom()` と同じ語彙)。中心から縮むよう軸を合わせる。
func _animate_brace(active: bool) -> void:
	pivot_offset = size * 0.5
	if _brace_tween != null and _brace_tween.is_valid():
		_brace_tween.kill()
	_brace_tween = create_tween()
	var target := Vector2.ONE * (BRACE_SCALE if active else 1.0)
	_brace_tween.tween_property(self, "scale", target, BRACE_SCALE_DURATION)


## 脈打つ輪郭のための継続的な再描画。`brace` の間だけ動く(`set_process()` で制御)。
func _process(delta: float) -> void:
	if not brace:
		return
	_brace_pulse += delta * BRACE_PULSE_SPEED
	queue_redraw()


## 取り消しの戻る動き(GameDesign.md 9章)。光っていた枠を短く縮めて消す。
func play_unselect() -> void:
	if _unselect_tween != null and _unselect_tween.is_valid():
		_unselect_tween.kill()
	unselect_amount = 1.0
	_unselect_tween = create_tween()
	_unselect_tween.set_ease(Tween.EASE_OUT)
	_unselect_tween.tween_method(_set_unselect_amount, 1.0, 0.0, UNSELECT_DURATION)


func _set_unselect_amount(value: float) -> void:
	unselect_amount = value
	queue_redraw()


## 手札のカードとして表示する。
func show_card(p_card: CardData, p_enabled: bool) -> void:
	mode = Mode.HAND
	unit = null
	card = p_card
	enabled = p_enabled
	custom_minimum_size = HAND_SIZE_PX
	queue_redraw()


## ダメージを受けた:砂が砕けて散る(消える砂と落ちる砂の描き分けは `CardViewSandFx`)。
func play_shatter(amount: int) -> void:
	_sand.play_shatter(amount)


## 相打ちの反撃:紋章が攻撃側へ向けて短く突き出し、すぐ戻る(GameDesign.md 9章)。
## `dir_x` は突き出す向き(正で右、負で左)。**段取りは `CardViewFlourish` が持つ**
## (1ファイル1000行の上限に達したため、`CardViewStrike` と同じ形で切り出した)。
func play_counter(dir_x: float) -> void:
	_ensure_flourish()
	_flourish.play_counter(dir_x)


## 効果を持つ駒が発火した:紋章の周りへ短い光の輪を出す(GameDesign.md 9章)。
## エコー・クラック・ページ・メモリーのようにドローを起こす設置効果・トリガーが、
## その駒自身から働いたことを示す軽い合図。盤面を動かさないため、揺れも移動も伴わない。
func play_spark() -> void:
	_ensure_flourish()
	_flourish.play_spark()


func _ensure_flourish() -> void:
	if _flourish == null:
		_flourish = CardViewFlourish.new(self)


func play_flip() -> void:
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_progress = 0.0
	_flip_tween = create_tween()
	_flip_tween.tween_method(_set_flip_progress, 0.0, FLIP_OVERSHOOT, FLIP_DURATION)
	(
		_flip_tween
		. tween_method(_set_flip_progress, FLIP_OVERSHOOT, 1.0, FLIP_SETTLE)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_flip_tween.finished.connect(_on_flip_finished)


func _set_flip_progress(value: float) -> void:
	_flip_progress = value
	queue_redraw()


func _on_flip_finished() -> void:
	_flip_progress = -1.0
	queue_redraw()


## 場に出した:台座の少し上から落ちて着地する(GameDesign.md 9章)。
func play_land() -> void:
	_fx.size = size
	_fx.play_land()


## 破壊された:砕けて台座へ崩れ落ちる。**枠が空になった後も演出だけが残る**ため、
## 絵はこの時点で渡しておく(`card` は次の同期で null になる)。
func play_break(broken: CardData) -> void:
	_fx.size = size
	var texture: Texture2D = broken.icon_fallen if broken != null else null
	if texture == null:
		return
	_fx.play_break(texture, _fit_art(texture, board_art_box()))


## 毒砂で破壊された:割れずに溶け落ちる(GameDesign.md 9章)。
func play_melt(melted: CardData) -> void:
	_fx.size = size
	var texture: Texture2D = melted.icon_fallen if melted != null else null
	if texture == null:
		return
	_fx.play_melt(texture, _fit_art(texture, board_art_box()))


## 硝子が最初のダメージを吸った:膜が割れる閃光を出す。
func play_glass_break() -> void:
	if card == null:
		return
	var texture := _icon()
	if texture == null:
		return
	_fx.size = size
	_fx.play_glass_break(_fit_art(texture, board_art_box()))


## ターン終了の1粒:砂が下の部屋へ流れる。
func play_drop() -> void:
	_sand.play_drop()


## 効果で砂が上へ戻る:`play_drop()` の逆向き(GameDesign.md 6章)。
func play_raise() -> void:
	_sand.play_raise()


func clear() -> void:
	card = null
	unit = null
	_prev_health = -1
	_prev_attack = -1
	queue_redraw()


func is_empty() -> bool:
	return card == null


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or card == null or not enabled:
		return null
	set_drag_preview(_make_drag_preview())
	drag_started.emit(self)
	return {"card_view": self}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not drop_handler.is_valid() or not data is Dictionary:
		return false
	return (data as Dictionary).get("card_view") is CardView


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_handler.call((data as Dictionary)["card_view"])


## ドラッグが終わった(枠に落とした/取り消した、いずれも)。攻撃ドラッグの矢印
## (`CardDragArrow`)を消す合図として使う(GameDesign.md 9章「対局画面の手触り」)。
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_ended.emit(self)


## 掴んでいる間はカードの絵だけを運ぶ。**札に描かれているのと同じ大きさ・同じ縦横比**に
## する。カードの枠に合わせると絵が札の中より大きく出て、掴んだ瞬間に絵が膨らんで見える。
## 動かす方向と逆へ遅れて傾く物理は `CardDragPreview` が持つ(GameDesign.md 9章)。
func _make_drag_preview() -> Control:
	var texture := _icon() if mode == Mode.BOARD else card.icon_upright
	var art := _fit_art(texture, _hand_art_box() if mode == Mode.HAND else board_art_box()).size
	var preview := CardDragPreview.new()
	preview.setup(texture, art)
	return preview


func _on_mouse_entered() -> void:
	_hovering = true
	if enabled:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# ホバー音(GameDesign.md 9章)。**空き枠では鳴らさない**。押しても何も
		# 起きない場所で音だけ返ると、押せるように聞こえる。
		if card != null:
			SoundBank.play(SoundBank.Sfx.HOVER)
	_zoom(true)
	hovered.emit(self)
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovering = false
	_zoom(false)
	queue_redraw()


## 拡大中は隣の札より手前へ出す。手札は絶対座標で並べているため、
## そのままだと後から足した右隣の札に上端を隠される。
func _zoom(active: bool) -> void:
	if not hover_zoom or mode != Mode.HAND:
		return
	pivot_offset = Vector2(size.x * 0.5, size.y)
	z_index = 1 if active else 0
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	var target := Vector2.ONE * (HAND_HOVER_SCALE if active else 1.0)
	_zoom_tween.tween_property(self, "scale", target, HAND_HOVER_DURATION)


func _gui_input(event: InputEvent) -> void:
	# **場の空き枠も押せなければならない。**カードを出す先はまさに空き枠であり、
	# ここで弾くと対局開始時(場が全て空)に1枚も出せなくなる。手札の空きスロットは
	# 呼び出し側が visible = false にしているため、そもそも入力が届かない。
	if card == null and mode == Mode.HAND:
		return
	var result := _tracker.feed(event, size)
	if result == PressTracker.Result.CONFIRMED:
		pressed.emit(self)


func _draw() -> void:
	if mode == Mode.BOARD:
		_draw_board_unit()
	elif card == null:
		_draw_empty()
	else:
		HandCardPaint.draw(self)
	_sand.draw()


func _tint() -> Color:
	if not enabled or exhausted:
		return Color(0.55, 0.55, 0.6, 1)
	return Color(1, 1, 1, 1)


# --- 場の砂時計(枠なし) -----------------------------------------------


func _draw_board_unit() -> void:
	CardViewPaint.pedestal_base(self)
	if card == null:
		CardViewPaint.pedestal_ring(self)
		return
	var tint := _tint()
	var sink := SUMMONED_SINK if unit != null and unit.summoned_this_turn else 0.0
	# 攻撃の演出で動かすのは絵だけ。台座は盤面の設備であって駒の一部ではないため、
	# 一緒に動くと枠ごと飛んでいくように見える。
	if striking:
		draw_set_transform_matrix(_strike_transform())
	_draw_board_art(tint, sink)
	if striking:
		_drawstrike_flash()
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# 輪は絵の後に描く。守護(太い真鍮の輪)と選択中(水色の輪)は駒が立っていても
	# 必ず見えなければならないため、絵の下へ隠してはいけない。
	CardViewPaint.pedestal_ring(self)
	CardViewPaint.pedestal_plaque(self, tint)
	if ready_mark and not selected:
		CardViewPaint.pedestal_glow(self, Color(UiPalette.GLOW_AMBER, 0.18))
	if _hovering and enabled:
		CardViewPaint.pedestal_glow(self, Color(1, 1, 1, 0.1))
	_draw_board_stats()
	_draw_board_labels(tint)


func _draw_board_art(tint: Color, sink: float) -> void:
	var texture := _icon()
	if texture == null:
		return
	var lift := _fx.land_offset()
	var box := board_art_box().grow_individual(0, sink, 0, sink)
	var rect := _fit_art(texture, box)
	rect.position.y += lift
	if _flip_progress >= 0.0:
		_draw_flipping_art(texture, rect, tint)
	else:
		draw_texture_rect(texture, rect, false, tint)
	# 硝子は枠ではなくガラスそのものへ膜を掛ける(GameDesign.md 9章)。
	if unit != null and unit.glass_intact:
		UiPaint.fill_ellipse(
			get_canvas_item(), rect.get_center(), rect.size * 0.42, Color(0.6, 0.85, 1.0, 0.16), 28
		)


## 反転中の絵。持ち上げながら縦に潰していき、真横を向いた瞬間(進捗0.5)に
## 厚みだけの線になり、そこから裏返って戻る。同時にガラスと砂の反射を重ねる。
func _draw_flipping_art(texture: Texture2D, rect: Rect2, tint: Color) -> void:
	var turn := absf(cos(PI * _flip_progress))
	var lift := sin(PI * _flip_progress) * FLIP_LIFT
	var center := rect.get_center() - Vector2(0.0, lift)
	var half := Vector2(rect.size.x * 0.5, rect.size.y * 0.5 * maxf(turn, 0.02))
	draw_texture_rect(texture, Rect2(center - half, half * 2.0), false, tint)
	var sheen := sin(PI * _flip_progress)
	UiPaint.fill_ellipse(
		get_canvas_item(), center, half * 0.9, Color(1.0, 0.94, 0.78, 0.3 * sheen), 28
	)
	if _flip_progress >= FLIP_LAND_AT:
		_draw_flip_landing()


## 着地の衝撃波。台座と同じ扁平な楕円を外へ広げる。
func _draw_flip_landing() -> void:
	# 行き過ぎ(1.0超)のぶんで衝撃波が広がり続けないよう、進捗は1.0で頭打ちにする。
	var ratio := clampf((_flip_progress - FLIP_LAND_AT) / (1.0 - FLIP_LAND_AT), 0.0, 1.0)
	var radius := PEDESTAL_RADIUS * (1.0 + 0.5 * ratio)
	UiPaint.draw_ellipse_ring(
		get_canvas_item(),
		Vector2(size.x * 0.5, PEDESTAL_CENTER_Y),
		radius,
		Color(UiPalette.PEDESTAL_DEFAULT_ACCENT, 0.7 * (1.0 - ratio)),
		3.0,
		40
	)


## 攻撃力=左下 / 体力=右下。台座の高さに合わせて左右へ振り分ける。**値が変わった側だけ
## バッジを跳ねさせる**(GameDesign.md 9章「対局画面の手触り」)。
func _draw_board_stats() -> void:
	if unit == null:
		return
	var y := PEDESTAL_CENTER_Y + 6.0
	var attack_radius := STAT_RADIUS * (1.0 + attack_punch * STAT_PUNCH_SCALE)
	var health_radius := STAT_RADIUS * (1.0 + health_punch * STAT_PUNCH_SCALE)
	CardViewPaint.stat(
		self, Vector2(STAT_RADIUS + 2.0, y), unit.attack, ATTACK_ORANGE, attack_radius
	)
	CardViewPaint.stat(
		self, Vector2(size.x - STAT_RADIUS - 2.0, y), unit.health, HEALTH_RED, health_radius
	)
	CardViewPaint.preview(self, Vector2(size.x - STAT_RADIUS - 2.0, y))


func _draw_board_labels(tint: Color) -> void:
	_centered_text(card.display_name, 14, size.y - 18.0, UiPalette.TEXT_OFFWHITE * tint)
	var note := _keyword_text()
	if not note.is_empty():
		_centered_text(note, 12, size.y - 3.0, UiPalette.BRASS_HIGHLIGHT * tint)


# --- 手札のカード -------------------------------------------------------


## 手札の見た目は `HAND_SIZE_PX`(118x158)を基準に組んである。**キーワード辞書のように
## 小さく置く場所があるため、各部の寸法はそこからの比で決める**。固定値のままだと、
## 名前とキーワードの行が札の外へ出たり、総量のバッジの上へ乗ったりする
## (枠・輪郭の太さを大きさに合わせる `CodedButtonStyle` と同じ考え方)。
func _hand_scale() -> float:
	return minf(size.x / HAND_SIZE_PX.x, size.y / HAND_SIZE_PX.y)


## 手札の絵を収める枠。
func _hand_art_box() -> Rect2:
	var scale := _hand_scale()
	var side := HAND_ART_SIDE * scale
	return Rect2(Vector2((size.x - side) * 0.5, 9.0 * scale), Vector2(side, side))


# --- 共通 ---------------------------------------------------------------


## 名前の下の1行。**語として見せるキーワードだけを語で出し**、それ以外は短い言い換えで
## 書く(GameDesign.md 6章)。1行しか無いので、全文は詳細パネルに任せる。
func _keyword_text() -> String:
	var words: PackedStringArray = []
	if card != null and card.cannot_attack:
		words.append("攻撃不可")
	if card != null and card.cannot_flip:
		words.append("反転不可")
	# 場に出ている駒は**その駒がいま持っている**キーワードを出す。CardData を直接見ると、
	# 効果で与えられたキーワードと、消された状態が面に出ない。
	for keyword in _live_keywords():
		if CardEnums.is_named(keyword):
			words.append(CardEnums.keyword_name(keyword))
		else:
			words.append(CardEnums.keyword_short_text(keyword))
	if unit != null and unit.silenced:
		return "効果なし" if words.is_empty() else " ".join(words)
	if words.is_empty() and not card.rules_text.is_empty():
		return card.category_name()
	return " ".join(words)


## 守護のように**形でも示すキーワード**(GameDesign.md 9章)の問い合わせ。
## 場の駒は付与・消去を反映する。
func _has_live_keyword(keyword: int) -> bool:
	if unit != null:
		return unit.has_keyword(keyword)
	return card != null and card.has_keyword(keyword)


## いま持っているキーワード。手札のカードは定義そのまま、場の駒は付与・消去を反映する。
func _live_keywords() -> Array:
	if unit != null:
		return unit.keywords()
	var found: Array = []
	for keyword in card.named_keywords():
		found.append(keyword)
	for keyword in card.plain_keywords():
		found.append(keyword)
	return found


## 砂時計の絵を、**元の縦横比のまま**枠へ収める(枠は正方形だが絵は縦長)。
## 正方形へ引き伸ばすと砂時計が横に潰れる。倍率は3状態で共通の基準(いちばん背の高い
## 状態のキャンバス)から求めるため、状態が切り替わっても絵の大きさが跳ねない。
## 台座に立って見えるよう、枠の下端で揃えて横は中央へ置く。
func _fit_art(texture: Texture2D, box: Rect2) -> Rect2:
	var reference := _art_reference()
	if reference <= 0.0 or texture == null:
		return box
	var art := texture.get_size() * (box.size.y / reference)
	var at := box.position + Vector2((box.size.x - art.x) * 0.5, box.size.y - art.y)
	return Rect2(at, art)


## 3状態のうちいちばん高いキャンバスの高さ。カードが変わるまで変わらないため覚えておく。
func _art_reference() -> float:
	if card == null:
		return 0.0
	if _art_reference_card == card:
		return _art_reference_cache
	_art_reference_card = card
	_art_reference_cache = 0.0
	for texture in [card.icon_upright, card.icon_falling, card.icon_fallen]:
		if texture != null:
			_art_reference_cache = maxf(_art_reference_cache, texture.get_size().y)
	return _art_reference_cache


## 体力と攻撃力の比で3枚を切り替える(GameDesign.md 9章)。手札は常に上向き。
func _icon() -> Texture2D:
	if unit == null:
		return card.icon_upright
	if unit.attack > unit.health:
		return card.icon_fallen
	if unit.attack >= unit.health - 1:
		return card.icon_falling
	return card.icon_upright


## 場の絵を収める枠。下端が台座の高さに来る正方形。
func board_art_box() -> Rect2:
	return Rect2(
		Vector2((size.x - BOARD_ART_SIDE) * 0.5, PEDESTAL_CENTER_Y + 4.0 - BOARD_ART_SIDE),
		Vector2(BOARD_ART_SIDE, BOARD_ART_SIDE)
	)


func _draw_empty() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color := SELECT_CYAN if selected else Color(0.3, 0.28, 0.3, 0.5)
	_dashed_rect(rect, color)


## カードの幅に収まらない文字列は、収まるまでフォントを縮めて描く。
## 語にしないキーワードは短い言い換えとはいえ語より長く、カードの幅は118pxしかないため。
func _centered_text(
	text: String, font_size: int, baseline: float, color: Color, limit_override := -1.0
) -> void:
	var limit := limit_override if limit_override > 0.0 else size.x - TEXT_MARGIN * 2.0
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width > limit and font_size > MIN_FONT_SIZE:
		font_size -= 1
		width = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		_font,
		Vector2((size.x - width) * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var x := rect.position.x
	while x < rect.end.x:
		var to := minf(x + 5, rect.end.x)
		draw_line(Vector2(x, rect.position.y), Vector2(to, rect.position.y), color, 2.0)
		draw_line(Vector2(x, rect.end.y), Vector2(to, rect.end.y), color, 2.0)
		x += 10.0
	var y := rect.position.y
	while y < rect.end.y:
		var to := minf(y + 5, rect.end.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, to), color, 2.0)
		draw_line(Vector2(rect.end.x, y), Vector2(rect.end.x, to), color, 2.0)
		y += 10.0


## 攻撃の演出。**段取りは CardViewStrike が持つ**(1ファイル1000行の上限に達したため、
## 「駒の見た目」と「殴りに行く段取り」で分けた)。状態はここに残し、描画も引き続き行う。
func play_strike(target_center: Vector2, quick := false, follow_center := Vector2.INF) -> void:
	if _strike == null:
		_strike = CardViewStrike.new(self)
	_strike.play(target_center, quick, follow_center)


## 当たった瞬間の閃光。絵の下端(当たった側)へ出す。
func _drawstrike_flash() -> void:
	if strike_flash <= 0.01:
		return
	var box := board_art_box()
	var at := Vector2(box.get_center().x, box.end.y - 8.0)
	var radius := 10.0 + 14.0 * (1.0 - strike_flash)
	UiPaint.fill_circle(
		get_canvas_item(), at, radius, Color(1.0, 0.94, 0.72, 0.55 * strike_flash), 20
	)


## 絵に掛ける変換。上端を支点に回し、そのぶんずらす。
func _strike_transform() -> Transform2D:
	var pivot := Vector2(size.x * 0.5, board_art_box().position.y + STRIKE_PIVOT_Y)
	var placed := Transform2D(strike_angle, Vector2.ONE, 0.0, pivot + strike_offset)
	return placed * Transform2D(0.0, Vector2.ONE, 0.0, -pivot)
