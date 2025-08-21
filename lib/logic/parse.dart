// lib/logic/parse.dart

import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

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
            final baseCombinations = combinationsCount(opponents.length, 2);
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

  if (d.containsKey('購入内容') && d['購入内容'] is List) {
    for (var detail in (d['購入内容'] as List)) {
      if (detail is Map<String, dynamic>) {
        generateAndSetAllCombinations(detail, d['方式'] as String);
      }
    }
  }

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