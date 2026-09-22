// lib/widgets/horse_detail/training_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/view_models/race_training_view_model.dart';
import 'package:hetaumakeiba_v2/widgets/training/training_cards.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの「調教」（最終追い切り／中間追い切り含む／全頭一覧。設計書 3-5） (v.2026.9.23+26092308)

/// 調教の表示の切替（タブ単位で持ち、全ページ共通）
enum HorseDetailTrainingMode { finalOnly, withInterim, allHorses }

class TrainingSection extends StatelessWidget {
  final PredictionHorseDetail horse;

  /// 全頭一覧に並べる馬（馬詳細タブの並び順）
  final List<PredictionHorseDetail> allHorses;
  final RaceTrainingViewModel viewModel;
  final String raceId;
  final HorseDetailTrainingMode mode;
  final ValueChanged<HorseDetailTrainingMode> onModeChanged;

  /// 全頭一覧でカードをタップしたとき
  final ValueChanged<PredictionHorseDetail> onSelectHorse;

  const TrainingSection({
    Key? key,
    required this.horse,
    required this.allHorses,
    required this.viewModel,
    required this.raceId,
    required this.mode,
    required this.onModeChanged,
    required this.onSelectHorse,
  }) : super(key: key);

  Widget _finalCard(PredictionHorseDetail target) {
    return TrainingFinalCard(
      horse: target,
      entries: viewModel.entriesFor(target.horseId),
      raceId: raceId,
      review: viewModel.raceReviewFor(target.horseId),
    );
  }

  List<Widget> _buildContent() {
    switch (mode) {
      case HorseDetailTrainingMode.finalOnly:
        return [_finalCard(horse)];
      case HorseDetailTrainingMode.withInterim:
        final groups = groupTrainingByRace(
          entries: viewModel.entriesFor(horse.horseId),
          pastRaces: viewModel.pastRacesFor(horse.horseId),
          currentRaceId: raceId,
          currentRaceYmd: viewModel.raceYmd,
        );
        return [
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
        ];
      case HorseDetailTrainingMode.allHorses:
        return [
          for (final target in allHorses)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelectHorse(target),
              child: Container(
                decoration: target.horseId == horse.horseId
                    ? BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: _finalCard(target),
              ),
            ),
        ];
    }
  }

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
        Center(
          child: ToggleButtons(
            isSelected: [
              mode == HorseDetailTrainingMode.finalOnly,
              mode == HorseDetailTrainingMode.withInterim,
              mode == HorseDetailTrainingMode.allHorses,
            ],
            onPressed: (index) =>
                onModeChanged(HorseDetailTrainingMode.values[index]),
            borderRadius: BorderRadius.circular(6),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 96),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('最終追い切り', style: TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('中間追い切り含む', style: TextStyle(fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('全頭一覧', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (viewModel.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ..._buildContent(),
      ],
    );
  }
}
