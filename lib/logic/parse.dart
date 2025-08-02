// lib/logic/parse.dart
import 'dart:math';

// --- 定数定義 (変更なし) ---
const Map<String, String> racecourseDict = {
  "01": "札幌", "02": "函館", "03": "福島", "04": "新潟", "05": "東京",
  "06": "中山", "07": "中京", "08": "京都", "09": "阪神", "10": "小倉",
};
const Map<String, String> typeDict = {
  "0": "通常", "1": "ボックス", "2": "ながし", "3": "フォーメーション",
  "4": "クイックピック", "5": "応援馬券",
};
const Map<String, String> ticketofficeDict = {
  "01": "JRA札幌", "02": "JRA函館", "03": "JRA福島", "04": "JRA新潟", "05": "JRA東京",
  "06": "JRA中山", "07": "JRA中京", "08": "JRA京都", "09": "阪神", "10": "小倉",
  "13": "ウインズ銀座", "16": "ウインズ渋谷", "18": "ウインズ浅草", "19": "ウインズ新白河",
  "20": "ウインズ横浜", "21": "ウインズ新横浜", "22": "ウインズ錦糸町", "23": "ウインズ梅田",
  "24": "ウインズ難波", "26": "ウインズ名古屋", "27": "ウインズ京都", "28": "ウインズ米子",
  "29": "ウインズ道頓堀", "30": "ウインズ札幌", "32": "ウインズ後楽園", "33": "ウインズ佐世保",
  "34": "ウインズ汐留", "38": "ウインズ広島", "39": "ウインズ釧路", "40": "ウインズ石和",
  "41": "ウインズ立川", "42": "ウインズ新宿", "43": "ウインズ新橋", "44": "ウインズ神戸",
  "46": "ウインズ高松", "49": "ウインズ高崎", "62": "エクセル伊勢佐木", "63": "ウインズ横手",
  "64": "ウインズ水沢", "67": "ウインズ佐賀", "68": "ウインズ盛岡", "69": "ウインズ銀座通り",
  "70": "エクセル田無", "71": "ウインズ津軽", "72": "ウインズ静内", "73": "ウインズ八幡",
  "74": "ウインズ姫路", "77": "ウインズ小郡", "79": "エクセル博多", "81": "ウインズ宮崎",
  "82": "ウインズ八代", "83": "エクセル浜松", "84": "ウインズ川崎", "85": "ウインズ浦和",
  "86": "ウインズ三本木", "87": "ライトウインズ阿見", "89": "ライトウインズりんくうタウン",
};
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
// --- 定数定義ここまで ---

