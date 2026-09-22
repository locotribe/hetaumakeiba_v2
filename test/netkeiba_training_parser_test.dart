// test/netkeiba_training_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/netkeiba_training_parser.dart';

const _oikiriHtml = '''
<html><body>
<table id="All_Oikiri_Table" class="race_table_01 OikiriTable">
<tr><th>枠</th><th>馬番</th><th>馬名</th><th>日付</th></tr>
<tr class="OikiriDataHead1 HorseList" id="tr_14">
 <td rowspan="2" class="Waku1"><span>1</span></td>
 <td rowspan="2" class="Umaban">2</td>
 <td rowspan="2" class="Horse_Info fc"><div class="Horse_Name"><a href="https://db.netkeiba.com/horse/2022100547" target="_blank">アサクサグレース</a></div>
  <a href="https://db.netkeiba.com/horse/training.html?id=2022100547" class="LinkMore">前走</a></td>
 <td colspan="14" class="TrainingReview_Cell"> テンからビシッと攻めた１週前が転機。 </td>
</tr>
<tr class="OikiriDataHead1 HorseList">
 <td nowrap="" class="Training_Day">2026/09/16(水)</td>
 <td nowrap=""> ＣＷ </td>
 <td nowrap="">重</td>
 <td nowrap="">助手</td>
 <td class="TrainingTimeData txt_l">
  <ul class="TrainingTimeDataList">
   <li>89.0<span class="RapTime">(16.0)</span></li><li>73.0<span class="RapTime">(17.2)</span></li><li>55.8<span class="RapTime">(16.1)</span></li><li>39.7<span class="RapTime">(27.9)</span></li><li class="TokeiColor01">11.8<span class="RapTime">(11.8)</span></li>
  </ul>
  <div class="Comment_Cell"><p>内<a href="https://db.netkeiba.com/horse/2024105150" target="_blank">レイルジェット</a>一杯と併せ０秒６先着</p></div>
 </td>
 <td nowrap="">8</td>
 <td nowrap="" class="TrainingLoad">馬也</td>
 <td nowrap="" class="Training_Critic">態勢整う</td>
 <td width="25" nowrap="" class="Rank_B">B</td>
</tr>
<tr class="OikiriDataHead2 HorseList" id="tr_20">
 <td rowspan="2" class="Waku6"><span>6</span></td>
 <td rowspan="2" class="Umaban">11</td>
 <td rowspan="2" class="Horse_Info fc"><div class="Horse_Name"><a href="https://db.netkeiba.com/horse/2021105202" target="_blank">ポエットリー</a></div></td>
 <td colspan="14" class="TrainingReview_Cell"> テンから少し力んだ。 </td>
</tr>
<tr class="OikiriDataHead1 HorseList">
 <td nowrap="" class="Training_Day">2026/09/17(木)</td>
 <td nowrap=""> 栗坂 <span class="IconWeekBestTime">一番時計</span> </td>
 <td nowrap="">稍</td>
 <td nowrap="">斎藤</td>
 <td class="TrainingTimeData txt_l">
  <ul class="TrainingTimeDataList">
   <li>-<span class="RapTime"></span></li><li class="TokeiColor01">52.4<span class="RapTime">(14.3)</span></li><li class="TokeiColor02">38.1<span class="RapTime">(13.3)</span></li><li>24.8<span class="RapTime">(12.5)</span></li><li>12.3<span class="RapTime">(12.3)</span></li>
  </ul>
 </td>
 <td nowrap=""></td>
 <td nowrap="" class="TrainingLoad">Ｇ一</td>
 <td nowrap="" class="Training_Critic">動き上々</td>
 <td width="25" nowrap="" class="Rank_A">A</td>
</tr>
</table>
</body></html>
''';

const _commentHtml = '''
<html><body>
<table id="All_Comment_Table" class="Stable_Comment Comment_Table_Show_All">
<tr><th>枠</th><th>馬番</th><th>馬名</th><th>コメント</th><th>評価</th></tr>
<tr>
 <td class="Waku1">1</td><td class="Waku">2</td>
 <td class="Horse_Name"><a href="https://db.netkeiba.com/horse/2022100547" target="_blank">アサクサグレース</a></td>
 <td class="txt_l"><dl class="Comment_Cell"><dt></dt><dd>暑さに弱いタイプです。改めて期待。<span>〈加藤公師〉</span></dd></dl></td>
 <td class="Hyoka"><span class="Icon_RaceInfo Icon_Mark_02"></span> </td>
</tr>
</table>
</body></html>
''';

