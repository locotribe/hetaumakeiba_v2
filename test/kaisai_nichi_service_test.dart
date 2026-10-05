// test/kaisai_nichi_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/services/kaisai_nichi_service.dart';

// [追加] netkeiba 開催一覧のHTMLから「競馬場コード→日次」を作る処理の検証 (v.2026.10.6+26100603)
void main() {
  group('KaisaiNichiService.parseNichiByVenue', () {
    test('1会場の日（2026-09-21 阪神7日目）は 09→07 だけ', () {
      const html = '<meta charset="UTF-8">\n<!-- block=race_list_sub (cp) -->\n'
          '<a href="../race/shutuba.html?race_id=202609040701&rf=race_list">1R</a>\n'
          '<a href="../race/movie.html?race_id=202609040701">動画</a>\n'
          '<a href="../race/shutuba.html?race_id=202609040712&rf=race_list">12R</a>\n';
      expect(KaisaiNichiService.parseNichiByVenue(html), {'09': '07'});
    });

    test('2会場の日（2026-09-19 中山・阪神5日目）は両方', () {
      const html = '<!-- block=race_list_sub (cp) -->\n'
          '<a href="../race/shutuba.html?race_id=202606040501&rf=race_list">1R</a>\n'
          '<a href="../race/shutuba.html?race_id=202609040501&rf=race_list">1R</a>\n';
      expect(KaisaiNichiService.parseNichiByVenue(html), {'06': '05', '09': '05'});
    });

    test('レースの無い日は空のMap（コメント内の race_ids= は拾わない）', () {
      const html = '<!-- block=race_list_sub (cg) -->\n'
          '//         var url = "output_pdf.html?d=" + d + "&" + "race_ids=" + raceIDs;\n';
      expect(KaisaiNichiService.parseNichiByVenue(html), <String, String>{});
    });

    test('開催一覧の目印が無いページは null', () {
      const html = '<html><body>Error</body></html>';
      expect(KaisaiNichiService.parseNichiByVenue(html), isNull);
    });
  });
}
