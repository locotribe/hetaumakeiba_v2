// lib/widgets/horse_detail/training_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/view_models/race_training_view_model.dart';
import 'package:hetaumakeiba_v2/widgets/training/training_cards.dart';

// [修正] 馬詳細タブStep4: 切替ボタンを馬詳細タブ側に移し、表示を「最終追切」「中間追切」「全頭一覧」の3つの部品に分けた (v.2026.9.23+26092309)

/// 調教の見出し文言と、未ログイン時の注記
class TrainingStatusHeader extends StatelessWidget {
  final RaceTrainingViewModel viewModel;

  const TrainingStatusHeader({Key? key, required this.viewModel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(viewModel.statusLabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (!viewModel.isLoggedIn)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '※netkeiba未ログインのため評価・コメントは表示されません',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

Widget _loading() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// 最終追い切り（1頭分のカード）
class TrainingFinalView extends StatelessWidget {
  final PredictionHorseDetail horse;
  final RaceTrainingViewModel viewModel;
  final String raceId;

  const TrainingFinalView({
    Key? key,
    required this.horse,
    required this.viewModel,
    required this.raceId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrainingStatusHeader(viewModel: viewModel),
        if (viewModel.isLoading)
          _loading()
        else
          TrainingFinalCard(
            horse: horse,
            entries: viewModel.entriesFor(horse.horseId),
            raceId: raceId,
            review: viewModel.raceReviewFor(horse.horseId),
          ),
      ],
    );
  }
}

/// 中間追い切り含む（レースごとのまとまり）
class TrainingInterimView extends StatelessWidget {
  final PredictionHorseDetail horse;
  final RaceTrainingViewModel viewModel;
  final String raceId;

  const TrainingInterimView({
    Key? key,
    required this.horse,
    required this.viewModel,
    required this.raceId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final groups = groupTrainingByRace(
      entries: viewModel.entriesFor(horse.horseId),
      pastRaces: viewModel.pastRacesFor(horse.horseId),
      currentRaceId: raceId,
      currentRaceYmd: viewModel.raceYmd,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrainingStatusHeader(viewModel: viewModel),
        if (viewModel.isLoading)
          _loading()
        else ...[
          if (viewModel.isFetchingHorse(horse.horseId))
            const LinearProgressIndicator(minHeight: 2),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('調教データなし',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            )
          else
            ...groups.map((group) => TrainingRaceGroupView(
                  group: group,
                  review: viewModel.reviewForGroup(horse.horseId, group),
                )),
        ],
      ],
    );
  }
}

/// 全頭の最終追い切り一覧（カードのタップでその馬へ）
class TrainingAllHorsesView extends StatelessWidget {
  final List<PredictionHorseDetail> horses;
  final RaceTrainingViewModel viewModel;
  final String raceId;
  final ValueChanged<PredictionHorseDetail> onSelectHorse;

  const TrainingAllHorsesView({
    Key? key,
    required this.horses,
    required this.viewModel,
    required this.raceId,
    required this.onSelectHorse,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrainingStatusHeader(viewModel: viewModel),
        if (viewModel.isLoading)
          _loading()
        else
          for (final horse in horses)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectHorse(horse),
              child: TrainingFinalCard(
                horse: horse,
                entries: viewModel.entriesFor(horse.horseId),
                raceId: raceId,
                review: viewModel.raceReviewFor(horse.horseId),
              ),
            ),
      ],
    );
  }
}
