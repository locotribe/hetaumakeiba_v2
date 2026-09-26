import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';
import 'package:hetaumakeiba_v2/utils/memo_csv_util.dart';

void main() {
  const header = 'raceId,horseId,horseNumber,horseName,predictionMemo';

  group('normalizeImportedPredictionCsv', () {
    test('LFのみのCSVでも行分割できる形で返す', () {
      final input = '$header\n202606040911,2019105496,1,テスト馬,メモ本文\n';
      final out = normalizeImportedPredictionCsv(input);
      final rows = const CsvToListConverter(eol: '\n').convert(out);
      expect(rows.length, 2);
      expect(rows.first.map((e) => e.toString().trim()).join(','), header);
    });

    test('CRLFはLFへ正規化される', () {
      final input = '$header\r\n202606040911,2019105496,1,テスト馬,メモ\r\n';
      final out = normalizeImportedPredictionCsv(input);
      expect(out.contains('\r'), isFalse);
    });

    test('先頭のBOMを除去する', () {
      final input = '﻿$header\n202606040911,2019105496,1,テスト馬,メモ';
      final out = normalizeImportedPredictionCsv(input);
      expect(out.startsWith('raceId'), isTrue);
    });

    test('Markdown見出しとコードフェンスを読み飛ばす', () {
      final input =
          '# Untitled\n\n```\n$header\n202606040911,2019105496,1,テスト馬,メモ\n```\n';
      final out = normalizeImportedPredictionCsv(input);
      expect(out, '$header\n202606040911,2019105496,1,テスト馬,メモ');
    });

    test('行末に半角空白があってもヘッダーを認識し行数が保たれる', () {
      final input = '$header  \n202606040911,2019105496,1,テスト馬,メモ  ';
      final out = normalizeImportedPredictionCsv(input);
      expect(out.split('\n').length, 2);
      expect(out.contains('202606040911,2019105496,1,テスト馬'), isTrue);
    });

    test('ヘッダーが無ければLF正規化のみで返す（判定は呼び出し側に委ねる）', () {
      final input = 'raceId,horseId,reviewMemo\r\n202606040911,2019105496,回顧';
      final out = normalizeImportedPredictionCsv(input);
      expect(out, 'raceId,horseId,reviewMemo\n202606040911,2019105496,回顧');
    });
  });
}
