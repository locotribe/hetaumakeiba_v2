// test/training_course_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/utils/training_course_utils.dart';

void main() {
  group('classifyTrainingCourse', () {
    test('栗坂・美坂は坂路（pakara 突き合わせ可）', () {
      final ritto = classifyTrainingCourse('栗坂');
      expect(ritto.location, '栗東');
      expect(ritto.pakaraTrackType, '坂路');
      expect(ritto.isHanro, isTrue);
      final miho = classifyTrainingCourse(' 美坂 ');
      expect(miho.location, '美浦');
      expect(miho.pakaraTrackType, '坂路');
    });
    test('ＣＷ・美Ｗは全角でも半角でもウッド', () {
      expect(classifyTrainingCourse('ＣＷ').pakaraTrackType, 'ウッド');
      expect(classifyTrainingCourse('ＣＷ').location, '栗東');
      expect(classifyTrainingCourse('CW').pakaraTrackType, 'ウッド');
      expect(classifyTrainingCourse('美Ｗ').location, '美浦');
      expect(classifyTrainingCourse('美Ｗ').isHanro, isFalse);
    });
    test('ＤＰ・函Ｗ・外厩は pakara と突き合わせない', () {
      expect(classifyTrainingCourse('ＤＰ').pakaraTrackType, isNull);
      expect(classifyTrainingCourse('ＤＰ').location, '');
      expect(classifyTrainingCourse('函Ｗ').pakaraTrackType, isNull);
      expect(classifyTrainingCourse('小林').isHanro, isFalse);
    });
  });

  group('slotsToFurlongs', () {
    test('坂路は [-,4F,3F,2F,1F]', () {
      expect(slotsToFurlongs('栗坂', [null, 52.4, 38.1, 24.8, 12.3]),
          {4: 52.4, 3: 38.1, 2: 24.8, 1: 12.3});
    });
    test('ウッドは [6F,5F,4F,3F,1F]（2F なし）', () {
      expect(slotsToFurlongs('ＣＷ', [89.0, 73.0, 55.8, 39.7, 11.8]),
          {6: 89.0, 5: 73.0, 4: 55.8, 3: 39.7, 1: 11.8});
    });
    test('短い追い切りは先頭が抜ける', () {
      expect(slotsToFurlongs('ＣＷ', [null, null, 52.0, 37.4, 11.4]),
          {4: 52.0, 3: 37.4, 1: 11.4});
    });
  });
}
