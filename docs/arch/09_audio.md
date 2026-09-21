# 9. 効果音・BGMの実装方針

- 効果音は `SoundBank`(`RefCounted` 継承のstaticクラス)に集約する。`MatchSetup`/`DeckSave`/`NetSession` と同じ「Autoloadを使わずstaticで持つ」流儀に揃える
- `ensure_ready(parent)` を `Main._ready()` から1度だけ呼び、`AudioStreamPlayer` のプール(常駐ノード)を生成する。staticクラス自体はNodeではないため、実際の再生には実ノードが要る
- `wire_buttons(root)` はシーンツリーを再帰的に走査し、全Buttonの `pressed` へ共通のボタン押下音を接続する。個別配線は漏れやすいため、`Main._ready()` で全体に対して1度呼ぶことを基本とするが、実行時に動的生成されるノード(例: `DeckListScreen` のカード一覧)は起動時の走査に含まれないため、生成元の画面スクリプト側で個別に呼び直す。`is_connected()` チェックにより二重接続は起きない
- 出す/反転/攻撃(相打ち)/被弾/決着の専用効果音は対局画面が該当処理箇所で直接 `SoundBank.play()` を呼ぶ。行動の列のボタンは共通のボタン押下音と二重に鳴らさないため `wire_buttons()` の対象から除外する
- 音量設定は `user://sound_settings.json` へJSONで永続化する。`SoundBank._sfx_volume`/`_bgm_volume`(いずれも0.0〜1.0のfloat)は `static var` の初期化式でクラス初回アクセス時に自動読み込みされるため、`ensure_ready()` を待たずに早期から正しい値を返せる(ホーム画面の設定ボタンは `Main` より先に `_ready()` が走るため、ここで読んでおかないと初期表示に反映されない)。`get_sfx_volume()`/`set_sfx_volume()`・`get_bgm_volume()`/`set_bgm_volume()` で参照・変更し、`play()` 時と設定変更時に `AudioStreamPlayer.volume_db` を `linear_to_db()` で更新する(0%は `-inf` を避けるため `-80.0dB` 固定)。`is_muted()` は `_sfx_volume <= 0.0` の派生として残している
- ホーム画面右上に `SettingsButton`(`Button`)を配置し、押すと `SettingsPanel`(`scenes/settings_panel.tscn`、`ResultOverlay`/`SurrenderConfirm` と同じ「暗幕+`content_panel.tres` の中央パネル」パターン)が開く。パネル内の `HSlider` 2本(いずれも0〜100%。効果音は `SoundBank.set_sfx_volume()`、BGMは `SoundBank.set_bgm_volume()` を随時更新する)で音量を操作し、その下に公式Discordサーバーへの導線、最後に「閉じる」ボタンを置く(GameDesign.md 9章)
- **ボタンの見た目はハンバーガー(`UiPaint.Emblem.MENU` / `img_icon_menu_*.tres`)とし、文言を持たない。**`StyleBox` はリソース参照のため `.tscn` のパッチ(値がJSON)では差し替えられず、`HomeScreen._ready()` が `CodedButton.apply_styles()` で指定する。同じ理由で、Discordのボタン(`img_icon_discord_*.tres`)も `SettingsPanel` がコードで組み立てて「閉じる」の直前へ挿す。**どちらも文言を持たない正方形のアイコンボタン**にして、メニューの中身が増えても同じ形で並べられるようにする
- **`EmblemPlacement.CENTER` の紋章は、単位座標の上限(±0.85)まで使ってはいけない。**`draw_emblem` へ渡る `size` はボタン矩形の 0.42 倍(半径)であり、±0.85 まで描くと額縁の内側の凹んだパネルからはみ出して枠へ載り上がる。±0.55 程度に留める
- **Discordのマークだけは多角形で似せず、公式のシンボル(`assets/ui/brands/discord_mark.svg`)をテクスチャとして敷く。**他の紋章と同じ真鍮の浮き彫りにしないのは、ブランドのマークを塗り替えないため(Discordの規定は blurple / 白 / 黒 のいずれかを求める)。SVGは `svg/scale=8`(192px)でインポートし、出所は `assets/CREDITS.md` へ記録する
- **リンクを開くのは `OS.shell_open()`**。Web書き出しでは `window.open` になるため、押した操作を起点にしないとブラウザに塞がれる(BGMの自動再生制限と同じ事情)。招待URLは `SettingsPanel.DISCORD_INVITE_URL` の1箇所だけが持つ
- 音源は**CC0(パブリックドメイン)ライセンスの外部フリー素材**を使う(GameDesign.md 9章)。効果音は `assets/sfx/`、BGMは `assets/bgm/` に置く。**取り込んだ素材の出所・作者・ライセンスは `assets/CREDITS.md` に必ず記録する**。CC0なので表示義務はないが、後から「この音はどこから来たのか」を追えないと、ライセンスの再確認も差し替えもできなくなるため
- **BGMは `MusicPlayer`(`scripts/logic/music_player.gd`、`RefCounted` 継承のstaticクラス)が担当し、`SoundBank` とは別クラスに分ける**。効果音が「1発鳴らして終わり」なのに対し、BGMはクロスフェード・ループ・自動再生制限の解除といった継続的な状態を持つため、同じクラスへ同居させると `SoundBank` が肥大化する。`ensure_ready(parent)` で `AudioStreamPlayer` を2本(クロスフェードで鳴り替えるため)生成する流儀は `SoundBank` と揃える
- **音量の単一情報源は `SoundBank` 側に置き続ける**。`_sfx_volume` と `_bgm_volume` の2つを持ち、`user://sound_settings.json` へ両方を保存する(旧形式の単一キー `volume` を見つけた場合は両系統の初期値として読み、次回保存時に新形式へ移行する)。`MusicPlayer` は自前で音量を永続化せず、`SoundBank.get_bgm_volume()` を参照し、`SoundBank.set_bgm_volume()` が `MusicPlayer.apply_volume()` を呼んで反映する。設定の読み書きを2クラスに分散させると、同じJSONファイルを互いに上書きし合うため
- **BGMの切り替えは `Main._show_only()`(画面切り替えのハブ)から1箇所で行う**。遷移先に応じた曲は `Main._track_for()` が決める(対局画面なら対局曲、`TitleScreen`ならタイトル曲、それ以外はホーム曲)。画面ごとに個別へ `MusicPlayer.play()` を書き散らさない
- **クラシック曲はシームレスにループしない**ため、`AudioStreamPlayer.finished` を購読し、数秒の間を置いてから頭へ戻す「アルバム再生」方式で繰り返す。インポート設定でループを有効にすると `finished` が発火しなくなるため、**実行時に `stream.loop = false` を明示する**
- **曲の終端の `TAIL_FADE` 秒前から音量を絞る**(GameDesign.md 9章)。再生開始時に `stream.get_length()` から逆算したタイマーを張り、発火時にまだ同じ曲が同じプレイヤーで鳴っていればフェードアウトを始める。タイトル曲のように**曲の途中を切り出した音源**でも切れ目が唐突に聞こえないようにするため。フェード中は `set_volume()` が音量を戻さないよう `_tail_fading` で守る
- **タイトル曲は元の録音を再エンコードせず、Oggのページ境界でそのまま切り出して使う**。この環境には ffmpeg/oggenc が無く、また再エンコードは音質を落とすため。切り出しは「granule_position が目標サンプル数を超えたページまでを残し、最後のページへ EOS フラグを立ててCRCを再計算する」だけで、ページの中身には触れない
- **ブラウザの自動再生制限に対応する**。`MusicPlayer.play()` は、最初のユーザー操作を検知するまで実際には鳴らさず、要求されたトラックを `_pending_track` として覚えておくだけにする。`Main` が最初のクリック/タップで `MusicPlayer.notify_user_gesture()` を呼び、そこで保留していたトラックの再生を始める
- **対局中の効果音は `CardMatchSound` が1箇所で鳴らす**(GameDesign.md 9章の6種のうち、
  ボタン押下を除く5種)。対応は 出す=`MOVE` / 反転=`FLIP` / 攻撃(相打ち)=`SWAP` /
  被弾=`DAMAGE` / 決着=`RESULT_WIN`・`RESULT_LOSE`。**攻撃(相打ち)は「砂時計どうしの攻撃」
  のときだけ鳴らし**、本体を殴った場合は被弾(HPの減り)の側で鳴る。HPの増減は
  `hp_changed` が新しい値しか渡さないため、直前の値をこのクラスが控えて減少だけを拾う
