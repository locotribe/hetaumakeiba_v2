// test/netkeiba_training_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';

void main() {
  test('Session: toMap / fromMap で往復できる', () {
    final session = NetkeibaTrainingSession(
      horseId: 'h1',
      trainingDate: '20260916',
      courseRaw: 'ＣＷ',
      seq: 0,
      trainingTime: '0535',
      trackCondition: '重',
      rider: '助手',
      isBestTime: true,
      slots: [89.0, 73.0, 55.8, 39.7, 11.8],
      laps: [16.0, 17.2, 16.1, 27.9, 11.8],
      colors: [0, 0, 0, 0, 1],
      position: 8,
      trainingLoad: '馬也',
      critic: '態勢整う',
      rank: 'B',
      partners: const [
        TrainingPartner(
            side: '内',
            horseId: '2024105150',
            name: 'レイルジェット',
            text: '一杯と併せ０秒６先着'),
      ],
      raceId: '202609040611',
      source: 'oikiri',
    );
    final map = session.toMap();
    expect(map['partner_text'], '内レイルジェット一杯と併せ０秒６先着');
    expect(map['is_best_time'], 1);
    final back = NetkeibaTrainingSession.fromMap(map);
    expect(back.slots, [89.0, 73.0, 55.8, 39.7, 11.8]);
    expect(back.laps.last, 11.8);
    expect(back.colors, [0, 0, 0, 0, 1]);
    expect(back.isBestTime, isTrue);
    expect(back.partners!.single.horseId, '2024105150');
    expect(back.partners!.single.name, 'レイルジェット');
  });

  test('Session: 調教ページの行に競走馬ページの行を重ねると時刻とラップがそろう', () {
    final fromOikiri = NetkeibaTrainingSession(
      horseId: 'h1',
      trainingDate: '20260916',
      courseRaw: 'ＣＷ',
      seq: 0,
      slots: [89.0, 73.0, 55.8, 39.7, 11.8],
      laps: [16.0, 17.2, 16.1, 27.9, 11.8],
      partners: const [TrainingPartner(side: '内', name: 'A', text: '併入')],
      source: 'oikiri',
    );
    final fromHorsePage = NetkeibaTrainingSession(
      horseId: 'h1',
      trainingDate: '20260916',
      courseRaw: 'ＣＷ',
      seq: 0,
      trainingTime: '0535',
      slots: [89.0, 73.0, 55.8, 39.7, 11.8],
      source: 'horse_page',
    );
    final merged = fromHorsePage.mergeOnto(fromOikiri);
    expect(merged.trainingTime, '0535');
    expect(merged.laps, [16.0, 17.2, 16.1, 27.9, 11.8]);
    expect(merged.partners!.single.name, 'A');
    expect(merged.source, 'horse_page');
  });

  test('Review: null の項目は既存値を残す', () {
    const base = NetkeibaTrainingReview(
        raceId: 'r',
        horseId: 'h',
        shortReview: '短評',
        critic: '態勢整う',
        rank: 'B');
    const comment = NetkeibaTrainingReview(
        raceId: 'r',
        horseId: 'h',
        stableComment: 'コメント',
        stableSpeaker: '加藤公師');
    final merged = comment.mergeOnto(base);
    expect(merged.shortReview, '短評');
    expect(merged.rank, 'B');
    expect(merged.stableComment, 'コメント');
    final back = NetkeibaTrainingReview.fromMap(merged.toMap());
    expect(back.stableSpeaker, '加藤公師');
  });
}
