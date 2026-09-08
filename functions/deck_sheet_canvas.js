/**
 * `/deck` 用の簡易デッキ表画像(GameDesign.md 26章 / Architecture.md 10.14節)。
 *
 * ゲーム内のデッキ表(`CardDeckSheet`、Godotの `SubViewport` 描画)とは別実装であり、
 * 見た目の一致は求めない。組み合わせが無数にあるデッキ表は事前生成できず、
 * 常駐サーバーを持たずに都度Godotを起動して描画するのも相性が悪いため、
 * Discord Bot側(Node.js)で完結する `@napi-rs/canvas` で独自に描く。
 */

const path = require("path");
const {createCanvas, GlobalFonts} = require("@napi-rs/canvas");

// Cloud Functions(Linux)のシステムには日本語フォントが無いため、そのまま描画すると
// 文字がすべて豆腐(□)になる(実測で確認済み)。同梱の日本語フォントを明示的に登録する。
// `functions/` の外(`assets/fonts/`)は firebase.json の `functions.source` に含まれず
// デプロイされないため、`functions/fonts/` へコピーして持たせている。
const FONT_FAMILY = "Zen Kaku Gothic New";
GlobalFonts.registerFromPath(path.join(__dirname, "fonts", "ZenKakuGothicNew-Bold.ttf"), FONT_FAMILY);

const COLUMNS = 6;
const ROWS = 5;
const CELL_WIDTH = 190;
const CELL_HEIGHT = 130;
const PADDING = 20;
const WIDTH = COLUMNS * CELL_WIDTH + PADDING * 2;
const HEIGHT = ROWS * CELL_HEIGHT + PADDING * 2;

/**
 * @param {Array<{id: string, display_name: string, cost: number, total_sand: number,
 *   is_spell: boolean}>} cards コスト順に並べ済みのカード配列(30枚を想定)
 * @return {Buffer} PNG画像
 */
function renderDeckSheet(cards) {
  const canvas = createCanvas(WIDTH, HEIGHT);
  const ctx = canvas.getContext("2d");

  ctx.fillStyle = "#1c1a16";
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  cards.slice(0, COLUMNS * ROWS).forEach((card, index) => {
    const col = index % COLUMNS;
    const row = Math.floor(index / COLUMNS);
    const x = PADDING + col * CELL_WIDTH;
    const y = PADDING + row * CELL_HEIGHT;
    drawCard(ctx, x, y, card);
  });

  return canvas.toBuffer("image/png");
}

function drawCard(ctx, x, y, card) {
  const w = CELL_WIDTH - 8;
  const h = CELL_HEIGHT - 8;
  ctx.fillStyle = card.is_spell ? "#2c3454" : "#3a2f22";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = "#8a6a34";
  ctx.lineWidth = 1.5;
  ctx.strokeRect(x, y, w, h);

  ctx.fillStyle = "#f0e6d0";
  ctx.font = `16px "${FONT_FAMILY}"`;
  ctx.textBaseline = "top";
  drawWrappedText(ctx, card.display_name, x + 8, y + 8, w - 16, 18);

  ctx.font = `13px "${FONT_FAMILY}"`;
  ctx.fillStyle = "#cbb98a";
  const total = card.is_spell ? "術" : String(card.total_sand);
  ctx.fillText(`コスト${card.cost} / 総量${total}`, x + 8, y + h - 22);
}

/** 1文字ずつ幅を測って折り返す。日本語は単語区切りが無いため文字単位で行う。 */
function drawWrappedText(ctx, text, x, y, maxWidth, lineHeight) {
  let line = "";
  let offsetY = y;
  for (const ch of text) {
    const candidate = line + ch;
    if (line !== "" && ctx.measureText(candidate).width > maxWidth) {
      ctx.fillText(line, x, offsetY);
      line = ch;
      offsetY += lineHeight;
    } else {
      line = candidate;
    }
  }
  if (line !== "") ctx.fillText(line, x, offsetY);
}

module.exports = {renderDeckSheet, WIDTH, HEIGHT};