- **砂時計の破壊(`UNIT_BREAK`)と硝子の膜割れ(`GLASS_BREAK`)は、音源を増やさず
  高さで鳴き分ける**(GameDesign.md 9章)。`SoundBank.SFX_PATHS` は被弾と同じ
  `damage.ogg` を指し、`SFX_PITCH` が破壊を低く・膜割れを高くする。素材を1つ足すたびに
  CC0の音源を探して `assets/CREDITS.md` へ出所を記録する手間が生まれるため、
  **区別を付けたいだけの場面では音源を増やさない**
  - **`pitch_scale` は再生のたびに入れ直す。**`AudioStreamPlayer` はプールで使い回すため、
    前に鳴らした音の高さが残る(入れ忘れると、破壊の直後の被弾まで低く鳴る)
  - 受け口は `unit_destroyed` と `unit_shielded` で、いずれも `MatchState` のシグナル。
    画面側の分岐を増やさずに、リプレイ・観戦・CPUのすべてで同じように鳴る
- **攻撃の演出中は、効果音を当たる瞬間まで持ち越す**(`CardMatchStrike._on_impact()` が
  `CardMatchSound.flush()` を呼ぶ)。砂の飛散を持ち越すのと同じ理由で、解決と同時に鳴らすと
  駒がまだ渡っている最中に衝突音だけが先に鳴り、因果が逆に聞こえる
- **決着でBGMを止めた後、「もう一度」で対局曲へ戻すのは `_begin_state()` の役目**。
  画面が切り替わらないため `Main._show_only()` を通らず、止めたままになる
- **結果画面ではBGMを止め、勝敗別の短いジングルを鳴らす**(GameDesign.md 9章)。`SoundBank.Sfx` の `RESULT` を `RESULT_WIN`/`RESULT_LOSE` の2つへ分け、`MatchResultPresenter` が勝敗に応じて鳴らし分ける
