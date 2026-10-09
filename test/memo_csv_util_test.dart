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

  // [追加] AIファイル名整理: ファイル名の組み立て・.txt判定・総評ファイル名の照合・回顧メモの表記揺れ吸収 (v.2026.10.10+26101006)
  group('buildPrefixedFileName', () {
    test('種別_レース名_日付_レースID.拡張子 の順で作る', () {
      final name = buildPrefixedFileName(
        prefix: kFilePrefixRaceData,
        raceName: 'サウジアラビアRC',
        raceDate: '2026年10月10日',
        raceId: '202605040311',
        extension: 'md',
      );
      expect(name, 'レースデータ_サウジアラビアRC_2026年10月10日_202605040311.md');
    });

    test('禁止文字を除き、レース名は40文字で切る', () {
      final name = buildPrefixedFileName(
        prefix: kFilePrefixPredictionTemplate,
        raceName: 'A/B${'あ' * 50}',
        raceDate: '2026年10月10日',
        raceId: '202605040311',
        extension: 'csv',
      );
      expect(name,
          'テンプレ予想メモ_AB${'あ' * 38}_2026年10月10日_202605040311.csv');
    });

    test('空の要素は詰める', () {
      final name = buildPrefixedFileName(
        prefix: kFilePrefixReviewTemplate,
        raceName: '',
        raceDate: '2026年10月10日',
        raceId: '202605040311',
        extension: 'csv',
      );
      expect(name, 'テンプレ回顧メモ_2026年10月10日_202605040311.csv');
    });
  });

  group('isTxtFileName', () {
    test('.txt だけ true（大文字も可）', () {
      expect(isTxtFileName('インポート予想メモ_X_2026年10月10日_1.txt'), isTrue);
      expect(isTxtFileName('/cache/file_picker/X.TXT'), isTrue);
      expect(isTxtFileName('テンプレ予想メモ_X_2026年10月10日_1.csv'), isFalse);
      expect(isTxtFileName('レースデータ_X_2026年10月10日_1.md'), isFalse);
    });
  });

  group('isImportSummaryFileNameFor', () {
    const id = '202605040311';

    test('先頭が「インポート総評_」で末尾のレースIDが合えば true', () {
      expect(
          isImportSummaryFileNameFor(
              'インポート総評_サウジアラビアRC_2026年10月10日_$id.txt', id),
          isTrue);
    });

    test('別のレースIDは false', () {
      expect(
          isImportSummaryFileNameFor(
              'インポート総評_X_2026年10月3日_202605040111.txt', id),
          isFalse);
    });

    test('別の種別・拡張子は false', () {
      expect(
          isImportSummaryFileNameFor(
              'インポート予想メモ_X_2026年10月10日_$id.txt', id),
          isFalse);
      expect(
          isImportSummaryFileNameFor('レースデータ_X_2026年10月10日_$id.md', id),
          isFalse);
      expect(
          isImportSummaryFileNameFor('インポート総評_X_2026年10月10日_$id.csv', id),
          isFalse);
    });

    test('レースIDの後ろだけ一致する別IDは false', () {
      expect(
          isImportSummaryFileNameFor('インポート総評_X_2026年10月10日_1$id.txt', id),
          isFalse);
    });
  });

  group('normalizeImportedReviewCsv', () {
    const reviewHeader =
        'raceId,horseId,horseNumber,horseName,reviewMemo,raceMemo';

    test('BOM・見出し・コードフェンス・CRLFを除きLFで返す', () {
      final input = '\uFEFF# 回顧\r\n```text\r\n$reviewHeader\r\n'
          '202605040311,2024105852,1,ギブリ,回顧本文,総評本文\r\n```\r\n';
      final out = normalizeImportedReviewCsv(input);
      expect(out,
          '$reviewHeader\n202605040311,2024105852,1,ギブリ,回顧本文,総評本文');
      final rows = const CsvToListConverter(eol: '\n').convert(out);
      expect(rows.length, 2);
    });

    test('予想メモのヘッダーは認識しない（LF正規化のみで返す）', () {
      final input = '$header\r\n202605040311,2024105852,1,ギブリ,メモ';
      final out = normalizeImportedReviewCsv(input);
      expect(out, '$header\n202605040311,2024105852,1,ギブリ,メモ');
    });
  });
}