// ▼▼▼ 組み合わせ計算のロジックを、既存の`calculatePoints`とは別に、安全な場所に追加 ▼▼▼
Iterable<List<T>> _combinations<T>(List<T> elements, int k) sync* {
  if (k < 0 || k > elements.length) return;
  if (k == 0) { yield []; return; }
  for (int i = 0; i <= elements.length - k; i++) {
    T head = elements[i];
    List<T> rest = elements.sublist(i + 1);
    for (List<T> tail in _combinations(rest, k - 1)) {
      yield [head, ...tail];
    }
  }
}
Iterable<List<T>> _permutations<T>(List<T> elements, int k) sync* {
  if (k < 0 || k > elements.length) return;
  if (k == 0) { yield []; return; }
  for (int i = 0; i < elements.length; i++) {
    T head = elements[i];
    List<T> rest = [...elements]..removeAt(i);
    for (List<T> tail in _permutations(rest, k - 1)) {
      yield [head, ...tail];
    }
  }
}
void _generateAndSetAllCombinations(Map<String, dynamic> di, String bettingMethod) {
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
          case '馬連': case 'ワイド': case '枠連': allCombinations = _combinations(horses, 2).toList(); break;
          case '3連複': allCombinations = _combinations(horses, 3).toList(); break;
          case '馬単': allCombinations = _permutations(horses, 2).toList(); break;
          case '3連単': allCombinations = _permutations(horses, 3).toList(); break;
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
              for (final combo in _combinations(opponents, 2)) allCombinations.add([axis.first, ...combo]);
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
                final opponentCombos = _combinations(opponentHorses, 2);
                for (final combo in opponentCombos) {
                  // 「軸1頭」と「相手2頭」の組み合わせ(合計3頭)で、全順列(6通り)を生成
                  allCombinations.addAll(_permutations([axisHorse, ...combo], 3));
                }
              } else if (di['ながし種別'] == '軸2頭ながし') {
                final axis1 = firstAxis.first;
                final axis2 = secondAxis.first;
                final opponentHorses = thirdAxis;
                // 相手を1頭ずつループ
                for (final opponent in opponentHorses) {
                  // 「軸2頭」と「相手1頭」の組み合わせ(合計3頭)で、全順列(6通り)を生成
                  allCombinations.addAll(_permutations([axis1, axis2, opponent], 3));
                }
              }
            } else { // マルチではない通常のながし
              if (di['ながし種別'] == '軸1頭ながし') {
                final nagashiType = di['ながし'];
                final otherHorses = secondAxis.isNotEmpty ? secondAxis : thirdAxis;
                for(final p in _permutations(otherHorses, 2)) {
                  if(nagashiType == '1着ながし') allCombinations.add([firstAxis.first, p[0], p[1]]);
                  if(nagashiType == '2着ながし') allCombinations.add([p[0], firstAxis.first, p[1]]);
                  if(nagashiType == '3着ながし') allCombinations.add([p[0], p[1], firstAxis.first]);
                }
              } else if (di['ながし種別'] == '軸2頭ながし') {
                final nagashiType = di['ながし'];
                final axisHorses = firstAxis; // 軸は1頭ずつのはず
                final opponentHorses = secondAxis; // 2頭軸の場合の相手
                final thirdOpponents = thirdAxis; // 1-2着流しなどの相手
                for(final ap in _permutations([...axisHorses, ...opponentHorses], 2)) {
                  for(final o in thirdOpponents) {
                    if(!ap.contains(o)) {
                      if(nagashiType == '1・2着ながし') allCombinations.add([ap[0], ap[1], o]);
                      if(nagashiType == '1・3着ながし') allCombinations.add([ap[0], o, ap[1]]);
                      if(nagashiType == '2・3着ながし') allCombinations.add([o, ap[0], ap[1]]);
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
    // ▼▼▼ ここに追加 ▼▼▼
    print('DEBUG: 生成直後の組み合わせ (ソート前): $allCombinations');
    // ▲▲▲ ここまで ▲▲▲

    if (['馬連', 'ワイド', '枠連', '3連複'].contains(ticketType)) {
      final unique = <String, List<int>>{};
      for (final combo in allCombinations) {
        final sorted = List<int>.from(combo)..sort();
        unique[sorted.join('-')] = sorted;
      }
      di['all_combinations'] = unique.values.toList();
      // ▼▼▼ ここに追加 ▼▼▼
      print('DEBUG: DB保存直前の組み合わせ (3連複など): ${di['all_combinations']}');
      // ▲▲▲ ここまで ▲▲▲
    } else {
      di['all_combinations'] = allCombinations;
      // ▼▼▼ ここに追加 ▼▼▼
      print('DEBUG: DB保存直前の組み合わせ (3連単など): ${di['all_combinations']}');
      // ▲▲▲ ここまで ▲▲▲
    }
  } catch (e) {
    print('Error generating combinations for $ticketType ($bettingMethod): $e');
    di['all_combinations'] = [];
  }
}


// ▼▼▼ `calculatePoints`関数を元の状態に復元 ▼▼▼
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
int _combinationsCount(int n, int k) {
  if (k < 0 || k > n) return 0;
  if (k == 0 || k == n) return 1;
  if (k > n / 2) k = n - k;
  int res = 1;
  for (int i = 1; i <= k; ++i) res = res * (n - i + 1) ~/ i;
  return res;
}
// ▲▲▲ ここまで復元 ▲▲▲


Map<String, dynamic> parseHorseracingTicketQr(String s) {
  List<String> underDigits = List.filled(40, "X");
  for (int i = 0; i < 34; i++) underDigits[i] = "0";

  Map<String, dynamic> d = {};
  d["QR"] = s;
  _StringIterator itr = _StringIterator(s);

  String ticketFormat = itr.next();
  String racecourseCode = itr.next() + itr.next();
  d["開催場"] = racecourseDict[racecourseCode];
  itr.move(2);
  String alternativeCode = itr.next();
  if (alternativeCode != "0") {
    if (alternativeCode == "2") d["開催種別"] = "代替";
    else if (alternativeCode == "7") d["開催種別"] = "継続";
    else d["開催種別"] = "不明";
  }
  d["年"] = int.parse(itr.next() + itr.next());
  d["回"] = int.parse(itr.next() + itr.next());
  d["日"] = int.parse(itr.next() + itr.next());
  d["レース"] = int.parse(itr.next() + itr.next());
  String typeCode = itr.next();
  d["方式"] = typeDict[typeCode];
  itr.next();
  for (int i = 28; i < 34; i++) underDigits[i] = itr.next();
  for (int i = 20; i < 26; i++) underDigits[i] = itr.next();
  for (int i = 0; i < 13; i++) underDigits[i] = itr.next();
  underDigits[26] = itr.next();
  String ticketofficeCode = underDigits.sublist(0, 4).join();
  d["発売所"] = ticketofficeDict[ticketofficeCode.substring(2)] ?? ticketofficeDict[ticketofficeCode.substring(0, 2)] ?? "不明";
  underDigits[13] = "1";
  underDigits[14] = typeCode;
  d["購入内容"] = [];

  int totalAmount = 0;

  // ▼▼▼ QRコード解析ロジックを完全に元の状態に戻す ▼▼▼
  switch (typeCode) {
    case "0": // 通常
    case "5": // 応援馬券
      while (true) {
        if (itr.peek(0) == "0") { itr.next(); break; }
        String bettingCode = itr.next();
        Map<String, dynamic> di = {};
        di["式別"] = bettingCode;
        int count;
        switch (bettingCode) {
          case "1": case "2": count = 1; break;
          case "3": case "5": case "6": case "7": count = 2; break;
          case "8": case "9": count = 3; break;
          default: throw ArgumentError("Unexpected bettingCode: $bettingCode");
        }
        di["馬番"] = [ for (int i = 0; i < count; i++) int.parse(itr.next() + itr.next()) ];
        int c = (int.parse(ticketFormat) + 1) ~/ 2;
        if (bettingCode == "5" && ticketFormat == "3") c += 1;
        if (c > count && typeCode != "5" && bettingCode != "6") itr.move((c - count) * 2);
        if (bettingCode == "1" || bettingCode == "2" || bettingCode == "6") {
          String ura = itr.next() + itr.next();
          if (bettingCode == "6") di["ウラ"] = ura == "01" ? "あり" : "なし";
        }
        String purchaseAmountStr = "";
        for (int i = 0; i < 5 && itr.position < s.length; i++) purchaseAmountStr += itr.next();
        di["購入金額"] = (purchaseAmountStr.length == 5) ? int.parse(purchaseAmountStr) * 100 : 0;

        (d["購入内容"] as List).add(di);
      }
      break;

    case "1": // ボックス
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingCode;
      List<int> nos = [];
      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) nos.add(int.parse(itr.next() + itr.next()));
      final originalPos = itr.position;
      itr.move(5);
      if (!(itr.peek(0) == "9" && itr.peek(1) == "0")) {
        itr.currentPosition = originalPos;
        for (int i = 0; i < 5; i++) nos.add(int.parse(itr.next() + itr.next()));
      } else { itr.currentPosition = originalPos; }
      final originalPos2 = itr.position;
      itr.move(5);
      if (!(itr.peek(0) == "9" && itr.peek(1) == "0")) {
        itr.currentPosition = originalPos2;
        for (int i = 0; i < 8; i++) nos.add(int.parse(itr.next() + itr.next()));
      } else { itr.currentPosition = originalPos2; }
      for (int i = 0; i < 5; i++) purchaseAmountStr += itr.next();
      di["馬番"] = nos.where((x) => x != 0).toList();
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      di["組合せ数"] = calculatePoints(ticketType: bettingDict[bettingCode]!, method: 'BOX', first: di["馬番"]);

      (d["購入内容"] as List).add(di);
      break;

    case "2": // ながし
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingCode;
      String method = '';
      String wheelCode = itr.next();
      int? currentPurchaseAmount;
      switch (bettingCode) {
        case "6": di["ながし"] = wheelExactaDict[wheelCode]; method = 'ながし'; break;
        case "8": di["ながし"] = wheelTrioDict[wheelCode]; method = di["ながし"]!; di['ながし種別'] = method; break;
        case "9": di["ながし"] = wheelTrifectaDict[wheelCode]; method = di["ながし"]!; if (di["ながし"]!.contains('・')) method = '軸2頭ながし'; else method = '軸1頭ながし'; di['ながし種別'] = method; break;
        default: di["ながし"] = "ながし"; method = 'ながし';
      }
      int count = 0;
      if (bettingCode == "6" || bettingCode == "8") {
        List<int> horseNumbers = [];
        for (int j = 0; j < 2; j++) for (int i = 1; i <= 18; i++) if (itr.next() == "1") horseNumbers.add(i);
        di["軸"] = horseNumbers;
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) if (itr.next() == "1") innerList.add(i);
        di["相手"] = innerList;
        count = innerList.length;
      } else if (bettingCode == "9") {
        List<List<int>> horseNumbers = [];
        for (int j = 0; j < 3; j++) {
          List<int> innerList = [];
          for (int i = 1; i <= 18; i++) if (itr.next() == "1") innerList.add(i);
          horseNumbers.add(innerList);
        }
        di["馬番"] = horseNumbers;
        if (method == '軸2頭ながし') count = horseNumbers.length > 2 ? horseNumbers[2].length : 0;
        else if (method == '軸1頭ながし') count = horseNumbers.length > 1 ? horseNumbers[1].length : 0;
      } else {
        di["軸"] = int.parse(itr.next() + itr.next());
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) purchaseAmountStr += itr.next();
        currentPurchaseAmount = int.parse("${purchaseAmountStr}00");
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) if (itr.next() == "1") innerList.add(i);
        di["相手"] = innerList;
        count = innerList.length;
      }
      if (bettingCode == "8" || bettingCode == "9" || bettingCode == "6") {
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) purchaseAmountStr += itr.next();
        currentPurchaseAmount = int.parse("${purchaseAmountStr}00");
      }
      di["購入金額"] = currentPurchaseAmount ?? 0;
      String multiCode = itr.next();
      if (multiCode == "1") {
        di["マルチ"] = "あり";
        if (bettingCode == "9") {
          final horseGroups = (di["馬番"] as List).map((e) => (e as List).cast<int>()).toList();
          if (method == '軸1頭ながし') {
            method = '軸1頭マルチ';
            final opponents = horseGroups.length > 1 ? horseGroups[1] : [];
            final baseCombinations = _combinationsCount(opponents.length, 2);
            di["組合せ数_表示用"] = '$baseCombinations × 6';
          } else if (method == '軸2頭ながし') {
            method = '軸2頭マルチ';
            final opponents = horseGroups.length > 2 ? horseGroups[2] : [];
            di["組合せ数_表示用"] = '${opponents.length} × 6';
          }
        } else if (bettingCode == "6") {
          method = 'マルチ';
          final opponents = (di["相手"] as List?)?.cast<int>() ?? [];
          di["組合せ数_表示用"] = '${opponents.length} × 2';
        }
      } else { di["マルチ"] = "なし"; }
      if (bettingCode == "9") {
        final hg = (di["馬番"] as List).map((e) => (e as List).cast<int>()).toList();
        if (method == '軸1頭ながし' || method == '軸1頭マルチ') di["組合せ数"] = calculatePoints(ticketType: bettingDict[bettingCode]!, method: method, first: hg[0], second: hg.length > 1 ? hg[1] : hg[2]);
        else if (method == '軸2頭ながし' || method == '軸2頭マルチ') di["組合せ数"] = calculatePoints(ticketType: bettingDict[bettingCode]!, method: method, first: hg[0], second: hg[1], third: hg[2]);
      } else if (bettingCode == "6" || bettingCode == "8") {
        di["組合せ数"] = calculatePoints(ticketType: bettingDict[bettingCode]!, method: method, first: (di["軸"] as List).cast<int>(), second: (di["相手"] as List).cast<int>());
      } else {
        di["組合せ数"] = calculatePoints(ticketType: bettingDict[bettingCode]!, method: 'ながし', first: [di["軸"] as int], second: (di["相手"] as List).cast<int>());
      }

      (d["購入内容"] as List).add(di);
      break;

    case "3": // フォーメーション
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingCode;
      itr.next();
      List<List<int>> horseNumbers = [];
      for (int j = 0; j < 3; j++) {
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) if (itr.next() == "1") innerList.add(i);
        if (innerList.isNotEmpty) horseNumbers.add(innerList);
      }
      di["馬番"] = horseNumbers;
      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) if (itr.position < s.length) purchaseAmountStr += itr.next();
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      itr.next();
      List<int> f = [], s_ = [], t = [];
      if (di["馬番"].length > 0) f = (di["馬番"][0] as List).cast<int>();
      if (di["馬番"].length > 1) s_ = (di["馬番"][1] as List).cast<int>();
      if (di["馬番"].length > 2) t = (di["馬番"][2] as List).cast<int>();
      di["組合せ数"] = calculatePoints(ticketType: bettingDict[bettingCode]!, method: 'フォーメーション', first: f, second: s_, third: t);

      (d["購入内容"] as List).add(di);
      break;

    case "4": // クイックピック
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingCode;
      int no = int.parse(itr.next() + itr.next());
      if (no != 0) d["軸"] = no;
      int positionSpecify = int.parse(itr.next());
      if (bettingCode == "6" || bettingCode == "9") d["着順指定"] = positionSpecify != 0 ? "$positionSpecify着指定" : "なし";
      d["組合せ数"] = int.parse(itr.next() + itr.next());
      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) if (itr.position < s.length) purchaseAmountStr += itr.next();
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      itr.move(2);
      List<List<int>> horseNumbersList = [];
      for (int i = 0; i < d["組合せ数"]; i++) {
        List<int> innerList = [];
        for (int j = 0; j < 3; j++) {
          int horseNum = int.parse(itr.next() + itr.next());
          if (horseNum != 0) innerList.add(horseNum);
        }
        horseNumbersList.add(innerList);
      }
      di["馬番"] = horseNumbersList;

      (d["購入内容"] as List).add(di);
      break;
    default:
      throw ArgumentError("Unknown type code: $typeCode");
  }
  // ▲▲▲ ここまで復元 ▲▲▲

  if (d.containsKey('購入内容') && d['購入内容'] is List) {
    for (var detail in (d['購入内容'] as List)) {
      if (detail is Map<String, dynamic>) {
        final amount = detail['購入金額'] as int? ?? 0;
        final combinations = detail['組合せ数'] as int? ?? 1;
        totalAmount += amount * combinations;
      }
    }
  }
  d['合計金額'] = totalAmount;

  // ▼▼▼ 解析完了後に、安全に組み合わせリストを追加 ▼▼▼
  if (d.containsKey('購入内容') && d['購入内容'] is List) {
    for (var detail in (d['購入内容'] as List)) {
      if (detail is Map<String, dynamic>) {
        _generateAndSetAllCombinations(detail, d['方式'] as String);
      }
    }
  }
  // ▲▲▲ ここまで ▲▲▲

  d["下端番号"] = _joinWithSpaces(underDigits);
  return d;
}

String _joinWithSpaces(List<String> underDigits) {
  final buffer = StringBuffer();
  for (int i = 0; i < underDigits.length; i++) {
    buffer.write(underDigits[i]);
    if (i == 12 || i == 25 || i == 33) buffer.write(" ");
  }
  return buffer.toString();
}

class _StringIterator {
  final String _s;
  int _currentPosition = 0;
  _StringIterator(this._s);
  String next() {
    if (_currentPosition >= _s.length) throw StateError("No more elements.");
    return _s[_currentPosition++];
  }
  void move(int offset) {
    _currentPosition += offset;
    if (_currentPosition < 0 || _currentPosition > _s.length) throw RangeError("Invalid position.");
  }
  int get position => _currentPosition;
  set currentPosition(int pos) => _currentPosition = pos;
  String peek(int offset) {
    int pos = _currentPosition + offset;
    if (pos >= _s.length || pos < 0) throw RangeError("Peek out of range.");
    return _s[pos];
  }
}