const _horsePageHtml = '''
<html><body>
<ul class="table_list">
<li>
<table cellpadding="0" cellspacing="1" summary="調教タイム" class="race_table_01 nk_tb_common">
<caption> 2026/09/20&nbsp;&nbsp;阪神11R&nbsp;&nbsp;<a href="https://db.netkeiba.com/race/202609040611/">道頓堀S(3勝)</a>&nbsp;&nbsp;結果 ： 着 </caption>
<tbody>
<tr class="even"><th>日付</th><th>コース</th><th>馬場</th><th>乗り役</th><th>調教タイム</th><th>位置</th><th>脚色</th><th colspan="2">評価</th><th>映像</th></tr>
<tr><td colspan="14" style="text-align: left;">[短評]テンからビシッと攻めた。</td></tr>
<tr class="even">
 <td class="txt_center">2026/09/16 05:35:00(水)</td><td class="txt_center"> ＣＷ </td><td class="txt_center">重</td><td class="txt_center">助手</td>
 <td class="TrainingTimeData txt_l"><ul class="TrainingTimeDataList"><li>89.0</li><li>73.0</li><li>55.8</li><li>39.7</li><li class="TokeiColor01">11.8</li></ul></td>
 <td class="txt_center">8</td><td class="txt_center">馬也</td><td class="txt_center">態勢整う</td><td class="txt_center">B</td><td class="txt_center"></td>
</tr>
<tr>
 <td class="txt_center">2026/09/13 06:59:00(日)</td><td class="txt_center"> 栗坂 </td><td class="txt_center">良</td><td class="txt_center"></td>
 <td class="TrainingTimeData txt_l"><ul class="TrainingTimeDataList"><li>-</li><li>55.3</li><li>41.3</li><li>26.6</li><li>13.2</li></ul></td>
 <td class="txt_center"></td><td class="txt_center">馬也</td><td class="txt_center">順調</td><td class="txt_center">C</td><td class="txt_center"></td>
</tr>
</tbody>
</table>
</li>
<li>
<table cellpadding="0" cellspacing="1" summary="調教タイム" class="race_table_01 nk_tb_common">
<caption> 2026/06/28&nbsp;&nbsp;小倉11R&nbsp;&nbsp;<a href="https://db.netkeiba.com/race/202610020611/">紫川S(3勝)</a>&nbsp;&nbsp;結果 ： 8着 </caption>
<tbody>
<tr class="even"><th>日付</th><th>コース</th></tr>
<tr class="even">
 <td class="txt_center">2026/06/24 05:01:00(水)</td><td class="txt_center"> 栗坂 </td><td class="txt_center">良</td><td class="txt_center">助手</td>
 <td class="TrainingTimeData txt_l"><ul class="TrainingTimeDataList"><li>-</li><li>54.3</li><li class="TokeiColor02">38.7</li><li class="TokeiColor02">25.2</li><li class="TokeiColor01">11.9</li></ul></td>
 <td class="txt_center"></td><td class="txt_center">馬也</td><td class="txt_center">末脚良し</td><td class="txt_center">B</td><td class="txt_center"></td>
</tr>
</tbody>
</table>
</li>
</ul>
</body></html>
''';

