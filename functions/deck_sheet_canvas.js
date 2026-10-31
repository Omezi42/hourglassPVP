/**
 * デッキ表の画像(GameDesign.md 32章 / Architecture.md 10.21節)。共有リンクの埋め込みと Discord `/deck` が使う。
 *
 * ゲーム内のデッキ表(`CardDeckSheet`、Godotの `SubViewport` 描画)とは別実装であり、
 * 見た目の一致は求めない。組み合わせが無数にあるデッキ表は事前生成できず、
 * 常駐サーバーを持たずに都度Godotを起動して描画するのも相性が悪いため、
 * Node.js で完結する `@napi-rs/canvas` で独自に描く。
 */

const path = require("path");
const {createCanvas, GlobalFonts} = require("@napi-rs/canvas");

// Cloud Functions(Linux)のシステムには日本語フォントが無いため、そのまま描画すると
// 文字がすべて豆腐(□)になる(実測で確認済み)。同梱の日本語フォントを明示的に登録する。
// `functions/` の外(`assets/fonts/`)は firebase.json の `functions.source` に含まれず
// デプロイされないため、`functions/fonts/` へコピーして持たせている。
const FONT_FAMILY = "Zen Kaku Gothic New";
GlobalFonts.registerFromPath(path.join(__dirname, "fonts", "ZenKakuGothicNew-Bold.ttf"), FONT_FAMILY);

// X・Discordの大きいプレビュー(1.91:1)に合わせる。
const WIDTH = 1200;
const HEIGHT = 630;
const MARGIN = 40;
const HEADER_HEIGHT = 104;
const FOOTER_HEIGHT = 40;
const GAP = 12;
const MAX_COLUMNS = 10;
const MAX_CELL_WIDTH = 150;
// 攻略サイトのサムネイル(build_wiki.py の THUMB_BOX)の縦横比。
const ART_RATIO = 290 / 222;
const NAME_HEIGHT = 28;
const TITLE = "砂時計アリーナ";

const COLOR = {
  backTop: "#26211a",
  backBottom: "#14120f",
  brass: "#c9a45c",
  brassDim: "#8a6a34",
  text: "#f0e6d0",
  subText: "#cbb98a",
  slot: "#3a2f22",
  spellSlot: "#2c3454",
  badge: "rgba(12, 10, 8, 0.85)",
};

/**
 * @param {Array<{id: string, display_name: string, cost: number}>} cards コスト順に並べ済みの30枚(重複あり)
 * @param {{name?: string, code?: string, loadArt?: function(string): Promise<?Image>}} options
 * @return {Promise<Buffer>} PNG画像
 */
async function renderDeckSheet(cards, options = {}) {
  const entries = groupByCard(cards);
  const arts = await Promise.all(entries.map((entry) => loadArtSafely(options.loadArt, entry.card.id)));
  const canvas = createCanvas(WIDTH, HEIGHT);
  const ctx = canvas.getContext("2d");
  drawBackground(ctx);
  drawHeader(ctx, options.name || "デッキ", options.code || "", cards.length);

  const layout = gridLayout(entries.length);
  const originX = (WIDTH - layout.width) / 2;
  const originY = HEADER_HEIGHT + (HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT - layout.height) / 2;
  entries.forEach((entry, index) => {
    const x = originX + (index % layout.columns) * (layout.cell + GAP);
    const y = originY + Math.floor(index / layout.columns) * (layout.cellHeight + GAP);
    drawCell(ctx, x, y, layout.cell, entry, arts[index]);
  });

  ctx.font = `16px "${FONT_FAMILY}"`;
  ctx.fillStyle = COLOR.subText;
  ctx.textAlign = "right";
  ctx.textBaseline = "middle";
  ctx.fillText(TITLE, WIDTH - MARGIN, HEIGHT - FOOTER_HEIGHT / 2);
  return canvas.toBuffer("image/png");
}

/** 並び順を保ったまま、同じカードを1マスへまとめる。 */
function groupByCard(cards) {
  const entries = [];
  const byId = new Map();
  for (const card of cards) {
    if (byId.has(card.id)) {
      byId.get(card.id).count += 1;
      continue;
    }
    const entry = {card, count: 1};
    byId.set(card.id, entry);
    entries.push(entry);
  }
  return entries;
}

async function loadArtSafely(loadArt, id) {
  if (!loadArt) return null;
  try {
    return await loadArt(id);
  } catch (error) {
    return null;
  }
}

