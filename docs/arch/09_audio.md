# 9. 効果音・BGMの実装方針

- 効果音は `SoundBank`(`RefCounted` 継承のstaticクラス)に集約する。`MatchSetup`/`DeckSave`/`NetSession` と同じ「Autoloadを使わずstaticで持つ」流儀に揃える
- `ensure_ready(parent)` を `Main._ready()` から1度だけ呼び、`AudioStreamPlayer` のプール(8本)とホバー専用の1本を生成する。staticクラス自体はNodeではないため、実際の再生には実ノードが要る。**プールは鳴り終わった1本を選び、すべて鳴っていれば最も古いものを譲る**(順番に使い回すと、鳴っている被弾や決着を途中で切る)。**ホバー音を専用の1本に分ける**のも同じ理由
- `wire_buttons(root)` はシーンツリーを再帰的に走査し、全Buttonの `pressed` へ押下音、`mouse_entered` へホバー音を接続する。**ホバー音は無効(`disabled`)のボタンでは鳴らさない**。個別配線は漏れやすいため、`Main._ready()` で全体に対して1度呼ぶことを基本とするが、実行時に動的生成されるノード(例: `DeckListScreen` のカード一覧)は起動時の走査に含まれないため、生成元の画面スクリプト側で個別に呼び直す。`is_connected()` チェックにより二重接続は起きない。手札・駒のホバー音は `CardView` が操作可能なときだけ鳴らす
- **ホバー音は `HOVER_MIN_INTERVAL_MS` の間隔の中では重ねない**(`SoundBank.play()` が見る)。手札を横切ると数十msおきに札を乗り換え、連打に聞こえるため
- 対局の効果音は `CardMatchSound`(後述)が、自分の番の鐘は「あなたの番」の幕を出す `CardMatchTurnFeed.announce_turn()` が鳴らす(幕と音を同じ条件にするため。誘導対局では幕ごと出ない)。行動の列のボタンは共通のボタン押下音と二重に鳴らさないため `wire_buttons()` の対象から除外する
- **音量はバスで効かせる。**`SoundBank` が `SFX` と `BGM` の2本のバスを実行時に作り(`bus_index()`。2本しかないため `default_bus_layout.tres` は持たない。足すときは `add_bus()` ではなく `bus_count` を増やす。Web版では `add_bus()` がブラウザ側のバスの並びを壊し、全く鳴らなくなるため)、効果音のプレイヤーは `SFX`、BGMのプレイヤーは `BGM` へ流す。スライダーの値 v は `volume_to_db()` で**振幅 v² として**バスの音量へ変える(耳の感じ方に近づけるため。線形のままだと上半分がほとんど変わらない)。0%はバスをミュートする。音源ごとの音量差は音源の側で揃えてあるため、再生時に音量比や高さを掛けない
- 全体の出口(Master)に `AudioEffectHardLimiter` を置き、音が重なったときの割れを防ぐ。**Web版の既定の再生方式(サンプル再生)ではバスのエフェクトが効かない**(音量とミュートは効く)。音源に余裕を持たせてあるため、Web版ではリミッター無しで割れないことを前提にする
- 音量設定は `user://sound_settings.json` へJSONで永続化する。`SoundBank._sfx_volume`/`_bgm_volume`(いずれも0.0〜1.0のfloat。既定は0.8/0.7)は `static var` の初期化式でクラス初回アクセス時に自動読み込みされるため、`ensure_ready()` を待たずに早期から正しい値を返せる(ホーム画面の設定ボタンは `Main` より先に `_ready()` が走るため、ここで読んでおかないと初期表示に反映されない)。`get_sfx_volume()`/`set_sfx_volume()`・`get_bgm_volume()`/`set_bgm_volume()` で参照・変更する。`is_muted()` は `_sfx_volume <= 0.0` の派生として残している
- ホーム画面右上に `SettingsButton`(`Button`)を配置し、押すと `SettingsPanel`(`scenes/settings_panel.tscn`、`ResultOverlay`/`SurrenderConfirm` と同じ「暗幕+`content_panel.tres` の中央パネル」パターン)が開く。パネル内の `HSlider` 2本(いずれも0〜100%。効果音は `SoundBank.set_sfx_volume()`、BGMは `SoundBank.set_bgm_volume()` を随時更新する)で音量を操作し、その下に公式Discordサーバーへの導線、最後に「閉じる」ボタンを置く(GameDesign.md 9章)
- **ボタンの見た目はハンバーガー(`UiPaint.Emblem.MENU` / `img_icon_menu_*.tres`)とし、文言を持たない。**`StyleBox` はリソース参照のため `.tscn` のパッチ(値がJSON)では差し替えられず、`HomeScreen._ready()` が `CodedButton.apply_styles()` で指定する。同じ理由で、Discordのボタン(`img_icon_discord_*.tres`)も `SettingsPanel` がコードで組み立てて「閉じる」の直前へ挿す。**どちらも文言を持たない正方形のアイコンボタン**にして、メニューの中身が増えても同じ形で並べられるようにする
- **`EmblemPlacement.CENTER` の紋章は、単位座標の上限(±0.85)まで使ってはいけない。**`draw_emblem` へ渡る `size` はボタン矩形の 0.42 倍(半径)であり、±0.85 まで描くと額縁の内側の凹んだパネルからはみ出して枠へ載り上がる。±0.55 程度に留める
- **Discordのマークだけは多角形で似せず、公式のシンボル(`assets/ui/brands/discord_mark.svg`)をテクスチャとして敷く。**他の紋章と同じ真鍮の浮き彫りにしないのは、ブランドのマークを塗り替えないため(Discordの規定は blurple / 白 / 黒 のいずれかを求める)。SVGは `svg/scale=8`(192px)でインポートし、出所は `assets/CREDITS.md` へ記録する
- **リンクを開くのは `OS.shell_open()`**。Web書き出しでは `window.open` になるため、押した操作を起点にしないとブラウザに塞がれる(BGMの自動再生制限と同じ事情)。招待URLは `SettingsPanel.DISCORD_INVITE_URL` の1箇所だけが持つ
- **効果音はすべて `tools/build_sfx.py`(Python + numpy/scipy/soundfile)がコードで合成した自作の音**(GameDesign.md 9章)。木の卓・硝子・砂・真鍮の打撃を、減衰する正弦波の和(モード合成)と帯域を絞った雑音・砂粒の連なりで作る。**音量は書き出す段階で種類ごとの目標ラウドネスへ揃える**(50msごとのRMSの最大。ホバー−34 / 押下−22 / 対局−17〜−21 / ターン終了−26 / ジングル−16〜−19 dB)。乱数の種は音の名前から決めるため、1つを直しても他の音は変わらない。音を直すときはスクリプトを直して再実行し、WAVを手で加工しない
- BGMは**パブリックドメイン/CC0の外部の録音**を使う。効果音は `assets/sfx/`、BGMは `assets/bgm/` に置く。**取り込んだ素材の出所・作者・ライセンスは `assets/CREDITS.md` に必ず記録する**。CC0なので表示義務はないが、後から「この音はどこから来たのか」を追えないと、ライセンスの再確認も差し替えもできなくなるため
- **BGMは `MusicPlayer`(`scripts/logic/music_player.gd`、`RefCounted` 継承のstaticクラス)が担当し、`SoundBank` とは別クラスに分ける**。効果音が「1発鳴らして終わり」なのに対し、BGMはクロスフェード・ループ・自動再生制限の解除といった継続的な状態を持つため、同じクラスへ同居させると `SoundBank` が肥大化する。`ensure_ready(parent)` で `AudioStreamPlayer` を2本(クロスフェードで鳴り替えるため)生成する流儀は `SoundBank` と揃える
- **音量の単一情報源は `SoundBank` 側に置き続ける**。`_sfx_volume` と `_bgm_volume` の2つを持ち、`user://sound_settings.json` へ両方を保存する(旧形式の単一キー `volume` を見つけた場合は両系統の初期値として読み、次回保存時に新形式へ移行する)。`MusicPlayer` は音量の設定を持たず、BGMバスの音量を `SoundBank.set_bgm_volume()` が変える。設定の読み書きを2クラスに分散させると、同じJSONファイルを互いに上書きし合うため
- **曲ごとの音量差は `MusicPlayer.TRACK_GAIN_DB` でならす**(GameDesign.md 9章)。録音ごとに音量が大きく違い、タイトル曲は他より約12dB大きい。3秒ごとのRMSの上位1割が約−24dBで揃うよう補正し、プレイヤーの `volume_db` はフェードの行き先としてこの値を使う
- **BGMの切り替えは `Main._show_only()`(画面切り替えのハブ)から1箇所で行う**。遷移先に応じた曲は `Main._track_for()` が決める(対局画面なら対局曲、`TitleScreen`ならタイトル曲、それ以外はホーム曲)。画面ごとに個別へ `MusicPlayer.play()` を書き散らさない
- **クラシック曲はシームレスにループしない**ため、`AudioStreamPlayer.finished` を購読し、数秒の間を置いてから頭へ戻す「アルバム再生」方式で繰り返す。インポート設定でループを有効にすると `finished` が発火しなくなるため、**実行時に `stream.loop = false` を明示する**
- **曲の終端の `TAIL_FADE` 秒前から音量を絞る**(GameDesign.md 9章)。再生開始時に `stream.get_length()` から逆算したタイマーを張り、発火時にまだ同じ曲が同じプレイヤーで鳴っていればフェードアウトを始める。タイトル曲のように**曲の途中を切り出した音源**でも切れ目が唐突に聞こえないようにするため
- **タイトル曲は元の録音を再エンコードせず、Oggのページ境界でそのまま切り出して使う**。この環境には ffmpeg/oggenc が無く、また再エンコードは音質を落とすため。切り出しは「granule_position が目標サンプル数を超えたページまでを残し、最後のページへ EOS フラグを立ててCRCを再計算する」だけで、ページの中身には触れない
- **ブラウザの自動再生制限に対応する**。`MusicPlayer.play()` は、最初のユーザー操作を検知するまで実際には鳴らさず、要求されたトラックを `_pending_track` として覚えておくだけにする。`Main` が最初のクリック/タップで `MusicPlayer.notify_user_gesture()` を呼び、そこで保留していたトラックの再生を始める
- **対局中の効果音は `CardMatchSound` が1箇所で鳴らす**(GameDesign.md 9章)。対応は
  出す(砂術も)=`PLACE` / 反転(反転権も)=`FLIP` / 攻撃(相打ち)=`CLASH` / 被弾=`DAMAGE` /
  破壊=`UNIT_BREAK`(毒砂で体力が0になった駒は `POISON_MELT`。`unit_poisoned` で枠を控えて続く `unit_destroyed` を振り分ける)/ 硝子の膜割れ=`GLASS_BREAK` / ターン終了=`TURN_END` / HPの器が砕ける=`VESSEL_SHATTER`(`CardMatchFinale` が器を砕くときに鳴らす。割れる音は `HpVesselFx.BURST_AT` と同じ位置に合わせて合成する)/ 決着=`RESULT_WIN`・`RESULT_LOSE`。**攻撃(相打ち)は「砂時計どうしの攻撃」
  のときだけ鳴らし**、本体を殴った場合は被弾(HPの減り)の側で鳴る。HPの増減は
  `hp_changed` が新しい値しか渡さないため、直前の値をこのクラスが控えて減少だけを拾う
- **ターン終了の音は `turn_started` で鳴らし、`turn_count` が1の(対局の最初の)手番では鳴らさない**。「前の手番が終わった」音であり、終わった手番の無い最初には合わないため。受け口はいずれも `MatchState` のシグナルで、画面側の分岐を増やさずにリプレイ・観戦・CPUのすべてで同じように鳴る
- **攻撃の演出中は、効果音を当たる瞬間まで持ち越す**(`CardMatchStrike._on_impact()` が
  `CardMatchSound.flush()` を呼ぶ)。砂の飛散を持ち越すのと同じ理由で、解決と同時に鳴らすと
  駒がまだ渡っている最中に衝突音だけが先に鳴り、因果が逆に聞こえる
- **決着でBGMを止めた後、「もう一度」で対局曲へ戻すのは `_begin_state()` の役目**。
  画面が切り替わらないため `Main._show_only()` を通らず、止めたままになる
- **結果パネルを出す瞬間にBGMを止め、勝敗別の短いジングルを鳴らす**(GameDesign.md 9章)。`CardMatchFinale` が締めを出す直前に `CardMatchSound.play_result()` を呼ぶ。`match_ended` の時点で鳴らすと、最後の一撃が当たる前に勝敗が聞こえてしまう
