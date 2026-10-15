// lib/logic/race_route.dart

// [追加] 前走と路線の部品 Step3: 過去走（前走）を「路線」にまとめる共通の部品。主催・芝ダ障・距離が同じで、名前が同じか一方が他方を含む（スポンサー名の有無・途中で切れた名前）ものを1つの路線にする。中央の条件戦はクラス、地方の重賞以外は「地方」1つにまとめる (v.2026.10.16+26101607)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 改名されたレース（旧名 → 新名）。名前の中心部分（raceRouteCoreName の結果）で書く。
/// 途中で切れた旧名（6文字以上）にも当てはめる。
const Map<String, String> kRaceRouteRenames = {
  'ジャパンダートダービー': 'ジャパンダートクラシック',
};

/// 地方の重賞以外をまとめた路線の名前。
const String kLocalRouteName = '地方';

/// 馬のページのレース名が途中で切れる長さ（この文字数以上は切れている可能性がある）。
const int _kTruncatedLength = 10;

/// 途中で切れた名前をつなぐときに、末尾が一致していなければならない最小の文字数。
const int _kTruncatedOverlap = 5;

/// 一方が他方を含むときにつなぐ、短い方の最小の文字数。
const int _kMinContainLength = 3;

/// レース名の中心部分。
/// 【 か [ 以降を切る（地方の「川崎記念【指定交流】」の形）→ 括弧を外す（(春)(秋) は残す）→
/// 先頭の「第N回」と空白を外す → 末尾の「競走」を外す → 改名の表で新しい名前にする。
String raceRouteCoreName(String raceName) {
  var t = normalizeRaceDigits(raceName);
  final cut = t.indexOf(RegExp(r'[【\[]'));
  if (cut >= 0) t = t.substring(0, cut);
  t = t.replaceAllMapped(RegExp(r'\([^)]*\)'), (m) {
    final s = m.group(0)!;
    return (s == '(春)' || s == '(秋)') ? s : '';
  });
  t = t.replaceFirst(RegExp(r'^第\d+回'), '');
  t = t.replaceAll(RegExp(r'[\s　]'), '');
  if (t.length > 2 && t.endsWith('競走')) t = t.substring(0, t.length - 2);
  for (final entry in kRaceRouteRenames.entries) {
    if (t.length >= 6 && entry.key.startsWith(t)) {
      t = entry.value;
      break;
    }
  }
  return t;
}

/// 路線のキー（主催・芝ダ障・距離・名前）。
class RaceRouteKey {
  /// 主催: 'jra'・'local'・'foreign'
  final String source;

  /// '芝'・'ダ'・'障'。地方の重賞以外と、距離が読めないときは ''
  final String surface;

  /// 距離（m）。地方の重賞以外と、距離が読めないときは null
  final int? meters;

  /// 名前の中心部分。中央の条件戦はクラス名（'2勝クラス' など）、地方の重賞以外は '地方'
  final String name;

  /// 名前でつなぐ対象か（中央の条件戦と地方の重賞以外は false）
  final bool isNamed;

  const RaceRouteKey({
    required this.source,
    required this.surface,
    required this.meters,
    required this.name,
    required this.isNamed,
  });

  /// 主催・芝ダ障・距離（名前を除いた部分）
  String get scope => '$source|$surface${meters ?? ''}';

  /// キーを1つの文字列にしたもの
  String get text => '$scope|$name';
}

String? _classRouteName(RaceClassGrade grade) {
  switch (grade) {
    case RaceClassGrade.win3:
      return '3勝クラス';
    case RaceClassGrade.win2:
      return '2勝クラス';
    case RaceClassGrade.win1:
      return '1勝クラス';
    case RaceClassGrade.newcomer:
      return '新馬';
    case RaceClassGrade.maiden:
      return '未勝利';
    default:
      return null;
  }
}

