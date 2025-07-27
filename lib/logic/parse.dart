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


// --- ▼▼▼ ここからが新しく追加する独立したロジック ▼▼▼ ---

/// 組み合わせ (nCk) を生成する
Iterable<List<T>> _combinations<T>(List<T> elements, int k) sync* {
  if (k < 0 || k > elements.length) return;
  if (k == 0) {
    yield [];
    return;
  }
  for (int i = 0; i <= elements.length - k; i++) {
    T head = elements[i];
    List<T> rest = elements.sublist(i + 1);
    for (List<T> tail in _combinations(rest, k - 1)) {
      yield [head, ...tail];
    }
  }
}

/// 順列 (nPk) を生成する
Iterable<List<T>> _permutations<T>(List<T> elements, int k) sync* {
  if (k < 0 || k > elements.length) return;
  if (k == 0) {
    yield [];
    return;
  }
  for (int i = 0; i < elements.length; i++) {
    T head = elements[i];
    List<T> rest = [...elements]..removeAt(i);
    for (List<T> tail in _permutations(rest, k - 1)) {
      yield [head, ...tail];
    }
  }
}

/// 購入内容から全ての組み合わせを生成し、di['all_combinations']に格納する新しいヘルパー関数
void _generateAndSetAllCombinations(Map<String, dynamic> di, String bettingMethod) {
  final String ticketType = di['式別'];
  List<List<int>> allCombinations = [];

  // (null)問題解決のため、個別の購入内容にも方式をコピー
  di['方式'] = bettingMethod;

  try {
    switch (bettingMethod) {
      case '通常':
      case '応援馬券':
        allCombinations.add((di['馬番'] as List).cast<int>());
        break;

      case 'ボックス':
        final horses = (di['馬番'] as List).cast<int>();
        switch (ticketType) {
          case '馬連': case 'ワイド': case '枠連':
          allCombinations = _combinations(horses, 2).toList();
          break;
          case '3連複':
            allCombinations = _combinations(horses, 3).toList();
            break;
          case '馬単':
            allCombinations = _permutations(horses, 2).toList();
            break;
          case '3連単':
            allCombinations = _permutations(horses, 3).toList();
            break;
        }
        break;

      case 'ながし':
        final axis = (di['軸'] as List? ?? []).cast<int>();
        final opponents = (di['相手'] as List? ?? []).cast<int>();
        final isMulti = di['マルチ'] == 'あり';

        switch (ticketType) {
          case '馬連': case 'ワイド': case '枠連':
          for (final a in axis) {
            for (final o in opponents) {
              if (a != o) allCombinations.add([a, o]);
            }
          }
          break;
          case '馬単':
            for (final a in axis) {
              for (final o in opponents) {
                if (a != o) {
                  if (isMulti) {
                    allCombinations.add([a, o]);
                    allCombinations.add([o, a]);
                  } else {
                    if (di['ながし'] == '1着ながし') allCombinations.add([a, o]);
                    if (di['ながし'] == '2着ながし') allCombinations.add([o, a]);
                  }
                }
              }
            }
            break;
          case '3連複':
            if (di['ながし種別'] == '軸1頭ながし') {
              final opponentCombos = _combinations(opponents, 2);
              for (final combo in opponentCombos) {
                allCombinations.add([axis.first, ...combo]);
              }
            } else if (di['ながし種別'] == '軸2頭ながし') {
              for (final o in opponents) {
                allCombinations.add([...axis, o]);
              }
            }
            break;
          case '3連単':
            final horseGroups = (di['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
            final firstAxis = horseGroups.isNotEmpty ? horseGroups[0] : <int>[];
            final secondAxis = horseGroups.length > 1 ? horseGroups[1] : <int>[];
            final thirdAxis = horseGroups.length > 2 ? horseGroups[2] : <int>[];

            if (!isMulti) {
              if (di['ながし種別'] == '軸1頭ながし') {
                final nagashiType = di['ながし'];
                final otherHorses = secondAxis.isNotEmpty ? secondAxis : thirdAxis;
                final perms = _permutations(otherHorses, 2).toList();
                for(final p in perms) {
                  if(nagashiType == '1着ながし') allCombinations.add([firstAxis.first, p[0], p[1]]);
                  if(nagashiType == '2着ながし') allCombinations.add([p[0], firstAxis.first, p[1]]);
                  if(nagashiType == '3着ながし') allCombinations.add([p[0], p[1], firstAxis.first]);
                }
              } else if (di['ながし種別'] == '軸2頭ながし') {
                final nagashiType = di['ながし'];
                final axisHorses = firstAxis;
                final opponentHorses = secondAxis.isNotEmpty ? secondAxis : thirdAxis;
                final axisPerms = _permutations(axisHorses, 2).toList();
                for(final ap in axisPerms) {
                  for(final o in opponentHorses) {
                    if(o != ap[0] && o != ap[1]) {
                      if(nagashiType == '1・2着ながし') allCombinations.add([ap[0], ap[1], o]);
                      if(nagashiType == '1・3着ながし') allCombinations.add([ap[0], o, ap[1]]);
                      if(nagashiType == '2・3着ながし') allCombinations.add([o, ap[0], ap[1]]);
                    }
                  }
                }
              }
            } else { // マルチの場合
              List<int> multiHorses = [];
              if (di['ながし種別']?.contains('1頭')) {
                multiHorses = [firstAxis.first, ...(secondAxis.isNotEmpty ? secondAxis : thirdAxis)];
              } else if (di['ながし種別']?.contains('2頭')) {
                multiHorses = [...firstAxis, ...secondAxis, ...thirdAxis];
              }
              if (multiHorses.isNotEmpty) {
                allCombinations = _permutations(multiHorses.toSet().toList(), 3).toList();
              }
            }
            break;
        }
        break;

      case 'フォーメーション':
        final firstPos = (di['馬番'][0] as List).cast<int>();
        final secondPos = (di['馬番'].length > 1) ? (di['馬番'][1] as List).cast<int>() : <int>[];
        final thirdPos = (di['馬番'].length > 2) ? (di['馬番'][2] as List).cast<int>() : <int>[];

        switch (ticketType) {
          case '馬連': case 'ワイド': case '枠連':
          for (final f in firstPos) {
            for (final s in secondPos) {
              if (f != s) allCombinations.add([f, s]);
            }
          }
          break;
          case '馬単':
            for (final f in firstPos) {
              for (final s in secondPos) {
                if (f != s) allCombinations.add([f, s]);
              }
            }
            break;
          case '3連複':
            for (final f in firstPos) {
              for (final s in secondPos) {
                for (final t in thirdPos) {
                  if (f != s && f != t && s != t) {
                    allCombinations.add([f, s, t]);
                  }
                }
              }
            }
            break;
          case '3連単':
            for (final f in firstPos) {
              for (final s in secondPos) {
                for (final t in thirdPos) {
                  if (f != s && f != t && s != t) {
                    allCombinations.add([f, s, t]);
                  }
                }
              }
            }
            break;
        }
        break;

      case 'クイックピック':
        allCombinations = (di['馬番'] as List).map((c) => (c as List).cast<int>()).toList();
        break;
    }

    if (ticketType == '馬連' || ticketType == 'ワイド' || ticketType == '枠連' || ticketType == '3連複') {
      final uniqueCombinations = <String, List<int>>{};
      for (final combo in allCombinations) {
        final sortedCombo = List<int>.from(combo)..sort();
        uniqueCombinations[sortedCombo.join('-')] = sortedCombo;
      }
      di['all_combinations'] = uniqueCombinations.values.toList();
    } else {
      di['all_combinations'] = allCombinations;
    }

    // ▼▼▼ `組合せ数_表示用`を復活させるロジック ▼▼▼
    if (di['マルチ'] == 'あり') {
      if (ticketType == '3連単') {
        final horseGroups = (di['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
        if (di['ながし種別'] == '軸1頭ながし') {
          final opponents = horseGroups.length > 1 ? horseGroups[1] : [];
          final baseCombinations = _combinations(opponents, 2).length;
          di['組合せ数_表示用'] = '$baseCombinations × 6';
        } else if (di['ながし種別'] == '軸2頭ながし') {
          final opponents = horseGroups.length > 2 ? horseGroups[2] : [];
          di['組合せ数_表示用'] = '${opponents.length} × 6';
        }
      } else if (ticketType == '馬単') {
        final opponents = (di["相手"] as List?)?.cast<int>() ?? [];
        di['組合せ数_表示用'] = '${opponents.length} × 2';
      }
    }
    // ▲▲▲ ここまで ▲▲▲

  } catch (e) {
    print('Error generating combinations for $ticketType ($bettingMethod): $e');
    di['all_combinations'] = [];
  }
}

// --- 組み合わせ生成ロジックここまで ---

// --- 既存ロジック (parseHorseracingTicketQr) ---
Map<String, dynamic> parseHorseracingTicketQr(String s) {
  List<String> underDigits = List.filled(40, "X");
  for (int i = 0; i < 34; i++) {
    underDigits[i] = "0";
  }

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

  switch (typeCode) {
    case "0": // 通常
    case "5": // 応援馬券
      while (true) {
        if (itr.peek(0) == "0") { itr.next(); break; }
        String bettingCode = itr.next();
        Map<String, dynamic> di = {};
        di["式別"] = bettingDict[bettingCode];
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

        _generateAndSetAllCombinations(di, d['方式'] as String);
        di["組合せ数"] = (di['all_combinations'] as List).length;
        totalAmount += (di["購入金額"] as int) * (di["組合せ数"] as int);
        (d["購入内容"] as List).add(di);
      }
      break;

    case "1": // ボックス
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      List<int> nos = [];
      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) nos.add(int.parse(itr.next() + itr.next()));
      final originalPos = itr.position;
      itr.move(5);
      if (!(itr.peek(0) == "9" && itr.peek(1) == "0")) {
        itr.currentPosition = originalPos;
        for (int i = 0; i < 5; i++) nos.add(int.parse(itr.next() + itr.next()));
      } else {
        itr.currentPosition = originalPos;
      }
      final originalPos2 = itr.position;
      itr.move(5);
      if (!(itr.peek(0) == "9" && itr.peek(1) == "0")) {
        itr.currentPosition = originalPos2;
        for (int i = 0; i < 8; i++) nos.add(int.parse(itr.next() + itr.next()));
      } else {
        itr.currentPosition = originalPos2;
      }
      for (int i = 0; i < 5; i++) purchaseAmountStr += itr.next();
      di["馬番"] = nos.where((x) => x != 0).toList();
      di["購入金額"] = int.parse("${purchaseAmountStr}00");

      _generateAndSetAllCombinations(di, d['方式'] as String);
      di["組合せ数"] = (di['all_combinations'] as List).length;
      totalAmount += (di["購入金額"] as int) * (di["組合せ数"] as int);
      (d["購入内容"] as List).add(di);
      break;

    case "2": // ながし
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      String wheelCode = itr.next();
      switch (bettingCode) {
        case "6": di["ながし"] = wheelExactaDict[wheelCode]; break;
        case "8": di["ながし"] = wheelTrioDict[wheelCode]; di['ながし種別'] = di['ながし']; break;
        case "9": di["ながし"] = wheelTrifectaDict[wheelCode]; di['ながし種別'] = di['ながし']!.contains('・') ? '軸2頭ながし' : '軸1頭ながし'; break;
        default: di["ながし"] = "ながし";
      }
      if (bettingCode == "9") {
        List<List<int>> horseNumbers = [];
        for (int j = 0; j < 3; j++) {
          List<int> innerList = [];
          for (int i = 1; i <= 18; i++) if (itr.next() == "1") innerList.add(i);
          horseNumbers.add(innerList);
        }
        di["馬番"] = horseNumbers;
      } else {
        List<int> axisHorses = [];
        for (int j = 0; j < (bettingCode == "8" || bettingCode == "6" ? 2 : 1); j++) {
          for (int i = 1; i <= 18; i++) if (itr.next() == "1") axisHorses.add(i);
        }
        di["軸"] = axisHorses;
        List<int> opponentHorses = [];
        for (int i = 1; i <= 18; i++) if (itr.next() == "1") opponentHorses.add(i);
        di["相手"] = opponentHorses;
      }
      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) purchaseAmountStr += itr.next();
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      String multiCode = itr.next();
      di["マルチ"] = multiCode == "1" ? "あり" : "なし";

      _generateAndSetAllCombinations(di, d['方式'] as String);
      di["組合せ数"] = (di['all_combinations'] as List).length;
      totalAmount += (di["購入金額"] as int) * (di["組合せ数"] as int);
      (d["購入内容"] as List).add(di);
      break;

    case "3": // フォーメーション
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
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

      _generateAndSetAllCombinations(di, d['方式'] as String);
      di["組合せ数"] = (di['all_combinations'] as List).length;
      totalAmount += (di["購入金額"] as int) * (di["組合せ数"] as int);
      (d["購入内容"] as List).add(di);
      break;

    case "4": // クイックピック
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      int no = int.parse(itr.next() + itr.next());
      if (no != 0) d["軸"] = no;
      int positionSpecify = int.parse(itr.next());
      if (bettingCode == "6" || bettingCode == "9") d["着順指定"] = positionSpecify != 0 ? "$positionSpecify着指定" : "なし";
      di["組合せ数"] = int.parse(itr.next() + itr.next());
      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) if (itr.position < s.length) purchaseAmountStr += itr.next();
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      itr.move(2);
      List<List<int>> horseNumbersList = [];
      for (int i = 0; i < di["組合せ数"]; i++) {
        List<int> innerList = [];
        for (int j = 0; j < 3; j++) {
          int horseNum = int.parse(itr.next() + itr.next());
          if (horseNum != 0) innerList.add(horseNum);
        }
        horseNumbersList.add(innerList);
      }
      di["馬番"] = horseNumbersList;

      _generateAndSetAllCombinations(di, d['方式'] as String);
      // クイックピックは組合せ数がQRに含まれているので、再計算はしない
      totalAmount += (di["購入金額"] as int) * (di["組合せ数"] as int);
      (d["購入内容"] as List).add(di);
      break;

    default:
      throw ArgumentError("Unknown type code: $typeCode");
  }

  d['合計金額'] = totalAmount;
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
