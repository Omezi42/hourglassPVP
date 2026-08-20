/**
 * 砂時計PvP アプリケーション メインコントローラー
 * 画面遷移・配置フェーズ・対局ループ
 */

class App {
  constructor() {
    this.ui = new GameUI();
    this.cpuBrain = new CpuBrain('normal');
    this.state = null;

    // 配置フェーズの状態
    this.playerDeck = [...DEFAULT_PLAYER_DECK];
    this.playerPlacement = []; // [pos0, pos1, pos2]
    this.cpuSetup = null;

    this.init();
  }

  init() {
    this.ui.init(this);
    this.setupPlacementScreen();
    this.setupResultScreen();
  }

  isPlayerTurn() {
    return this.state && this.state.currentTurn === 'player' && !this.state.winner && !this.ui.isAnimating;
  }

  /**
   * 配置フェーズの初期化・描画
   */
  setupPlacementScreen() {
    // プリセットボタン
    const presetBtns = document.querySelectorAll('.preset-btn');
    presetBtns.forEach(btn => {
      btn.onclick = () => {
        const presetKey = btn.dataset.preset;
        if (PRESET_DECKS[presetKey]) {
          presetBtns.forEach(b => b.classList.remove('active'));
          btn.classList.add('active');
          this.playerDeck = [...PRESET_DECKS[presetKey].cards];
          this.playerPlacement = [];
          this.renderPlacementView();
          Sound.play('button');
        }
      };
    });

    // カスタムデッキ構築トグル（10種から選択）
    this.renderCustomDeckPool();

    // CPUセットアップ生成
    this.cpuSetup = CpuBrain.generateCpuSetup();

    // 開始ボタン
    const startMatchBtn = document.getElementById('start-match-btn');
    if (startMatchBtn) {
      startMatchBtn.onclick = () => {
        if (this.playerPlacement.length === 3) {
          Sound.play('button');
          this.startMatch();
        } else {
          this.ui.showToast('場に出す3枚を左・中央・右に配置してください');
        }
      };
    }

    // ランダム配置ボタン
    const randomPlaceBtn = document.getElementById('random-placement-btn');
    if (randomPlaceBtn) {
      randomPlaceBtn.onclick = () => {
        const shuffled = [...this.playerDeck].sort(() => Math.random() - 0.5);
        this.playerPlacement = shuffled.slice(0, 3);
        this.renderPlacementView();
        Sound.play('button');
      };
    }

    // デフォルトで最初の3枚を場に配置
    this.playerPlacement = this.playerDeck.slice(0, 3);
    this.renderPlacementView();
  }

  renderCustomDeckPool() {
    const poolEl = document.getElementById('deck-builder-pool');
    if (!poolEl) return;
    poolEl.innerHTML = '';

    ALL_HOURGLASS_IDS.forEach(id => {
      const data = HOURGLASS_DEFINITIONS[id];
      const card = document.createElement('div');
      card.className = `pool-card ${this.playerDeck.includes(id) ? 'in-deck' : ''}`;
      card.innerHTML = `
        <img src="${getHourglassImagePath(id, HourglassState.UPRIGHT)}" alt="${data.name}" />
        <div class="pool-card-info">
          <span class="pool-name">${data.name}</span>
          <span class="pool-dmg">⚡${data.damage}</span>
        </div>
      `;

      card.onclick = () => {
        const inDeck = this.playerDeck.includes(id);
        if (inDeck) {
          if (this.playerDeck.length > 1) {
            this.playerDeck = this.playerDeck.filter(c => c !== id);
            this.playerPlacement = this.playerPlacement.filter(c => c !== id);
          }
        } else {
          if (this.playerDeck.length < 5) {
            this.playerDeck.push(id);
          } else {
            this.ui.showToast('デッキは5枚までです');
            return;
          }
        }
        Sound.play('button');
        document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
        this.renderCustomDeckPool();
        this.renderPlacementView();
      };

      card.oncontextmenu = (e) => {
        e.preventDefault();
        this.ui.showDetailModal(id);
      };

      poolEl.appendChild(card);
    });
  }

