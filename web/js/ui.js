/**
 * 砂時計PvP UI層
 * docs/GameDesign.md & docs/Architecture.md 準拠
 */

class GameUI {
  constructor() {
    this.app = null; // Appインスタンス
    this.selectedTarget = null; // { type: 'board'|'bench', side: 'player'|'cpu', pos: 0|1|2, benchIndex: 0|1 }
    this.moveSourcePos = null; // 移動元マス
    this.isAnimating = false; // 進行アニメーション中は操作ロック
  }

  init(app) {
    this.app = app;
    this.bindEvents();
  }

  bindEvents() {
    // 画面外クリックでポップアップ閉じる
    document.addEventListener('click', (e) => {
      if (this.isAnimating) return;
      const actionMenu = document.getElementById('action-menu');
      const isCardOrSlot = e.target.closest('.hourglass-slot, .bench-slot, .action-menu, .modal-content');
      if (!isCardOrSlot && actionMenu && !actionMenu.classList.contains('hidden')) {
        this.clearSelection();
      }
    });

    // モーダル閉じる
    const modalClose = document.getElementById('modal-close');
    if (modalClose) {
      modalClose.addEventListener('click', () => {
        this.hideDetailModal();
      });
    }

    const detailModal = document.getElementById('detail-modal');
    if (detailModal) {
      detailModal.addEventListener('click', (e) => {
        if (e.target === detailModal) {
          this.hideDetailModal();
        }
      });
    }

    // ログトグル
    const logToggleBtn = document.getElementById('log-toggle-btn');
    if (logToggleBtn) {
      logToggleBtn.addEventListener('click', () => {
        const logDrawer = document.getElementById('log-drawer');
        if (logDrawer) {
          logDrawer.classList.toggle('open');
        }
      });
    }

    const logCloseBtn = document.getElementById('log-close-btn');
    if (logCloseBtn) {
      logCloseBtn.addEventListener('click', () => {
        const logDrawer = document.getElementById('log-drawer');
        if (logDrawer) {
          logDrawer.classList.remove('open');
        }
      });
    }

    // 音量・ミュートボタン
    const muteBtn = document.getElementById('mute-btn');
    if (muteBtn) {
      muteBtn.addEventListener('click', () => {
        const isMuted = Sound.toggleMute();
        muteBtn.textContent = isMuted ? '🔇 消音中' : '🔊 音声ON';
        muteBtn.classList.toggle('muted', isMuted);
        Sound.play('button');
      });
    }

    // サレンダーボタン
    const surrenderBtn = document.getElementById('surrender-btn');
    if (surrenderBtn) {
      surrenderBtn.addEventListener('click', () => {
        if (this.app.state && !this.app.state.winner) {
          if (confirm('本当に投了（サレンダー）しますか？')) {
            Sound.play('button');
            this.app.surrender('player');
          }
        }
      });
    }
  }

  clearSelection() {
    this.selectedTarget = null;
    this.moveSourcePos = null;
    const actionMenu = document.getElementById('action-menu');
    if (actionMenu) actionMenu.classList.add('hidden');

    document.querySelectorAll('.hourglass-slot, .bench-slot').forEach(el => {
      el.classList.remove('selected', 'move-highlight', 'target-highlight');
    });
  }

  /**
   * HPバー更新
   */
  updateHp(state) {
    for (const side of ['player', 'cpu']) {
      const hp = state.hp[side];
      const maxHp = state.maxHp;
      const pct = Math.max(0, Math.min(100, (hp / maxHp) * 100));

      const barEl = document.getElementById(`${side}-hp-bar`);
      const valEl = document.getElementById(`${side}-hp-val`);
      const boxEl = document.getElementById(`${side}-hp-box`);

      if (barEl) {
        barEl.style.width = `${pct}%`;
        // 残量に応じた色の切り替え (GameDesign.md 9章: 琥珀〜危険域で赤)
        if (pct <= 30) {
          barEl.style.background = 'linear-gradient(90deg, #ef4444, #dc2626)';
        } else if (pct <= 60) {
          barEl.style.background = 'linear-gradient(90deg, #f59e0b, #d97706)';
        } else {
          barEl.style.background = 'linear-gradient(90deg, #eab308, #ca8a04)';
        }
      }
      if (valEl) {
        valEl.textContent = `${hp} / ${maxHp}`;
      }
      if (boxEl && pct <= 30) {
        boxEl.classList.add('danger');
      } else if (boxEl) {
        boxEl.classList.remove('danger');
      }
    }
  }

