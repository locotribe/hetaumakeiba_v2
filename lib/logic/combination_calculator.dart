// lib/logic/combination_calculator.dart

const Map<String, String> bettingDict = {
  "1": "単勝", "2": "複勝", "3": "枠連", "5": "馬連", "6": "馬単",
  "7": "ワイド", "8": "3連複", "9": "3連単",
};
const Map<String, String> wheelExactaDict = {"1": "1着ながし", "2": "2着ながし"};
const Map<String, String> wheelTrioDict = {"3": "軸2頭ながし", "7": "軸1頭ながし"};
const Map<String, String> wheelTrifectaDict = {
  "1": "1・2着ながし", "2": "1・3着ながし", "3": "2・3着ながし",
  "4": "1着ながし", "5": "2着ながし", "6": "3着ながし",
};

// ▼▼▼ 組み合わせ計算のロジックを、既存の`calculatePoints`とは別に、安全な場所に追加 ▼▼▼
Iterable<List<T>> combinations<T>(List<T> elements, int k) sync* {
  if (k < 0 || k > elements.length) return;
  if (k == 0) { yield []; return; }
  for (int i = 0; i <= elements.length - k; i++) {
    T head = elements[i];
    List<T> rest = elements.sublist(i + 1);
    for (List<T> tail in combinations(rest, k - 1)) {
      yield [head, ...tail];
    }
  }
}
Iterable<List<T>> permutations<T>(List<T> elements, int k) sync* {
  if (k < 0 || k > elements.length) return;
  if (k == 0) { yield []; return; }
  for (int i = 0; i < elements.length; i++) {
    T head = elements[i];
    List<T> rest = [...elements]..removeAt(i);
    for (List<T> tail in permutations(rest, k - 1)) {
      yield [head, ...tail];
    }
  }
}
void generateAndSetAllCombinations(Map<String, dynamic> di, String bettingMethod) {
  final String ticketType = bettingDict[di['式別']]!;
  List<List<int>> allCombinations = [];
  di['方式'] = bettingMethod;

  try {
    switch (bettingMethod) {
      case '通常': case '応援馬券':
      allCombinations.add((di['馬番'] as List).cast<int>());
      break;
      case 'ボックス':
        final horses = (di['馬番'] as List).cast<int>();
        switch (ticketType) {
          case '馬連': case 'ワイド': case '枠連': allCombinations = combinations(horses, 2).toList(); break;
          case '3連複': allCombinations = combinations(horses, 3).toList(); break;
          case '馬単': allCombinations = permutations(horses, 2).toList(); break;
          case '3連単': allCombinations = permutations(horses, 3).toList(); break;
        }
        break;
      case 'ながし':
        List<int> axis;
        if (di['軸'] is List) {
          axis = (di['軸'] as List).cast<int>();
        } else if (di['軸'] is int) {
          axis = [di['軸'] as int];
        } else {
          axis = [];
        }
        final opponents = (di['相手'] as List? ?? []).cast<int>();
        final isMulti = di['マルチ'] == 'あり';
        switch (ticketType) {
          case '馬連': case 'ワイド': case '枠連':
          for (final a in axis) for (final o in opponents) if (a != o) allCombinations.add([a, o]);
          break;
          case '馬単':
            for (final a in axis) for (final o in opponents) if (a != o) {
              if (isMulti) {
                allCombinations.add([a, o]); allCombinations.add([o, a]);
              } else {
                if (di['ながし'] == '1着ながし') allCombinations.add([a, o]);
                if (di['ながし'] == '2着ながし') allCombinations.add([o, a]);
              }
            }
            break;
          case '3連複':
            if (di['ながし種別'] == '軸1頭ながし') {
              for (final combo in combinations(opponents, 2)) allCombinations.add([axis.first, ...combo]);
            } else if (di['ながし種別'] == '軸2頭ながし') {
              for (final o in opponents) allCombinations.add([...axis, o]);
            }
            break;
          case '3連単':
            final horseGroups = (di['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            final firstAxis = horseGroups.isNotEmpty ? horseGroups[0] : <int>[];
            final secondAxis = horseGroups.length > 1 ? horseGroups[1] : <int>[];
            final thirdAxis = horseGroups.length > 2 ? horseGroups[2] : <int>[];

            if (isMulti) {
              if (di['ながし種別'] == '軸1頭ながし') {
                final axisHorse = firstAxis.first;
                final opponentHorses = secondAxis.isNotEmpty ? secondAxis : thirdAxis;
                // 相手から2頭選ぶ組み合わせを全て作る
                final opponentCombos = combinations(opponentHorses, 2);
                for (final combo in opponentCombos) {
                  // 「軸1頭」と「相手2頭」の組み合わせ(合計3頭)で、全順列(6通り)を生成
                  allCombinations.addAll(permutations([axisHorse, ...combo], 3));
                }
              } else if (di['ながし種別'] == '軸2頭ながし') {
                final axis1 = firstAxis.first;
                final axis2 = secondAxis.first;
                final opponentHorses = thirdAxis;
                // 相手を1頭ずつループ
                for (final opponent in opponentHorses) {
                  // 「軸2頭」と「相手1頭」の組み合わせ(合計3頭)で、全順列(6通り)を生成
                  allCombinations.addAll(permutations([axis1, axis2, opponent], 3));
                }
              }
            } else { // マルチではない通常のながし
              if (di['ながし種別'] == '軸2頭ながし') {
                // ▼▼▼【修正箇所2】買い目が着順固定 (例: 1着に1頭、2着に1頭) かどうかを判別し、組み合わせ生成方法を分岐 ▼▼▼
                // 1着・2着の軸がそれぞれ1頭ずつの場合は、着順固定として扱う
                if (firstAxis.length == 1 && secondAxis.length == 1) {
                  final axis1 = firstAxis.first;
                  final axis2 = secondAxis.first;
                  // 3着の相手馬と順番に組み合わせるだけ (順列は作らない)
                  for (final o in thirdAxis) {
                    if (axis1 != o && axis2 != o) {
                      allCombinations.add([axis1, axis2, o]);
                    }
                  }
                } else {
                  // それ以外の場合は、元々の「軸2頭の着順を入れ替える」ロジックで組み合わせを生成
                  final nagashiType = di['ながし'];
                  final axisHorses = firstAxis;
                  final otherHorses = secondAxis;
                  for (final p in permutations(axisHorses, 2)) {
                    for (final o in otherHorses) {
                      if (p[0] != o && p[1] != o) {
                        if (nagashiType == '1・2着ながし') {
                          allCombinations.add([p[0], p[1], o]);
                        } else if (nagashiType == '1・3着ながし') {
                          allCombinations.add([p[0], o, p[1]]);
                        } else if (nagashiType == '2・3着ながし') {
                          allCombinations.add([o, p[0], p[1]]);
                        }
                      }
                    }
                  }
                }
              }
            }
            break;
        }
        break;
      case 'フォーメーション':
        final p1 = (di['馬番'][0] as List).cast<int>();
        final p2 = (di['馬番'].length > 1) ? (di['馬番'][1] as List).cast<int>() : <int>[];
        final p3 = (di['馬番'].length > 2) ? (di['馬番'][2] as List).cast<int>() : <int>[];
        switch (ticketType) {
          case '馬連': case 'ワイド': case '枠連':
          for (final f in p1) for (final s in p2) if (f != s) allCombinations.add([f, s]);
          break;
          case '馬単':
            for (final f in p1) for (final s in p2) if (f != s) allCombinations.add([f, s]);
            break;
          case '3連複':
            for (final f in p1) for (final s in p2) for (final t in p3) if (f != s && f != t && s != t) allCombinations.add([f, s, t]);
            break;
          case '3連単':
            for (final f in p1) for (final s in p2) for (final t in p3) if (f != s && f != t && s != t) allCombinations.add([f, s, t]);
            break;
        }
        break;
      case 'クイックピック':
        allCombinations = (di['馬番'] as List).map((c) => (c as List).cast<int>()).toList();
        break;
    }
    print('DEBUG: 生成直後の組み合わせ (ソート前): $allCombinations');

    if (['馬連', 'ワイド', '枠連', '3連複'].contains(ticketType)) {
      final unique = <String, List<int>>{};
      for (final combo in allCombinations) {
        final sorted = List<int>.from(combo)..sort();
        unique[sorted.join('-')] = sorted;
      }
      di['all_combinations'] = unique.values.toList();
      print('DEBUG: DB保存直前の組み合わせ (3連複など): ${di['all_combinations']}');
    } else {
      di['all_combinations'] = allCombinations;
      print('DEBUG: DB保存直前の組み合わせ (3連単など): ${di['all_combinations']}');
    }
  } catch (e) {
    print('Error generating combinations for $ticketType ($bettingMethod): $e');
    di['all_combinations'] = [];
  }
}


int calculatePoints({
  required String ticketType,
  required String method,
  required List<int> first,
  List<int>? second,
  List<int>? third,
}) {
  final normalizedTicketType = ticketType.trim();
  final normalizedMethod = method.trim();

  final f = first;
  final s = second ?? [];
  final t = third ?? [];

  switch (normalizedTicketType) {
    case '3連単':
      switch (normalizedMethod) {
        case 'フォーメーション':
          int count = 0;
          for (var i in f) {
            for (var j in s) {
              for (var k in t) {
                if (i != j && i != k && j != k) {
                  count++;
                }
              }
            }
          }
          return count;
        case 'BOX':
          if (f.length < 3) return 0;
          return f.length * (f.length - 1) * (f.length - 2);
        case '軸1頭ながし':
          return s.length * (s.length - 1);
        case '軸1頭マルチ':
          return s.length * (s.length - 1) * 3;
        case '軸2頭ながし':
        // ▼▼▼【修正箇所1】軸馬のリスト(first, second)の要素が各1頭の場合、着順固定とみなし「* 2」をしない ▼▼▼
          if (f.length == 1 && s.length == 1) {
            return t.length;
          }
          return t.length * 2;
        case '軸2頭マルチ':
          return t.length * 6;
        default:
          return 0;
      }

    case '3連複':
      switch (normalizedMethod) {
        case 'フォーメーション':
          Set<String> combos = {};
          for (var i in f) {
            for (var j in s) {
              for (var k in t) {
                var set = {i, j, k};
                if (set.length == 3) {
                  var sorted = set.toList()..sort();
                  combos.add(sorted.join('-'));
                }
              }
            }
          }
          return combos.length;
        case 'BOX':
          if (f.length < 3) return 0;
          return f.length * (f.length - 1) * (f.length - 2) ~/ 6;
        case '軸1頭ながし':
          return s.length * (s.length - 1) ~/ 2;
        case '軸2頭ながし':
          return s.length;
        default:
          return 0;
      }

    case '馬単':
      switch (normalizedMethod) {
        case 'フォーメーション':
          int count = 0;
          for (var i in f) {
            for (var j in s) {
              if (i != j) {
                count++;
              }
            }
          }
          return count;
        case 'BOX':
          return f.length * (f.length - 1);
        case 'ながし':
          return s.length;
        case 'マルチ':
          return s.length * 2;
        default:
          return 0;
      }

    case '馬連':
    case 'ワイド':
    case '枠連':
      switch (normalizedMethod) {
        case 'フォーメーション':
          final overlap = f.toSet().intersection(s.toSet()).length;
          return (f.length * s.length) - overlap;
        case 'BOX':
          if (f.length < 2) return 0;
          return f.length * (f.length - 1) ~/ 2;
        case 'ながし':
          return s.length;
        default:
          return 0;
      }

    default:
      return 0;
  }
}
int combinationsCount(int n, int k) {
  if (k < 0 || k > n) return 0;
  if (k == 0 || k == n) return 1;
  if (k > n / 2) k = n - k;
  int res = 1;
  for (int i = 1; i <= k; ++i) res = res * (n - i + 1) ~/ i;
  return res;
}