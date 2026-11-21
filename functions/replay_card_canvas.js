/**
 * 共有リプレイの埋め込みの画像(GameDesign.md 32章 / Architecture.md 10.21節)。
 * 両者のアイコンと表示名・勝敗・手数・それぞれのデッキの主なカード。デッキ表(deck_sheet_canvas.js)と同じ地と色で描く。
 */

const {createCanvas} = require("@napi-rs/canvas");
const {
  WIDTH, HEIGHT, FONT_FAMILY, COLOR, ART_RATIO, TITLE,
  drawBackground, drawBadge, fitText, roundedRect, loadArtSafely,
} = require("./deck_sheet_canvas");

const MARGIN = 48;
const CENTER_GAP = 120;
const ICON_RADIUS = 46;
const ICON_Y = 96;
const NAME_Y = 182;
const RESULT_Y = 232;
const CARD_TOP = 284;
const CARD_WIDTH = 132;
const CARD_GAP = 20;
const NAME_HEIGHT = 30;
const FOOTER_HEIGHT = 40;
const RESULT_LABELS = {win: "勝ち", lose: "負け", draw: "引き分け"};
const RESULT_COLORS = {win: COLOR.brass, lose: COLOR.subText, draw: COLOR.text};

/**
 * @param {{players: Array<{name: string, icon: ?Image, result: string, cards: Array}>, turns: number,
 *   loadArt: function(string): Promise<?Image>}} replay players は [手前(共有した人), 相手]
 * @return {Promise<Buffer>} PNG画像
 */
async function renderReplayCard(replay) {
  const arts = await Promise.all(replay.players.map((player) =>
    Promise.all(player.cards.map((card) => loadArtSafely(replay.loadArt, card.id)))));
  const canvas = createCanvas(WIDTH, HEIGHT);
  const ctx = canvas.getContext("2d");
  drawBackground(ctx);
  const columnWidth = (WIDTH - MARGIN * 2 - CENTER_GAP) / 2;
  replay.players.forEach((player, index) => {
    const centerX = MARGIN + columnWidth / 2 + index * (columnWidth + CENTER_GAP);
    drawPlayer(ctx, centerX, columnWidth, player, arts[index]);
  });

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = COLOR.brass;
  ctx.font = `40px "${FONT_FAMILY}"`;
  ctx.fillText("VS", WIDTH / 2, ICON_Y);
  ctx.fillStyle = COLOR.subText;
  ctx.font = `24px "${FONT_FAMILY}"`;
  ctx.fillText(`${replay.turns}手`, WIDTH / 2, RESULT_Y);

  ctx.font = `16px "${FONT_FAMILY}"`;
  ctx.textAlign = "right";
  ctx.fillText(`${TITLE} リプレイ`, WIDTH - MARGIN, HEIGHT - FOOTER_HEIGHT / 2);
  return canvas.toBuffer("image/png");
}

function drawPlayer(ctx, centerX, columnWidth, player, arts) {
  ctx.save();
  ctx.beginPath();
  ctx.arc(centerX, ICON_Y, ICON_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = COLOR.slot;
  ctx.fill();
  ctx.clip();
  if (player.icon) ctx.drawImage(player.icon, centerX - ICON_RADIUS, ICON_Y - ICON_RADIUS, ICON_RADIUS * 2, ICON_RADIUS * 2);
  ctx.restore();
  ctx.beginPath();
  ctx.arc(centerX, ICON_Y, ICON_RADIUS, 0, Math.PI * 2);
  ctx.strokeStyle = COLOR.brass;
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = COLOR.text;
  ctx.font = `36px "${FONT_FAMILY}"`;
  ctx.fillText(fitText(ctx, player.name, columnWidth), centerX, NAME_Y);
  ctx.fillStyle = RESULT_COLORS[player.result];
  ctx.font = `30px "${FONT_FAMILY}"`;
  ctx.fillText(RESULT_LABELS[player.result], centerX, RESULT_Y);

  const rowWidth = player.cards.length * CARD_WIDTH + Math.max(0, player.cards.length - 1) * CARD_GAP;
  player.cards.forEach((card, index) => {
    drawCard(ctx, centerX - rowWidth / 2 + index * (CARD_WIDTH + CARD_GAP), CARD_TOP, card, arts[index]);
  });
}

function drawCard(ctx, x, y, card, art) {
  const artHeight = CARD_WIDTH * ART_RATIO;
  const radius = CARD_WIDTH * 0.06;
  ctx.save();
  roundedRect(ctx, x, y, CARD_WIDTH, artHeight, radius);
  ctx.clip();
  if (art) {
    ctx.drawImage(art, x, y, CARD_WIDTH, artHeight);
  } else {
    ctx.fillStyle = card.is_spell ? COLOR.spellSlot : COLOR.slot;
    ctx.fillRect(x, y, CARD_WIDTH, artHeight);
  }
  ctx.restore();
  roundedRect(ctx, x, y, CARD_WIDTH, artHeight, radius);
  ctx.strokeStyle = COLOR.brassDim;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  const badge = CARD_WIDTH * 0.26;
  drawBadge(ctx, x + badge * 0.62, y + badge * 0.62, badge / 2, String(card.cost), COLOR.brass);
  ctx.font = `20px "${FONT_FAMILY}"`;
  ctx.fillStyle = COLOR.text;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(fitText(ctx, card.display_name, CARD_WIDTH), x + CARD_WIDTH / 2, y + artHeight + NAME_HEIGHT / 2 + 2);
}

module.exports = {renderReplayCard};
