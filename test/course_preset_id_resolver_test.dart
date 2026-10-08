// test/course_preset_id_resolver_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/analysis/course_preset_id_resolver.dart';

void main() {
  group('CoursePresetIdResolver.candidates', () {
    test('ダートは従来のIDだけ', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '06',
          trackType: 'dirt',
          distance: '1200',
          direction: '右',
          courseInOut: '外',
        ),
        ['06_dirt_1200'],
      );
    });

    test('障害は従来のIDだけ', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '05',
          trackType: 'obstacle',
          distance: '3000',
          courseInOut: '外',
        ),
        ['05_obstacle_3000'],
      );
    });

    test('内外回りの無い競馬場の芝も、先頭は従来のID', () {
      final ids = CoursePresetIdResolver.candidates(
        venueCode: '05',
        trackType: 'shiba',
        distance: '2000',
        direction: '左',
        courseInOut: 'A',
      );
      expect(ids.first, '05_shiba_2000');
    });

    test('外の表記なら外回りを先に試す', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '06',
          trackType: 'shiba',
          distance: '1200',
          direction: '右',
          courseInOut: '外 C',
        ),
        [
          '06_shiba_1200',
          '06_shiba_soto_1200',
          '06_shiba_w_1200',
          '06_shiba_uchi_1200',
          '06_shiba_straight_1200',
        ],
      );
    });

    test('内の表記なら内回りを先に試す', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '08',
          trackType: 'shiba',
          distance: '2000',
          direction: '右',
          courseInOut: '内',
        ),
        [
          '08_shiba_2000',
          '08_shiba_uchi_2000',
          '08_shiba_w_2000',
          '08_shiba_soto_2000',
          '08_shiba_straight_2000',
        ],
      );
    });

    test('外と内の両方の表記ならWを先に試す', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '06',
          trackType: 'shiba',
          distance: '3200',
          direction: '右',
          courseInOut: '外-内',
        ),
        [
          '06_shiba_3200',
          '06_shiba_w_3200',
          '06_shiba_soto_3200',
          '06_shiba_uchi_3200',
          '06_shiba_straight_3200',
        ],
      );
    });

    test('直線コースは直線用のIDを先に試す', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '04',
          trackType: 'shiba',
          distance: '1000',
          direction: '直',
        ),
        [
          '04_shiba_1000',
          '04_shiba_straight_1000',
          '04_shiba_uchi_1000',
          '04_shiba_soto_1000',
          '04_shiba_w_1000',
        ],
      );
    });

    test('表記が無ければ 内回り→外回り→W→直線 の順', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '06',
          trackType: 'shiba',
          distance: '1200',
        ),
        [
          '06_shiba_1200',
          '06_shiba_uchi_1200',
          '06_shiba_soto_1200',
          '06_shiba_w_1200',
          '06_shiba_straight_1200',
        ],
      );
    });

    test('競馬場コードや距離が分からなければ従来のIDだけ', () {
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: null,
          trackType: 'shiba',
          distance: '1200',
          courseInOut: '外',
        ),
        ['null_shiba_1200'],
      );
      expect(
        CoursePresetIdResolver.candidates(
          venueCode: '06',
          trackType: 'shiba',
          distance: '',
          courseInOut: '外',
        ),
        ['06_shiba_'],
      );
    });
  });
}