/// 過去走1つの路線のキー。
RaceRouteKey raceRouteKeyOf(HorseRaceRecord record) {
  final sourceKind = earnedPrizeSourceOf(record);
  final source = sourceKind == EarnedPrizeSource.jra
      ? 'jra'
      : sourceKind == EarnedPrizeSource.local
          ? 'local'
          : 'foreign';
  final grade = raceClassGradeOfRecord(record);
  final rawName = normalizeRaceDigits(record.raceName);
  if (grade == RaceClassGrade.local && !rawName.contains('(重賞)')) {
    return RaceRouteKey(
      source: source,
      surface: '',
      meters: null,
      name: kLocalRouteName,
      isNamed: false,
    );
  }
  final m = RegExp(r'^(芝|ダ|障)(\d+)')
      .firstMatch(normalizeRaceDigits(record.distance.trim()));
  final surface = m == null ? '' : m.group(1)!;
  final meters = m == null ? null : int.parse(m.group(2)!);
  final className = _classRouteName(grade);
  if (className != null) {
    return RaceRouteKey(
      source: source,
      surface: surface,
      meters: meters,
      name: className,
      isNamed: false,
    );
  }
  return RaceRouteKey(
    source: source,
    surface: surface,
    meters: meters,
    name: raceRouteCoreName(record.raceName),
    isNamed: true,
  );
}

/// 2つの名前を同じ路線とみなすか（主催・芝ダ障・距離が同じものどうしで使う）。
/// 同じ名前、短い方が3文字以上で一方が他方を含む、
/// または10文字以上の（途中で切れた可能性がある）名前の末尾5文字以上が他方に含まれる。
bool raceRouteNamesMatch(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  if (shorter.length >= _kMinContainLength && longer.contains(shorter)) {
    return true;
  }
  for (final pair in [
    [a, b],
    [b, a],
  ]) {
    final x = pair[0];
    final y = pair[1];
    if (x.length < _kTruncatedLength) continue;
    for (var k = x.length - 1; k >= _kTruncatedOverlap; k--) {
      if (y.contains(x.substring(x.length - k))) return true;
    }
  }
  return false;
}

/// 1つの路線。
class RaceRoute {
  /// 路線のID（例 'jra|芝1800|フジTVスプリングS'）。名前はグループの中で一番長い名前
  final String id;

  /// 表示名。グループの中で一番新しい走の名前（条件戦はクラス名、地方の重賞以外は '地方'）
  final String displayName;

  /// '芝'・'ダ'・'障'。地方の重賞以外と、距離が読めないときは ''
  final String surface;

  /// 距離（m）。地方の重賞以外と、距離が読めないときは null
  final int? meters;

  /// この路線に入った過去走（新しい順）
  final List<HorseRaceRecord> records;

  const RaceRoute({
    required this.id,
    required this.displayName,
    required this.surface,
    required this.meters,
    required this.records,
  });
}

/// 過去走の集まりを路線に分けたもの。
class RaceRouteIndex {
  /// 路線の一覧（過去走の多い順、同数は id の順）
  final List<RaceRoute> routes;

  final Map<String, RaceRoute> _routeByKeyText;
  final Map<String, List<RaceRouteKey>> _keysByScope;

  RaceRouteIndex._(this.routes, this._routeByKeyText, this._keysByScope);

