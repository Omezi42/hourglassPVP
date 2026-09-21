# 砂時計アリーナ 実装設計書(Architecture v5.0)

`docs/GameDesign.md` の仕様を Godot 4.x / GDScript 2.0 でどう実装するかの方針。
仕様(ルール・数値・UI)は GameDesign.md が唯一の情報源であり、本書はその実装設計だけを扱う。
本文は章・節ごとに `docs/arch/` へ分けてあり、「Architecture.md 10.6節」はこの表の 10.6節 のファイルを指す。

| 章・節 | 内容 | ファイル |
|---|---|---|
| 1章 | 設計方針 | [`arch/01_policy.md`](arch/01_policy.md) |
| 2章 | データ構造(Resource設計) | [`arch/02_data.md`](arch/02_data.md) |
| 3章 | ロジック層 | [`arch/03_logic.md`](arch/03_logic.md) |
| 4章 | シーン構成(責務を小さく分け、UI・ロジック・データを分離する)。以下の節に分かれる | — |
| 4.0節 | 対局画面 | [`arch/04_00_match_screen.md`](arch/04_00_match_screen.md) |
| 4.1節 | 砂時計イラストの解像度と配置(4.1.5 はじめてのプレイ・4.1.6 Web配信のロード時間を含む) | [`arch/04_01_hourglass_art.md`](arch/04_01_hourglass_art.md) |
| 4.2節 | ルール画面(GameDesign.md 16章) | [`arch/04_02_rules_screen.md`](arch/04_02_rules_screen.md) |
| 4.3節 | キーワード辞書(GameDesign.md 17章) | [`arch/04_03_keyword_dict.md`](arch/04_03_keyword_dict.md) |
| 4.4節 | 画面の見かた(GameDesign.md 20章) | [`arch/04_04_screen_guide.md`](arch/04_04_screen_guide.md) |
| 4.5節 | デッキを複数持つ(GameDesign.md 9章) | [`arch/04_05_multi_deck.md`](arch/04_05_multi_deck.md) |
| 5章 | 拡張運用について | [`arch/05_extension.md`](arch/05_extension.md) |
| 6章 | オンライン対戦の実装方針 | [`arch/06_online.md`](arch/06_online.md) |
| 7章 | リプレイ・観戦の実装方針 | [`arch/07_replay.md`](arch/07_replay.md) |
| 8章 | CPU戦の実装方針 | [`arch/08_cpu.md`](arch/08_cpu.md) |
| 9章 | 効果音・BGMの実装方針 | [`arch/09_audio.md`](arch/09_audio.md) |
| 10章 | アカウント・通貨の実装方針(10.1〜10.4節を含む) | [`arch/10_account.md`](arch/10_account.md) |
| 10.5節 | UI | [`arch/10_05_ui.md`](arch/10_05_ui.md) |
| 10.6節 | デッキコード(GameDesign.md 9章) | [`arch/10_06_deck_code.md`](arch/10_06_deck_code.md) |
| 10.7節 | 戦績(GameDesign.md 19章) | [`arch/10_07_stats.md`](arch/10_07_stats.md) |
| 10.8節 | ショップと所有(GameDesign.md 21章) | [`arch/10_08_shop.md`](arch/10_08_shop.md) |
| 10.9節 | 対局の記録と分析(GameDesign.md 22章) | [`arch/10_09_match_records.md`](arch/10_09_match_records.md) |
| 10.10節 | 対局中演出・QOL(GameDesign.md 9章) | [`arch/10_10_match_feel.md`](arch/10_10_match_feel.md) |
| 10.11節 | デイリーミッション(GameDesign.md 23章) | [`arch/10_11_daily_missions.md`](arch/10_11_daily_missions.md) |
| 10.12節 | リーサルパズル(GameDesign.md 24章) | [`arch/10_12_lethal_puzzle.md`](arch/10_12_lethal_puzzle.md) |
| 10.13節 | 日曜イベントとその告知(GameDesign.md 15章・25章) | [`arch/10_13_sunday_event.md`](arch/10_13_sunday_event.md) |
| 10.14節 | Discordスラッシュコマンド(GameDesign.md 26章) | [`arch/10_14_discord_commands.md`](arch/10_14_discord_commands.md) |
| 10.15節 | ソロモード | [`arch/10_15_solo_mode.md`](arch/10_15_solo_mode.md) |
| 10.16節 | ランクマッチ(GameDesign.md 28章) | [`arch/10_16_ranked.md`](arch/10_16_ranked.md) |
| 10.17節 | 掲示板(ラボ)(GameDesign.md 29章) | [`arch/10_17_lab.md`](arch/10_17_lab.md) |
| 10.18節 | 公式大会「箱庭杯」(GameDesign.md 30章) | [`arch/10_18_tournament.md`](arch/10_18_tournament.md) |
| 10.19節 | カードスキン(GameDesign.md 31章) | [`arch/10_19_card_skins.md`](arch/10_19_card_skins.md) |
| 11章 | 開発時の落とし穴 | [`Pitfalls.md`](Pitfalls.md)(コードやシーンを触る前に読む。新しく踏んだ穴もそちらへ足す) |
| — | 未検討事項 | [`arch/99_open_issues.md`](arch/99_open_issues.md) |
