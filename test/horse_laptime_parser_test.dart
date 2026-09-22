// test/horse_laptime_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/horse_laptime_parser.dart';

const _html = '''
<html><body>
<div class="HorseLapCard" data-result-rank="1" data-horse-lap-card=""
  data-individual-laps="12.7,11.4,12.4,12.6,12.3,12.2,12.2,12.1,11.6,11.0,11.0,11.2"
  data-race-laps="12.3,10.9,12.4,12.6,12.5,12.2,12.2,12.2,11.8,11.4,11.4,11.4">
 <div class="HorseLapCard_Header">
  <div class="HorseLapCard_TitleRow"><span class="HorseLapCard_Run">[前走]</span>
   <a class="HorseLapCard_RaceName" href="https://db.sp.netkeiba.com/race/202605021211/">東京優駿</a></div>
  <div class="HorseLapCard_DataRow"><span class="ResultRank01">1着</span><span class="RaceDay">2026/05/31</span>
   <span class="RaceVenue">東京</span><span class="RaceCourse Turf">芝2400m</span><span class="HorseLapCard_RaceType">瞬発戦</span></div>
 </div>
 <div class="LapCard_Splits" aria-label="前後半の区間タイム">
  <dl class=""><dt>前半3F</dt><dd><span class="LapCard_SplitTime">36.5</span> <span class="LapCard_RaceSplitTime">(35.6)</span></dd></dl>
  <dl class="LapCard_SplitFinish"><dt>後半3F</dt><dd><span class="LapCard_SplitTime Rank01">33.2</span> <span class="LapCard_RaceSplitTime">(34.2)</span></dd></dl>
  <dl class=""><dt>前半5F</dt><dd><span class="LapCard_SplitTime">61.4</span> <span class="LapCard_RaceSplitTime">(60.7)</span></dd></dl>
  <dl class="LapCard_SplitFinish"><dt>後半5F</dt><dd><span class="LapCard_SplitTime Rank01">56.9</span> <span class="LapCard_RaceSplitTime">(57.7)</span></dd></dl>
 </div>
</div>
<div class="HorseLapCard" data-horse-lap-card=""
  data-individual-laps="00.0,00.0,00.0,00.0" data-race-laps="12.5,11.0,11.8,12.3">
 <a class="HorseLapCard_RaceName" href="https://db.sp.netkeiba.com/race/202606030811/">皐月賞</a>
</div>
</body></html>
''';

void main() {
  test('前走のカードを読み、伏せ字のカードは入れない', () {
    final extras = HorseLapTimeParser.parse(_html, '2023107089',
        fetchedAt: '2026-09-23T12:00:00');
    expect(extras.length, 1);
    final e = extras.single;
    expect(e.horseId, '2023107089');
    expect(e.raceId, '202605021211');
    expect(e.individualFirst3f, 36.5);
    expect(e.individualLast3f, 33.2);
    expect(e.individualFirst5f, 61.4);
    expect(e.individualLast5f, 56.9);
    expect(e.individualLaps!.length, 12);
    expect(e.individualLaps!.first, 12.7);
    expect(e.raceLaps!.last, 11.4);
    expect(e.lapRaceType, '瞬発戦');
    expect(e.lapPageFetchedAt, '2026-09-23T12:00:00');
  });

  test('parseLaps: 空・数字以外・すべて0は null', () {
    expect(HorseLapTimeParser.parseLaps(null), isNull);
    expect(HorseLapTimeParser.parseLaps(''), isNull);
    expect(HorseLapTimeParser.parseLaps('12.1,abc'), isNull);
    expect(HorseLapTimeParser.parseLaps('00.0,00.0'), isNull);
    expect(HorseLapTimeParser.parseLaps('12.1, 11.5'), [12.1, 11.5]);
  });

  test('カードが無い HTML は空', () {
    expect(HorseLapTimeParser.parse('<html></html>', 'h'), isEmpty);
  });
}