  /// [records] を路線に分ける。
  /// ① 主催・芝ダ障・距離・名前が同じものは同じ路線
  /// ② 同じレースID（空でないもの）は同じ路線
  /// ③ 主催・芝ダ障・距離が同じで raceRouteNamesMatch が成り立つ名前は同じ路線（名前でつなぐ対象どうしだけ）
  factory RaceRouteIndex.build(Iterable<HorseRaceRecord> records) {
    final keyByText = <String, RaceRouteKey>{};
    final recordsByKeyText = <String, List<HorseRaceRecord>>{};
    final keyTextByRaceId = <String, String>{};
    final parent = <String, String>{};

    String find(String x) {
      var root = x;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      var cur = x;
      while (parent[cur] != root) {
        final next = parent[cur]!;
        parent[cur] = root;
        cur = next;
      }
      return root;
    }

    void union(String a, String b) {
      final ra = find(a);
      final rb = find(b);
      if (ra == rb) return;
      // 文字列の小さい方を根にする（入力の順に左右されないように）
      if (ra.compareTo(rb) <= 0) {
        parent[rb] = ra;
      } else {
        parent[ra] = rb;
      }
    }

    for (final record in records) {
      final key = raceRouteKeyOf(record);
      final text = key.text;
      keyByText.putIfAbsent(text, () => key);
      parent.putIfAbsent(text, () => text);
      recordsByKeyText.putIfAbsent(text, () => <HorseRaceRecord>[]).add(record);
      final raceId = record.raceId.trim();
      if (raceId.isNotEmpty) {
        final other = keyTextByRaceId[raceId];
        if (other == null) {
          keyTextByRaceId[raceId] = text;
        } else {
          union(other, text);
        }
      }
    }

    final keysByScope = <String, List<RaceRouteKey>>{};
    for (final key in keyByText.values) {
      keysByScope.putIfAbsent(key.scope, () => <RaceRouteKey>[]).add(key);
    }
    for (final keys in keysByScope.values) {
      for (var i = 0; i < keys.length; i++) {
        for (var j = i + 1; j < keys.length; j++) {
          final a = keys[i];
          final b = keys[j];
          if (!a.isNamed || !b.isNamed) continue;
          if (raceRouteNamesMatch(a.name, b.name)) union(a.text, b.text);
        }
      }
    }

    final membersByRoot = <String, List<String>>{};
    for (final text in keyByText.keys) {
      membersByRoot.putIfAbsent(find(text), () => <String>[]).add(text);
    }

    final routes = <RaceRoute>[];
    final routeByKeyText = <String, RaceRoute>{};
    for (final members in membersByRoot.values) {
      final groupRecords = <HorseRaceRecord>[];
      for (final text in members) {
        groupRecords.addAll(recordsByKeyText[text]!);
      }
      groupRecords.sort(_compareNewestFirst);

      final keys = members.map((t) => keyByText[t]!).toList();
      var longest = keys.first;
      for (final key in keys) {
        if (key.name.length > longest.name.length ||
            (key.name.length == longest.name.length &&
                key.text.compareTo(longest.text) < 0)) {
          longest = key;
        }
      }
      final newestKey = raceRouteKeyOf(groupRecords.first);

      final route = RaceRoute(
        id: longest.text,
        displayName: newestKey.name,
        surface: newestKey.surface,
        meters: newestKey.meters,
        records: List.unmodifiable(groupRecords),
      );
      routes.add(route);
      for (final text in members) {
        routeByKeyText[text] = route;
      }
    }
    routes.sort((a, b) {
      final byCount = b.records.length.compareTo(a.records.length);
      return byCount != 0 ? byCount : a.id.compareTo(b.id);
    });

    return RaceRouteIndex._(
      List.unmodifiable(routes),
      routeByKeyText,
      keysByScope,
    );
  }

  /// [record] の路線。build に渡していない過去走でも、①と③の規則で当てはまる路線があれば返す。無ければ null。
  RaceRoute? routeOf(HorseRaceRecord record) {
    final key = raceRouteKeyOf(record);
    final exact = _routeByKeyText[key.text];
    if (exact != null) return exact;
    if (!key.isNamed) return null;
    final candidates = _keysByScope[key.scope];
    if (candidates == null) return null;
    for (final other in candidates) {
      if (other.isNamed && raceRouteNamesMatch(key.name, other.name)) {
        return _routeByKeyText[other.text];
      }
    }
    return null;
  }
}

/// 日付の新しい順。同じ日付（や読めない日付）は名前の長い順、次に名前の順。
int _compareNewestFirst(HorseRaceRecord a, HorseRaceRecord b) {
  final da = parseEarnedPrizeDate(a.date);
  final db = parseEarnedPrizeDate(b.date);
  if (da != null && db != null) {
    final byDate = db.compareTo(da);
    if (byDate != 0) return byDate;
  } else if (da != null) {
    return -1;
  } else if (db != null) {
    return 1;
  }
  final byLength = b.raceName.length.compareTo(a.raceName.length);
  if (byLength != 0) return byLength;
  return a.raceName.compareTo(b.raceName);
}
