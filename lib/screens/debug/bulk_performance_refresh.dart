// lib/screens/debug/bulk_performance_refresh.dart

// [一時] 陣営の本気度指数 実施順2: 過去走の一括取り直し（ドロワーの一時ボタンから呼ぶ）。
// horse_performance に過去走がある全馬の競走馬ページを、既存の scrapeHorsePerformance →
// insertOrUpdateHorsePerformance で1頭ずつ取り直す。処理済みの馬IDは SharedPreferences に保存し、
// 中止・アプリ終了・自動停止のあとも「続きから」再開できる。実行後、ボタンと一緒に削除する (v.2026.10.2+26100205)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/bulk_performance_refresh_plan.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// 処理済みの馬IDを保存する SharedPreferences のキー
const String _kDoneIdsPrefKey = 'bulk_performance_refresh_done_ids';

const String _kTitle = '過去走の一括取り直し';

enum _StartChoice { cancel, backup, resume, restart }

class _BulkRefreshResult {
  final BulkRefreshTally tally;
  final int targetCount;
  final bool stoppedByUser;
  final bool autoStopped;

  const _BulkRefreshResult({
    required this.tally,
    required this.targetCount,
    required this.stoppedByUser,
    required this.autoStopped,
  });
}

/// ドロワーの一時ボタンから呼ぶ入口。
/// [onBackup] には main_scaffold.dart の `_backupDatabase` を渡す（実行前・実行後のバックアップ用）。
Future<void> runBulkPerformanceRefresh(
  BuildContext context, {
  required Future<void> Function() onBackup,
}) async {
  if (!await NetkeibaSessionService.isLoggedIn()) {
    if (!context.mounted) return;
    await _showMessage(
      context,
      'netkeiba にログインしていません。\n'
      'ログインしてから実行してください（未ログインだとタイム指数・備考が最新走しか取れません）。',
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final allTargets = await _loadTargets();
  if (!context.mounted) return;
  if (allTargets.isEmpty) {
    await _showMessage(context, '過去走のある馬がいません。');
    return;
  }

  _StartChoice choice;
  while (true) {
    final savedDoneIds = _loadDoneIds(prefs);
    final remaining = remainingBulkRefreshTargets(allTargets, savedDoneIds);
    if (!context.mounted) return;
    choice = await _showStartDialog(
      context,
      allCount: allTargets.length,
      remainingCount: remaining.length,
      hasProgress: savedDoneIds.isNotEmpty,
    );
    if (choice == _StartChoice.backup) {
      await onBackup();
      continue;
    }
    break;
  }
  if (choice == _StartChoice.cancel) return;
  if (choice == _StartChoice.restart) {
    await prefs.remove(_kDoneIdsPrefKey);
  }

  final doneIds = _loadDoneIds(prefs);
  final targets = remainingBulkRefreshTargets(allTargets, doneIds);
  final rowsBefore = await _countPerformanceRows();
  if (!context.mounted) return;

  final result = await showDialog<_BulkRefreshResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _BulkRefreshProgressDialog(
      targets: targets,
      prefs: prefs,
      doneIds: doneIds,
    ),
  );
  if (result == null) return;

  final rowsAfter = await _countPerformanceRows();
  final finishedAll = result.tally.failed.isEmpty &&
      result.tally.processedCount == result.targetCount;
  int remainingAfter = 0;
  if (finishedAll) {
    await prefs.remove(_kDoneIdsPrefKey);
  } else {
    remainingAfter =
        remainingBulkRefreshTargets(allTargets, _loadDoneIds(prefs)).length;
  }
  if (!context.mounted) return;

  final wantsBackup = await _showResultDialog(
    context,
    result: result,
    rowsBefore: rowsBefore,
    rowsAfter: rowsAfter,
    remainingAfter: remainingAfter,
  );
  if (wantsBackup == true) {
    await onBackup();
  }
}

/// 対象: horse_performance に過去走がある全馬。最後に走った日が新しい順（同日は馬ID順）。
Future<List<BulkRefreshTarget>> _loadTargets() async {
  final db = await DbProvider().database;
  final rows = await db.rawQuery('''
    SELECT p.horse_id AS horseId, MAX(p.date) AS lastDate, hp.horseName AS horseName
    FROM ${DbConstants.tableHorsePerformance} p
    LEFT JOIN ${DbConstants.tableHorseProfiles} hp ON hp.horseId = p.horse_id
    GROUP BY p.horse_id
    ORDER BY lastDate DESC, p.horse_id ASC
  ''');
  return rows
      .map((row) => BulkRefreshTarget(
            horseId: (row['horseId'] as String?) ?? '',
            horseName: (row['horseName'] as String?) ?? '',
          ))
      .toList();
}

Set<String> _loadDoneIds(SharedPreferences prefs) {
  return (prefs.getStringList(_kDoneIdsPrefKey) ?? const <String>[]).toSet();
}

Future<int> _countPerformanceRows() async {
  final db = await DbProvider().database;
  return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM ${DbConstants.tableHorsePerformance}')) ??
      0;
}

Future<void> _showMessage(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(_kTitle),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

Future<_StartChoice> _showStartDialog(
  BuildContext context, {
  required int allCount,
  required int remainingCount,
  required bool hasProgress,
}) async {
  final allMinutes = estimatedBulkRefreshMinutes(allCount);
  final remainingMinutes = estimatedBulkRefreshMinutes(remainingCount);
  final String progressText = hasProgress
      ? '前回の続きがあります: 残り $remainingCount 頭（目安 約$remainingMinutes分）\n'
          '最初からやり直す場合は $allCount 頭（目安 約$allMinutes分）です。\n\n'
      : '対象は $allCount 頭です（目安 約$allMinutes分）。\n\n';
  final choice = await showDialog<_StartChoice>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(_kTitle),
      content: SingleChildScrollView(
        child: Text(
          '過去走のある馬の競走馬ページを1頭ずつ取り直し、その後の走を埋めます。\n'
          '$progressText'
          '・実行の前に「データのバックアップ」を取ってください。\n'
          '・netkeiba にログインした状態で実行してください。\n'
          '・処理中は画面を消さず、アプリを切り替えないでください。\n'
          '・途中で中止しても、次回「続きから」再開できます。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(_StartChoice.cancel),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(_StartChoice.backup),
          child: const Text('先にバックアップ'),
        ),
        if (hasProgress)
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_StartChoice.restart),
            child: const Text('最初から'),
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext)
              .pop(hasProgress ? _StartChoice.resume : _StartChoice.restart),
          child: Text(hasProgress ? '続きから' : '実行する'),
        ),
      ],
    ),
  );
  return choice ?? _StartChoice.cancel;
}

