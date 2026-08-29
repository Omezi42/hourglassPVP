extends Control
## サムネ用GIFの素材フレームを書き出す。
## タイトル画面 → 砂のトランジション → 対局(設置・攻撃・反転・本体攻撃)を
## 固定の台本で再生する。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を必ず付ける):
##   godot --path . --write-movie scratchpad/gif/f.png
##     --fixed-fps 20 res://tools/record_thumbnail_gif.tscn
##
## GIFへの変換(ImageMagick):
##   magick -delay 5 -loop 0 scratchpad/gif/f0*.png -resize 640x360
##     -ordered-dither o8x8,32,32,32 -layers Optimize thumb640.gif

const DECK_IDS := [
	"grain", "sand", "dash", "shield", "drill", "glass", "sword", "lance", "poison", "wall"
]

var title_screen: TitleScreen
var match_screen: CardMatchScreen
var sand: SandTransition


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	title_screen = load("res://scenes/title_screen.tscn").instantiate()
	add_child(title_screen)
	match_screen = CardMatchScreen.new()
	match_screen.anchor_right = 1.0
	match_screen.anchor_bottom = 1.0
	match_screen.visible = false
	add_child(match_screen)
	sand = SandTransition.new()
	add_child(sand)
	call_deferred("_run")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _card(id: String) -> CardData:
	return CardLibrary.find_by_id(id)


func _deck() -> Array:
	var cards: Array = []
	for id in DECK_IDS:
		cards.append(_card(id))
		cards.append(_card(id))
	return cards


func _unit(side: int, slot: int, id: String, health: int, attack: int) -> void:
	var inst := CardInstance.new(_card(id))
	inst.health = health
	inst.attack = attack
	inst.summoned_this_turn = false
	inst.attacks_this_turn = 0
	inst.flipped_this_turn = false
	match_screen.state.board[side][slot] = inst


func _run() -> void:
	# 1. タイトル
	await _wait(1.5)
	await title_screen.play_launch()
	await sand.cover()

	# 2. 盤面へ差し替える
	title_screen.visible = false
	match_screen.visible = true
	match_screen.start_cpu_match(_deck(), _deck())
	match_screen._on_mulligan_confirmed([])
	await _wait(0.05)
	_setup_board()
	match_screen.refresh()
	await sand.reveal()
	await _wait(0.45)

	# 3. 手札から場へ出す
	match_screen._perform(MatchAction.play(MatchState.Side.A, 0, 3))
	await _wait(0.75)

	# 4. 相手の駒を殴る(相打ち)
	match_screen._perform(MatchAction.attack(MatchState.Side.A, 1, 1))
	await _wait(1.15)

	# 5. 反転
	match_screen._perform(MatchAction.flip(MatchState.Side.A, 0))
	await _wait(1.25)

	# 6. 本体を殴る
	match_screen._perform(MatchAction.attack(MatchState.Side.A, 0, -1))
	await _wait(1.35)

	get_tree().quit()


func _setup_board() -> void:
	var state := match_screen.state
	var a := MatchState.Side.A
	var b := MatchState.Side.B
	state.hp[a] = 23
	state.hp[b] = 16
	state.mana[a] = 5
	state.max_mana[a] = 7
	state.mana[b] = 2
	state.max_mana[b] = 7
	_unit(a, 0, "wall", 3, 6)
	_unit(a, 1, "lance", 3, 3)
	_unit(a, 2, "shield", 3, 1)
	_unit(b, 0, "poison", 5, 1)
	_unit(b, 1, "glass", 2, 4)
	_unit(b, 4, "drill", 6, 1)
	# 手札は見栄えのする5枚に揃える。
	var hand: Array = []
	for id in ["sword", "dash", "grain", "wall", "poison"]:
		hand.append(_card(id))
	state.hand[a] = hand
