---
name: project-overview
description: Flutterで作られた競馬予想・馬券管理アプリ「へたうま競馬」のプロジェクト概要・アーキテクチャ
metadata: 
  node_type: memory
  type: project
  originSessionId: 73d5a79a-a27d-4862-b42e-b30bc178a24a
---

# へたうま競馬 v2

**アプリ概要:** 競馬予想と馬券データ管理のFlutterアプリ。バージョン13.39.1+1。Android/iOS/Web/Windows対応。

**Why:** 競馬予想の分析ロジックと馬券データの管理を統合したパーソナルアプリ。

## 未解決課題 (Current Issues)

- **`historical_match_engine.dart` の引数 `pastRaceVolatility` が未使用**
  88行目で同名のローカル変数を宣言して上書きしているため、呼び出し側
  (`stats_match_tab.dart`) が渡す `volResult.averagePopularity` が使われていない。
  `flutter analyze` で警告が出るか要確認。動作上の実害は今のところなし。
- **脚質の判定ロジックが3系統あり、数値が一致しない**
  `statistics_service`（最終コーナー位置率）/ `volatility_analyzer.determineLegStyle()` /
  `leg_style_analyzer`（コーナー通過＋上がり）の3つ。
  同一画面のグラフと表で頭数が食い違う。現状は脚質タブの注意書きで説明する対応にとどめ、
  判定器の統一は未実施。
- **血統・ローテーションはリフト方式に統一できていない**
  他タブのリフトは全出走馬が分母だが、この2つは1〜3着馬のみを集計している。
  ローテはDB読み込みを増やせば対応可能（+約130クエリ）。
  血統は全出走馬160頭のスクレイピングが必要（取得時間 30秒 → 2分10秒）のため見送り中。
  各タブの注意書きで基準の違いを明示して対応している。
- **`FrameFactor` は枠番(1〜8)を馬番(1〜18)のスケールで比較している**
  12頭立て以上では「外」ゾーンに分類される馬が存在しない。
  ユーザー判断により **現仕様のまま維持**（過去の傾向を今回に当てはめるファクターとして許容）。
  再発見して修正しないよう記録しておく。

**Tech Stack:**
- Flutter (Dart), sqflite（ローカルDB）, shared_preferences
- HTTPスクレイピング（html, http, charset_converter）
- responsive_framework でマルチデバイス対応
- fl_chart でグラフ描画

## lib/ ディレクトリ構成

```
lib/
├── main.dart              # エントリーポイント、テーマ設定（緑系）
├── main_scaffold.dart     # メインの画面骨格
├── screens/               # 画面（ページ）レイヤー
├── models/                # データモデル
├── services/              # スクレイピング・外部API・同期サービス
├── logic/                 # ビジネスロジック（解析エンジン）
│   └── analysis/          # 各種分析エンジン（適性/状態/フォーメーション/脚質など）
├── db/                    # DB層（Provider, Constants, Repositories）
│   └── repositories/      # horse/race/ticket/training等のリポジトリ
├── view_models/           # ViewModelレイヤー
├── widgets/               # 再利用可能なUIコンポーネント
└── utils/                 # ユーティリティ（色/グレード/URL生成など）
```

## 主要画面 (screens/)
- home_page.dart — ホーム
- race_page.dart — レース詳細
- race_schedule_page.dart — レーススケジュール
- shutuba_table_page.dart — 出馬表
- race_result_page.dart — レース結果
- odds_page.dart — オッズ
- horse_stats_page.dart — 馬の成績統計
- jockey_stats_page.dart — 騎手統計
- race_statistics_page.dart — レース統計
- saved_tickets_list_page.dart — 保存馬券一覧
- qr_scanner_page.dart — QRスキャン（馬券読み取り）

## 分析エンジン (logic/analysis/)
- aptitude_analyzer — 適性解析
- condition_analyzer — 状態解析
- formation_analysis_engine — フォーメーション分析
- volatility_analyzer — 波乱度解析
- rating_engine — レーティング計算
- historical_match_engine — 過去成績マッチング
- leg_style_analyzer — 脚質解析
- weather_analyzer — 天候解析
- race_analysis_bundle_loader — 過去分析タブの子タブ共通データを1回だけ読み込む
- factor_candidate_selector — 統計由来7ファクターの該当馬選出（リフト方式）
- bundle_factor_selector — バンドル由来5ファクターの該当馬選出（擬似リフト方式）

**How to apply:** 分析ロジックの変更はlogic/analysis/、スクレイピングはservices/、画面UIはscreens/またはwidgets/を起点に探す。

## 作業履歴

### 2026-09-09 開催日程の分離（Phase 4）— RaceRepository の責務分割が完了

指示書: `memory/RaceSchedule分割_CLI指示書_Phase4.md`

- `RaceRepository` に残っていた最後の別ドメイン「開催日程」を `RaceScheduleRepository` へ分離。
  対象は `race_schedules` と `week_schedules_cache` の7メソッド
  （`insertOrUpdateRaceSchedule` / `getMultipleRaceSchedules` / `getRaceSchedule` /
  `insertOrUpdateWeekCache` / `getWeekCache` / `getDateFromScheduleByRaceId` / `mergeRaceSchedule`）。
