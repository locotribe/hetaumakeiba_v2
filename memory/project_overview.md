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

**How to apply:** 分析ロジックの変更はlogic/analysis/、スクレイピングはservices/、画面UIはscreens/またはwidgets/を起点に探す。
