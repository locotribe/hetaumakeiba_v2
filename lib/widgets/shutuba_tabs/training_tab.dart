// lib/widgets/shutuba_tabs/training_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
// [修正] 馬詳細タブStep1: 読み込み・取得の処理を ViewModel に、表示部品を共通ファイルに移した。見た目・動作は変更なし (v.2026.9.23+26092306)
import 'package:hetaumakeiba_v2/view_models/race_training_view_model.dart';
import 'package:hetaumakeiba_v2/widgets/training/training_cards.dart';

// 「最終追い切り」（1頭1枚）と「中間追い切り含む」（レースごとのまとまり）を切り替える
class TrainingTabWidget extends StatefulWidget {
  final String raceId;
  final String raceDate;
  final List<PredictionHorseDetail> horses;

  const TrainingTabWidget({
    Key? key,
    required this.raceId,
    required this.raceDate,
    required this.horses,
  }) : super(key: key);

  @override
  State<TrainingTabWidget> createState() => _TrainingTabWidgetState();
}

class _TrainingTabWidgetState extends State<TrainingTabWidget> {
  late final RaceTrainingViewModel _viewModel;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _viewModel = RaceTrainingViewModel(
      raceId: widget.raceId,
      raceDate: widget.raceDate,
      horses: widget.horses,
    );
    _viewModel.load().then((_) => _viewModel.autoFetchRaceTrainingIfNeeded());
  }

  @override
  void didUpdateWidget(covariant TrainingTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _viewModel.horses = widget.horses;
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  /// 中間追い切り含む（馬ごとの折りたたみ、レースごとのまとまり）
  Widget _buildAllCard(PredictionHorseDetail horse) {
    final entries = _viewModel.entriesFor(horse.horseId);
    final finalEntry = pickFinalEntry(entries, widget.raceId);
    final finalRow =
        finalEntry == null ? null : buildTrainingRowView(finalEntry);
    final review = _viewModel.raceReviewFor(horse.horseId);
    final groups = groupTrainingByRace(
      entries: entries,
      pastRaces: _viewModel.pastRacesFor(horse.horseId),
      currentRaceId: widget.raceId,
      currentRaceYmd: _viewModel.raceYmd,
    );
    final isFetching = _viewModel.isFetchingHorse(horse.horseId);
    final summary = finalRow == null
        ? '調教データなし'
        : [finalRow.dateLabel, finalRow.courseLabel, finalRow.critic, finalRow.rank]
            .whereType<String>()
            .join(' ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: kTrainingGateBarWidth),
            child: ExpansionTile(
              key: PageStorageKey<String>('training_all_${horse.horseId}'),
              // 開いたときに競走馬調教ページを取得（必要なときだけ）
              onExpansionChanged: (expanded) {
                if (expanded) _viewModel.fetchHorseTrainingIfNeeded(horse.horseId);
              },
              title: TrainingHorseName(horse: horse),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (review?.shortReview != null)
                    TrainingShortReview(text: review!.shortReview!),
                  Text('最終: $summary',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFetching) const LinearProgressIndicator(minHeight: 2),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('調教データなし',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  )
                else
                  ...groups.map((group) => TrainingRaceGroupView(
                        group: group,
                        review: _viewModel.reviewForGroup(horse.horseId, group),
                      )),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: kTrainingGateBarWidth,
            child: TrainingGateBar(horse: horse),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(_viewModel.statusLabel,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _viewModel.fetchAll,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('調教データを取得'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  ToggleButtons(
                    isSelected: [!_showAll, _showAll],
                    onPressed: (index) => setState(() => _showAll = index == 1),
                    borderRadius: BorderRadius.circular(6),
                    constraints:
                        const BoxConstraints(minHeight: 32, minWidth: 110),
                    children: const [
                      Text('最終追い切り', style: TextStyle(fontSize: 12)),
                      Text('中間追い切り含む', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  if (!_viewModel.isLoggedIn)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '※netkeiba未ログインのため評価・コメントは表示されません',
                          maxLines: 2,
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _viewModel.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: widget.horses.length,
                      itemBuilder: (context, index) {
                        final horse = widget.horses[index];
                        return _showAll
                            ? _buildAllCard(horse)
                            : TrainingFinalCard(
                                horse: horse,
                                entries: _viewModel.entriesFor(horse.horseId),
                                raceId: widget.raceId,
                                review: _viewModel.raceReviewFor(horse.horseId),
                              );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
