class_name CpuMatchSettings
extends RefCounted
## CPU戦の設定(GameDesign.md 13章「CPU戦の設定」/ Architecture.md 8.2節)。
## 思考レベルは `CardCpuDifficultySave` が持ち、それ以外をここが持つ。
## 値は前回のものを覚えておく(Autoloadを使わずstaticで持つ流儀。CardDeckSave と同じ)。

enum First { PLAYER, CPU, RANDOM }
enum Speed { SLOW, NORMAL, FAST }

const SAVE_PATH := "user://cpu_match_settings.json"
## 相手のデッキのキー。空文字がランダム、`OWN_PREFIX + 位置` が自分の保存デッキ、それ以外はCPUデッキのid。
const FOE_RANDOM := ""
const OWN_PREFIX := "own:"
const HP_CHOICES: Array[int] = [12, 24, 36]
const SPEED_SCALES := {Speed.SLOW: 1.5, Speed.NORMAL: 1.0, Speed.FAST: 0.5}
const OWN_FOE_NAME := "CPU ・ あなたの『%s』"

var first := First.PLAYER
var foe_deck := FOE_RANDOM
var speed := Speed.NORMAL
var own_hp := MatchState.INITIAL_HP
var foe_hp := MatchState.INITIAL_HP
var mulligan := true
var coin := true
var reveal_hand := false


## 練習ルールを1つでも既定から変えたか。変えた対局は報酬・戦績の対象外(13章)。
func is_practice() -> bool:
	return (
		own_hp != MatchState.INITIAL_HP
		or foe_hp != MatchState.INITIAL_HP
		or not mulligan
		or not coin
		or reveal_hand
	)


## プレイヤーは常に A 側。後手を選んだら B が先手になる。
func first_side(rng: RandomNumberGenerator) -> int:
	match first:
		First.CPU:
			return MatchState.Side.B
		First.RANDOM:
			return MatchState.Side.A if rng.randi_range(0, 1) == 0 else MatchState.Side.B
	return MatchState.Side.A


func speed_scale() -> float:
	return float(SPEED_SCALES[speed])


## `{"name", "cards"}` で返す(`CardCpuDecks.pick()` と同じ形)。名前は対局中に出す相手の名前。
func pick_foe_deck(rng: RandomNumberGenerator) -> Dictionary:
	var own_index := own_deck_index()
	if own_index >= 0:
		var deck: Dictionary = CardDeckSave.list_decks()[own_index]
		return {"name": OWN_FOE_NAME % deck["name"], "cards": deck["cards"]}
	if CardCpuDecks.deck_ids().has(foe_deck):
		return {"name": CardCpuDecks.foe_name_of(foe_deck), "cards": CardCpuDecks.deck_of(foe_deck)}
	var picked := CardCpuDecks.pick(rng)
	return {"name": CardCpuDecks.foe_name(picked), "cards": picked["cards"]}


## 自分の保存デッキを指しているならその位置。消えて範囲外になったものは -1(ランダムへ落とす)。
func own_deck_index() -> int:
	if not foe_deck.begins_with(OWN_PREFIX):
		return -1
	var index := int(foe_deck.trim_prefix(OWN_PREFIX))
	return index if index >= 0 and index < CardDeckSave.list_decks().size() else -1


## 相手のデッキの選択肢のキーを、モーダルで回す順に返す。
static func foe_deck_keys() -> Array[String]:
	var keys: Array[String] = [FOE_RANDOM]
	keys.append_array(CardCpuDecks.deck_ids())
	for i in CardDeckSave.list_decks().size():
		keys.append(OWN_PREFIX + str(i))
	return keys


static func load_saved() -> CpuMatchSettings:
	var settings := CpuMatchSettings.new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return settings
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return settings
	var data: Dictionary = parsed
	settings.first = clampi(int(data.get("first", First.PLAYER)), 0, First.RANDOM) as First
	settings.foe_deck = str(data.get("foe_deck", FOE_RANDOM))
	settings.speed = clampi(int(data.get("speed", Speed.NORMAL)), 0, Speed.FAST) as Speed
	settings.own_hp = _valid_hp(data.get("own_hp", MatchState.INITIAL_HP))
	settings.foe_hp = _valid_hp(data.get("foe_hp", MatchState.INITIAL_HP))
	settings.mulligan = bool(data.get("mulligan", true))
	settings.coin = bool(data.get("coin", true))
	settings.reveal_hand = bool(data.get("reveal_hand", false))
	return settings


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"first": int(first),
		"foe_deck": foe_deck,
		"speed": int(speed),
		"own_hp": own_hp,
		"foe_hp": foe_hp,
		"mulligan": mulligan,
		"coin": coin,
		"reveal_hand": reveal_hand,
	}
	file.store_string(JSON.stringify(data))
	file.close()


static func _valid_hp(raw: Variant) -> int:
	var value := int(raw)
	return value if HP_CHOICES.has(value) else MatchState.INITIAL_HP
