// test/race_result_scraper_race_info_test.dart

// [追加] レース結果のコース情報取得修正: parseRaceInfoText の単体テスト (v.2026.9.30+26093003)

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';

void main() {
  group('RaceResultScraperService.parseRaceInfoText', () {
    test('新しい並び(diary_snap_cut の内側に p)でも取れる', () {
      final doc = html.parse('''
<div class="data_intro"><dl class="racedata fc"><dt>11R</dt><dd>
<h1>第60回スプリンターズS(GI)</h1>
<diary_snap_cut><p><span>
芝右 外1200m&nbsp;/&nbsp;
天候 : 曇&nbsp;/&nbsp;
芝 : 稍重&nbsp;&nbsp;/&nbsp;
発走 : 15:40
</span><br /><a href="#">過去のスプリンターズＳ</a></p></diary_snap_cut>
</dd></dl></div>''');
      expect(
        RaceResultScraperService.parseRaceInfoText(doc),
        '芝右 外1200m / 天候 : 曇 / 芝 : 稍重 / 発走 : 15:40',
      );
    });

    test('以前の並び(p の内側に diary_snap_cut)でも同じ書き方で取れる', () {
      final doc = html.parse('''
<div class="data_intro"><dl class="racedata fc"><dt>11R</dt><dd>
<h1>第73回クイーンS(GIII)</h1>
<p><diary_snap_cut><span>芝右1800m&nbsp;/&nbsp;天候 : 晴&nbsp;/&nbsp;芝 : 良&nbsp;&nbsp;/&nbsp;発走 : 15:25</span></diary_snap_cut></p>
</dd></dl></div>''');
      expect(
        RaceResultScraperService.parseRaceInfoText(doc),
        '芝右1800m / 天候 : 晴 / 芝 : 良 / 発走 : 15:25',
      );
    });

    test('コース情報が無ければ空文字', () {
      final doc = html.parse(
          '<div class="data_intro"><dl class="racedata fc"><dd><h1>x</h1></dd></dl></div>');
      expect(RaceResultScraperService.parseRaceInfoText(doc), '');
    });
  });
}
