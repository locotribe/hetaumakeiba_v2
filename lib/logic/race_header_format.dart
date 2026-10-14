// lib/logic/race_header_format.dart

// [追加] レース情報ヘッダー整理 Step1: 出馬表「レース情報」タブの見出しに出す文字を、取得した文字列から組み立てる純粋関数。画面・DB・通信には触れない (v.2026.10.15+26101509)

/// 全角数字を半角数字にする。
String _toHalfWidthDigits(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// 競走条件の括弧の中の記号を、チップに出す言葉にする。表に無いものはそのまま出す。
const Map<String, String> _categoryMarkLabels = {
  '指': '指定',
  '混': '混合',
};

/// 競走条件（例: "サラ系３歳以上 オープン (国際)(指) 別定"）をチップ用の言葉に分ける。
/// 先頭の「サラ系」は外し、全角数字は半角にする。() と [] の中身は1つずつのチップにする。
/// 例: ["3歳以上", "オープン", "国際", "指定", "別定"]
List<String> buildRaceCategoryChips(String? raceCategory) {
  if (raceCategory == null) return const [];
  var text = _toHalfWidthDigits(raceCategory.trim());
  if (text.startsWith('サラ系')) text = text.substring(3);
  final chips = <String>[];
  final pattern = RegExp(r'\(([^)]*)\)|\[([^\]]*)\]|([^\s()\[\]]+)');
  for (final match in pattern.allMatches(text)) {
    final inner = match.group(1) ?? match.group(2);
    if (inner != null) {
      final word = inner.trim();
      if (word.isEmpty) continue;
      chips.add(_categoryMarkLabels[word] ?? word);
    } else {
      chips.add(match.group(3)!);
    }
  }
  return chips;
}

/// コース種別の表示名（"芝"→"芝"、"ダ"→"ダート"、"障"→"障害"）。null は空文字。
String buildTrackTypeLabel(String? trackType) {
  if (trackType == null) return '';
  if (trackType.contains('ダ')) return 'ダート';
  if (trackType.contains('障')) return '障害';
  return trackType;
}

/// コースの補足。方向と courseInOut を「・」でつなぐ。
/// 例: ("左", "A") → "左回り・A"、("右", "外 C") → "右回り・外・C"、("直", null) → "直線"
String buildCourseSubLabel(String? direction, String? courseInOut) {
  final parts = <String>[];
  if (direction == '右') {
    parts.add('右回り');
  } else if (direction == '左') {
    parts.add('左回り');
  } else if (direction == '直') {
    parts.add('直線');
  }
  if (courseInOut != null) {
    parts.addAll(
        courseInOut.split(RegExp(r'\s+')).where((part) => part.isNotEmpty));
  }
  return parts.join('・');
}

/// 開催の表示（例: ("東京", 4, 6) → "東京 4回6日目"）。回・日目が無ければ付けない。
String buildHoldingLabel(String venue, int? holdingTimes, int? holdingDays) {
  final times = holdingTimes != null ? '$holdingTimes回' : '';
  final days = holdingDays != null ? '$holdingDays日目' : '';
  return '$venue $times$days'.trim();
}

/// 本賞金（万円）を3桁区切りにする。null と 0 以下は "-"。
String formatPrizeMan(int? value) {
  if (value == null || value <= 0) return '-';
  return value
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}

/// 日付の文字列（例: "2026年10月18日"・"2026-10-12"）を "10/18(日)" の形にする。読めなければ null。
String? formatMonthDayWithWeekday(String raw) {
  final match = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const weekdays = ['', '月', '火', '水', '木', '金', '土', '日'];
  final weekday = weekdays[DateTime(year, month, day).weekday];
  return '$month/$day($weekday)';
}

/// 天候・馬場の値。未発表（null・空・"-"）は null にそろえる。
String? normalizeAnnouncedValue(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '-') return null;
  return trimmed;
}
