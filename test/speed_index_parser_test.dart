// test/speed_index_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_parser.dart';

void main() {
  group('parseRaceTime', () {
    test('分:秒.コンマ 形式を秒へ変換する', () {
      expect(parseRaceTime('2:04.8'), 124.8);
      expect(parseRaceTime('3:50.9'), 230.9);
    });

    test('異常値は null を返す', () {
      expect(parseRaceTime('0:00.0'), isNull);
      expect(parseRaceTime('-1:00.0'), isNull);
      expect(parseRaceTime('99:00.0'), isNull); // 1200秒超え
      expect(parseRaceTime(''), isNull);
      expect(parseRaceTime('abc'), isNull);
    });
  });

  group('parseDistance', () {
    test('馬場種別と距離を抽出する', () {
      final turf = parseDistance('芝1800');
      expect(turf?.surface, '芝');
      expect(turf?.meters, 1800);

      final dirt = parseDistance('ダ1800');
      expect(dirt?.surface, 'ダ');
      expect(dirt?.meters, 1800);

      final jump = parseDistance('障3380');
      expect(jump?.surface, '障');
      expect(jump?.meters, 3380);
    });

    test('不正な形式は null を返す', () {
      expect(parseDistance(''), isNull);
      expect(parseDistance('1800'), isNull);
      expect(parseDistance('芝'), isNull);
    });
  });

  group('parseCarriedWeight', () {
    test('斤量を double へ変換する', () {
      expect(parseCarriedWeight('58.5'), 58.5);
      expect(parseCarriedWeight('57'), 57.0);
    });

    test('変換不能な場合は null を返す', () {
      expect(parseCarriedWeight(''), isNull);
      expect(parseCarriedWeight('abc'), isNull);
    });
  });

  group('parseHorseWeight', () {
    test('体重と増減を抽出する', () {
      final r1 = parseHorseWeight('490(+2)');
      expect(r1?.weight, 490);
      expect(r1?.diff, 2);

      final r2 = parseHorseWeight('488(-10)');
      expect(r2?.weight, 488);
      expect(r2?.diff, -10);
    });

    test('増減カッコが無い場合は diff が null', () {
      final r = parseHorseWeight('480');
      expect(r?.weight, 480);
      expect(r?.diff, isNull);
    });

    test('不正な形式は null を返す', () {
      expect(parseHorseWeight(''), isNull);
      expect(parseHorseWeight('計不'), isNull);
    });
  });

  group('parsePace', () {
    test('前半・後半3ハロンタイムを抽出する', () {
      final p = parsePace('35.4-38.0');
      expect(p?.front, 35.4);
      expect(p?.back, 38.0);
    });

    test('不正な形式は null を返す', () {
      expect(parsePace(''), isNull);
      expect(parsePace('35.4'), isNull);
      expect(parsePace('abc-def'), isNull);
    });
  });

  group('parseVenue', () {
    test('開催回・競馬場名・開催日を抽出する', () {
      final v = parseVenue('1阪神3');
      expect(v?.kai, 1);
      expect(v?.track, '阪神');
      expect(v?.day, 3);
    });

    test('実データ形式(2福島7)も抽出できる', () {
      final v = parseVenue('2福島7');
      expect(v?.kai, 2);
      expect(v?.track, '福島');
      expect(v?.day, 7);
    });

    test('不正な形式は null を返す', () {
      expect(parseVenue(''), isNull);
      expect(parseVenue('阪神'), isNull);
    });
  });
}
