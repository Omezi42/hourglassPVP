/**
 * 砂時計PvP CPU思考ロジック (CpuBrain)
 * docs/GameDesign.md 13章 & docs/Architecture.md 8章 準拠
 */

class CpuBrain {
  constructor(difficulty = 'normal') {
    this.difficulty = difficulty;
    this.thinkingDelay = 600; // 0.6秒の思考ディレイ (GameDesign.md 13章)
  }

  /**
   * 全ての合法手を列挙
   */
  getLegalActions(gameState, side = 'cpu') {
    const actions = [];
    const opp = gameState.getOpponent(side);

    // 1. 反転 (自陣3マス + 敵陣3マス)
    // 自陣
    for (let pos = 0; pos < 3; pos++) {
      if (gameState.canFlip(side, pos)) {
        actions.push({
          type: 'flip',
          targetSide: side,
          pos: pos,
          actorSide: side
        });
      }
    }
    // 敵陣
    for (let pos = 0; pos < 3; pos++) {
      if (gameState.canFlip(opp, pos)) {
        actions.push({
          type: 'flip',
          targetSide: opp,
          pos: pos,
          actorSide: side
        });
      }
    }

    // 2. 移動 (自陣の3組み合わせ: (0,1), (0,2), (1,2))
    const movePairs = [[0, 1], [0, 2], [1, 2]];
    for (const [posA, posB] of movePairs) {
      if (gameState.canMove(side, posA, posB)) {
        actions.push({
          type: 'move',
          side: side,
          posA: posA,
          posB: posB
        });
      }
    }

    // 3. 交代 (控えの各スロットと左マス)
    for (let b = 0; b < gameState.bench[side].length; b++) {
      if (gameState.canSwap(side, b)) {
        actions.push({
          type: 'swap',
          side: side,
          benchIndex: b
        });
      }
    }

    return actions;
  }

  /**
   * アクションのスコア評価
   */
  evaluateAction(action, gameState, side = 'cpu') {
    const opp = gameState.getOpponent(side);
    let score = 10; // 基礎スコア

    if (action.type === 'flip') {
      const piece = gameState.board[action.targetSide][action.pos];
      if (!piece) return 0;

      if (action.targetSide === opp) {
        // 相手の駒を反転する場合
        if (piece.state === HourglassState.FALLING) {
          // 落下中の高火力駒（サンド4、ソード3等）を反転して阻止
          score += piece.data.damage * 8;
        } else if (piece.state === HourglassState.UPRIGHT) {
          // すでに上向きの相手駒を反転しても意味が薄い
          score -= 15;
        } else if (piece.state === HourglassState.FALLEN) {
          if (piece.id === 'judge') {
            score += 12; // ジャッジの継続ダメージを止める
          } else {
            score -= 5;
          }
        }

        // ウォールの場合: 反転すると反撃される
        if (piece.id === 'wall') {
          score -= 12;
        }
      } else {
        // 自分の駒を反転する場合
        if (piece.state === HourglassState.FALLEN) {
          // 落ちきった自駒を再利用するために上向きへ（高評価）
          score += 18;
        } else if (piece.state === HourglassState.FALLING) {
          // 落下中の自駒を反転するとダメージが遅れる
          score -= 10;
        } else if (piece.state === HourglassState.UPRIGHT) {
          score -= 20;
        }

        // 特殊効果の評価
        if (piece.id === 'sword') {
          // ソード反転で相手に1点ダメージ
          score += 15;
          if (gameState.hp[opp] <= 1) score += 100; // リーサル
        }
        if (piece.id === 'dash') {
          // ダッシュは即座に落下中へ進む
          score += 14;
        }
        if (piece.id === 'mirror') {
          // ミラーは右隣を上向きにする
          score += 10;
        }
      }
    } else if (action.type === 'move') {
      score += 4;
    } else if (action.type === 'swap') {
      const boardPiece = gameState.board[side][0];
      if (boardPiece.state === HourglassState.FALLEN) {
        score += 16;
      } else if (boardPiece.state === HourglassState.FALLING) {
        score -= 6;
      }
    }

    // 思考にバリエーションを持たせるための適度なランダム値
    score += (Math.random() * 8 - 4);

    return score;
  }

  /**
   * 次の手を選択
   */
  async chooseAction(gameState, side = 'cpu') {
    if (this.thinkingDelay > 0) {
      await new Promise(resolve => setTimeout(resolve, this.thinkingDelay));
    }

    const legalActions = this.getLegalActions(gameState, side);
    if (legalActions.length === 0) return null;

    if (this.difficulty === 'easy') {
      const randIdx = Math.floor(Math.random() * legalActions.length);
      return legalActions[randIdx];
    }

    let bestAction = legalActions[0];
    let maxScore = -Infinity;

    for (const action of legalActions) {
      const score = this.evaluateAction(action, gameState, side);
      if (score > maxScore) {
        maxScore = score;
        bestAction = action;
      }
    }

    return bestAction;
  }

  /**
   * CPUのランダム初期配置を生成 (全10種から5枚選び、場3枚と控え2枚に分割)
   */
  static generateCpuSetup() {
    const allIds = [...ALL_HOURGLASS_IDS];
    for (let i = allIds.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [allIds[i], allIds[j]] = [allIds[j], allIds[i]];
    }

    const cpuDeck = allIds.slice(0, 5);
    const cpuBoard = cpuDeck.slice(0, 3);
    const cpuBench = cpuDeck.slice(3, 5);

    return {
      deck: cpuDeck,
      board: cpuBoard,
      bench: cpuBench
    };
  }
}