Future<bool?> _showResultDialog(
  BuildContext context, {
  required _BulkRefreshResult result,
  required int rowsBefore,
  required int rowsAfter,
  required int remainingAfter,
}) {
  final tally = result.tally;
  final String headline;
  if (result.autoStopped) {
    headline = '失敗が$kBulkRefreshMaxConsecutiveFailures頭続いたため自動で止めました。'
        '通信状態と netkeiba のログインを確かめ、時間をおいて「続きから」で再開してください。';
  } else if (result.stoppedByUser) {
    headline = '中止しました。次回「続きから」で再開できます。';
  } else if (tally.failed.isNotEmpty) {
    headline = '最後まで処理しましたが、失敗した馬がいます。'
        '次回「続きから」で失敗した馬だけ取り直せます。';
  } else {
    headline = 'すべての馬の取り直しが完了しました。';
  }
  final diff = rowsAfter - rowsBefore;
  final diffText = diff >= 0 ? '+$diff' : '$diff';
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(_kTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline),
            const SizedBox(height: 12),
            Text('今回の処理: ${tally.processedCount} / ${result.targetCount} 頭'),
            Text('成功 ${tally.successCount} 頭 ・ 失敗 ${tally.failed.length} 頭'),
            Text('残り（次回の対象）: $remainingAfter 頭'),
            Text('過去走の行数: $rowsBefore → $rowsAfter（$diffText）'),
            if (tally.failed.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('失敗した馬:'),
              SelectableText(tally.failed.map((t) => t.label).join('\n')),
            ],
            const SizedBox(height: 12),
            const Text(
              '終わったら「データのバックアップ」を取ってください。',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('閉じる'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('バックアップを取る'),
        ),
      ],
    ),
  );
}

