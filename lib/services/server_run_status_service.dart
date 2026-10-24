// lib/services/server_run_status_service.dart

// [追加] 馬場データを作るサーバー（GitHub Actions）の最後の実行を取得し、馬場状態ページのヘッダーに出すための部品 (v.2026.10.24+26102405)
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// ヘッダーの表示の色分け。
/// normal: ふつう ／ stale: 最後の実行が古い ／ failed: 最後の実行が失敗 ／ unknown: 取得できなかった
enum ServerRunLevel { normal, stale, failed, unknown }

/// サーバー（GitHub Actions）の最後の実行。
class ServerRunStatus {
  /// 実行を始めた日時（端末のローカル時刻）
  final DateTime startedAt;

  /// 実行が終わっているか（status が completed）
  final bool completed;

  /// 成功したか（conclusion が success）
  final bool succeeded;

  const ServerRunStatus({
    required this.startedAt,
    required this.completed,
    required this.succeeded,
  });
}

class ServerRunStatusService {
  /// 馬場データを作るワークフローの実行一覧（新しい順・1件）。公開リポジトリなのでログイン不要
  static const String latestRunUrl =
      'https://api.github.com/repos/locotribe/keiba-track-conditions/actions/workflows/update_track_conditions.yml/runs?per_page=1';

  /// 最後の実行からこれより長くたったら「古い」とする。
  /// 実行は毎日1回だが、開始時刻が 21時〜翌3時ごろとばらつくため、余裕を持たせて48時間
  static const Duration staleAfter = Duration(hours: 48);

  /// API の応答から最後の実行を取り出す。取り出せないときは null
  static ServerRunStatus? parseLatestRun(Map<String, dynamic> data) {
    final runs = data['workflow_runs'];
    if (runs is! List || runs.isEmpty) return null;
    final run = runs.first;
    if (run is! Map) return null;
    final started = run['run_started_at'] ?? run['created_at'];
    if (started is! String) return null;
    final parsed = DateTime.tryParse(started);
    if (parsed == null) return null;
    return ServerRunStatus(
      startedAt: parsed.toLocal(),
      completed: run['status'] == 'completed',
      succeeded: run['conclusion'] == 'success',
    );
  }

  /// 表示の色分けを決める。失敗を古さより優先する
  static ServerRunLevel levelOf(ServerRunStatus? status, DateTime now) {
    if (status == null) return ServerRunLevel.unknown;
    if (status.completed && !status.succeeded) return ServerRunLevel.failed;
    if (now.difference(status.startedAt) > staleAfter) return ServerRunLevel.stale;
    return ServerRunLevel.normal;
  }

  /// ヘッダーの1行目の文字。例: 「サーバー」「サーバー 失敗」「サーバー 実行中」
  static String headLabelOf(ServerRunStatus? status) {
    if (status == null) return 'サーバー';
    if (!status.completed) return 'サーバー 実行中';
    if (!status.succeeded) return 'サーバー 失敗';
    return 'サーバー';
  }

  /// ヘッダーの2行目の文字（実行を始めた日時）。例: 「10/24 21:59」。取れないときは「--」
  static String timeLabelOf(ServerRunStatus? status) {
    if (status == null) return '--';
    return DateFormat('M/d HH:mm').format(status.startedAt);
  }

  /// 最後の実行を取得する。通信できない・回数制限などで取れないときは null
  Future<ServerRunStatus?> fetchLatest() async {
    try {
      final response = await http.get(
        Uri.parse(latestRunUrl),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return parseLatestRun(data);
    } catch (e) {
      debugPrint('ServerRunStatusService fetchLatest Error: $e');
      return null;
    }
  }
}
