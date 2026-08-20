/**
 * 砂時計PvP ゲームロジック層 (GameState & EffectResolver)
 * docs/GameDesign.md & docs/Architecture.md 準拠
 */

class HourglassInstance {
  constructor(id, state = HourglassState.UPRIGHT) {
    this.id = id;
    this.data = HOURGLASS_DEFINITIONS[id] || {
      id: id,
      name: id,
      damage: 0,
      description: '',
      effects: []
    };
    this.state = state;
    this.locked = false; // アイによるロック状態
  }

  clone() {
    const inst = new HourglassInstance(this.id, this.state);
    inst.locked = this.locked;
    return inst;
  }
}

class GameState {
  constructor(playerDeck, cpuDeck, playerPlacement, cpuPlacement) {
    // playerDeck, cpuDeck: 5つのID配列
    // playerPlacement, cpuPlacement: 3つのID配列 (左・中央・右)
    this.hp = {
      player: 20,
      cpu: 20
    };
    this.maxHp = 20;
    this.currentTurn = 'player'; // プレイヤー先手固定 (GameDesign.md 13章)
    this.turnNumber = 1;
    this.hasAdvanced = false; // 初回ターン進行スキップ用
    this.winner = null; // 'player', 'cpu', または null
    this.isSurrendered = false;
    this.totalMoves = 0;
    this.logs = [];

    // 盤面初期化 (全て上向きスタート: GameDesign.md 2章)
    this.board = {
      player: playerPlacement.map(id => new HourglassInstance(id, HourglassState.UPRIGHT)),
      cpu: cpuPlacement.map(id => new HourglassInstance(id, HourglassState.UPRIGHT))
    };

    // 控え初期化 (デッキ5枚から場3枚を除いた2枚)
    const playerBenchIds = playerDeck.filter(id => !playerPlacement.includes(id));
    // 重複駒に対応するための正確な差分計算
    const pDeckCopy = [...playerDeck];
    playerPlacement.forEach(id => {
      const idx = pDeckCopy.indexOf(id);
      if (idx !== -1) pDeckCopy.splice(idx, 1);
    });
    this.bench = {
      player: pDeckCopy.map(id => new HourglassInstance(id, HourglassState.UPRIGHT)),
      cpu: []
    };

    const cDeckCopy = [...cpuDeck];
    cpuPlacement.forEach(id => {
      const idx = cDeckCopy.indexOf(id);
      if (idx !== -1) cDeckCopy.splice(idx, 1);
    });
    this.bench.cpu = cDeckCopy.map(id => new HourglassInstance(id, HourglassState.UPRIGHT));

    this.updateLocks();
    this.addLog(`--- 第1ターン (プレイヤーの手番) ---`, 'turn');
  }

  addLog(message, type = 'info') {
    const entry = {
      turn: this.turnNumber,
      side: this.currentTurn,
      text: message,
      type: type,
      time: new Date().toLocaleTimeString()
    };
    this.logs.push(entry);
    return entry;
  }

  getOpponent(side) {
    return side === 'player' ? 'cpu' : 'player';
  }

  /**
   * 被ダメージ軽減の計算
   * 防御側の「落下中」のキング・シールドの数をカウント
   */
  calculateDamageReduction(targetSide) {
    let reduction = 0;
    const board = this.board[targetSide];
    for (let pos = 0; pos < 3; pos++) {
      const piece = board[pos];
      if (piece && piece.state === HourglassState.FALLING) {
        for (const eff of piece.data.effects) {
          if (eff.trigger === TriggerType.WHILE_FALLING && eff.type === EffectType.DAMAGE_REDUCTION) {
            reduction += eff.value;
          }
        }
      }
    }
    return reduction;
  }

  /**
   * ダメージ適用（軽減処理含む）
   */
  applyDamage(targetSide, rawDamage, sourceName = '', isDirect = false) {
    if (rawDamage <= 0 || this.winner) {
      return { actualDamage: 0, reduction: 0, targetSide, targetHp: this.hp[targetSide] };
    }

    const reduction = isDirect ? 0 : this.calculateDamageReduction(targetSide);
    const actualDamage = Math.max(0, rawDamage - reduction);
    this.hp[targetSide] = Math.max(0, this.hp[targetSide] - actualDamage);

    const sideName = targetSide === 'player' ? 'プレイヤー' : 'CPU';
    let logText = `${sideName}に ${actualDamage} ダメージ！`;
    if (reduction > 0) {
      logText += ` (軽減 -${reduction})`;
    }
    if (sourceName) {
      logText = `[${sourceName}] ${logText}`;
    }
    this.addLog(logText, 'damage');

    this.checkWinner();

    return {
      actualDamage,
      reduction,
      targetSide,
      targetHp: this.hp[targetSide]
    };
  }

