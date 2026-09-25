/**
 * 掲示板〈ラボ〉の運用(GameDesign.md 29章 / Architecture.md 10.17節)。
 *
 * プレイヤー側クライアントは回の取得・投稿・投票までしか行わない。お題の作成・非表示・
 * 採用の印・結果の確定は、ここ(Cloud Functions、Admin SDK)を経由する `tools/lab_admin/` の
 * 管理ツールだけが行う。認証は共有シークレット1本のみ
 * (`firebase functions:secrets:set LAB_ADMIN_SECRET`)。
 */

const ROUNDS = "lab_rounds";
const PROPOSALS = "lab_proposals";
const PLAYERS = "players";
const JST_OFFSET_MS = 9 * 3600 * 1000;

/**
 * `POST /labAdmin` の本文にある `action` で分岐する(`discordInteractions` と同じ、
 * 1関数へ集約する流儀)。
 *
 * @param {import("express").Request} req
 * @param {import("express").Response} res
 * @param {import("firebase-admin").firestore.Firestore} db
 * @param {typeof import("firebase-admin").firestore} firestoreNs
 */
async function handleLabAdmin(req, res, db, firestoreNs) {
  const body = req.body || {};
  const action = String(body.action || "");

  try {
    switch (action) {
      case "list_rounds":
        return res.json({ok: true, rounds: await listRounds(db)});
      case "create_round":
        return res.json({ok: true, id: await createRound(db, body)});
      case "list_round":
        return res.json({ok: true, proposals: await listRound(db, body.round_id)});
      case "set_hidden":
        await db.collection(PROPOSALS).doc(String(body.id)).update({hidden: Boolean(body.hidden)});
        return res.json({ok: true});
      case "set_result":
        await setResult(db, firestoreNs, body.id, body.result);
        return res.json({ok: true});
      case "fix_results":
        await db.collection(ROUNDS).doc(String(body.round_id)).update({results_fixed: true});
        return res.json({ok: true});
      case "grant_tournament_prize":
        await grantTournamentPrize(db, firestoreNs, body);
        return res.json({ok: true});
      default:
        return res.status(400).json({ok: false, message: "unknown action"});
    }
  } catch (err) {
    return res.status(500).json({ok: false, message: String(err && err.message || err)});
  }
}

async function listRounds(db) {
  const snapshot = await db.collection(ROUNDS).orderBy("starts_at", "desc").get();
  return snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
}

/**
 * 回を作る。`starts_at` / `ends_at` はunix秒。IDは `r` + 開始日(JST)の `YYYYMMDD`。
 * 期間が既存の回と重なるときは断る(同時に開いている回は1つだけ。29章)。
 */
async function createRound(db, body) {
  const title = String(body.title || "").trim();
  const detail = String(body.detail || "").trim();
  const startsAt = Number(body.starts_at);
  const endsAt = Number(body.ends_at);
  if (!title || title.length > 20) throw new Error("title is required (20 chars max)");
  if (detail.length > 80) throw new Error("detail is 80 chars max");
  if (!(startsAt > 0) || !(endsAt > startsAt)) throw new Error("invalid period");

  const rounds = await listRounds(db);
  const overlap = rounds.find((r) => r.starts_at < endsAt && startsAt < r.ends_at);
  if (overlap) throw new Error(`period overlaps round ${overlap.id}`);

  const jst = new Date(startsAt * 1000 + JST_OFFSET_MS);
  const id = "r" + jst.toISOString().slice(0, 10).replace(/-/g, "");
  const ref = db.collection(ROUNDS).doc(id);
  await ref.create({
    title,
    detail,
    starts_at: startsAt,
    ends_at: endsAt,
    results_fixed: false,
    created_at: Date.now() / 1000,
  });
  return id;
}

/** 回の案を非表示も含めて得票順に返す(等価フィルタ1本。並べ替えはここで行う)。 */
async function listRound(db, roundId) {
  const snapshot = await db.collection(PROPOSALS).where("round_id", "==", String(roundId)).get();
  const rows = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  rows.sort((a, b) => (b.good_count || 0) - (a.good_count || 0) ||
    (a.created_at || 0) - (b.created_at || 0));
  return rows;
}

/** 採用の印。`"adopted"` のときは投稿者へ称号「発案者」を付与する(29章)。 */
async function setResult(db, firestoreNs, id, result) {
  const value = String(result) === "adopted" ? "adopted" : "";
  await db.runTransaction(async (tx) => {
    const proposalRef = db.collection(PROPOSALS).doc(String(id));
    const proposalSnap = await tx.get(proposalRef);
    if (!proposalSnap.exists) throw new Error("proposal not found");
    const proposal = proposalSnap.data();
    tx.update(proposalRef, {result: value});
    if (value === "adopted" && proposal.author_uid) {
      tx.set(
        db.collection(PLAYERS).doc(String(proposal.author_uid)),
        {owned_titles: firestoreNs.FieldValue.arrayUnion("proposer")},
        {merge: true}
      );
    }
  });
}

/**
 * 公式大会「箱庭杯」の優勝賞品(GameDesign.md 30章)。募集回に属さない
 * `source: "tournament"` の案として直接作成し、同じトランザクションで
 * 称号「発案者」「箱庭王」の両方を付与する。
 */
async function grantTournamentPrize(db, firestoreNs, body) {
  const uid = String(body.uid || "");
  const cardName = String(body.card_name || "");
  const description = String(body.description || "");
  const kind = String(body.kind || "hourglass");
  if (!uid || !cardName || !description) {
    throw new Error("uid, card_name, description are required");
  }
  await db.runTransaction(async (tx) => {
    tx.set(db.collection(PROPOSALS).doc(), {
      author_uid: uid,
      round_id: "",
      card_name: cardName,
      description: description,
      card_kind: kind === "spell" ? "spell" : "hourglass",
      hidden: false,
      good_count: 0,
      result: "adopted",
      source: "tournament",
      created_at: Date.now() / 1000,
    });
    tx.set(
      db.collection(PLAYERS).doc(uid),
      {owned_titles: firestoreNs.FieldValue.arrayUnion("proposer", "hakoniwa_ou")},
      {merge: true}
    );
  });
}

module.exports = {handleLabAdmin};