  renderPlacementView() {
    // 相手の公開デッキ5枚
    const cpuDeckListEl = document.getElementById('placement-cpu-deck');
    if (cpuDeckListEl && this.cpuSetup) {
      cpuDeckListEl.innerHTML = '';
      this.cpuSetup.deck.forEach(id => {
        const data = HOURGLASS_DEFINITIONS[id];
        const card = document.createElement('div');
        card.className = 'mini-preview-card';
        card.innerHTML = `
          <img src="${getHourglassImagePath(id, HourglassState.UPRIGHT)}" alt="${data.name}" />
          <span>${data.name}</span>
        `;
        card.onclick = () => this.ui.showDetailModal(id);
        cpuDeckListEl.appendChild(card);
      });
    }

    // プレイヤーの場 3マス
    for (let pos = 0; pos < 3; pos++) {
      const slot = document.getElementById(`placement-slot-${pos}`);
      if (!slot) continue;
      slot.innerHTML = '';
      const placedId = this.playerPlacement[pos];

      if (placedId) {
        const data = HOURGLASS_DEFINITIONS[placedId];
        slot.className = 'placement-board-slot filled';
        slot.innerHTML = `
          <img src="${getHourglassImagePath(placedId, HourglassState.UPRIGHT)}" />
          <div class="pos-badge">${['左(入口)', '中央', '右'][pos]}</div>
          <div class="card-title">${data.name} (⚡${data.damage})</div>
          <button class="remove-place-btn">✕</button>
        `;
        slot.querySelector('.remove-place-btn').onclick = (e) => {
          e.stopPropagation();
          this.playerPlacement.splice(pos, 1);
          this.renderPlacementView();
          Sound.play('button');
        };
      } else {
        slot.className = 'placement-board-slot empty';
        slot.innerHTML = `
          <div class="empty-hint">${['左マス (交代入口)', '中央マス', '右マス'][pos]}</div>
          <div class="select-cue">手札から選択</div>
        `;
      }

      slot.onclick = () => {
        // 空いていれば手札から未配置のものを追加
        if (!this.playerPlacement[pos]) {
          const unplaced = this.playerDeck.find(id => !this.playerPlacement.includes(id));
          if (unplaced) {
            this.playerPlacement[pos] = unplaced;
            this.renderPlacementView();
            Sound.play('button');
          }
        }
      };
    }

    // プレイヤーの手札（デッキ5枚一覧）
    const handEl = document.getElementById('placement-hand-cards');
    if (handEl) {
      handEl.innerHTML = '';
      this.playerDeck.forEach(id => {
        const data = HOURGLASS_DEFINITIONS[id];
        const isPlaced = this.playerPlacement.includes(id);
        const placedIndex = this.playerPlacement.indexOf(id);

        const card = document.createElement('div');
        card.className = `placement-hand-card ${isPlaced ? 'placed' : 'available'}`;
        card.innerHTML = `
          <img src="${getHourglassImagePath(id, HourglassState.UPRIGHT)}" alt="${data.name}" />
          <div class="hand-card-info">
            <span class="hand-card-name">${data.name}</span>
            <span class="hand-card-dmg">⚡${data.damage}</span>
          </div>
          ${isPlaced ? `<div class="placed-tag">${['左', '中央', '右'][placedIndex]}に配置中</div>` : `<div class="bench-tag">控え予定</div>`}
        `;

        card.onclick = () => {
          if (isPlaced) {
            // 配置解除
            this.playerPlacement.splice(placedIndex, 1);
            this.renderPlacementView();
            Sound.play('button');
          } else {
            // 空いているマスへ配置
            if (this.playerPlacement.length < 3) {
              this.playerPlacement.push(id);
              this.renderPlacementView();
              Sound.play('button');
            } else {
              this.ui.showToast('場は3マスまでです。配置中の駒を外してから選択してください');
            }
          }
        };

        card.oncontextmenu = (e) => {
          e.preventDefault();
          this.ui.showDetailModal(id);
        };

        handEl.appendChild(card);
      });
    }

    // 開始ボタンの活性化チェック
    const startBtn = document.getElementById('start-match-btn');
    if (startBtn) {
      startBtn.disabled = this.playerPlacement.length !== 3;
    }
  }

  /**
   * 対局開始
   */
  startMatch() {
    document.getElementById('screen-placement').classList.add('hidden');
    document.getElementById('screen-match').classList.remove('hidden');

    this.state = new GameState(
      this.playerDeck,
      this.cpuSetup.deck,
      this.playerPlacement,
      this.cpuSetup.board
    );

    this.ui.clearSelection();
    this.ui.renderBoard(this.state);
    this.ui.showToast('対局開始！あなたの手番です');
  }

  /**
   * プレイヤーアクション実行: 反転
   */
  async executeFlip(targetSide, pos) {
    if (!this.isPlayerTurn()) return;

    const res = this.state.flip(targetSide, pos, 'player');
    if (!res.success) {
      this.ui.showToast(res.reason);
      return;
    }

    // UI反映
    this.ui.renderBoard(this.state);

    // ダメージ等の演出
    for (const ev of res.events) {
      if (ev.type === 'effect_damage' || ev.type === 'counter_damage') {
        this.ui.showDamageFloatingText(ev.targetSide, ev.damage, ev.pos);
        this.ui.updateHp(this.state);
      }
    }

    // 勝敗チェック
    if (this.checkMatchEnd()) return;

    // ターン終了＆次ターンへ
    await this.processTurnTransition();
  }

