class_name RankedMatchmakingQueue
extends MatchmakingQueue
## ランクマッチのマッチングキュー(GameDesign.md 11章・28章、Architecture.md 10.16節)。
## 見知らぬ人との対戦はこれ1つ。中身は `MatchmakingQueue` と同じで、コレクションだけを
## `ranked_queue` にする。段位は考慮せず「早い者勝ち」でマッチさせる。

const RANKED_COLLECTION := "ranked_queue"


func _init(p_client: FirestoreClient, p_auth: FirebaseAuth) -> void:
	super(p_client, p_auth)
	collection = RANKED_COLLECTION


## ホームへ出す「いま相手を待っている人」の数(GameDesign.md 9章)。
## 自分・古い待機者・違うビルドの人は掴めないため数えない。
static func count_waiting(p_client: FirestoreClient, my_uid: String) -> int:
	var candidates: Array = await p_client.query_waiting(RANKED_COLLECTION, QUERY_LIMIT)
	var count := 0
	for candidate: Dictionary in candidates:
		if candidate["id"] == my_uid or is_stale(candidate):
			continue
		if GameVersion.matches_build(candidate["fields"].get("build", "")):
			count += 1
	return count