/// 取り直しを実行しながら進捗を出すダイアログ。戻るボタンでは閉じず、終わると結果を返して閉じる。
class _BulkRefreshProgressDialog extends StatefulWidget {
  final List<BulkRefreshTarget> targets;
  final SharedPreferences prefs;
  final Set<String> doneIds;

  const _BulkRefreshProgressDialog({
    required this.targets,
    required this.prefs,
    required this.doneIds,
  });

  @override
  State<_BulkRefreshProgressDialog> createState() =>
      _BulkRefreshProgressDialogState();
}

class _BulkRefreshProgressDialogState
    extends State<_BulkRefreshProgressDialog> {
  final HorseRepository _horseRepository = HorseRepository();
  final BulkRefreshTally _tally = BulkRefreshTally();
  late final Set<String> _doneIds;
  String _currentLabel = '';
  bool _stopRequested = false;
  bool _autoStopped = false;

  @override
  void initState() {
    super.initState();
    _doneIds = {...widget.doneIds};
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    for (final target in widget.targets) {
      if (_stopRequested || !mounted) break;
      setState(() {
        _currentLabel = target.label;
      });
      final ok = await _refreshOne(target.horseId);
      if (ok) {
        _tally.recordSuccess();
        _doneIds.add(target.horseId);
        await widget.prefs.setStringList(_kDoneIdsPrefKey, _doneIds.toList());
      } else {
        _tally.recordFailure(target);
      }
      if (!mounted) return;
      setState(() {});
      if (_tally.shouldAutoStop) {
        _autoStopped = true;
        break;
      }
      await Future.delayed(kBulkRefreshInterval);
    }
    if (!mounted) return;
    Navigator.of(context).pop(_BulkRefreshResult(
      tally: _tally,
      targetCount: widget.targets.length,
      stoppedByUser:
          _stopRequested && _tally.processedCount < widget.targets.length,
      autoStopped: _autoStopped,
    ));
  }

  /// 1頭分を取り直す。取得結果が空なら少し待って1回だけ取り直し、それでも空なら失敗（false）。
  /// 対象は全頭DBに過去走がある馬なので、空は通信失敗とみなす。
  Future<bool> _refreshOne(String horseId) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(kBulkRefreshRetryDelay);
      }
      try {
        final List<HorseRaceRecord> scraped =
            await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);
        if (scraped.isEmpty) continue;
        for (final record in scraped) {
          await _horseRepository.insertOrUpdateHorsePerformance(record);
        }
        return true;
      } catch (e) {
        debugPrint('BulkPerformanceRefresh: $horseId の取り直しに失敗: $e');
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.targets.length;
    final processed = _tally.processedCount;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('過去走を取り直しています'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: total == 0 ? null : processed / total),
            const SizedBox(height: 12),
            Text('$processed / $total 頭'),
            const SizedBox(height: 4),
            Text('成功 ${_tally.successCount} 頭 ・ 失敗 ${_tally.failed.length} 頭'),
            const SizedBox(height: 4),
            Text(
              '取得中: $_currentLabel',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Text(
              '画面を消さず、アプリを切り替えないでください。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _stopRequested
                ? null
                : () {
                    setState(() {
                      _stopRequested = true;
                    });
                  },
            child: Text(_stopRequested ? '中止しています…' : '中止'),
          ),
        ],
      ),
    );
  }
}
