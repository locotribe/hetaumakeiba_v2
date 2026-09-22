// test/horse_past_race_extra_laps_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';

void main() {
  test('個別ラップの列が toMap / fromMap で往復できる', () {
    const extra = HorsePastRaceExtra(
      horseId: 'h1',
      raceId: 'r1',
      individualFirst3f: 36.5,
      individualLast3f: 33.2,
      individualFirst5f: 61.4,
      individualLast5f: 56.9,
      individualLaps: [12.7, 11.4, 11.0],
      raceLaps: [12.3, 10.9, 11.4],
      lapRaceType: '瞬発戦',
      lapPageFetchedAt: '2026-09-23T12:00:00',
    );
    final map = extra.toMap();
    expect(map['individual_laps'], '12.7,11.4,11.0');
    final back = HorsePastRaceExtra.fromMap(map);
    expect(back.individualLaps, [12.7, 11.4, 11.0]);
    expect(back.raceLaps, [12.3, 10.9, 11.4]);
    expect(back.individualLast3f, 33.2);
    expect(back.lapRaceType, '瞬発戦');
  });

  test('新聞ページ由来の行に個別ラップを重ねても既存値が残る', () {
    const fromNewspaper = HorsePastRaceExtra(
      horseId: 'h1',
      raceId: 'r1',
      paceMark: 'S',
      individualFirst3f: 36.4,
    );
    const fromLapPage = HorsePastRaceExtra(
      horseId: 'h1',
      raceId: 'r1',
      individualLast3f: 33.2,
      individualLaps: [12.7, 11.4],
    );
    final merged = fromLapPage.mergeOnto(fromNewspaper);
    expect(merged.paceMark, 'S');
    expect(merged.individualFirst3f, 36.4);
    expect(merged.individualLast3f, 33.2);
    expect(merged.individualLaps, [12.7, 11.4]);
  });
}
