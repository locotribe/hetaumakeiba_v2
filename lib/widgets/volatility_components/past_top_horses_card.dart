import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/volatility_analyzer.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

class PastTopHorsesCard extends StatelessWidget {
  final List<PastRaceTop3Result>? pastTop3Result;
  final Map<String, TrackConditionRecord> trackConditionMap;

  const PastTopHorsesCard({
    super.key,
    required this.pastTop3Result,
    required this.trackConditionMap,
  });

  @override
  Widget build(BuildContext context) {
    if (pastTop3Result == null || pastTop3Result!.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('過去レース上位3頭と馬場状態', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...pastTop3Result!.map((res) {
              final tc = trackConditionMap[res.raceId];

              bool isTurf = res.raceInfo.contains('芝') || res.raceInfo.contains('障');
              bool isDirt = res.raceInfo.contains('ダ');

              String conditionLabel = "";
              if (res.raceInfo.contains('不良')) {
                conditionLabel = '不良';
              } else if (res.raceInfo.contains('稍重')) {
                conditionLabel = '稍重';
              } else if (res.raceInfo.contains('重')) {
                conditionLabel = '重';
              } else if (res.raceInfo.contains('良')) {
                conditionLabel = '良';
              }

              bool hasTcDataTurf = tc != null && (tc.cushionValue != null || tc.moistureTurfGoal != null || tc.moistureTurf4c != null);
              bool hasTcDataDirt = tc != null && (tc.moistureDirtGoal != null || tc.moistureDirt4c != null);

              bool showConditionBox = conditionLabel.isNotEmpty || (isTurf && hasTcDataTurf) || (isDirt && hasTcDataDirt);

              return Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(4)),
                          child: Text('${res.year}年', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(res.raceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (showConditionBox)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isTurf)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (conditionLabel.isNotEmpty)
                                    Container(
                                      width: 32,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(2)),
                                      child: Text(conditionLabel, style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                                    ),
                                  if (hasTcDataTurf) ...[
                                    const Text('芝: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                    Text('ｸｯｼｮﾝ値 ${tc.cushionValue ?? "-"} / ', style: const TextStyle(fontSize: 11)),
                                    Text('含水率(G) ${tc.moistureTurfGoal ?? "-"}% (4C) ${tc.moistureTurf4c ?? "-"}%', style: const TextStyle(fontSize: 11)),
                                  ]
                                ],
                              ),
                            if (isDirt)
                              Padding(
                                padding: EdgeInsets.only(top: (isTurf && (conditionLabel.isNotEmpty || hasTcDataTurf)) ? 4.0 : 0.0),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (conditionLabel.isNotEmpty)
                                      Container(
                                        width: 32,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(2)),
                                        child: Text(conditionLabel, style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                      ),
                                    if (hasTcDataDirt) ...[
                                      const Text('ダート: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      Text('含水率(G) ${tc.moistureDirtGoal ?? "-"}% (4C) ${tc.moistureDirt4c ?? "-"}%', style: const TextStyle(fontSize: 11)),
                                    ]
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (showConditionBox)
                      const SizedBox(height: 8),

                    ...res.topHorses.map((h) {
                      Color rankColor = h.rank == 1 ? Colors.amber : (h.rank == 2 ? Colors.blueGrey : Colors.brown.shade400);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text('${h.rank}着', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rankColor))),
                            const SizedBox(width: 8),
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(2)),
                              child: Text(h.frameNumber, style: const TextStyle(fontSize: 10)),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                              child: Text(h.horseNumber, style: const TextStyle(fontSize: 10)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(h.horseName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${h.popularity}番人気', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}