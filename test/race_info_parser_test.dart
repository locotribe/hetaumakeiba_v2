// test/race_info_parser_test.dart

// [追加] 過去レース表記揺れ吸収: RaceInfoParser の単体テスト。
// 入力は保存済みレース結果(race_results)に実在する書き方 (v.2026.9.30+26093004)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/race_info_parser.dart';

void expectCourse(
  String raceInfo, {
  required String? trackType,
  required String? direction,
  required int? distanceValue,
  required String? courseInOut,
}) {
  final info = RaceInfoParser.parse(raceInfo);
  expect(info.trackType, trackType, reason: 'trackType: $raceInfo');
  expect(info.direction, direction, reason: 'direction: $raceInfo');
  expect(info.distanceValue, distanceValue, reason: 'distanceValue: $raceInfo');
  expect(info.courseInOut, courseInOut, reason: 'courseInOut: $raceInfo');
}

void main() {
  group('結果ページ(db.netkeiba)の書き方', () {
    test('芝右1800m(無印)は内外なし', () {
      expectCourse('芝右1800m / 天候 : 晴 / 芝 : 良 / 発走 : 15:30',
          trackType: '芝', direction: '右', distanceValue: 1800, courseInOut: null);
    });

    test('ダ右1800m(無印)', () {
      expectCourse('ダ右1800m / 天候 : 曇 / ダート : 稍重 / 発走 : 12:10',
          trackType: 'ダ', direction: '右', distanceValue: 1800, courseInOut: null);
    });

    test('芝右 外1600m は外回り', () {
      expectCourse('芝右 外1600m / 天候 : 晴 / 芝 : 良 / 発走 : 15:30',
          trackType: '芝', direction: '右', distanceValue: 1600, courseInOut: '外');
    });

    test('芝左 外2000m は外回り', () {
      expectCourse('芝左 外2000m / 天候 : 晴 / 芝 : 良 / 発走 : 15:45',
          trackType: '芝', direction: '左', distanceValue: 2000, courseInOut: '外');
    });

    test('芝直線1000m は方向「直」', () {
      expectCourse('芝直線1000m / 天候 : 晴 / 芝 : 良 / 発走 : 15:45',
          trackType: '芝', direction: '直', distanceValue: 1000, courseInOut: null);
    });

    test('芝右 内2周3600m', () {
      expectCourse('芝右 内2周3600m / 天候 : 晴 / 芝 : 良 / 発走 : 15:45',
          trackType: '芝', direction: '右', distanceValue: 3600, courseInOut: '内2周');
    });

    test('旧形式 芝右2200m(内)', () {
      expectCourse('芝右2200m(内) / 天候 : 晴 / 芝 : 良',
          trackType: '芝', direction: '右', distanceValue: 2200, courseInOut: '内');
    });
  });

  group('障害は「障」', () {
    test('障芝2750m', () {
      expectCourse('障芝2750m / 天候 : 晴 / 芝 : 良 / 発走 : 11:15',
          trackType: '障', direction: null, distanceValue: 2750, courseInOut: null);
    });

    test('障芝 外-内2850m', () {
      expectCourse('障芝 外-内2850m / 天候 : 晴 / 芝 : 良 / 発走 : 11:25',
          trackType: '障', direction: null, distanceValue: 2850, courseInOut: '外-内');
    });

    test('障芝 ダート2880m', () {
      expectCourse('障芝 ダート2880m / 天候 : 雨 / 芝 : 良 / 発走 : 11:35',
          trackType: '障', direction: null, distanceValue: 2880, courseInOut: null);
    });
  });

  group('race.netkeiba の書き方(出馬表と同じ語彙)', () {
    test('芝2200m (右 外 C)', () {
      expectCourse('15:45発走 / 芝2200m (右 外 C) / 天候:雨 / 馬場:重',
          trackType: '芝', direction: '右', distanceValue: 2200, courseInOut: '外 C');
    });

    test('芝2000m (右 A)', () {
      expectCourse('15:45発走 / 芝2000m (右 A) / 天候:晴 / 馬場:良',
          trackType: '芝', direction: '右', distanceValue: 2000, courseInOut: 'A');
    });

    test('芝3600m (右 内2周 A)', () {
      expectCourse('15:45発走 / 芝3600m (右 内2周 A) / 天候:晴 / 馬場:良',
          trackType: '芝', direction: '右', distanceValue: 3600, courseInOut: '内2周 A');
    });
  });

  group('対象外', () {
    test('ばんえい 直200m は全て null', () {
      expectCourse('直200m / 天候 : 曇 / 水分量 : 2.4 / 発走 : 19:25',
          trackType: null, direction: null, distanceValue: null, courseInOut: null);
    });

    test('空文字は全て null', () {
      expectCourse('',
          trackType: null, direction: null, distanceValue: null, courseInOut: null);
    });
  });
}