  /**
   * 盤面・控えの全スロット描画
   */
  renderBoard(state) {
    this.updateHp(state);
    this.updateTurnIndicator(state);

    // 相手側盤面
    for (let pos = 0; pos < 3; pos++) {
      const slot = document.getElementById(`cpu-slot-${pos}`);
      const piece = state.board.cpu[pos];
      this.renderSlotContent(slot, piece, 'cpu', pos);
    }

    // 自分側盤面
    for (let pos = 0; pos < 3; pos++) {
      const slot = document.getElementById(`player-slot-${pos}`);
      const piece = state.board.player[pos];
      this.renderSlotContent(slot, piece, 'player', pos);
    }

    // 控えスロット
    for (let b = 0; b < 2; b++) {
      const slot = document.getElementById(`player-bench-${b}`);
      const piece = state.bench.player[b];
      this.renderBenchSlot(slot, piece, 'player', b);
    }

    // 相手控えスロット (控え情報)
    for (let b = 0; b < 2; b++) {
      const slot = document.getElementById(`cpu-bench-${b}`);
      const piece = state.bench.cpu[b];
      this.renderBenchSlot(slot, piece, 'cpu', b);
    }

    this.renderLogs(state);
  }

  renderSlotContent(slotEl, piece, side, pos) {
    if (!slotEl) return;
    slotEl.innerHTML = '';
    slotEl.className = `hourglass-slot ${side}-slot`;

    if (!piece) {
      slotEl.innerHTML = '<div class="empty-slot">空</div>';
      return;
    }

    if (piece.locked) {
      slotEl.classList.add('locked');
    }

    // 状態クラス
    slotEl.classList.add(`state-${piece.state.toLowerCase()}`);

    // 台座
    const pedestal = document.createElement('div');
    pedestal.className = 'slot-pedestal';
    slotEl.appendChild(pedestal);

    // 画像
    const img = document.createElement('img');
    img.className = 'hourglass-img';
    img.src = getHourglassImagePath(piece.id, piece.state);
    img.alt = piece.data.name;
    slotEl.appendChild(img);

    // ダメージバッジ
    const badge = document.createElement('div');
    badge.className = 'damage-badge';
    badge.innerHTML = `<span class="dmg-icon">⚡</span>${piece.data.damage}`;
    slotEl.appendChild(badge);

    // 名前ラベル
    const nameLabel = document.createElement('div');
    nameLabel.className = 'piece-name';
    nameLabel.textContent = piece.data.name;
    slotEl.appendChild(nameLabel);

    // 状態インジケータ
    const stateLabel = document.createElement('div');
    stateLabel.className = 'state-badge';
    if (piece.state === HourglassState.UPRIGHT) {
      stateLabel.textContent = '上向き';
    } else if (piece.state === HourglassState.FALLING) {
      stateLabel.textContent = '落下中';
    } else {
      stateLabel.textContent = '落ちきり';
    }
    slotEl.appendChild(stateLabel);

    // ロックアイコン
    if (piece.locked) {
      const lockIcon = document.createElement('div');
      lockIcon.className = 'lock-overlay';
      lockIcon.innerHTML = '🔒 反転不可';
      slotEl.appendChild(lockIcon);
    }

    // クリックイベント
    slotEl.onclick = (e) => {
      e.stopPropagation();
      this.handleSlotClick(side, pos, slotEl);
    };

    // 右クリックで詳細確認
    slotEl.oncontextmenu = (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.showDetailModal(piece.id);
    };
  }