- 呼び出し元5ファイルを移行。`JyusyoMatchingService` のみコンストラクタDI設計のため、
  注入する型と引数名を `RaceScheduleRepository? raceScheduleRepository` へ変更した
  （生成箇所2つはいずれも引数なし呼び出しのため影響なし）。
  `TrackConditionsScraperService` の `_raceRepo` はフィールドではなくメソッド内ローカル変数だった。
- 3サブフェーズ・3コミット。前回同様、一時的な `@Deprecated` 委譲ブリッジを挟んで段階移行し最後に撤去。
- **ロジック・SQL・スキーマ・メソッドシグネチャは無変更。**
  `race_repository.dart` の差分は削除133行・追加0行。
- `flutter analyze` はベースラインと完全一致（679件 / error 0）、`flutter test` 107件全パス。
  実機で開催日程・重賞一覧・購入履歴の日付・馬場情報を確認済み。
- **結果: `RaceRepository` は 370行/6ドメイン → 94行/レース結果5メソッドのみに純化。**
  `db/repositories/` は11 → 16ファイル。
- 今後の候補（未着手）: `RaceRepository` を `RaceResultRepository` へリネーム（呼び出し元20ファイル超のため
  IDEの一括リネーム推奨）。Smart UIパターンの解消（UI層からのDBアクセス）、シングルトンのDI化。

### 2026-09-09 RaceRepository のドメイン分割（SRP違反の解消）

指示書: `memory/RaceRepository分割_CLI指示書.md`

- ゴッドクラス化していた `RaceRepository`（370行 / 6ドメイン）から4ドメインを分離。残り228行。
- 新設リポジトリ（いずれも `lib/db/repositories/`）
  `race_memo_repository.dart` (race_memos) / `race_statistics_repository.dart` (race_statistics) /
  `featured_race_repository.dart` (featured_races) / `shutuba_table_cache_repository.dart` (shutuba_table_cache)
- 移行は3フェーズ・7コミット。呼び出し元が7ファイルに及ぶ出馬表キャッシュのみ、
  一時的な `@Deprecated` 委譲ブリッジを挟んで段階移行し、最後に撤去した。
- **ロジック・SQL・スキーマ・メソッドシグネチャは一切変更していない。**
  `race_repository.dart` の差分は削除143行・追加0行。呼び出し元12ファイルの変更は
  import / フィールド宣言 / レシーバ名のみ。
- `flutter analyze` 新規エラー0件、`flutter test` 107件全パス。
  実機で起動・未来レースの情報取得・確定済みレース表示を確認済み。
- `RaceRepository` の残存は レース結果5メソッド / 開催日程7メソッド。
  次の分離候補は `race_schedules` + `week_schedules_cache`（呼び出し元5ファイル）。
- 注意: `test_apps/database_migration_app.dart`（`.gitignore` 対象）も1箇所修正済み。
  未追跡のためコミットには含まれず、ローカル変更として残っている。

### 2026-09-05 過去分析タブの再編成（フェーズ1〜4完了）

設計レポート: `memory/タブ再編成_設計レポート.md`

- **親タブの並び替え**（race_page.dart）
  出馬表 / 出走馬分析 / 能力分析(Rt) / 過去分析 / オッズ分析 / 騎手特性 / レース結果 / レース詳細
- **共有データバンドルの導入**
  `RaceAnalysisBundle` + `RaceAnalysisBundleLoader` を新設。
  従来 StatsMatchTab が自前で行っていた約300クエリの読み込みを親ページで1回にまとめた。
  実測 351クエリ / 4,517ms。子タブを分割しても読み込みは1回のみ。
- **子タブの再編成**（race_statistics_page.dart）
  傾向分析タブを廃止し、ペース / 馬場 / 血統 / ローテ / 人気妙味 の5タブへ分割。
  総合タブから馬場・血統・ラップの3カードを各タブへ移設。
  StatsMatchTab は結果分析タブ専用として残存（コード無変更）。
- **各タブへ「今回の該当馬」カードを追加**
  過去傾向と今回の出走メンバーを突き合わせ、最大5頭を選出。
  並べ替えは生の率ではなく**リフト値**（率 ÷ 全体平均）。勝率/連対率/複勝率を切替可能。
- **総合タブに12ファクター横断のマトリクスを追加**
  ペース・馬場は中庸シナリオ固定で集計（`neutralMetric`）。
- **馬体重の当日/前走フォールバック**を `weight_factor.dart` と同じ挙動に統一。
- 脚質タブに、母数が「区分の定員」であることを説明する注意書きを追加（4脚質×4リフト水準の16パターン）。
- バグ修正: `styleDistribution` は 0.0〜1.0 の比率なのに % 表示していた（0.6→「1%」）。

新規ファイル: `models/race_analysis_bundle.dart` /
`logic/analysis/race_analysis_bundle_loader.dart` /
`logic/analysis/factor_candidate_selector.dart` /
`logic/analysis/bundle_factor_selector.dart` /
`widgets/factor_candidates_card.dart` / `widgets/horse_number_badge.dart`

