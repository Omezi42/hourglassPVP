class_name RankedMatchmakingQueue
extends MatchmakingQueue
## ランクマッチ専用のマッチングキュー(GameDesign.md 28章、Architecture.md 10.16節)。
## 中身は `MatchmakingQueue` と同じで、コレクションを `ranked_queue` に分けて
## フリーマッチのプールと混ざらないようにし、Discordへの募集通知(11章)だけを外す。
## 段位は考慮せず、フリーマッチと同じ「早い者勝ち」でマッチさせる。

const RANKED_COLLECTION := "ranked_queue"


func _init(p_client: FirestoreClient, p_auth: FirebaseAuth) -> void:
	super(p_client, p_auth)
	collection = RANKED_COLLECTION
	announces = false
