/**
 * 砂時計PvP 効果音マネージャー
 * ../assets/sfx/ 内のWAVを再生し、音量・ミュートを管理
 */

class SoundManager {
  constructor() {
    this.muted = false;
    this.volume = 0.7;
    this.audioCache = {};
    this.audioContext = null;
    this.initAudioContext();
    this.preloadSounds();
  }

  initAudioContext() {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        this.audioContext = new AudioCtx();
      }
    } catch (e) {
      console.warn('AudioContext initialization failed', e);
    }
  }

  preloadSounds() {
    const soundFiles = {
      button: '../assets/sfx/button.wav',
      damage: '../assets/sfx/damage.wav',
      flip: '../assets/sfx/flip.wav',
      move: '../assets/sfx/move.wav',
      result: '../assets/sfx/result.wav',
      swap: '../assets/sfx/swap.wav'
    };

    for (const [key, path] of Object.entries(soundFiles)) {
      try {
        const audio = new Audio();
        audio.src = path;
        audio.preload = 'auto';
        this.audioCache[key] = audio;
      } catch (e) {
        console.warn(`Failed to preload audio: ${key}`, e);
      }
    }
  }

  play(key) {
    if (this.muted) return;
    if (this.audioContext && this.audioContext.state === 'suspended') {
      this.audioContext.resume().catch(() => {});
    }

    try {
      const original = this.audioCache[key];
      if (original) {
        // 連続再生のためにクローンして再生
        const sound = original.cloneNode();
        sound.volume = this.volume;
        sound.play().catch((err) => {
          // 自動再生制限などで失敗した場合はフォールバック
          this.playFallbackSynth(key);
        });
      } else {
        this.playFallbackSynth(key);
      }
    } catch (e) {
      this.playFallbackSynth(key);
    }
  }

  playFallbackSynth(key) {
    if (this.muted || !this.audioContext) return;
    try {
      const ctx = this.audioContext;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.connect(gain);
      gain.connect(ctx.destination);

      const now = ctx.currentTime;
      gain.gain.setValueAtTime(this.volume * 0.2, now);

      if (key === 'button') {
        osc.frequency.setValueAtTime(440, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
        osc.start(now);
        osc.stop(now + 0.08);
      } else if (key === 'flip') {
        osc.frequency.setValueAtTime(300, now);
        osc.frequency.exponentialRampToValueAtTime(600, now + 0.15);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
        osc.start(now);
        osc.stop(now + 0.15);
      } else if (key === 'move') {
        osc.frequency.setValueAtTime(350, now);
        osc.frequency.linearRampToValueAtTime(450, now + 0.1);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.1);
        osc.start(now);
        osc.stop(now + 0.1);
      } else if (key === 'swap') {
        osc.frequency.setValueAtTime(250, now);
        osc.frequency.exponentialRampToValueAtTime(500, now + 0.18);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.18);
        osc.start(now);
        osc.stop(now + 0.18);
      } else if (key === 'damage') {
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(150, now);
        osc.frequency.exponentialRampToValueAtTime(60, now + 0.25);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.25);
        osc.start(now);
        osc.stop(now + 0.25);
      } else if (key === 'result') {
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(440, now);
        osc.frequency.setValueAtTime(554.37, now + 0.15);
        osc.frequency.setValueAtTime(659.25, now + 0.3);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);
        osc.start(now);
        osc.stop(now + 0.6);
      }
    } catch (e) {}
  }

  setVolume(val) {
    this.volume = Math.max(0, Math.min(1, val));
  }

  toggleMute() {
    this.muted = !this.muted;
    return this.muted;
  }
}

const Sound = new SoundManager();
