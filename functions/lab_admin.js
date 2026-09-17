/**
 * 掲示板〈ラボ〉の承認・却下・月末の採用判断(GameDesign.md 29章 / Architecture.md 10.17節)。
 *
 * プレイヤー側クライアントは投稿・一覧の取得・投票までしか行わない。承認・却下・
 * 採用の確定は、ここ(Cloud Functions、Admin SDK)を経由する `tools/lab_admin/` の
 * 管理ツールだけが行う。認証は共有シークレット1本のみ
 * (`firebase functions:secrets:set LAB_ADMIN_SECRET`)で、Firestoreのセキュリティ
 * ルールではなくこのシークレットを知っているかどうかで権限を絞る。
 */

const COLLECTION = "lab_proposals";
const PLAYERS_COLLECTION = "players";

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
      case "list_pending":
        return res.json({ok: true, proposals: await listPending(db)});
      case "list_current_month":
        return res.json({ok: true, proposals: await listCurrentMonth(db, body.month)});
      case "approve":
        await setStatus(db, body.id, "approved");
        return res.json({ok: true});
      case "reject":
        await rejectAndRefund(db, firestoreNs, body.id);
        return res.json({ok: true});
      case "set_result":
        await setResult(db, firestoreNs, body.id, body.result);
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

async function listPending(db) {
  const snapshot = await db
    .collection(COLLECTION)
    .where("status", "==", "pending")
    .orderBy("created_at", "asc")
    .get();
  return snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
}

async function listCurrentMonth(db, month) {
  const key = month || currentMonthKey();
  const snapshot = await db
    .collection(COLLECTION)
    .where("status", "==", "approved")
    .where("month", "==", key)
    .get();
  const rows = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  rows.sort((a, b) => (b.good_count || 0) - (a.good_count || 0));
  return rows;
}

async function setStatus(db, id, status) {
  await db.collection(COLLECTION).doc(String(id)).update({status});
}

/** 却下し、投稿時に支払った砂金をそのまま返す(GameDesign.md 29章)。 */
async function rejectAndRefund(db, firestoreNs, id) {
  await db.runTransaction(async (tx) => {
    const proposalRef = db.collection(COLLECTION).doc(String(id));
    const proposalSnap = await tx.get(proposalRef);
    if (!proposalSnap.exists) throw new Error("proposal not found");
    const proposal = proposalSnap.data();
    tx.update(proposalRef, {status: "rejected"});
    const cost = Number(proposal.cost_paid || 0);
    if (cost > 0 && proposal.author_uid) {
      const playerRef = db.collection(PLAYERS_COLLECTION).doc(String(proposal.author_uid));
      tx.set(
        playerRef,
        {currency: firestoreNs.FieldValue.increment(cost)},
        {merge: true}
      );
    }
  });
}

/** 月末の採用判断。`"adopted"` のときは投稿者へ称号「発案者」を付与する(29章)。 */
async function setResult(db, firestoreNs, id, result) {
  await db.runTransaction(async (tx) => {
    const proposalRef = db.collection(COLLECTION).doc(String(id));
    const proposalSnap = await tx.get(proposalRef);
    if (!proposalSnap.exists) throw new Error("proposal not found");
    const proposal = proposalSnap.data();
    tx.update(proposalRef, {result: String(result)});
    if (String(result) === "adopted" && proposal.author_uid) {
      const playerRef = db.collection(PLAYERS_COLLECTION).doc(String(proposal.author_uid));
      tx.set(
        playerRef,
        {owned_titles: firestoreNs.FieldValue.arrayUnion("proposer")},
        {merge: true}
      );
    }
  });
}

/**
 * 公式大会「箱庭杯」の優勝賞品(GameDesign.md 30章)。投票を経ない
 * `source: "tournament"` の投稿として`lab_proposals`へ直接作成し、
 * 同じトランザクションで称号「発案者」「箱庭王」の両方を付与する。
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
    const proposalRef = db.collection(COLLECTION).doc();
    tx.set(proposalRef, {
      author_uid: uid,
      card_name: cardName,
      description: description,
      card_kind: kind === "spell" ? "spell" : "hourglass",
      month: currentMonthKey(),
      status: "approved",
      good_count: 0,
      result: "adopted",
      cost_paid: 0,
      source: "tournament",
      created_at: Date.now() / 1000,
    });
    const playerRef = db.collection(PLAYERS_COLLECTION).doc(uid);
    tx.set(
      playerRef,
      {owned_titles: firestoreNs.FieldValue.arrayUnion("proposer", "hakoniwa_ou")},
      {merge: true}
    );
  });
}

/** `YYYY-MM`。ゲーム内クライアント(`LabProposalService.current_month()`)と同じJST換算。 */
function currentMonthKey() {
  const jst = new Date(Date.now() + 9 * 3600 * 1000);
  const year = jst.getUTCFullYear();
  const month = String(jst.getUTCMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

module.exports = {handleLabAdmin};
