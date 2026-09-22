// test/horse_detail_order_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/horse_detail_order.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの馬の並び順 (v.2026.9.23+26092308)

PredictionHorseDetail _horse(String id, int number, String name) {
  return PredictionHorseDetail(
    horseId: id,
    horseNumber: number,
    gateNumber: number > 0 ? (number + 1) ~/ 2 : 0,
    horseName: name,
    sexAndAge: '牡3',
    jockey: '',
    jockeyId: '',
    carriedWeight: 57.0,
    trainerName: '',
    trainerAffiliation: '',
    isScratched: false,
  );
}

void main() {
  test('馬番の昇順に並べる（元のリストは変えない）', () {
    final horses = [
      _horse('c', 3, 'シー'),
      _horse('a', 1, 'エー'),
      _horse('b', 2, 'ビー'),
    ];
    final ordered = orderHorsesForDetail(horses);
    expect(ordered.map((h) => h.horseId).toList(), ['a', 'b', 'c']);
    expect(horses.map((h) => h.horseId).toList(), ['c', 'a', 'b']);
  });

  test('馬番0の馬は馬番のある馬の後ろに馬名順', () {
    final horses = [
      _horse('z', 0, 'ロブチェン'),
      _horse('b', 2, 'ビー'),
      _horse('y', 0, 'アルトラムス'),
      _horse('a', 1, 'エー'),
    ];
    final ordered = orderHorsesForDetail(horses);
    expect(ordered.map((h) => h.horseId).toList(), ['a', 'b', 'y', 'z']);
  });

  test('全頭が馬番0なら馬名順', () {
    final horses = [
      _horse('x', 0, 'ウ'),
      _horse('y', 0, 'ア'),
      _horse('z', 0, 'イ'),
    ];
    final ordered = orderHorsesForDetail(horses);
    expect(ordered.map((h) => h.horseId).toList(), ['y', 'z', 'x']);
  });
}
