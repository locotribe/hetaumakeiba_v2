// lib/utils/training_course_utils.dart

// [追加] 調教タブ改修Step2: netkeiba 調教コース表記の分類と時計5枠の読み方 (v.2026.9.22+26092211)

/// netkeiba 調教コース表記の分類結果。
class TrainingCourseInfo {
  /// '栗東' / '美浦'。判断できないコース（函Ｗ・ＤＰ・外厩など）は ''。
  final String location;

  /// pakara と突き合わせるときの種別（'坂路' / 'ウッド'）。pakara に無いコースは null。
  final String? pakaraTrackType;

  /// 坂路か（時計5枠の読み方に使う）。
  final bool isHanro;

  const TrainingCourseInfo({
    required this.location,
    this.pakaraTrackType,
    required this.isHanro,
  });
}

/// 全角英数記号を半角にし、空白（全角空白含む）を除く。
String normalizeCourseText(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000) {
      continue;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), '');
}

/// netkeiba のコース表記（'栗坂' '美坂' 'ＣＷ' '美Ｗ' 'ＤＰ' '函Ｗ' など）を分類する。
TrainingCourseInfo classifyTrainingCourse(String courseRaw) {
  final c = normalizeCourseText(courseRaw);
  switch (c) {
    case '栗坂':
      return const TrainingCourseInfo(
          location: '栗東', pakaraTrackType: '坂路', isHanro: true);
    case '美坂':
      return const TrainingCourseInfo(
          location: '美浦', pakaraTrackType: '坂路', isHanro: true);
    case 'CW':
      return const TrainingCourseInfo(
          location: '栗東', pakaraTrackType: 'ウッド', isHanro: false);
    case '美W':
      return const TrainingCourseInfo(
          location: '美浦', pakaraTrackType: 'ウッド', isHanro: false);
  }
  final location = c.startsWith('栗')
      ? '栗東'
      : c.startsWith('美')
          ? '美浦'
          : '';
  return TrainingCourseInfo(location: location, isHanro: c.contains('坂'));
}

/// 時計5枠（netkeiba の並び）を「ハロン数 → 累計タイム」に直す。値の無い枠は含めない。
/// 坂路: [(5F), 4F, 3F, 2F, 1F] / それ以外: [6F, 5F, 4F, 3F, 1F]（2F の枠は無い）
Map<int, double> slotsToFurlongs(String courseRaw, List<double?> slots) {
  const hanroOrder = [5, 4, 3, 2, 1];
  const otherOrder = [6, 5, 4, 3, 1];
  final order =
      classifyTrainingCourse(courseRaw).isHanro ? hanroOrder : otherOrder;
  final result = <int, double>{};
  for (int i = 0; i < slots.length && i < order.length; i++) {
    final value = slots[i];
    if (value != null) result[order[i]] = value;
  }
  return result;
}