  checkWinner() {
    if (this.winner) return this.winner;
    if (this.hp.player <= 0 && this.hp.cpu <= 0) {
      // 同時ノックアウト時は手番側敗北または後手勝利（通常先起きで判定）
      this.winner = this.currentTurn === 'player' ? 'cpu' : 'player';
    } else if (this.hp.player <= 0) {
      this.winner = 'cpu';
    } else if (this.hp.cpu <= 0) {
      this.winner = 'player';
    }
    if (this.winner) {
      const winnerName = this.winner === 'player' ? 'プレイヤー' : 'CPU';
      this.addLog(`決着！ ${winnerName}の勝利！`, 'result');
    }
    return this.winner;
  }

  surrender(side) {
    if (this.winner) return;
    this.isSurrendered = true;
    this.winner = this.getOpponent(side);
    const sideName = side === 'player' ? 'プレイヤー' : 'CPU';
    this.addLog(`${sideName}が投了しました。`, 'result');
  }

  /**
   * ロック状態（アイの効果）を盤面全体で更新
   */
  updateLocks() {
    // 全駒のロックを初期化
    for (const side of ['player', 'cpu']) {
      for (let pos = 0; pos < 3; pos++) {
        if (this.board[side][pos]) {
          this.board[side][pos].locked = false;
        }
      }
    }

    // アイ(eye)がFALLINGなら正面(OPPONENT_MIRROR)をロック
    for (const side of ['player', 'cpu']) {
      const opp = this.getOpponent(side);
      for (let pos = 0; pos < 3; pos++) {
        const piece = this.board[side][pos];
        if (piece && piece.id === 'eye' && piece.state === HourglassState.FALLING) {
          if (this.board[opp][pos]) {
            this.board[opp][pos].locked = true;
          }
        }
      }
    }
  }

  /**
   * アクション: 反転 (FLIP)
   */
  canFlip(targetSide, pos) {
    if (this.winner) return false;
    const piece = this.board[targetSide][pos];
    if (!piece) return false;
    if (piece.locked) return false;
    return true;
  }

  flip(targetSide, pos, actorSide) {
    if (!this.canFlip(targetSide, pos)) {
      return { success: false, reason: 'ロックされているか無効なマスです' };
    }

    const piece = this.board[targetSide][pos];
    const prevPieceName = piece.data.name;
    const actorName = actorSide === 'player' ? 'プレイヤー' : 'CPU';
    const targetSideName = targetSide === 'player' ? '自陣' : '敵陣';

    // 反転実行: 上向きに戻す
    piece.state = HourglassState.UPRIGHT;
    this.totalMoves++;

    const events = [];
    events.push({
      type: 'flip',
      side: targetSide,
      pos: pos,
      piece: piece
    });

    this.addLog(`${actorName}が ${targetSideName}[${['左','中央','右'][pos]}]の「${prevPieceName}」を反転`, 'action');

    // 1. カウンター判定: wallが相手によって反転された場合
    if (piece.id === 'wall' && actorSide !== targetSide) {
      // 反転させた側(actorSide)に1ダメージ
      const dmgRes = this.applyDamage(actorSide, 1, 'ウォール 反撃', true);
      events.push({
        type: 'counter_damage',
        targetSide: actorSide,
        damage: dmgRes.actualDamage,
        source: 'wall',
        pos: pos
      });
    }

    // 2. ON_FLIP 効果判定
    for (const eff of piece.data.effects) {
      if (eff.trigger === TriggerType.ON_FLIP) {
        if (eff.type === EffectType.DAMAGE && eff.target === TargetType.OPPONENT_PLAYER) {
          // ソードなど: 反転した側の相手プレイヤーにダメージ
          const oppSide = this.getOpponent(actorSide);
          const dmgRes = this.applyDamage(oppSide, eff.value, `${piece.data.name} 反転効果`);
          events.push({
            type: 'effect_damage',
            targetSide: oppSide,
            damage: dmgRes.actualDamage,
            source: piece.id,
            pos: pos
          });
        } else if (eff.type === EffectType.FORCE_ADVANCE && eff.target === TargetType.SELF) {
          // ダッシュ: 即座に次状態(上向き→落下中)へ進める
          piece.state = HourglassState.FALLING;
          this.addLog(`[ダッシュ] 即座に落下中へ進行！`, 'effect');
          events.push({
            type: 'state_change',
            side: targetSide,
            pos: pos,
            newState: HourglassState.FALLING
          });
        } else if (eff.type === EffectType.SYNC_STATE && eff.target === TargetType.ADJACENT_RIGHT) {
          // ミラー(→): 右隣(pos + 1)の状態を自分(UPRIGHT)に揃える
          const rightPos = pos + 1;
          if (rightPos < 3 && this.board[targetSide][rightPos]) {
            const targetPiece = this.board[targetSide][rightPos];
            targetPiece.state = piece.state; // UPRIGHT
            this.addLog(`[ミラー] 右隣の「${targetPiece.data.name}」を上向きに揃えた！`, 'effect');
            events.push({
              type: 'state_change',
              side: targetSide,
              pos: rightPos,
              newState: targetPiece.state
            });
          }
        }
      }
    }

    this.updateLocks();

    return {
      success: true,
      events: events
    };
  }