  /**
   * プレイヤーアクション実行: 移動
   */
  async executeMove(posA, posB) {
    if (!this.isPlayerTurn()) return;

    const res = this.state.move('player', posA, posB);
    if (!res.success) {
      this.ui.showToast(res.reason);
      return;
    }

    this.ui.renderBoard(this.state);

    if (this.checkMatchEnd()) return;

    await this.processTurnTransition();
  }

  /**
   * プレイヤーアクション実行: 交代
   */
  async executeSwap(benchIndex) {
    if (!this.isPlayerTurn()) return;

    const res = this.state.swap('player', benchIndex);
    if (!res.success) {
      this.ui.showToast(res.reason);
      return;
    }

    this.ui.renderBoard(this.state);

    if (this.checkMatchEnd()) return;

    await this.processTurnTransition();
  }

  /**
   * サレンダー
   */
  surrender(side) {
    if (!this.state || this.state.winner) return;
    this.state.surrender(side);
    this.ui.renderBoard(this.state);
    this.checkMatchEnd();
  }

  /**
   * 手番移行と砂時計進行アニメーション
   */
  async processTurnTransition() {
    // ターン開始処理 (手番交代＋進行)
    const turnResult = this.state.beginNextTurn();
    if (!turnResult) return;

    // 砂時計進行ステップを左から順にアニメーション表示
    if (turnResult.steps && turnResult.steps.length > 0) {
      await this.ui.playTurnAdvanceSteps(turnResult.steps, this.state);
    } else {
      this.ui.renderBoard(this.state);
    }

    if (this.checkMatchEnd()) return;

    // CPUの手番ならCPU思考を実行
    if (this.state.currentTurn === 'cpu') {
      await this.processCpuTurn();
    }
  }

  /**
   * CPU手番の実行
   */
  async processCpuTurn() {
    if (this.state.winner) return;

    // CPU思考（0.6秒ディレイ含む）
    const action = await this.cpuBrain.chooseAction(this.state, 'cpu');
    if (!action || this.state.winner) return;

    if (action.type === 'flip') {
      Sound.play('flip');
      const res = this.state.flip(action.targetSide, action.pos, 'cpu');
      this.ui.renderBoard(this.state);
      if (res.events) {
        for (const ev of res.events) {
          if (ev.type === 'effect_damage' || ev.type === 'counter_damage') {
            this.ui.showDamageFloatingText(ev.targetSide, ev.damage, ev.pos);
            this.ui.updateHp(this.state);
          }
        }
      }
    } else if (action.type === 'move') {
      Sound.play('move');
      this.state.move('cpu', action.posA, action.posB);
      this.ui.renderBoard(this.state);
    } else if (action.type === 'swap') {
      Sound.play('swap');
      this.state.swap('cpu', action.benchIndex);
      this.ui.renderBoard(this.state);
    }

    if (this.checkMatchEnd()) return;

    // プレイヤーの手番へ移行
    await this.processTurnTransition();
  }

  /**
   * 終局判定
   */
  checkMatchEnd() {
    if (!this.state) return false;
    const winner = this.state.checkWinner();
    if (winner) {
      this.ui.renderBoard(this.state);
      setTimeout(() => {
        this.ui.showResultOverlay(winner, this.state);
      }, 500);
      return true;
    }
    return false;
  }

  setupResultScreen() {
    const rematchBtn = document.getElementById('rematch-btn');
    if (rematchBtn) {
      rematchBtn.onclick = () => {
        Sound.play('button');
        this.ui.hideResultOverlay();
        // CPUの配置を再生成してリマッチ
        this.cpuSetup = CpuBrain.generateCpuSetup();
        this.startMatch();
      };
    }

    const backToPlacementBtn = document.getElementById('back-to-placement-btn');
    if (backToPlacementBtn) {
      backToPlacementBtn.onclick = () => {
        Sound.play('button');
        this.ui.hideResultOverlay();
        document.getElementById('screen-match').classList.add('hidden');
        document.getElementById('screen-placement').classList.remove('hidden');
        this.cpuSetup = CpuBrain.generateCpuSetup();
        this.renderPlacementView();
      };
    }
  }
}

// 起動
window.addEventListener('DOMContentLoaded', () => {
  window.gameApp = new App();
});
