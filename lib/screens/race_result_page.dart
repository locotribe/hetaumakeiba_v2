// lib/screens/race_result_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/logic/memo_import_logic.dart';
import 'package:hetaumakeiba_v2/models/analysis_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/screens/bulk_review_edit_page.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
// [追加] 状態管理・ビジネスロジックをViewModelへ分離 (v.13.41.0)
import 'package:hetaumakeiba_v2/view_models/race_result_view_model.dart';
import 'package:hetaumakeiba_v2/widgets/betting_ticket_card.dart';
import 'package:hetaumakeiba_v2/widgets/race_header_card.dart';
import 'package:hetaumakeiba_v2/widgets/race_review_card.dart';

class RaceResultPage extends StatefulWidget {
  final String raceId;
  final QrData? qrData;

  const RaceResultPage({
    super.key,
    required this.raceId,
    this.qrData,
  });

  @override
  State<RaceResultPage> createState() => _RaceResultPageState();
}

class _RaceResultPageState extends State<RaceResultPage> {
  // [修正] データ取得・加工ロジックをRaceResultViewModelへ移行 (v.13.41.0)
  late final RaceResultViewModel _viewModel;

  late PageController _ticketPageController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // [追加] ViewModelを生成し、画面の状態管理を委譲する (v.13.41.0)
    _viewModel = RaceResultViewModel(raceId: widget.raceId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeData();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _ticketPageController.dispose();
    // [追加] ViewModelの破棄を追加 (v.13.41.0)
    _viewModel.dispose();
    super.dispose();
  }

  // 初期データ設定（RouteSettingsからの引数受け取り含む）
  // [修正] _qrDataList/_pageDataFutureへの直接代入をやめ、ViewModel.initialize()へ委譲 (v.13.41.0)
  void _initializeData() {
    // 遷移元から渡された引数をチェック
    final args = ModalRoute.of(context)?.settings.arguments;
    int initialIndex = 0;
    List<QrData> initialQrDataList = [];

    if (args is Map && args.containsKey('siblingTickets')) {
      // 保存済みリストから遷移した場合
      final siblingTickets = args['siblingTickets'] as List<QrData>;
      initialQrDataList = siblingTickets;
      initialIndex = args['initialIndex'] as int? ?? 0;
    } else {
      // QR読み取りや直接遷移の場合（単一）
      if (widget.qrData != null) {
        initialQrDataList = [widget.qrData!];
      }
    }

    // データがない場合のフォールバック（通常ありえない）
    if (initialQrDataList.isEmpty && widget.qrData != null) {
      initialQrDataList = [widget.qrData!];
    }

    _ticketPageController = PageController(initialPage: initialIndex, viewportFraction: 0.92); // 少し隣が見えるように
    _viewModel.initialize(initialQrDataList, initialIndex);
  }