  /**
   * アクション: 移動 (MOVE)
   */
  canMove(side, posA, posB) {
    if (this.winner) return false;
    if (posA === posB) return false;
    if (posA < 0 || posA > 2 || posB < 0 || posB > 2) return false;
    return !!(this.board[side][posA] && this.board[side][posB]);
  }

  move(side, posA, posB) {
    if (!this.canMove(side, posA, posB)) {
      return { success: false, reason: '無効な移動です' };
    }

    const temp = this.board[side][posA];
    this.board[side][posA] = this.board[side][posB];
    this.board[side][posB] = temp;
    this.totalMoves++;

    const sideName = side === 'player' ? 'プレイヤー' : 'CPU';
    const posNames = ['左', '中央', '右'];
    this.addLog(`${sideName}が [${posNames[posA]}] と [${posNames[posB]}] を入れ替え`, 'action');

    this.updateLocks();

    return {
      success: true,
      events: [
        {
          type: 'move',
          side: side,
          posA: posA,
          posB: posB
        }
      ]
    };
  }

  /**
   * アクション: 交代 (SWAP)
   * 左マス(pos 0)と控え(benchIndex)を入れ替え
   */
  canSwap(side, benchIndex) {
    if (this.winner) return false;
    if (benchIndex < 0 || benchIndex >= this.bench[side].length) return false;
    return !!(this.board[side][0] && this.bench[side][benchIndex]);
  }

  swap(side, benchIndex) {
    if (!this.canSwap(side, benchIndex)) {
      return { success: false, reason: '無効な交代です' };
    }

    const oldBoardPiece = this.board[side][0];
    const newPiece = this.bench[side][benchIndex];

    // 新しく出た駒は上向きスタート (GameDesign.md 4.3)
    newPiece.state = HourglassState.UPRIGHT;

    this.board[side][0] = newPiece;
    this.bench[side][benchIndex] = oldBoardPiece;
    this.totalMoves++;

    const sideName = side === 'player' ? 'プレイヤー' : 'CPU';
    this.addLog(`${sideName}が控えの「${newPiece.data.name}」を左マスへ交代出場`, 'action');

    this.updateLocks();

    return {
      success: true,
      events: [
        {
          type: 'swap',
          side: side,
          benchIndex: benchIndex,
          newPiece: newPiece,
          oldPiece: oldBoardPiece
        }
      ]
    };
  }

