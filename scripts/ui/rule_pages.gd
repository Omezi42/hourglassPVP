class_name RulePages
extends RefCounted
## ルール画面(GameDesign.md 16章)の紙芝居の中身。
##
## 章・見出し・本文・盤面の種類をこの1箇所へ持ち、ページを増やすときはここへ1件足すだけで
## 済む形を保つ。盤面の描き方そのものは `RuleStage` が持ち、ここは「何を見せるか」だけを持つ。

## 盤面の種類。`RuleStage` の分岐と1対1で対応する。
const STAGE_SINGLE := "single"
const STAGE_DROP := "drop"
const STAGE_FLIP := "flip"
const STAGE_PLAY := "play"
const STAGE_COMBAT := "combat"
const STAGE_SAND_DIFF := "sand_diff"
const STAGE_HAND := "hand"
const STAGE_BOARD := "board"

const CHAPTERS: Array = [
	{
		"title": "砂時計の読み方",
		"pages":
		[
			{
				"heading": "上の砂が体力、下の砂が攻撃力",
				"body":
				"砂時計の上の部屋に残っている砂が体力、下へ落ちた砂が攻撃力です。合計は総量と呼び、カードごとに決まっています。出したばかりの砂時計は砂がすべて上にあるため、攻撃力0でまだ何もできません。",
				"stage":
				{"kind": STAGE_SINGLE, "cards": [{"id": "sand", "health": 5, "attack": 0}]},
			},
			{
				"heading": "数字は左下が攻撃力、右下が体力",
				"body": "砂が落ちるほど攻撃力が上がり、体力が減ります。イラストも砂の量に合わせて3段階で変わるので、数字を読まなくてもいまの状態が分かります。",
				"stage":
				{"kind": STAGE_SINGLE, "cards": [{"id": "sand", "health": 2, "attack": 3}]},
			},
		],
	},
	{
		"title": "砂が落ちる",
		"pages":
		[
			{
				"heading": "毎ターン終了時、砂が1粒落ちる",
				"body":
				"自分のターンが終わるたび、場の砂時計は体力-1・攻撃力+1になります。時間が経つほど強くなると同時に脆くなり、体力が0になった砂時計は破壊されます。",
				"stage": {"kind": STAGE_DROP, "cards": [{"id": "sand", "health": 5, "attack": 0}]},
			}
		],
	},
	{
		"title": "反転",
		"pages":
		[
			{
				"heading": "反転すると、体力と攻撃力が入れ替わる",
				"body":
				"反転にマナは要りません。1体につき1ターンに1回まで、出したターンは反転できません。攻撃力が体力を上回ったら返すのが基本で、高い攻撃力を保ったまま寿命を伸ばせます。",
				"stage": {"kind": STAGE_FLIP, "cards": [{"id": "sand", "health": 1, "attack": 4}]},
			}
		],
	},
	{
		"title": "場に出す",
		"pages":
		[
			{
				"heading": "マナを払って、場の6枠へ出す",
				"body": "マナは自分のターン開始時に最大値+1で全回復します(上限10)。カード左上の数字がコスト、右下が総量です。出したターンは反転も攻撃もできません。",
				"stage": {"kind": STAGE_PLAY, "cards": [{"id": "drill"}]},
			}
		],
	},
	{
		"title": "攻撃と相打ち",
		"pages":
		[
			{
				"heading": "砂時計どうしの攻撃は必ず相打ち",
				"body":
				"相手の砂時計を攻撃すると、互いに相手の攻撃力ぶんのダメージを受けます。一方的に倒せる攻撃はありません。相手プレイヤーを狙った場合は、攻撃力がそのままHPへ入ります。",
				"stage":
				{
					"kind": STAGE_COMBAT,
					"cards":
					[
						{"id": "sand", "health": 3, "attack": 2, "caption": "自分"},
						{"id": "lock", "health": 6, "attack": 2, "caption": "相手"},
					],
				},
			},
			{
				"heading": "消える砂と、落ちる砂",
				"body":
				"ダメージで砕けた砂は消え、総量そのものが減ります。ターン終了時に落ちる砂は下の部屋へ移るだけで、総量は変わりません。この2つは演出で描き分けています。",
				"stage":
				{
					"kind": STAGE_SAND_DIFF,
					"cards":
					[
						{"id": "sand", "health": 4, "attack": 1, "caption": "落ちる(総量は同じ)"},
						{"id": "sand", "health": 4, "attack": 1, "caption": "消える(総量が減る)"},
					],
				},
			},
		],
	},
	{
		"title": "キーワード",
		"pages":
		[
			{
				"heading": "覚えるキーワードは4つ",
				"body":
				"守護=相手はこれを無視して他を攻撃できない。硝子=最初に受けるダメージを1度だけ無効にする。貫通=砂時計を攻撃したとき超過分が相手プレイヤーへ抜ける。速落=場に出た瞬間に砂が2粒落ちる。",
				"stage":
				{
					"kind": STAGE_HAND,
					"cards": [{"id": "shield"}, {"id": "glass"}, {"id": "drill"}, {"id": "dash"}],
				},
			}
		],
	},
	{
		"title": "対局の流れ",
		"pages":
		[
			{
				"heading": "6枠の盤面と、30から始まるHP",
				"body": "デッキは20枚(同名2枚まで)。場は各プレイヤー6枠で、相手のHPを先に0にすれば勝ちです。情報帯にはHP・マナ・山札・墓地の枚数が並びます。",
				"stage": {"kind": STAGE_BOARD, "cards": []},
			},
			{
				"heading": "先手と後手、そしてコイン",
				"body":
				"初期手札は先手3枚・後手4枚です。後手はコインを1枚持ち、1対局に1度だけマナを+1できます。山札が尽きた後は、自分のターン終了ごとに1ダメージを受けます。",
				"stage": {"kind": STAGE_BOARD, "cards": []},
			},
		],
	},
]

static var _flat: Array = []


## 全ページを1本の配列として返す。各ページは章の情報を併せ持つ。
static func pages() -> Array:
	if not _flat.is_empty():
		return _flat
	for chapter_index in CHAPTERS.size():
		var chapter: Dictionary = CHAPTERS[chapter_index]
		for page: Dictionary in chapter["pages"]:
			var entry := page.duplicate()
			entry["chapter"] = chapter_index
			entry["chapter_title"] = chapter["title"]
			_flat.append(entry)
	return _flat


## その章の先頭ページの通し番号。目次から飛ぶときに使う。
static func first_page_of(chapter_index: int) -> int:
	var all := pages()
	for i in all.size():
		if int(all[i]["chapter"]) == chapter_index:
			return i
	return 0