  renderBenchSlot(slotEl, piece, side, index) {
    if (!slotEl) return;
    slotEl.innerHTML = '';
    slotEl.className = `bench-slot ${side}-bench`;

    if (!piece) {
      slotEl.innerHTML = '<div class="empty-slot">控</div>';
      return;
    }

    const img = document.createElement('img');
    img.className = 'bench-img';
    img.src = getHourglassImagePath(piece.id, HourglassState.UPRIGHT);
    img.alt = piece.data.name;
    slotEl.appendChild(img);

    const name = document.createElement('span');
    name.className = 'bench-name';
    name.textContent = piece.data.name;
    slotEl.appendChild(name);

    if (side === 'player') {
      slotEl.onclick = (e) => {
        e.stopPropagation();
        this.handleBenchClick(index, slotEl);
      };
    }

    slotEl.oncontextmenu = (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.showDetailModal(piece.id);
    };
  }

  /**
   * スロットクリック時の挙動
   */
  handleSlotClick(side, pos, slotEl) {
    if (this.isAnimating || !this.app.isPlayerTurn()) {
      // 相手のターン中のクリック時は拒否アニメーション (GameDesign.md 9章: 左右に揺れる)
      slotEl.classList.remove('shake');
      void slotEl.offsetWidth; // リフロー
      slotEl.classList.add('shake');
      return;
    }

    // 移動モード中の場合（移動先選択）
    if (this.moveSourcePos !== null) {
      if (side === 'player' && pos !== this.moveSourcePos) {
        Sound.play('move');
        this.app.executeMove(this.moveSourcePos, pos);
        this.clearSelection();
        return;
      } else {
        // 移動キャンセル
        this.clearSelection();
        return;
      }
    }

    // 通常選択
    this.clearSelection();
    this.selectedTarget = { type: 'board', side, pos };
    slotEl.classList.add('selected');

    // ポップアップアクションメニュー表示
    this.showActionMenu(slotEl, side, pos);
    Sound.play('button');
  }

  handleBenchClick(index, slotEl) {
    if (this.isAnimating || !this.app.isPlayerTurn()) return;
    this.clearSelection();
    this.selectedTarget = { type: 'bench', side: 'player', benchIndex: index };
    slotEl.classList.add('selected');

    this.showBenchActionMenu(slotEl, index);
    Sound.play('button');
  }

  /**
   * アクションメニュー（駒の近くにポップアップ表示）
   */
  showActionMenu(anchorEl, side, pos) {
    const actionMenu = document.getElementById('action-menu');
    if (!actionMenu) return;

    actionMenu.innerHTML = '';
    actionMenu.classList.remove('hidden');

    const rect = anchorEl.getBoundingClientRect();
    const isPlayer = side === 'player';

    // 位置設定: プレイヤー側は駒の上、CPU側は駒の下に表示 (Architecture.md 4章)
    if (isPlayer) {
      actionMenu.style.top = `${rect.top - 54}px`;
      actionMenu.style.left = `${rect.left + rect.width / 2}px`;
    } else {
      actionMenu.style.top = `${rect.bottom + 10}px`;
      actionMenu.style.left = `${rect.left + rect.width / 2}px`;
    }

    const piece = this.app.state.board[side][pos];

    // 1. 反転ボタン (自他問わず)
    const flipBtn = document.createElement('button');
    flipBtn.className = 'menu-btn flip-btn';
    flipBtn.innerHTML = '🔄 反転';
    if (!this.app.state.canFlip(side, pos)) {
      flipBtn.disabled = true;
      flipBtn.title = 'ロック中または無効';
    } else {
      flipBtn.onclick = (e) => {
        e.stopPropagation();
        Sound.play('flip');
        this.app.executeFlip(side, pos);
        this.clearSelection();
      };
    }
    actionMenu.appendChild(flipBtn);

    // 2. 移動ボタン (自陣のみ)
    if (isPlayer) {
      const moveBtn = document.createElement('button');
      moveBtn.className = 'menu-btn move-btn';
      moveBtn.innerHTML = '⇄ 移動';
      moveBtn.onclick = (e) => {
        e.stopPropagation();
        this.startMoveMode(pos);
      };
      actionMenu.appendChild(moveBtn);
    }

    // 3. 詳細ボタン
    const infoBtn = document.createElement('button');
    infoBtn.className = 'menu-btn info-btn';
    infoBtn.innerHTML = 'ℹ️ 詳細';
    infoBtn.onclick = (e) => {
      e.stopPropagation();
      this.showDetailModal(piece.id);
      this.clearSelection();
    };
    actionMenu.appendChild(infoBtn);
  }