  /**
   * ターン終了＆次ターンの開始進行処理
   * GameDesign.md 2章 & 9章:
   * 「自分の手番が来るたびに、自分陣営の砂時計だけが自動で1段階進行する」
   * 「左のマスから順に1つずつ解決」
   */
  beginNextTurn() {
    if (this.winner) return null;

    // 手番交代
    this.currentTurn = this.getOpponent(this.currentTurn);
    if (this.currentTurn === 'player') {
      this.turnNumber++;
    }

    const activeSide = this.currentTurn;
    const sideName = activeSide === 'player' ? 'プレイヤー' : 'CPU';

    this.addLog(`--- 第${this.turnNumber}ターン (${sideName}の手番) ---`, 'turn');

    const steps = [];

    // 手番側陣営の砂時計を左から順に解決 (pos: 0, 1, 2)
    for (let pos = 0; pos < 3; pos++) {
      if (this.winner) break;

      const piece = this.board[activeSide][pos];
      if (!piece) continue;

      const step = {
        pos: pos,
        side: activeSide,
        pieceId: piece.id,
        pieceName: piece.data.name,
        fromState: piece.state,
        toState: piece.state,
        damageEvents: [],
        effectEvents: []
      };

      const posName = ['左', '中央', '右'][pos];

      // 1. 状態遷移
      if (piece.state === HourglassState.UPRIGHT) {
        piece.state = HourglassState.FALLING;
        step.toState = HourglassState.FALLING;
        this.addLog(`[${posName}]「${piece.data.name}」が 落下中 に進行`, 'step');
      } else if (piece.state === HourglassState.FALLING) {
        piece.state = HourglassState.FALLEN;
        step.toState = HourglassState.FALLEN;
        this.addLog(`[${posName}]「${piece.data.name}」が 落ちきり に到達！`, 'step');

        // 落ちきり到達時: 基礎落下ダメージを相手に与える
        const oppSide = this.getOpponent(activeSide);
        if (piece.data.damage > 0) {
          const dmgRes = this.applyDamage(oppSide, piece.data.damage, `${piece.data.name} 落下ダメージ`);
          step.damageEvents.push({
            targetSide: oppSide,
            damage: dmgRes.actualDamage,
            source: 'fall_damage'
          });
        }

        // ON_FALLEN 効果発動
        for (const eff of piece.data.effects) {
          if (eff.trigger === TriggerType.ON_FALLEN) {
            if (eff.type === EffectType.DAMAGE && eff.target === TargetType.OWN_PLAYER) {
              // キング: 自分に2ダメージ
              const selfDmg = this.applyDamage(activeSide, eff.value, `${piece.data.name} 落ちきり自傷`);
              step.damageEvents.push({
                targetSide: activeSide,
                damage: selfDmg.actualDamage,
                source: 'self_damage'
              });
            } else if (eff.type === EffectType.RECOVER && eff.target === TargetType.RANDOM_ALLY) {
              // エコー: 味方ランダム1個を上向きに戻す
              const allyIndices = [];
              for (let p = 0; p < 3; p++) {
                if (p !== pos && this.board[activeSide][p]) {
                  allyIndices.push(p);
                }
              }
              if (allyIndices.length > 0) {
                const pickPos = allyIndices[Math.floor(Math.random() * allyIndices.length)];
                const targetAlly = this.board[activeSide][pickPos];
                targetAlly.state = HourglassState.UPRIGHT;
                this.addLog(`[エコー] 味方[${['左','中央','右'][pickPos]}]「${targetAlly.data.name}」を上向きに回復！`, 'effect');
                step.effectEvents.push({
                  type: 'recover',
                  targetSide: activeSide,
                  targetPos: pickPos
                });
              }
            }
          }
        }
      } else if (piece.state === HourglassState.FALLEN) {
        // すでに落ちきり状態の場合
        // WHILE_FALLEN 効果 (ジャッジ: 毎ターン相手に1ダメージ)
        for (const eff of piece.data.effects) {
          if (eff.trigger === TriggerType.WHILE_FALLEN && eff.type === EffectType.DAMAGE && eff.target === TargetType.OPPONENT_PLAYER) {
            const oppSide = this.getOpponent(activeSide);
            const judgeDmg = this.applyDamage(oppSide, eff.value, `${piece.data.name} 継続ダメージ`);
            step.damageEvents.push({
              targetSide: oppSide,
              damage: judgeDmg.actualDamage,
              source: 'judge_damage'
            });
          }
        }
      }

      steps.push(step);
      this.updateLocks();
    }

    return {
      turnNumber: this.turnNumber,
      currentTurn: activeSide,
      steps: steps
    };
  }
}
