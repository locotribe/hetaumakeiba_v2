// lib/logic/analysis/course_preset_id_resolver.dart

// [追加] 展開シミュ コースプリセット内外回り対応Step1: 展開シミュの計算がコースプリセット
// (直線の長さ・keyPoints)を探すときのID候補を、試す順に並べる純粋ロジック。
// 内回り/外回りのある競馬場(中山・京都・阪神・新潟の芝)はプリセットIDに
// uchi/soto/w/straight が入るため、従来の「競馬場_芝ダ_距離」だけでは見つからなかった。
// このファイルは DB / I/O / UI に一切触れない (v.2026.9.30+26093001)

/// コースプリセットIDの候補を作る。
class CoursePresetIdResolver {
  CoursePresetIdResolver._();

  /// 芝で、出馬表の表記から決まらなかったときに最後に試す順番。
  /// 表記が無いときは内回りを先にする(画面のコース図の予備判定と同じ)。
  static const List<String> _fallbackTurfSuffixes = [
    'uchi',
    'soto',
    'w',
    'straight',
  ];

  /// 試す順に並べたID候補を返す。先頭は必ず従来のID(`競馬場_種別_距離`)。
  /// 内外回りの無い競馬場は先頭の従来IDで見つかるため、2番目以降は使われない。
  ///
  /// [venueCode] 競馬場コード('06'など)。不明ならnull。
  /// [trackType] 'shiba' / 'dirt' / 'obstacle'。
  /// [distance] 距離の数字の文字列('1200'など)。不明なら空文字。
  /// [direction] 出馬表の方向('右' / '左' / '直')。
  /// [courseInOut] 出馬表の内外表記('外 C'、'内'、'外-内' など)。
  static List<String> candidates({
    required String? venueCode,
    required String trackType,
    required String distance,
    String? direction,
    String? courseInOut,
  }) {
    final baseId = '${venueCode}_${trackType}_$distance';
    final result = <String>[baseId];

    // 芝以外(ダート・障害)と、競馬場や距離が分からないときは従来のIDだけ
    if (venueCode == null || distance.isEmpty || trackType != 'shiba') {
      return result;
    }

    final dir = direction ?? '';
    final inOut = courseInOut ?? '';
    final hasOuter = inOut.contains('外');
    final hasInner = inOut.contains('内');

    final suffixes = <String>[];
    if (dir.contains('直')) {
      suffixes.add('straight');
    }
    if (hasOuter && hasInner) {
      suffixes.addAll(['w', 'soto', 'uchi']);
    } else if (hasOuter) {
      suffixes.addAll(['soto', 'w']);
    } else if (hasInner) {
      suffixes.addAll(['uchi', 'w']);
    }
    suffixes.addAll(_fallbackTurfSuffixes);

    for (final suffix in suffixes) {
      final id = '${venueCode}_shiba_${suffix}_$distance';
      if (!result.contains(id)) {
        result.add(id);
      }
    }
    return result;
  }
}