  showBenchActionMenu(anchorEl, benchIndex) {
    const actionMenu = document.getElementById('action-menu');
    if (!actionMenu) return;

    actionMenu.innerHTML = '';
    actionMenu.classList.remove('hidden');

    const rect = anchorEl.getBoundingClientRect();
    actionMenu.style.top = `${rect.top - 54}px`;
    actionMenu.style.left = `${rect.left + rect.width / 2}px`;

    const piece = this.app.state.bench.player[benchIndex];

    // 交代ボタン
    const swapBtn = document.createElement('button');
    swapBtn.className = 'menu-btn swap-btn';
    swapBtn.innerHTML = '🔄 左マスと交代';
    if (!this.app.state.canSwap('player', benchIndex)) {
      swapBtn.disabled = true;
    } else {
      swapBtn.onclick = (e) => {
        e.stopPropagation();
        Sound.play('swap');
        this.app.executeSwap(benchIndex);
        this.clearSelection();
      };
    }
    actionMenu.appendChild(swapBtn);

    // 詳細ボタン
    const infoBtn = document.createElement('button');
    infoBtn.className = 'menu-btn info-btn';
    infoBtn.innerHTML = 'ℹ️ 詳細';
    infoBtn.onclick = (e) => {
      e.stopPropagation();
      this.showDetailModal(piece.id);
      this.clearSelection();
    };
    actionMenu.appendChild(infoBtn);
  }

  /**
   * 移動モード開始（入れ替え先マスのハイライト）
   */
  startMoveMode(sourcePos) {
    this.moveSourcePos = sourcePos;
    const actionMenu = document.getElementById('action-menu');
    if (actionMenu) actionMenu.classList.add('hidden');

    for (let pos = 0; pos < 3; pos++) {
      const slot = document.getElementById(`player-slot-${pos}`);
      if (slot) {
        if (pos === sourcePos) {
          slot.classList.add('selected');
        } else {
          slot.classList.add('move-highlight');
        }
      }
    }
    this.showToast('入れ替えたい自分のマスを選択してください');
  }

  /**
   * 手番インジケータ更新
   */
  updateTurnIndicator(state) {
    const indicator = document.getElementById('turn-status-text');
    const turnBadge = document.getElementById('turn-number-badge');
    const boardEl = document.getElementById('game-board');

    if (turnBadge) {
      turnBadge.textContent = `Turn ${state.turnNumber}`;
    }

    if (state.winner) {
      if (indicator) indicator.textContent = '対局終了';
      if (boardEl) boardEl.classList.remove('player-turn-active', 'cpu-turn-active');
      return;
    }

    if (state.currentTurn === 'player') {
      if (indicator) indicator.innerHTML = '<span class="glow-text">あなたの手番</span>';
      if (boardEl) {
        boardEl.classList.add('player-turn-active');
        boardEl.classList.remove('cpu-turn-active');
      }
    } else {
      if (indicator) indicator.innerHTML = '<span class="wait-text">相手の手を待っています<span class="dots">...</span></span>';
      if (boardEl) {
        boardEl.classList.add('cpu-turn-active');
        boardEl.classList.remove('player-turn-active');
      }
    }
  }

  /**
   * ログ表示更新
   */
  renderLogs(state) {
    const logList = document.getElementById('log-list');
    if (!logList) return;

    logList.innerHTML = '';
    for (const log of state.logs) {
      const li = document.createElement('li');
      li.className = `log-entry log-${log.type}`;
      li.innerHTML = `<span class="log-time">[T${log.turn}]</span> ${log.text}`;
      logList.appendChild(li);
    }
    logList.scrollTop = logList.scrollHeight;
  }

