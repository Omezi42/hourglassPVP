/**
 * 砂時計PvP データ定義
 * docs/GameDesign.md & docs/Hourglasses.md 準拠
 */

const HourglassState = {
  UPRIGHT: 'UPRIGHT',   // 上向き (セット直後、砂は全部上)
  FALLING: 'FALLING',   // 落下中 (砂が流れている最中)
  FALLEN: 'FALLEN'      // 落ちきり (砂が全部下に落ちた状態)
};

const TriggerType = {
  ON_FLIP: 'ON_FLIP',             // 反転時
  WHILE_FALLING: 'WHILE_FALLING', // 落下中の間
  ON_FALLEN: 'ON_FALLEN',         // 落ちきり到達時
  WHILE_FALLEN: 'WHILE_FALLEN',   // 落ちきり状態の間(ターン進行時)
  COUNTER: 'COUNTER'              // 相手に反転させられた時
};

const TargetType = {
  SELF: 'SELF',                         // 自分自身
  ADJACENT_LEFT: 'ADJACENT_LEFT',       // 左隣
  ADJACENT_RIGHT: 'ADJACENT_RIGHT',     // 右隣
  OPPONENT_PLAYER: 'OPPONENT_PLAYER',   // 相手プレイヤー
  OWN_PLAYER: 'OWN_PLAYER',             // 自分プレイヤー
  RANDOM_ALLY: 'RANDOM_ALLY',           // 味方ランダム(自分の場の砂時計から1個)
  OPPONENT_MIRROR: 'OPPONENT_MIRROR'    // 正面の相手砂時計
};

const EffectType = {
  DAMAGE: 'DAMAGE',                     // 直接ダメージ
  DAMAGE_REDUCTION: 'DAMAGE_REDUCTION', // 被ダメージ軽減
  LOCK: 'LOCK',                         // 反転ロック
  FORCE_ADVANCE: 'FORCE_ADVANCE',       // 強制進行
  RECOVER: 'RECOVER',                   // 上向きに戻す
  COUNTER: 'COUNTER',                   // 反撃ダメージ
  SYNC_STATE: 'SYNC_STATE'              // 状態同期
};

const HOURGLASS_DEFINITIONS = {
  sand: {
    id: 'sand',
    name: 'サンド',
    damage: 4,
    description: 'なし (バニラ、基準駒)',
    effects: []
  },
  sword: {
    id: 'sword',
    name: 'ソード',
    damage: 3,
    description: '反転時: 相手プレイヤーに1ダメージ',
    effects: [
      { trigger: TriggerType.ON_FLIP, target: TargetType.OPPONENT_PLAYER, type: EffectType.DAMAGE, value: 1 }
    ]
  },
  king: {
    id: 'king',
    name: 'キング',
    damage: 1,
    description: '落下中の間: 被ダメージ-1 / 落ちきり時: 自分に2ダメージ',
    effects: [
      { trigger: TriggerType.WHILE_FALLING, target: TargetType.OWN_PLAYER, type: EffectType.DAMAGE_REDUCTION, value: 1 },
      { trigger: TriggerType.ON_FALLEN, target: TargetType.OWN_PLAYER, type: EffectType.DAMAGE, value: 2 }
    ]
  },
  judge: {
    id: 'judge',
    name: 'ジャッジ',
    damage: 1,
    description: '落ちきり状態の間、毎ターン相手に1ダメージ (継続)',
    effects: [
      { trigger: TriggerType.WHILE_FALLEN, target: TargetType.OPPONENT_PLAYER, type: EffectType.DAMAGE, value: 1 }
    ]
  },
  shield: {
    id: 'shield',
    name: 'シールド',
    damage: 2,
    description: '落下中の間: 被ダメージ-1',
    effects: [
      { trigger: TriggerType.WHILE_FALLING, target: TargetType.OWN_PLAYER, type: EffectType.DAMAGE_REDUCTION, value: 1 }
    ]
  },
  wall: {
    id: 'wall',
    name: 'ウォール',
    damage: 2,
    description: '相手に反転させられた時: 相手に1ダメージ (カウンター)',
    effects: [
      { trigger: TriggerType.COUNTER, target: TargetType.OPPONENT_PLAYER, type: EffectType.COUNTER, value: 1 }
    ]
  },
  dash: {
    id: 'dash',
    name: 'ダッシュ',
    damage: 2,
    description: '反転時: 自分をもう1段階進める (即座に次状態へ)',
    effects: [
      { trigger: TriggerType.ON_FLIP, target: TargetType.SELF, type: EffectType.FORCE_ADVANCE, value: 1 }
    ]
  },
  echo: {
    id: 'echo',
    name: 'エコー',
    damage: 2,
    description: '落ちきり時: 味方ランダム1個を上向きに戻す',
    effects: [
      { trigger: TriggerType.ON_FALLEN, target: TargetType.RANDOM_ALLY, type: EffectType.RECOVER, value: 0 }
    ]
  },
  mirror: {
    id: 'mirror',
    name: 'ミラー(→)',
    damage: 2,
    description: '反転時: 右隣の砂時計の状態を自分に揃える',
    effects: [
      { trigger: TriggerType.ON_FLIP, target: TargetType.ADJACENT_RIGHT, type: EffectType.SYNC_STATE, value: 0 }
    ]
  },
  eye: {
    id: 'eye',
    name: 'アイ',
    damage: 0,
    description: '落下中の間: 正面の相手の砂時計をロック (反転不可)',
    effects: [
      { trigger: TriggerType.WHILE_FALLING, target: TargetType.OPPONENT_MIRROR, type: EffectType.LOCK, value: 0 }
    ]
  }
};

const ALL_HOURGLASS_IDS = Object.keys(HOURGLASS_DEFINITIONS);

/**
 * 砂時計の画像パスを解決
 */
function getHourglassImagePath(id, state = HourglassState.UPRIGHT) {
  let file = 'state_full.png';
  if (state === HourglassState.FALLING) {
    file = 'state_falling.png';
  } else if (state === HourglassState.FALLEN) {
    file = 'state_empty.png';
  }
  return `../assets/hourglasses/processed/${id}/${file}`;
}

/**
 * デフォルトのデッキ構成（5枚）
 */
const DEFAULT_PLAYER_DECK = ['sand', 'sword', 'shield', 'wall', 'echo'];
const PRESET_DECKS = {
  standard: {
    name: 'スタンダード',
    cards: ['sand', 'sword', 'shield', 'wall', 'echo']
  },
  aggressive: {
    name: 'アグレッシブ',
    cards: ['sword', 'sand', 'dash', 'judge', 'echo']
  },
  control: {
    name: 'コントロール',
    cards: ['shield', 'wall', 'eye', 'king', 'mirror']
  },
  trick: {
    name: 'トリック',
    cards: ['mirror', 'dash', 'eye', 'judge', 'sword']
  }
};
