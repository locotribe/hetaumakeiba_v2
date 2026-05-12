// [自動生成] 全競馬場データへのアクセス窓口 (v.3.1)
// このファイルはPythonスクリプトによって自動生成されました。手動での編集は推奨されません。

export 'package:hetaumakeiba_v2/models/elevation_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

// --- 各競馬場コースデータのインポート ---
import 'package:hetaumakeiba_v2/db/elevations/chukyo/chukyo_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/fukushima/fukushima_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/hakodate/hakodate_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/hanshin/hanshin_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/kokura/kokura_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/kyoto/kyoto_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/nakayama/nakayama_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/niigata/niigata_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/sapporo/sapporo_course.dart';
import 'package:hetaumakeiba_v2/db/elevations/tokyo/tokyo_course.dart';

class CourseElevations {
  /// アプリ全体で利用する全てのレースコースデータのリスト
  static const List<RaceCourseData> allRaceCourses = [
    // --- Chukyo ---
    ChukyoCourse.shiba1200,
    ChukyoCourse.shiba1300,
    ChukyoCourse.shiba1400,
    ChukyoCourse.shiba1600,
    ChukyoCourse.shiba2000,
    ChukyoCourse.shiba2200,
    ChukyoCourse.shiba3000,
    ChukyoCourse.dirt1200,
    ChukyoCourse.dirt1400,
    ChukyoCourse.dirt1800,
    ChukyoCourse.dirt1900,

    // --- Fukushima ---
    FukushimaCourse.shiba1000,
    FukushimaCourse.shiba1200,
    FukushimaCourse.shiba1700,
    FukushimaCourse.shiba1800,
    FukushimaCourse.shiba2000,
    FukushimaCourse.shiba2600,
    FukushimaCourse.dirt1000,
    FukushimaCourse.dirt1150,
    FukushimaCourse.dirt1700,
    FukushimaCourse.dirt2400,

    // --- Hakodate ---
    HakodateCourse.shiba1000,
    HakodateCourse.shiba1200,
    HakodateCourse.shiba1800,
    HakodateCourse.shiba2000,
    HakodateCourse.shiba2600,
    HakodateCourse.dirt1000,
    HakodateCourse.dirt1700,
    HakodateCourse.dirt2400,

    // --- Hanshin ---
    HanshinCourse.shibaInner1200,
    HanshinCourse.shibaInner1400,
    HanshinCourse.shibaInner2000,
    HanshinCourse.shibaInner2200,
    HanshinCourse.shibaInner3000,
    HanshinCourse.shibaOuter1600,
    HanshinCourse.shibaOuter1800,
    HanshinCourse.shibaOuter2400,
    HanshinCourse.dirt1200,
    HanshinCourse.dirt1400,
    HanshinCourse.dirt1800,
    HanshinCourse.dirt2000,

    // --- Kokura ---
    KokuraCourse.shiba1200,
    KokuraCourse.shiba1700,
    KokuraCourse.shiba1800,
    KokuraCourse.shiba2000,
    KokuraCourse.shiba2600,
    KokuraCourse.dirt1000,
    KokuraCourse.dirt1700,

    // --- Kyoto ---
    KyotoCourse.shibaInner1200,
    KyotoCourse.shibaInner1400,
    KyotoCourse.shibaInner1600,
    KyotoCourse.shibaInner2000,
    KyotoCourse.shibaOuter1400,
    KyotoCourse.shibaOuter1600,
    KyotoCourse.shibaOuter1800,
    KyotoCourse.shibaOuter2200,
    KyotoCourse.shibaOuter2400,
    KyotoCourse.shibaOuter3000,
    KyotoCourse.shibaOuter3200,
    KyotoCourse.dirt1200,
    KyotoCourse.dirt1400,
    KyotoCourse.dirt1800,
    KyotoCourse.dirt1900,

    // --- Nakayama ---
    NakayamaCourse.dirt1800,
    NakayamaCourse.dirt2400,
    NakayamaCourse.dirt2500,
    NakayamaCourse.shibaInner1800,
    NakayamaCourse.shibaInner2000,
    NakayamaCourse.shibaInner2500,
    NakayamaCourse.shibaInner3600,
    NakayamaCourse.shibaOuter1200,
    NakayamaCourse.shibaOuter1600,
    NakayamaCourse.shibaOuter2200,
    NakayamaCourse.dirt1200,
    NakayamaCourse.shibaOuter2600,
    NakayamaCourse.dirt1700,

    // --- Niigata ---
    NiigataCourse.shibaInner1200,
    NiigataCourse.shibaInner1400,
    NiigataCourse.shibaInner2000,
    NiigataCourse.shibaInner2200,
    NiigataCourse.shibaInner2400,
    NiigataCourse.shibaOuter1600,
    NiigataCourse.shibaOuter1800,
    NiigataCourse.shibaOuter2000,
    NiigataCourse.dirt1200,
    NiigataCourse.dirt1800,
    NiigataCourse.dirt2500,
    NiigataCourse.shibaStraight1000,

    // --- Sapporo ---
    SapporoCourse.shiba1000,
    SapporoCourse.shiba1200,
    SapporoCourse.shiba1500,
    SapporoCourse.shiba1800,
    SapporoCourse.shiba2000,
    SapporoCourse.shiba2600,
    SapporoCourse.dirt1000,
    SapporoCourse.dirt1700,
    SapporoCourse.dirt2400,

    // --- Tokyo ---
    TokyoCourse.shiba1400,
    TokyoCourse.shiba1600,
    TokyoCourse.shiba1800,
    TokyoCourse.shiba2000,
    TokyoCourse.shiba2300,
    TokyoCourse.shiba2400,
    TokyoCourse.shiba2500,
    TokyoCourse.shiba3400,
    TokyoCourse.dirt1300,
    TokyoCourse.dirt1400,
    TokyoCourse.dirt1600,
    TokyoCourse.dirt2100,
    TokyoCourse.dirt2400,
    TokyoCourse.dirt1200,
    TokyoCourse.shiba2600,

  ];

  /// 【便利機能】 競馬場コード、距離、トラックタイプから特定のコースデータを検索する
  static RaceCourseData? findRaceCourse(String venueCode, int distance, String trackType) {
    try {
      return allRaceCourses.firstWhere((course) =>
          course.venueCode == venueCode &&
          course.raceDistance == distance &&
          course.baseData.trackType == trackType);
    } catch (_) {
      return null;
    }
  }
}