/** マスが最も大きくなる列数を選ぶ。 */
function gridLayout(count) {
  const areaWidth = WIDTH - MARGIN * 2;
  const areaHeight = HEIGHT - HEADER_HEIGHT - FOOTER_HEIGHT;
  let best = null;
  for (let columns = 1; columns <= MAX_COLUMNS; columns += 1) {
    const rows = Math.ceil(count / columns);
    const byWidth = (areaWidth - GAP * (columns - 1)) / columns;
    const byHeight = ((areaHeight - GAP * (rows - 1)) / rows - NAME_HEIGHT) / ART_RATIO;
    const cell = Math.min(byWidth, byHeight, MAX_CELL_WIDTH);
    if (!best || cell > best.cell) best = {columns, rows, cell};
  }
  const cellHeight = best.cell * ART_RATIO + NAME_HEIGHT;
  const columns = Math.min(best.columns, count);
  return {
    columns,
    cell: best.cell,
    cellHeight,
    width: columns * best.cell + GAP * (columns - 1),
    height: best.rows * cellHeight + GAP * (best.rows - 1),
  };
}

function drawBackground(ctx) {
  const gradient = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  gradient.addColorStop(0, COLOR.backTop);
  gradient.addColorStop(1, COLOR.backBottom);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);
  ctx.strokeStyle = COLOR.brassDim;
  ctx.lineWidth = 2;
  ctx.strokeRect(12, 12, WIDTH - 24, HEIGHT - 24);
}

function drawHeader(ctx, name, code, total) {
  ctx.textBaseline = "middle";
  ctx.textAlign = "left";
  ctx.fillStyle = COLOR.text;
  ctx.font = `44px "${FONT_FAMILY}"`;
  ctx.fillText(name, MARGIN, HEADER_HEIGHT / 2 + 6);
  const nameWidth = ctx.measureText(name).width;
  ctx.font = `20px "${FONT_FAMILY}"`;
  ctx.fillStyle = COLOR.subText;
  ctx.fillText(`${total}枚`, MARGIN + nameWidth + 16, HEADER_HEIGHT / 2 + 12);

  if (code) {
    ctx.textAlign = "right";
    ctx.font = `18px "${FONT_FAMILY}"`;
    ctx.fillStyle = COLOR.subText;
    ctx.fillText("デッキコード", WIDTH - MARGIN, HEADER_HEIGHT / 2 - 14);
    ctx.font = `34px "${FONT_FAMILY}"`;
    ctx.fillStyle = COLOR.brass;
    ctx.fillText(code, WIDTH - MARGIN, HEADER_HEIGHT / 2 + 18);
  }
  ctx.strokeStyle = COLOR.brassDim;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(MARGIN, HEADER_HEIGHT);
  ctx.lineTo(WIDTH - MARGIN, HEADER_HEIGHT);
  ctx.stroke();
}

function drawCell(ctx, x, y, width, entry, art) {
  const artHeight = width * ART_RATIO;
  const radius = width * 0.06;
  ctx.save();
  roundedRect(ctx, x, y, width, artHeight, radius);
  ctx.clip();
  if (art) {
    ctx.drawImage(art, x, y, width, artHeight);
  } else {
    ctx.fillStyle = entry.card.is_spell ? COLOR.spellSlot : COLOR.slot;
    ctx.fillRect(x, y, width, artHeight);
  }
  ctx.restore();
  roundedRect(ctx, x, y, width, artHeight, radius);
  ctx.strokeStyle = COLOR.brassDim;
  ctx.lineWidth = 1.5;
  ctx.stroke();

  const badge = width * 0.26;
  drawBadge(ctx, x + badge * 0.62, y + badge * 0.62, badge / 2, String(entry.card.cost), COLOR.brass);
  if (entry.count > 1) {
    drawBadge(ctx, x + width - badge * 0.62, y + artHeight - badge * 0.62, badge / 2, `×${entry.count}`, COLOR.text);
  }

  ctx.font = `${Math.round(Math.min(18, width * 0.15))}px "${FONT_FAMILY}"`;
  ctx.fillStyle = COLOR.text;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(fitText(ctx, entry.card.display_name, width), x + width / 2, y + artHeight + NAME_HEIGHT / 2 + 2);
}

function drawBadge(ctx, cx, cy, radius, label, color) {
  ctx.beginPath();
  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
  ctx.fillStyle = COLOR.badge;
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.font = `${Math.round(radius * (label.length > 1 ? 0.95 : 1.2))}px "${FONT_FAMILY}"`;
  ctx.fillStyle = color;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(label, cx, cy + 1);
}

/** 幅に収まらない名前は末尾を「…」にする。 */
function fitText(ctx, text, maxWidth) {
  if (ctx.measureText(text).width <= maxWidth) return text;
  let cut = text;
  while (cut.length > 1 && ctx.measureText(`${cut}…`).width > maxWidth) cut = cut.slice(0, -1);
  return `${cut}…`;
}

function roundedRect(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + width, y, x + width, y + height, radius);
  ctx.arcTo(x + width, y + height, x, y + height, radius);
  ctx.arcTo(x, y + height, x, y, radius);
  ctx.arcTo(x, y, x + width, y, radius);
  ctx.closePath();
}

module.exports = {renderDeckSheet, WIDTH, HEIGHT};
