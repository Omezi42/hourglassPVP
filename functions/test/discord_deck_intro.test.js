/**
 * Discordのデッキ紹介(GameDesign.md 26章)の流れを、偽のFirestoreと偽の fetch で確かめる。
 *
 *     node --test functions/test/
 */

const test = require("node:test");
const assert = require("node:assert/strict");
const cardsData = require("../data/cards.json");
const {handleDeckIntroComponent, handleCommentSubmit, isDeckIntroModal, deckText} = require("../discord_deck_intro");

const EPHEMERAL = 64;
const MODAL = 9;
const DISCORD_USER = "1001";
const UID = "uid-a";
const CHANNEL = "555";

// --- 偽のFirestore -----------------------------------------------------------

class FakeDb {
  constructor() {
    this.docs = new Map();
    this.nextId = 0;
  }

  collection(path) {
    return new FakeCollection(this, path);
  }

  put(path, data) {
    this.docs.set(path, data);
  }

  under(path) {
    return [...this.docs.entries()].filter(([key]) => key.startsWith(`${path}/`) && !key.slice(path.length + 1).includes("/"));
  }
}

class FakeCollection {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.max = Infinity;
  }

  doc(id) {
    return new FakeDoc(this.db, `${this.path}/${id}`);
  }

  async add(data) {
    this.db.nextId += 1;
    this.db.put(`${this.path}/auto${this.db.nextId}`, data);
  }

  limit(count) {
    const limited = new FakeCollection(this.db, this.path);
    limited.max = count;
    return limited;
  }

  async get() {
    return {size: Math.min(this.db.under(this.path).length, this.max)};
  }
}

class FakeDoc {
  constructor(db, path) {
    this.db = db;
    this.path = path;
  }

  collection(name) {
    return new FakeCollection(this.db, `${this.path}/${name}`);
  }

  async get() {
    const data = this.db.docs.get(this.path);
    return {exists: data !== undefined, data: () => data};
  }

  async create(data) {
    if (this.db.docs.has(this.path)) throw Object.assign(new Error("exists"), {code: 6});
    this.db.put(this.path, data);
  }
}

// --- 偽の fetch(Discordへの送信を記録し、カードの絵は無いことにする) ----------

let sent = [];

global.fetch = async (url, options = {}) => {
  const target = String(url);
  if (target.includes("/art/")) return new Response("", {status: 404});
  let body = options.body;
  if (body instanceof FormData) body = JSON.parse(body.get("payload_json"));
  else if (typeof body === "string") body = JSON.parse(body);
  sent.push({url: target, method: options.method, body});
  return new Response(JSON.stringify({id: `msg${sent.length}`}), {status: 200});
};

// --- 下ごしらえ ----------------------------------------------------------------

function fullDeckIds() {
  const ids = [];
  for (const card of cardsData.cards) {
    for (let i = 0; i < 2 && ids.length < 30; i += 1) ids.push(card.id);
  }
  return ids;
}

function linkedDb(decks) {
  const db = new FakeDb();
  db.put(`discord_links/${DISCORD_USER}`, {uid: UID});
  db.put(`players/${UID}`, {display_name: "砂の人", decks});
  return db;
}

function interaction(customId, extra = {}) {
  return {member: {user: {id: DISCORD_USER}}, id: "i1", token: "tok", application_id: "app", data: {custom_id: customId, ...extra}};
}

test.beforeEach(() => {
  sent = [];
});

// --- 入口 ----------------------------------------------------------------------

test("連携していなければ選択肢の代わりにアカウント連携ボタンを返す", async () => {
  const response = await handleDeckIntroComponent(interaction("deck_intro:start"), new FakeDb());
  assert.equal(response.data.flags, EPHEMERAL);
  assert.equal(response.data.components[0].components[0].custom_id, "deck_intro:link");
});

test("30枚そろったデッキだけを、デッキ一覧の添字つきで25件まで出す", async () => {
  const full = fullDeckIds();
  const decks = [{name: "未完成", ids: full.slice(0, 10)}];
  for (let i = 0; i < 30; i += 1) decks.push({name: `D${i}`, ids: full});
  const response = await handleDeckIntroComponent(interaction("deck_intro:start"), linkedDb(decks));
  assert.equal(response.data.flags, EPHEMERAL);
  const options = response.data.components[0].components[0].options;
  assert.equal(options.length, 25);
  assert.deepEqual(options[0], {label: "D0", value: "1"});
});

test("30枚そろったデッキが無ければその旨だけ返す", async () => {
  const response = await handleDeckIntroComponent(interaction("deck_intro:start"), linkedDb([{name: "x", ids: []}]));
  assert.equal(response.data.flags, EPHEMERAL);
  assert.equal(response.data.components, undefined);
});

test("アカウント連携のボタンは /link と同じフォームを開く", async () => {
  const response = await handleDeckIntroComponent(interaction("deck_intro:link"), new FakeDb());
  assert.equal(response.type, MODAL);
  assert.equal(response.data.custom_id, "link_modal");
});