  // [修正] ViewModel.refreshData()へ処理を委譲し、結果メッセージをSnackBar表示する (v.13.41.0)
  Future<void> _handleRefresh() async {
    final result = await _viewModel.refreshData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _openBulkReviewEdit(RaceResult raceResult) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BulkReviewEditPage(
          raceId: widget.raceId,
          horseResults: raceResult.horseResults,
        ),
      ),
    );
    if (result == true) {
      _handleRefresh(); // 保存されたら画面を更新
    }
  }

  // [修正] ViewModel.importReviewsFromCsv()へ処理を委譲し、競合解決ダイアログはコールバックとして渡す (v.13.41.0)
  Future<void> _importReviewsFromCsv() async {
    final result = await _viewModel.importReviewsFromCsv(_resolveConflictDialog);
    if (mounted && result.message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  /// 競合発生時にユーザーに解決アクションを選択させるダイアログ
  Future<String?> _resolveConflictDialog(String title, MemoMergeResult conflict) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // 誤タップで閉じるのを防ぎ、必ず選択させる
      builder: (context) => AlertDialog(
        title: Text('競合の解決: $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('【現在のデータ】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(conflict.existingText.isEmpty ? '(なし)' : conflict.existingText),
              ),
              const Text('【インポートデータ】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(conflict.newText.isEmpty ? '(なし)' : conflict.newText),
              ),
              const Text('このデータをどのように処理しますか？', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, conflict.existingText),
            child: const Text('スキップ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, conflict.newText),
            child: const Text('CSVで上書き', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, '${conflict.existingText}\n\n${conflict.newText}'),
            child: const Text('追記する'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemoDialog(HorseResult horse) async {
    // [修正] UserSession経由でlocalUserIdを参照 (v.13.41.0)
    final userId = UserSession().localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final existingReviewMemo = horse.userMemo?.reviewMemo ?? '';
    final predictionMemo = horse.userMemo?.predictionMemo;

    // 既存メモ編集用のコントローラー
    final existingMemoController = TextEditingController(text: existingReviewMemo);
    // 新規追記用のコントローラー
    final appendController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${horse.horseName} - 回顧メモ'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 予想メモ（完全読み取り専用）
                  if (predictionMemo != null && predictionMemo.isNotEmpty) ...[
                    const Text('【当時の予想】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(top: 4.0, bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(predictionMemo, style: const TextStyle(fontSize: 13)),
                    ),
                  ],

                  // 2. 既存の回顧メモ（タップで修正可能だが、見た目は表示欄風）
                  if (existingReviewMemo.isNotEmpty) ...[
                    const Text('【これまでの回顧】 (タップで修正可)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: existingMemoController,
                      maxLines: null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.orange.shade50,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        contentPadding: const EdgeInsets.all(8.0),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. 追記用フォーム（ここに最初からフォーカスが当たるため、誤消去を防げる）
                  const Text('【追記】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: appendController,
                    autofocus: true, // 開いた瞬間ここにカーソルが合う
                    maxLines: null,
                    minLines: 3,
                    decoration: const InputDecoration(
                      hintText: '新たな気づきや次走へのメモを追記...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // 既存のメモ（編集反映）と、新しく追記したメモを結合
                  String finalMemo = existingMemoController.text.trim();
                  final appendedText = appendController.text.trim();

                  if (appendedText.isNotEmpty) {
                    if (finalMemo.isNotEmpty) {
                      finalMemo += '\n\n'; // 既存のメモがあれば改行を挟む
                    }
                    finalMemo += appendedText;
                  }

                  final newMemo = HorseMemo(
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: horse.userMemo?.predictionMemo, // 維持
                    reviewMemo: finalMemo, // 結合したメモを保存
                    timestamp: DateTime.now(),
                  );
                  // [修正] ViewModel.saveHorseMemo()へ保存処理を委譲 (v.13.41.0)
                  await _viewModel.saveHorseMemo(newMemo);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // [修正] FutureBuilderをListenableBuilderに置き換え、ViewModelの状態を監視する (v.13.41.0)
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListenableBuilder(
          listenable: _viewModel,
          builder: (context, _) {
            if (_viewModel.isLoading && _viewModel.pageData == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_viewModel.errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'エラー: ${_viewModel.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final pageData = _viewModel.pageData;
            if (pageData == null) {
              return const Center(child: Text('データがありません。'));
            }

            final parsedTickets = pageData.parsedTickets;
            final raceResult = pageData.raceResult;

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                children: [
                  if (parsedTickets.isNotEmpty)
                    _buildTicketPageView(parsedTickets, raceResult),

                  if (raceResult != null) ...[
                    if (raceResult.isIncomplete)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildIncompleteRaceDataCard(),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildRaceInfoCard(raceResult, pageData.pacePrediction),
                      ),
                      // 【新規追加】レース総評カードをここに挿入
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: RaceReviewCard(
                          raceId: widget.raceId,
                          userId: UserSession().localUserId ?? '',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildFullResultsCard(raceResult),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildRefundsCard(raceResult),
                      ),
                    ]
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _buildNoRaceDataCard(),
                    ),
                  ]
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // [修正] 収支計算・的中判定をViewModelのgetter経由で取得するよう変更 (v.13.41.0)
  Widget _buildTicketPageView(List<Map<String, dynamic>> parsedTickets, RaceResult? raceResult) {
    // 現在のチケットの収支計算
    final currentHitResult = _viewModel.currentHitResult;

    // レース全体の収支計算
    final balance = _viewModel.raceBalanceSummary;
    final raceTotalPurchase = balance.totalPurchase;
    final raceTotalPayout = balance.totalPayout;
    final raceTotalRefund = balance.totalRefund;
    final raceBalance = balance.balance;

    return Column(
      children: [
        // 1. 馬券イメージ（横スワイプ可能）
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _ticketPageController,
            itemCount: parsedTickets.length,
            onPageChanged: (index) {
              // [修正] setStateの代わりにViewModelへインデックス更新を委譲 (v.13.41.0)
              _viewModel.setCurrentTicketIndex(index);
            },
            itemBuilder: (context, index) {
              final ticket = parsedTickets[index];

              // 的中判定ロジック
              final isHit = _viewModel.isTicketHit(index);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Stack(
                  children: [
                    // 1層目: 馬券カード本体
                    BettingTicketCard(ticketData: ticket, raceResult: raceResult),

                    // 2層目: 的中画像 (的中時のみ表示)
                    if (isHit)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/images/hit.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // 2. インジケーター (複数枚ある場合のみ)
        if (parsedTickets.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(parsedTickets.length, (index) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _viewModel.currentTicketIndex == index ? Colors.blue.shade700 : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ),

        // 3. 表示中チケットの詳細結果（的中情報など）
        if (currentHitResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                if (currentHitResult.hitDetails.isNotEmpty) ...[
                  ...currentHitResult.hitDetails.map((detail) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('$detail', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
                if (currentHitResult.refundDetails.isNotEmpty) ...[
                  ...currentHitResult.refundDetails.map((detail) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('↩️ $detail', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
              ],
            ),
          ),

        // 4. レース全体の収支サマリーカード
        if (raceResult != null && !raceResult.isIncomplete)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: raceBalance > 0 ? Colors.blue.shade50 : (raceBalance < 0 ? Colors.red.shade50 : Colors.white),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('レース合計購入', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('${raceTotalPurchase}円', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('払戻・返還計', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('${raceTotalPayout + raceTotalRefund}円', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('レース収支', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '${raceBalance >= 0 ? '+' : ''}${raceBalance}円',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: raceBalance > 0 ? Colors.blue.shade800 : (raceBalance < 0 ? Colors.red.shade800 : Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIncompleteRaceDataCard() {
    return Card(
      elevation: 2,
      color: Colors.amber.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 32),
              const SizedBox(height: 12),
              const Text(
                'このレースはまだ結果を取得していません。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'レース確定後に、画面を下に引っ張って更新してください。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoRaceDataCard() {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'レース結果のデータはまだありません。\nレース確定後に再度ご確認ください。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildRaceInfoCard(RaceResult raceResult, RacePacePrediction? pacePrediction) {
    return RaceHeaderCard(
      title: raceResult.raceTitle,
      detailsLine1: raceResult.raceDate,
      detailsLine2: '${raceResult.raceInfo}\n${raceResult.raceGrade}',
    );
  }

  Widget _buildFullResultsCard(RaceResult raceResult) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分：枠線付きのボタン（OutlinedButton）に変更し、ラベルを明確化
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'レース結果',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _openBulkReviewEdit(raceResult),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0), // 少し角丸のカード風
                        ),
                      ),
                      child: const Text('一括編集', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8), // ボタン間の隙間
                    OutlinedButton(
                      onPressed: _importReviewsFromCsv,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      child: const Text('CSV入力', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      // [修正] ViewModel.exportReviewsAsCsv()を直接呼び出すよう変更 (v.13.41.0)
                      onPressed: () => _viewModel.exportReviewsAsCsv(),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      child: const Text('CSV出力', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('着')),
                  DataColumn(label: Text('馬番')),
                  DataColumn(label: Text('馬名')),
                  DataColumn(label: Text('騎手')),
                  DataColumn(label: Text('単勝')),
                  DataColumn(label: Text('人気')),
                  DataColumn(label: Text('メモ')),
                ],
                rows: raceResult.horseResults.map((horse) {
                  return DataRow(cells: [
                    DataCell(Text(horse.rank)),
                    DataCell(
                      Center(
                        child: Container(
                          width: 32,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: horse.frameNumber.gateBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                            border: horse.frameNumber == '1' ? Border.all(color: Colors.grey.shade400) : null,
                          ),
                          child: Text(
                            horse.horseNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: horse.frameNumber.gateTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(horse.horseName)),
                    DataCell(Text(horse.jockeyName)),
                    DataCell(Text(horse.odds)),
                    DataCell(Text(horse.popularity)),
                    DataCell(_buildMemoCell(horse)),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // [修正] 引数からuserCombinationsByTypeを除去し、ViewModelのgetterから取得するよう変更 (v.13.41.0)
  Widget _buildRefundsCard(RaceResult raceResult) {
    final userCombinationsByType = _viewModel.userCombinationsByType;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '払戻',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...raceResult.refunds.map((refund) {
              final ticketTypeName = bettingDict[refund.ticketTypeId] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        ticketTypeName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: refund.payouts.map((payout) {
                          final userCombosForThisType = userCombinationsByType[refund.ticketTypeId] ?? [];
                          bool isHit = userCombosForThisType.any((userCombo) {
                            switch (ticketTypeName) {
                              case '馬連':
                              case 'ワイド':
                              case '3連複':
                              case '枠連':
                                return setEquals(userCombo.toSet(), payout.combinationNumbers.toSet());
                              default:
                                return listEquals(userCombo, payout.combinationNumbers);
                            }
                          });

                          final hitTextStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700);
                          final hitDecoration = BoxDecoration(color: Colors.red.shade50);

                          return Container(
                            decoration: isHit ? hitDecoration : null,
                            padding: isHit ? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0) : null,
                            child: Text(
                              '${payout.combination} : ${payout.amount}円 (${payout.popularity}人気)',
                              style: isHit ? hitTextStyle : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoCell(HorseResult horse) {
    final reviewText = horse.userMemo?.reviewMemo ?? '';
    final hasReview = reviewText.isNotEmpty;

    return InkWell(
      onTap: () => _showMemoDialog(horse),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200), // 右端なので少し広めに許容
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                hasReview ? reviewText : 'メモなし',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasReview ? Colors.black87 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 16,
              color: hasReview ? Colors.orange.shade800 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