void main() {
  group('parseOikiri', () {
    final result = NetkeibaTrainingParser.parseOikiri(
        _oikiriHtml, '202609040611',
        fetchedAt: '2026-09-22T12:00:00');

    test('馬ごとの評価（短評・評価文・評価）', () {
      expect(result.reviews.length, 2);
      final first = result.reviews[0];
      expect(first.horseId, '2022100547');
      expect(first.raceId, '202609040611');
      expect(first.shortReview, 'テンからビシッと攻めた１週前が転機。');
      expect(first.critic, '態勢整う');
      expect(first.rank, 'B');
      expect(first.oikiriFetchedAt, '2026-09-22T12:00:00');
      expect(result.reviews[1].rank, 'A');
    });

    test('調教1本（ウッド・併せ馬・色・ラップ）', () {
      expect(result.sessions.length, 2);
      final s = result.sessions[0];
      expect(s.horseId, '2022100547');
      expect(s.trainingDate, '20260916');
      expect(s.courseRaw, 'ＣＷ');
      expect(s.seq, 0);
      expect(s.trainingTime, isNull);
      expect(s.trackCondition, '重');
      expect(s.rider, '助手');
      expect(s.isBestTime, isNull);
      expect(s.slots, [89.0, 73.0, 55.8, 39.7, 11.8]);
      expect(s.laps, [16.0, 17.2, 16.1, 27.9, 11.8]);
      expect(s.colors, [0, 0, 0, 0, 1]);
      expect(s.position, 8);
      expect(s.trainingLoad, '馬也');
      expect(s.raceId, '202609040611');
      expect(s.source, 'oikiri');
      final partner = s.partners!.single;
      expect(partner.side, '内');
      expect(partner.horseId, '2024105150');
      expect(partner.name, 'レイルジェット');
      expect(partner.text, '一杯と併せ０秒６先着');
    });

    test('調教1本（坂路・一番時計・位置なし・併せ馬なし）', () {
      final s = result.sessions[1];
      expect(s.horseId, '2021105202');
      expect(s.courseRaw, '栗坂');
      expect(s.isBestTime, isTrue);
      expect(s.slots, [null, 52.4, 38.1, 24.8, 12.3]);
      expect(s.laps[0], isNull);
      expect(s.colors, [0, 1, 2, 0, 0]);
      expect(s.position, isNull);
      expect(s.trainingLoad, 'Ｇ一');
      expect(s.partners, isNull);
    });

    test('表が無い HTML は空', () {
      final empty = NetkeibaTrainingParser.parseOikiri('<html></html>', 'x');
      expect(empty.reviews, isEmpty);
      expect(empty.sessions, isEmpty);
    });
  });

  test('parseStableComment', () {
    final reviews = NetkeibaTrainingParser.parseStableComment(
        _commentHtml, '202609040611');
    expect(reviews.length, 1);
    expect(reviews[0].horseId, '2022100547');
    expect(reviews[0].stableComment, '暑さに弱いタイプです。改めて期待。');
    expect(reviews[0].stableSpeaker, '加藤公師');
    expect(reviews[0].stableMark, '02');
  });

  group('parseHorseTraining', () {
    final result = NetkeibaTrainingParser.parseHorseTraining(
        _horsePageHtml, '2022100547');

    test('レース見出し', () {
      expect(result.races.length, 2);
      expect(result.races[0].raceId, '202609040611');
      expect(result.races[0].raceDate, '20260920');
      expect(result.races[0].venueRace, '阪神11R');
      expect(result.races[0].raceName, '道頓堀S(3勝)');
      expect(result.races[0].result, '');
      expect(result.races[1].result, '8着');
    });

    test('短評', () {
      expect(result.reviews.length, 1);
      expect(result.reviews[0].raceId, '202609040611');
      expect(result.reviews[0].shortReview, 'テンからビシッと攻めた。');
    });

    test('調教1本（時刻付き・ラップなし・レース紐付け）', () {
      expect(result.sessions.length, 3);
      final s0 = result.sessions[0];
      expect(s0.trainingDate, '20260916');
      expect(s0.trainingTime, '0535');
      expect(s0.courseRaw, 'ＣＷ');
      expect(s0.laps, [null, null, null, null, null]);
      expect(s0.colors, [0, 0, 0, 0, 1]);
      expect(s0.position, 8);
      expect(s0.rank, 'B');
      expect(s0.raceId, '202609040611');
      expect(s0.source, 'horse_page');
      final s1 = result.sessions[1];
      expect(s1.trainingTime, '0659');
      expect(s1.rider, isNull);
      expect(s1.rank, 'C');
      final s2 = result.sessions[2];
      expect(s2.raceId, '202610020611');
      expect(s2.critic, '末脚良し');
      expect(s2.colors, [0, 0, 2, 2, 1]);
    });
  });
}