test("デッキを選ぶと200字までの省略できるコメントのフォームが開く", async () => {
  const response = await handleDeckIntroComponent(interaction("deck_intro:pick", {values: ["3"]}), new FakeDb());
  assert.equal(response.type, MODAL);
  assert.equal(response.data.custom_id, "deck_intro:comment:3");
  assert.ok(isDeckIntroModal({data: {custom_id: response.data.custom_id}}));
  const field = response.data.components[0].components[0];
  assert.equal(field.required, false);
  assert.equal(field.max_length, 200);
});

test("デッキ紹介のものでないボタンは null を返して他へ回す", async () => {
  assert.equal(await handleDeckIntroComponent(interaction("other"), new FakeDb()), null);
});

// --- 投稿 ----------------------------------------------------------------------

function commentSubmit(index, comment) {
  return interaction(`deck_intro:comment:${index}`, {
    components: [{components: [{custom_id: "comment", value: comment}]}],
  });
}

test("コメントを送ると #デッキ紹介 へ紹介とコードの返信の2件を流し、本人には1行だけ返す", async () => {
  const db = linkedDb([{name: "砂嵐", ids: fullDeckIds()}]);
  await handleCommentSubmit(commentSubmit(0, "  @everyone 強い  "), db, {botToken: "bot", channelId: CHANNEL});

  const [defer, intro, reply, done] = sent;
  assert.match(defer.url, /\/interactions\/i1\/tok\/callback$/);
  assert.equal(defer.body.data.flags, EPHEMERAL);

  assert.match(intro.url, new RegExp(`/channels/${CHANNEL}/messages$`));
  assert.ok(intro.body.content.startsWith(`<@${DISCORD_USER}>`));
  assert.ok(intro.body.content.includes("@everyone 強い"));
  assert.deepEqual(intro.body.allowed_mentions, {parse: []});
  assert.equal(intro.body.embeds[0].title, "砂嵐");
  const [add, site] = intro.body.components[0].components;
  const code = add.custom_id.slice("deck_add:".length);
  assert.match(code, /^\d{8}$/);
  assert.ok(site.url.endsWith(`/d/${code}`));

  assert.equal(reply.body.content, code);
  assert.equal(reply.body.message_reference.message_id, "msg2");
  assert.deepEqual(reply.body.allowed_mentions, {parse: []});

  assert.equal(done.method, "PATCH");
  assert.equal(done.body.content, `<#${CHANNEL}> に投稿しました。`);

  assert.deepEqual(db.docs.get(`deckcodes/${code}`).cards, deckText(fullDeckIds()));
  const [[, record]] = db.under("deck_intros");
  assert.equal(record.code, code);
  assert.equal(record.comment, "@everyone 強い");
  assert.equal(record.author_name, "砂の人");
  assert.equal(record.uid, UID);
});

test("選んだ後にデッキが崩れていれば流さずに選び直しを促す", async () => {
  const db = linkedDb([{name: "砂嵐", ids: fullDeckIds().slice(0, 29)}]);
  await handleCommentSubmit(commentSubmit(0, ""), db, {botToken: "bot", channelId: CHANNEL});
  assert.equal(sent.filter((s) => s.url.includes("/channels/")).length, 0);
  assert.equal(sent.at(-1).body.content, "デッキが見つかりませんでした。もう一度選び直してください。");
});

// --- ゲームに追加 ----------------------------------------------------------------

function seededCode(db) {
  db.put("deckcodes/12345678", {cards: deckText(fullDeckIds()), name: "砂嵐"});
  return interaction("deck_add:12345678");
}

test("ゲームに追加は連携済みなら受け取り箱へ入れ、本人にだけ返す", async () => {
  const db = linkedDb([]);
  const response = await handleDeckIntroComponent(seededCode(db), db);
  assert.equal(response.data.flags, EPHEMERAL);
  assert.equal(response.data.content, "ゲームを開くと「砂嵐」が届きます。");
  const [[, item]] = db.under(`players/${UID}/deck_inbox`);
  assert.equal(item.name, "砂嵐");
  assert.equal(item.cards, deckText(fullDeckIds()));
});

test("ゲームに追加は連携していなければアカウント連携ボタンを返す", async () => {
  const db = new FakeDb();
  const response = await handleDeckIntroComponent(seededCode(db), db);
  assert.equal(response.data.components[0].components[0].custom_id, "deck_intro:link");
});

test("受け取り箱が10件埋まっていれば攻略サイトと同じ文言を返して入れない", async () => {
  const db = linkedDb([]);
  for (let i = 0; i < 10; i += 1) db.put(`players/${UID}/deck_inbox/q${i}`, {});
  const response = await handleDeckIntroComponent(seededCode(db), db);
  assert.equal(response.data.content, "ゲームを開いて受け取ってから追加してください");
  assert.equal(db.under(`players/${UID}/deck_inbox`).length, 10);
});