  /**
   * 駒詳細モーダル表示
   */
  showDetailModal(hourglassId) {
    const data = HOURGLASS_DEFINITIONS[hourglassId];
    if (!data) return;

    const modal = document.getElementById('detail-modal');
    if (!modal) return;

    document.getElementById('modal-card-name').textContent = data.name;
    document.getElementById('modal-card-damage').textContent = `${data.damage} ダメージ`;
    document.getElementById('modal-card-desc').textContent = data.description;

    // 3形態のイラスト
    document.getElementById('modal-img-full').src = getHourglassImagePath(data.id, HourglassState.UPRIGHT);
    document.getElementById('modal-img-falling').src = getHourglassImagePath(data.id, HourglassState.FALLING);
    document.getElementById('modal-img-empty').src = getHourglassImagePath(data.id, HourglassState.FALLEN);

    modal.classList.remove('hidden');
    Sound.play('button');
  }

  hideDetailModal() {
    const modal = document.getElementById('detail-modal');
    if (modal) modal.classList.add('hidden');
  }

  /**
   * フローティングダメージ数字演出
   */
  showDamageFloatingText(side, amount, sourcePos = null) {
    if (amount <= 0) return;
    Sound.play('damage');

    const hpBox = document.getElementById(`${side}-hp-box`);
    if (!hpBox) return;

    const floatEl = document.createElement('div');
    floatEl.className = 'damage-floating-text';
    floatEl.textContent = `-${amount}`;

    hpBox.appendChild(floatEl);

    // HPボックス揺れ
    hpBox.classList.remove('hit-shake');
    void hpBox.offsetWidth;
    hpBox.classList.add('hit-shake');

    setTimeout(() => {
      if (floatEl.parentNode) {
        floatEl.parentNode.removeChild(floatEl);
      }
    }, 1200);
  }

  /**
   * ターン進行のステップ順次アニメーション
   * GameDesign.md 9章: 左から順に1つずつ解決
   */
  async playTurnAdvanceSteps(stepResults, state) {
    this.isAnimating = true;
    this.clearSelection();

    for (const step of stepResults) {
      const slotEl = document.getElementById(`${step.side}-slot-${step.pos}`);
      if (slotEl) {
        // マスを一瞬光らせる
        slotEl.classList.add('step-highlight');
      }

      // 状態変更の反映
      this.renderBoard(state);

      // ダメージのフローティング演出
      for (const dmg of step.damageEvents) {
        this.showDamageFloatingText(dmg.targetSide, dmg.damage, step.pos);
        this.updateHp(state);
      }

      await new Promise(r => setTimeout(r, 450));

      if (slotEl) {
        slotEl.classList.remove('step-highlight');
      }
    }

    this.renderBoard(state);
    this.isAnimating = false;
  }

  /**
   * トースト通知
   */
  showToast(msg) {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.remove('hidden', 'fade-out');
    toast.classList.add('fade-in');

    setTimeout(() => {
      toast.classList.remove('fade-in');
      toast.classList.add('fade-out');
      setTimeout(() => {
        toast.classList.add('hidden');
      }, 300);
    }, 2000);
  }

  /**
   * 対局結果オーバーレイ
   */
  showResultOverlay(winner, state) {
    Sound.play('result');
    const overlay = document.getElementById('result-overlay');
    if (!overlay) return;

    const isWin = winner === 'player';
    const titleEl = document.getElementById('result-title');
    const subEl = document.getElementById('result-sub');
    const statsEl = document.getElementById('result-stats');

    if (isWin) {
      titleEl.textContent = 'VICTORY';
      titleEl.className = 'result-title win';
      subEl.textContent = state.isSurrendered ? '相手が投了しました' : 'あなたの勝利です！';
    } else {
      titleEl.textContent = 'DEFEAT';
      titleEl.className = 'result-title lose';
      subEl.textContent = state.isSurrendered ? '投了しました' : 'CPUの勝利です...';
    }

    if (statsEl) {
      statsEl.innerHTML = `
        <div class="stat-item"><span>総手数:</span> <strong>${state.totalMoves}手</strong></div>
        <div class="stat-item"><span>経過ターン:</span> <strong>${state.turnNumber}ターン</strong></div>
        <div class="stat-item"><span>あなた残りHP:</span> <strong>${state.hp.player}</strong></div>
        <div class="stat-item"><span>CPU残りHP:</span> <strong>${state.hp.cpu}</strong></div>
      `;
    }

    overlay.classList.remove('hidden');
  }

  hideResultOverlay() {
    const overlay = document.getElementById('result-overlay');
    if (overlay) overlay.classList.add('hidden');
  }
}
