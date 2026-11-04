// lib/widgets/shutuba_tabs/past_records_status_dialog.dart

// [追加] 過去走の取得状況ポップアップ: 馬詳細タブの「過去走を取り直す」を押したときに出すポップアップ。
// 出走馬の戦績と戦績内レースの結果が揃っているか・何が欠けているか・取得に失敗したものは何か・netkeibaのログイン状態を表示し、
// 「取得する」ボタンを押すと true を返して閉じる（実際の取得は呼び出し側が始める） (v.2026.11.5+26110501)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/past_record_status.dart';
import 'package:hetaumakeiba_v2/screens/netkeiba_login_page.dart';
import 'package:hetaumakeiba_v2/services/past_records_status_service.dart';

/// 過去走の取得状況ポップアップを出す。「取得する」が押されたら true、閉じたら false（枠外タップは null）を返す。
Future<bool?> showPastRecordsStatusDialog({
  required BuildContext context,
  required String raceId,
  required List<PastRecordHorse> horses,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => PastRecordsStatusDialog(raceId: raceId, horses: horses),
  );
}

class PastRecordsStatusDialog extends StatefulWidget {
  final String raceId;
  final List<PastRecordHorse> horses;

  const PastRecordsStatusDialog({
    super.key,
    required this.raceId,
    required this.horses,
  });

  @override
  State<PastRecordsStatusDialog> createState() =>
      _PastRecordsStatusDialogState();
}

class _PastRecordsStatusDialogState extends State<PastRecordsStatusDialog> {
  late Future<PastRecordsReport> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PastRecordsReport> _load() {
    return PastRecordsStatusService()
        .load(raceId: widget.raceId, horses: widget.horses);
  }

  /// netkeiba のログイン画面を開き、戻ったら状況を調べ直す。
  Future<void> _openLogin() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NetkeibaLoginPage()),
    );
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  String _formatDateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _horseLabels(List<PastRecordHorse> horses) =>
      horses.map((h) => h.label).join('、');

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildSummary(PastRecordsReport report) {
    switch (report.overall) {
      case PastRecordsOverall.failed:
        return _row(Icons.error, Colors.red, '取得に失敗したデータがあります');
      case PastRecordsOverall.missing:
        return _row(Icons.warning_amber_rounded, Colors.orange, '欠けているデータがあります');
      case PastRecordsOverall.loginSuspected:
        return _row(Icons.warning_amber_rounded, Colors.orange,
            'netkeibaのログインが切れている可能性があります');
      case PastRecordsOverall.complete:
        return _row(Icons.check_circle, Colors.green,
            '過去走のデータは揃っています（戦績を最新にしたいときは、下のボタンで取り直せます）');
    }
  }

  List<Widget> _buildReportBody(PastRecordsReport report) {
    final children = <Widget>[_buildSummary(report)];
    if (report.hasRunningRecord) {
      children.add(_row(Icons.sync, Colors.blueGrey,
          '取得中の記録があります（画面下のバーに進み具合が出ている間は取得中です）'));
    }

    // 出走馬の戦績
    children.add(_section('出走馬の戦績（${widget.horses.length}頭）'));
    children.add(_row(Icons.check_circle, Colors.green,
        '取得済み: ${report.fetchedHorses.length}頭'));
    if (report.debutHorses.isNotEmpty) {
      children.add(_row(Icons.info_outline, Colors.blueGrey,
          '初出走のため戦績なし（正常）: ${_horseLabels(report.debutHorses)}'));
    }
    if (report.missingHorses.isNotEmpty) {
      children.add(_row(Icons.warning_amber_rounded, Colors.orange,
          '未取得: ${_horseLabels(report.missingHorses)}'));
    }
    if (report.failedHorses.isNotEmpty) {
      children.add(_row(Icons.error, Colors.red,
          '取得に失敗: ${_horseLabels(report.failedHorses)}'));
    }

    // 戦績内レースの結果
    children.add(_section('戦績内のレース結果（${report.pastRaceTotal}件）'));
    children.add(_row(Icons.check_circle, Colors.green,
        '保存済み: ${report.savedRaceCount}件'));
    if (report.unsavedRaceIds.isNotEmpty) {
      children.add(_row(Icons.warning_amber_rounded, Colors.orange,
          '未保存: ${report.unsavedRaceIds.length}件'));
    }
    if (report.failedRaceIds.isNotEmpty) {
      children.add(_row(Icons.error, Colors.red,
          '取得に失敗（未保存のまま）: ${report.failedRaceIds.length}件'));
    }
    if (report.provisionalRaceIds.isNotEmpty) {
      children.add(_row(Icons.warning_amber_rounded, Colors.orange,
          '速報版のため取り直す対象: ${report.provisionalRaceIds.length}件'));
    }

    // netkeibaのログイン状態
    children.add(_section('netkeibaのログイン'));
    if (!report.isLoggedIn) {
      children.add(_row(Icons.info_outline, Colors.blueGrey,
          '未ログイン（ログインしていない記録です）。タイム指数・馬場指数・備考は最新の走しか取得できません'));
    } else if (report.loginSuspected) {
      children.add(_row(Icons.warning_amber_rounded, Colors.orange,
          'ログイン中の記録ですが、最後の取得でタイム指数が伏せ字（**）でした。ログインが切れている可能性があります: ${_horseLabels(report.maskedHorses)}'));
    } else {
      children.add(_row(Icons.check_circle, Colors.green, 'ログイン中'));
    }
    if (!report.isLoggedIn || report.loginSuspected) {
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _openLogin,
          icon: const Icon(Icons.login, size: 18),
          label: const Text('netkeibaにログインする'),
        ),
      ));
    }

    if (report.performanceUpdatedAt != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '戦績の最後の取得記録: ${_formatDateTime(report.performanceUpdatedAt!)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ));
    }
    return children;
  }

  Widget _buildContent() {
    return FutureBuilder<PastRecordsReport>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _row(Icons.error, Colors.red,
              '取得状況を調べられませんでした: ${snapshot.error}');
        }
        final report = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _buildReportBody(report),
          ),
        );
      },
    );
  }

  /// 取得ボタン。調べ終わって全部揃っているときだけ文言を変える（取得できなくはしない。戦績を最新にしたい場合があるため）。
  Widget _buildStartButton() {
    return FutureBuilder<PastRecordsReport>(
      future: _future,
      builder: (context, snapshot) {
        final report = snapshot.data;
        final label = report != null && report.overall == PastRecordsOverall.complete
            ? '最新の状態に取り直す'
            : '取得する';
        return ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(label),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('過去走の取得状況'),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('閉じる'),
        ),
        _buildStartButton(),
      ],
    );
  }
}
