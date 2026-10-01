// test/trainer_affiliation_test.dart

// [追加] 陣営の本気度指数: 調教師の所属の読み替え（trainer_affiliation.dart）の単体テスト (v.2026.10.2+26100209)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/trainer_affiliation.dart';

void main() {
  group('parseTrainerAffiliation', () {
    test('美浦の書き方', () {
      for (final text in ['美浦', '美', '[東]', '木村哲也 (美浦)', '美浦[木村]', ' 美浦 ']) {
        expect(parseTrainerAffiliation(text), TrainerAffiliation.miho,
            reason: text);
      }
    });

    test('栗東の書き方', () {
      for (final text in ['栗東', '栗', '[西]', '友道康夫 (栗東)', '栗東[藤野]']) {
        expect(parseTrainerAffiliation(text), TrainerAffiliation.ritto,
            reason: text);
      }
    });

    test('地方・海外', () {
      expect(parseTrainerAffiliation('地方'), TrainerAffiliation.local);
      expect(parseTrainerAffiliation('[地]'), TrainerAffiliation.local);
      expect(parseTrainerAffiliation('海外'), TrainerAffiliation.overseas);
      expect(parseTrainerAffiliation('[外]'), TrainerAffiliation.overseas);
    });

    test('空・名前だけ・美や栗で始まる名前は分からない扱い', () {
      for (final text in ['', '  ', '西村', '友道康夫', '美濃', '栗田']) {
        expect(parseTrainerAffiliation(text), TrainerAffiliation.unknown,
            reason: text);
      }
    });
  });

  group('trainerAffiliationLabel', () {
    test('表示名', () {
      expect(trainerAffiliationLabel(TrainerAffiliation.miho), '美浦');
      expect(trainerAffiliationLabel(TrainerAffiliation.ritto), '栗東');
      expect(trainerAffiliationLabel(TrainerAffiliation.local), '地方');
      expect(trainerAffiliationLabel(TrainerAffiliation.overseas), '海外');
      expect(trainerAffiliationLabel(TrainerAffiliation.unknown), '');
    });
  });
}
