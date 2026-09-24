// test/training_display_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

HorseRaceRecord _race(String raceId, String date,
    {String venue = '', String raceNumber = '', String raceName = '', String rank = ''}) {
  return HorseRaceRecord(
    horseId: 'h1',
    raceId: raceId,
    date: date,
    venue: venue,
    weather: '',
    raceNumber: raceNumber,
    raceName: raceName,
    numberOfHorses: '',
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: '',
    rank: rank,
    jockey: '',
    jockeyId: '',
    carriedWeight: '',
    distance: '',
    trackCondition: '',
    time: '',
    margin: '',
    cornerPassage: '',
    pace: '',
    agari: '',
    horseWeight: '',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

MergedTrainingEntry _entry(String date) =>
    MergedTrainingEntry(trainingDate: date);

void main() {
  // [修正] 中間追切6列化: 期待値を6マスに更新（先頭6F・5Fが空欄） (v.2026.9.24+26092405)
  test('pakara だけの坂路: 6マスとラップ（2F→1F が抜けない）', () {
    final row = buildTrainingRowView(MergedTrainingEntry(
      trainingDate: '20260921',
      trainingTime: '0450',
      pakara: TrainingTimeModel(
        horseId: 'h1',
        trainingDate: '20260921',
        trainingTime: '0450',
        trackType: '坂路',
        location: '栗東',
        f4: 64.0,
        f3: 46.1,
        f2: 30.4,
        f1: 15.4,
      ),
    ));
    expect(row.courseLabel, '栗坂');
    expect(row.isHanro, isTrue);
    expect(row.cells.map((c) => c.time).toList(),
        [null, null, 64.0, 46.1, 30.4, 15.4]);
    expect(row.cells.map((c) => c.lap).toList(),
        [null, null, 17.9, 15.7, 15.0, 15.4]);
    expect(row.lastLapTrend, 1);
    expect(row.headerLabel, '26/09/21(月) 04:50 栗坂');
    expect(row.loadLabel, isNull);
    expect(row.rank, isNull);
  });

  // [修正] 中間追切6列化: 期待値を6マスに更新（netkeiba単独は2Fが空欄、3Fラップは2ハロンのまま） (v.2026.9.24+26092405)
  test('netkeiba のウッド: 色・脚色(位置)・評価・併せ馬', () {
    final row = buildTrainingRowView(MergedTrainingEntry(
      trainingDate: '20260916',
      trainingTime: '0535',
      netkeiba: NetkeibaTrainingSession(
        horseId: 'h1',
        trainingDate: '20260916',
        courseRaw: 'ＣＷ',
        seq: 0,
        trainingTime: '0535',
        trackCondition: '重',
        rider: '助手',
        isBestTime: true,
        slots: [89.0, 73.0, 55.8, 39.7, 11.8],
        colors: [0, 0, 0, 0, 1],
        position: 8,
        trainingLoad: '馬也',
        critic: '態勢整う',
        rank: 'B',
        partners: const [
          TrainingPartner(side: '内', name: 'レイルジェット', text: '一杯と併せ０秒６先着'),
        ],
      ),
    ));
    expect(row.isHanro, isFalse);
    expect(row.cells.map((c) => c.time).toList(),
        [89.0, 73.0, 55.8, 39.7, null, 11.8]);
    expect(row.cells.map((c) => c.lap).toList(),
        [16.0, 17.2, 16.1, 27.9, null, 11.8]);
    expect(row.cells.last.color, 1);
    expect(row.loadLabel, '馬也⑧');
    expect(row.lastLapTrend, -1);
    expect(row.headerLabel, '26/09/16(水) 05:35 ＣＷ 重 助手');
    expect(row.isBestTime, isTrue);
    expect(row.partners.single.fullText, '内レイルジェット一杯と併せ０秒６先着');
  });

  // [追加] 中間追切6列化: 突き合わせ済みは共有ハロンnetkeiba優先・2Fはpakara補完・3Fが丸まらない (v.2026.9.24+26092405)
  test('netkeiba＋pakara のウッド: 2Fはpakaraで補完、共有ハロンはnetkeiba優先で丸めない', () {
    final row = buildTrainingRowView(MergedTrainingEntry(
      trainingDate: '20260916',
      trainingTime: '0535',
      netkeiba: NetkeibaTrainingSession(
        horseId: 'h1',
        trainingDate: '20260916',
        courseRaw: 'ＣＷ',
        seq: 0,
        trainingTime: '0535',
        slots: [89.0, 73.0, 55.8, 39.7, 11.8],
        colors: [0, 0, 0, 0, 1],
      ),
      pakara: TrainingTimeModel(
        horseId: 'h1',
        trainingDate: '20260916',
        trainingTime: '0535',
        trackType: 'ウッド',
        location: '栗東',
        f6: 89.5,
        f5: 73.5,
        f4: 56.0,
        f3: 40.0,
        f2: 25.4,
        f1: 12.0,
      ),
    ));
    expect(row.isHanro, isFalse);
    // 共有ハロンは netkeiba 値を維持（pakara の 89.5 / 12.0 ではない）、2F だけ pakara(25.4)
    expect(row.cells.map((c) => c.time).toList(),
        [89.0, 73.0, 55.8, 39.7, 25.4, 11.8]);
    // 3F ラップが丸まらず 14.3、2F ラップ 13.6 に分割される
    expect(row.cells.map((c) => c.lap).toList(),
        [16.0, 17.2, 16.1, 14.3, 13.6, 11.8]);
    expect(row.cells.last.color, 1);
  });

  test('pickFinalEntry: このレースの調教ページ由来の行を優先、無ければ先頭', () {
    final oikiri = MergedTrainingEntry(
      trainingDate: '20260916',
      netkeiba: NetkeibaTrainingSession(
        horseId: 'h1',
        trainingDate: '20260916',
        courseRaw: 'ＣＷ',
        seq: 0,
        laps: [16.0, 17.2, 16.1, 27.9, 11.8],
        raceId: 'R1',
      ),
    );
    final latest = _entry('20260921');
    expect(pickFinalEntry([latest, oikiri], 'R1'), same(oikiri));
    expect(pickFinalEntry([latest, oikiri], 'R2'), same(latest));
    expect(pickFinalEntry([], 'R1'), isNull);
  });

  test('groupTrainingByRace: 調教日より後で最初のレースへ振り分け、新しい順', () {
    final groups = groupTrainingByRace(
      entries: [
        _entry('20260916'),
        _entry('20260901'),
        _entry('20260826'),
        _entry('20260420'),
        _entry('20260101'),
      ],
      pastRaces: [
        _race('P9', '2026/10/10'),
        _race('P1', '2026/08/30',
            venue: '2札幌6', raceNumber: '11', raceName: '日高S', rank: '7'),
        _race('P0', '2026/05/03', venue: '3京都4', raceNumber: '10', raceName: '朱雀S', rank: '中止'),
      ],
      currentRaceId: 'R',
      currentRaceYmd: '20260920',
    );
    expect(groups.length, 3);
    expect(groups[0].isCurrent, isTrue);
    expect(groups[0].title, '今回のレース');
    expect(groups[0].entries.map((e) => e.trainingDate).toList(),
        ['20260916', '20260901']);
    expect(groups[1].raceId, 'P1');
    expect(groups[1].title, '2026/08/30 札幌11R 日高S');
    expect(groups[1].result, '7着');
    expect(groups[1].entries.single.trainingDate, '20260826');
    expect(groups[2].raceId, 'P0');
    expect(groups[2].result, '中止');
    expect(groups[2].entries.map((e) => e.trainingDate).toList(),
        ['20260420', '20260101']);
  });

  // [追加] 調教タブ改修Step6: 調教と出走レースの並び順 (v.2026.9.23+26092303)
  test('buildTrainingTimeline: 日付の新しい順、同じ日はレースが先、調教は時刻の新しい順', () {
    final timeline = buildTrainingTimeline(
      [
        const MergedTrainingEntry(trainingDate: '20260826', trainingTime: '0600'),
        const MergedTrainingEntry(trainingDate: '20260916', trainingTime: '0535'),
        const MergedTrainingEntry(trainingDate: '20260916', trainingTime: '0710'),
      ],
      [
        _race('P1', '2026/08/30', raceName: '日高S'),
        _race('P2', '2026/08/26', raceName: '同日のレース'),
        _race('PX', '不明'),
      ],
    );
    expect(timeline.map((i) => i.isRace ? 'R:${i.race!.raceId}' : 'T:${i.date}${i.entry!.trainingTime}').toList(), [
      'T:202609160710',
      'T:202609160535',
      'R:P1',
      'R:P2',
      'T:202608260600',
    ]);
  });
}
