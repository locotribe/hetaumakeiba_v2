// lib/logic/parse.dart

const Map<String, String> racecourseDict = {
  "01": "札幌",
  "02": "函館",
  "03": "福島",
  "04": "新潟",
  "05": "東京",
  "06": "中山",
  "07": "中京",
  "08": "京都",
  "09": "阪神",
  "10": "小倉",
};

const Map<String, String> typeDict = {
  "0": "通常",
  "1": "ボックス",
  "2": "ながし",
  "3": "フォーメーション",
  "4": "クイックピック",
  "5": "応援馬券",
};

const Map<String, String> ticketofficeDict = {
  "01": "JRA札幌",
  "02": "JRA函館",
  "03": "JRA福島",
  "04": "JRA新潟",
  "05": "JRA東京",
  "06": "JRA中山",
  "07": "JRA中京",
  "08": "JRA京都",
  "09": "JRA阪神",
  "10": "小倉",
  "13": "ウインズ銀座",
  "16": "ウインズ渋谷",
  "18": "ウインズ浅草",
  "19": "ウインズ新白河",
  "20": "ウインズ横浜",
  "21": "ウインズ新横浜",
  "22": "ウインズ錦糸町",
  "23": "ウインズ梅田",
  "24": "ウインズ難波",
  "26": "ウインズ名古屋",
  "27": "ウインズ京都",
  "28": "ウインズ米子",
  "29": "ウインズ道頓堀",
  "30": "ウインズ札幌",
  "32": "ウインズ後楽園",
  "33": "ウインズ佐世保",
  "34": "ウインズ汐留",
  "38": "ウインズ広島",
  "39": "ウインズ釧路",
  "40": "ウインズ石和",
  "41": "ウインズ立川",
  "42": "ウインズ新宿",
  "43": "ウインズ新橋",
  "44": "ウインズ神戸",
  "46": "ウインズ高松",
  "49": "ウインズ高崎",
  "62": "エクセル伊勢佐木",
  "63": "ウインズ横手",
  "64": "ウインズ水沢",
  "67": "ウインズ佐賀",
  "68": "ウインズ盛岡",
  "69": "ウインズ銀座通り",
  "70": "エクセル田無",
  "71": "ウインズ津軽",
  "72": "ウインズ静内",
  "73": "ウインズ八幡",
  "74": "ウインズ姫路",
  "77": "ウインズ小郡",
  "79": "エクセル博多",
  "81": "ウインズ宮崎",
  "82": "ウインズ八代",
  "83": "エクセル浜松",
  "84": "ウインズ川崎",
  "85": "ウインズ浦和",
  "86": "ウインズ三本木",
  "87": "ライトウインズ阿見",
  "89": "ライトウインズりんくうタウン",
};

const Map<String, String> bettingDict = {
  "1": "単勝",
  "2": "複勝",
  "3": "枠連",
  "5": "馬連",
  "6": "馬単",
  "7": "ワイド",
  "8": "3連複",
  "9": "3連単",
};

const Map<String, String> wheelExactaDict = {"1": "1着ながし", "2": "2着ながし"};

const Map<String, String> wheelTrioDict = {"3": "軸2頭ながし", "7": "軸1頭ながし"};

const Map<String, String> wheelTrifectaDict = {
  "1": "1・2着ながし",
  "2": "1・3着ながし",
  "3": "2・3着ながし",
  "4": "1着ながし",
  "5": "2着ながし",
  "6": "3着ながし",
};

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
          return t.length * 2; // 2頭軸流しは (相手の数) * 2通り
        case '軸2頭マルチ':
          return s.length * 6;
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

// 組み合わせ計算 C(n, k) を行うヘルパー関数
int _combinations(int n, int k) {
  if (k < 0 || k > n) {
    return 0;
  }
  if (k == 0 || k == n) {
    return 1;
  }
  if (k > n / 2) {
    k = n - k;
  }
  int res = 1;
  for (int i = 1; i <= k; ++i) {
    res = res * (n - i + 1) ~/ i;
  }
  return res;
}

Map<String, dynamic> parseHorseracingTicketQr(String s) {
  List<String> underDigits = List.filled(40, "X");
  for (int i = 0; i < 34; i++) {
    underDigits[i] = "0";
  }

  Map<String, dynamic> d = {};
  d["QR"] = s;
  _StringIterator itr = _StringIterator(s);

  print('--- parseHorseracingTicketQr Start ---');
  print('QR String: $s');

  String ticketFormat = itr.next();
  print('Parsed ticketFormat: $ticketFormat (Iterator position: ${itr.position})');

  String racecourseCode = itr.next() + itr.next();
  d["開催場"] = racecourseDict[racecourseCode];
  print(
      'Parsed racecourseCode: $racecourseCode, 開催場: ${d["開催場"]} (Iterator position: ${itr.position})');

  itr.move(2);
  print('Moved 2 positions. (Iterator position: ${itr.position})');

  String alternativeCode = itr.next();
  if (alternativeCode != "0") {
    if (alternativeCode == "2") {
      d["開催種別"] = "代替";
    } else if (alternativeCode == "7") {
      d["開催種別"] = "継続";
    } else {
      d["開催種別"] = "不明";
    }
    print(
        'Parsed alternativeCode: $alternativeCode, 開催種別: ${d["開催種別"]} (Iterator position: ${itr.position})');
  } else {
    print(
        'Parsed alternativeCode: $alternativeCode (no special type). (Iterator position: ${itr.position})');
  }

  d["年"] = int.parse(itr.next() + itr.next());
  d["回"] = int.parse(itr.next() + itr.next());
  d["日"] = int.parse(itr.next() + itr.next());
  d["レース"] = int.parse(itr.next() + itr.next());
  print(
      'Parsed 年: ${d["年"]}, 回: ${d["回"]}, 日: ${d["日"]}, レース: ${d["レース"]} (Iterator position: ${itr.position})');

  String typeCode = itr.next();
  // ★★★ 修正箇所: キーを「式別」から「方式」へ変更 ★★★
  d["方式"] = typeDict[typeCode];
  print(
      'Parsed typeCode (購入方式): $typeCode, 方式: ${d["方式"]} (Iterator position: ${itr.position})');

  itr.next(); // 常に1文字スキップ

  for (int i = 28; i < 34; i++) {
    underDigits[i] = itr.next();
  }
  for (int i = 20; i < 26; i++) {
    underDigits[i] = itr.next();
  }
  for (int i = 0; i < 13; i++) {
    underDigits[i] = itr.next();
  }
  underDigits[26] = itr.next();
  print('Populated initial underDigits. (Iterator position: ${itr.position})');

  String ticketofficeCode = underDigits.sublist(0, 4).join();
  d["発売所"] = ticketofficeDict[ticketofficeCode.substring(2)] ??
      ticketofficeDict[ticketofficeCode.substring(0, 2)] ??
      "不明";
  print('Parsed 発売所: ${d["発売所"]} (ticketofficeCode: $ticketofficeCode)');

  underDigits[13] = "1";
  underDigits[14] = typeCode;
  d["購入内容"] = [];

  switch (typeCode) {
    case "0": // 通常
    case "5": // 応援馬券
      print('--- Entering Normal/Ouen (typeCode: $typeCode) Betting Loop ---');
      String? prevCode;

      while (true) {
        print('[Loop Start] itr.position = ${itr.position}');

        String peekedChar = itr.peek(0);
        print('  [Peek] next char = "$peekedChar"');
        if (peekedChar == "0") {
          itr.next();
          print('  [End Marker] found. Breaking loop. position=${itr.position}');
          break;
        }

        String bettingCode = itr.next();
        print('  [Parsed] bettingCode = $bettingCode (position=${itr.position})');

        Map<String, dynamic> di = {};
        di["式別"] = bettingDict[bettingCode];
        print('    => 式別: ${di["式別"]}');

        int count;
        switch (bettingCode) {
          case "1":
          case "2":
            count = 1;
            break;
          case "3":
          case "5":
          case "6":
          case "7":
            count = 2;
            break;
          case "8":
          case "9":
            count = 3;
            break;
          default:
            throw ArgumentError("Unexpected bettingCode: $bettingCode");
        }
        print('    => 馬番 count = $count');

        di["馬番"] = [
          for (int i = 0; i < count; i++)
            int.parse(
              (() {
                String a = itr.next();
                String b = itr.next();
                print('      [Horse] read = ${a + b}');
                return a + b;
              })(),
            ),
        ];
        print('    => 馬番: ${di["馬番"]} (position=${itr.position})');

        int c = (int.parse(ticketFormat) + 1) ~/ 2;
        if (bettingCode == "5" && ticketFormat == "3") {
          c += 1;
        }
        if (c > count && typeCode != "5" && bettingCode != "6") {
          itr.move((c - count) * 2);
        }

        if (bettingCode == "1" || bettingCode == "2" || bettingCode == "6") {
          String ura = itr.next() + itr.next();
          if (bettingCode == "6") {
            di["ウラ"] = ura == "01" ? "あり" : "なし";
          }
        }

        String purchaseAmountStr = "";
        print(
            '    [Amount] start reading 5 digits at position=${itr.position}');
        for (int i = 0; i < 5 && itr.position < s.length; i++) {
          purchaseAmountStr += itr.next();
        }
        print('    [Amount] raw="$purchaseAmountStr"');

        di["購入金額"] = (purchaseAmountStr.length == 5)
            ? int.parse(purchaseAmountStr) * 100
            : 0;
        print('    => 購入金額: ${di["購入金額"]} (position=${itr.position})');

        if (underDigits[15] == "0" || underDigits[15] == bettingCode) {
          underDigits[15] = bettingCode;
          underDigits[18] = (int.parse(underDigits[18]) + 1).toString();
          print('    [UD] updated underDigits[15,18] for same code');
        } else {
          if (underDigits[16] == "0") {
            underDigits[17] = underDigits[18];
            underDigits[18] = "0";
            print('    [UD] reset underDigits[17,18] (first new code)');
          }
          underDigits[16] = bettingCode;
          underDigits[18] = (int.parse(underDigits[18]) + 1).toString();
          print('    [UD] updated underDigits[16,18] for new code');
        }

        (d["購入内容"] as List).add(di);
        print('    [Added] purchase entry: $di');

        prevCode = bettingCode;
      }

      print('--- Exited Normal/Ouen Betting Loop ---');
      break;

    case "1": // ボックス
      print('--- Entering BOX Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print(
          '  Parsed bettingCode (BOX): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      List<int> nos = [];
      String purchaseAmountStr = "";

      print('  Reading first 5 horse numbers (BOX)...');
      for (int i = 0; i < 5; i++) {
        nos.add(int.parse(itr.next() + itr.next()));
      }
      print(
          '  After first 5 horse numbers. Current nos: $nos (Iterator position: ${itr.position})');

      final originalPos = itr.position;
      itr.move(5);
      String sixth = itr.next();
      String seventh = itr.next();
      itr.currentPosition = originalPos;
      print('  Peeked 6th and 7th chars: "$sixth", "$seventh"');
      if (!(sixth == "9" && seventh == "0")) {
        print('  Reading next 5 horse numbers (BOX)...');
        for (int i = 0; i < 5; i++) {
          nos.add(int.parse(itr.next() + itr.next()));
        }
        print(
            '  After next 5 horse numbers. Current nos: $nos (Iterator position: ${itr.position})');
      }

      final originalPos2 = itr.position;
      itr.move(5);
      String sixth2 = itr.next();
      String seventh2 = itr.next();
      itr.currentPosition = originalPos2;
      print('  Peeked 6th2 and 7th2 chars: "$sixth2", "$seventh2"');
      if (!(sixth2 == "9" && seventh2 == "0")) {
        print('  Reading additional 8 horse numbers (BOX)...');
        for (int i = 0; i < 8; i++) {
          nos.add(int.parse(itr.next() + itr.next()));
        }
        print(
            '  After additional 8 horse numbers. Current nos: $nos (Iterator position: ${itr.position})');
      }

      print(
          '  Reading purchase amount (5 characters) for BOX from position: ${itr.position}');
      for (int i = 0; i < 5; i++) {
        purchaseAmountStr += itr.next();
      }
      di["馬番"] = nos.where((x) => x != 0).toList();
      print('  Filtered 馬番 (BOX): ${di["馬番"]}');
      print('  Raw purchaseAmountStr (BOX): "$purchaseAmountStr"');

      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      print(
          '  Parsed 購入金額 (BOX): ${di["購入金額"]} (Iterator position: ${itr.position})');

      underDigits[15] = bettingCode;
      if ((di["馬番"] as List).length < 10) {
        underDigits[17] = (di["馬番"] as List).length.toString();
      } else {
        underDigits[17] = "1";
        underDigits[18] = ((di["馬番"] as List).length % 10).toString();
      }
      print(
          '  Updated underDigits for BOX. underDigits[15]: ${underDigits[15]}, [17]: ${underDigits[17]}, [18]: ${underDigits[18]}');

      di["組合せ数"] = calculatePoints(
        ticketType: bettingDict[bettingCode]!,
        method: 'BOX',
        first: di["馬番"],
      );
      print('  Calculated 組合せ数 (BOX): ${di["組合せ数"]}');

      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (BOX): $di');

      print('--- Exited BOX Betting ---');
      break;

    case "2": // ながし
      print('--- Entering NAGASHI Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print(
          '  Parsed bettingCode (NAGASHI): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      String method = '';
      String wheelCode = itr.next();
      print('  Parsed wheelCode: $wheelCode (Iterator position: ${itr.position})');

      int? currentPurchaseAmount;

      switch (bettingCode) {
        case "6":
          di["ながし"] = wheelExactaDict[wheelCode];
          method = 'ながし';
          print('  馬単ながし: ${di["ながし"]}, method: $method');
          break;
        case "8":
          di["ながし"] = wheelTrioDict[wheelCode];
          method = di["ながし"]!;
          di['ながし種別'] = method; // ### 修正: ながし種別を追加
          print('  3連複ながし: ${di["ながし"]}, method: $method');
          break;
        case "9":
          di["ながし"] = wheelTrifectaDict[wheelCode];
          method = di["ながし"]!;
          if (di["ながし"]!.contains('・')) {
            method = '軸2頭ながし';
          } else {
            method = '軸1頭ながし';
          }
          di['ながし種別'] = method; // ### 修正: ながし種別を追加
          print('  3連単ながし: ${di["ながし"]}, method: $method');
          break;
        default:
          di["ながし"] = "ながし";
          method = 'ながし';
          print('  Other ながし: ${di["ながし"]}, method: $method');
      }
      int count = 0;
      if (bettingCode == "6" || bettingCode == "8") {
        List<int> horseNumbers = [];
        print(
            '  Parsing axis horses for bettingCode $bettingCode (2 sets of 18 bits)...');
        for (int j = 0; j < 2; j++) {
          for (int i = 1; i <= 18; i++) {
            if (itr.next() == "1") {
              horseNumbers.add(i);
            }
          }
        }
        di["軸"] = horseNumbers;
        print('  Parsed 軸: ${di["軸"]} (Iterator position: ${itr.position})');

        List<int> innerList = [];
        print(
            '  Parsing opponent horses for bettingCode $bettingCode (1 set of 18 bits)...');
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        print('  Parsed 相手: ${di["相手"]} (Iterator position: ${itr.position})');
        count = innerList.length;
        print('  Count (opponent horses): $count');
      } else if (bettingCode == "9") {
        List<List<int>> horseNumbers = [];
        print('  Parsing horses for 3連単 (3 sets of 18 bits)...');
        for (int j = 0; j < 3; j++) {
          List<int> innerList = [];
          for (int i = 1; i <= 18; i++) {
            if (itr.next() == "1") {
              innerList.add(i);
            }
          }
          horseNumbers.add(innerList);
          print('    Horse set ${j + 1}: $innerList');
        }
        di["馬番"] = horseNumbers;
        print(
            '  Parsed 馬番 (3連単): ${di["馬番"]} (Iterator position: ${itr.position})');
        // Use the count of opponents for the underDigits calculation
        if (method == '軸2頭ながし') {
          count = horseNumbers.length > 2 ? horseNumbers[2].length : 0;
        } else if (method == '軸1頭ながし') {
          count = horseNumbers.length > 1 ? horseNumbers[1].length : 0;
        }
        print('  Count (opponent horses): $count');
      } else {
        di["軸"] = int.parse(itr.next() + itr.next());
        print(
            '  Parsed 軸 (single horse): ${di["軸"]} (Iterator position: ${itr.position})');

        String purchaseAmountStr = "";
        print(
            '  Reading purchase amount (5 characters) for other NAGASHI from position: ${itr.position}');
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        currentPurchaseAmount = int.parse("${purchaseAmountStr}00");
        print(
            '  Parsed 購入金額 (other NAGASHI): $currentPurchaseAmount (Iterator position: ${itr.position})');

        List<int> innerList = [];
        print(
            '  Parsing opponent horses for other NAGASHI (1 set of 18 bits)...');
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        print(
            '  Parsed 相手 (other NAGASHI): ${di["相手"]} (Iterator position: ${itr.position})');
        count = innerList.length;
        print('  Count (opponent horses for other NAGASHI): $count');
      }

      if (bettingCode == "8" || bettingCode == "9" || bettingCode == "6") {
        String purchaseAmountStr = "";
        print(
            '  Reading purchase amount (5 characters) for 3連複/3連単/馬単 NAGASHI from position: ${itr.position}');
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        currentPurchaseAmount = int.parse("${purchaseAmountStr}00");
        print(
            '  Parsed 購入金額 (3連複/3連単/馬単 NAGASHI): $currentPurchaseAmount (Iterator position: ${itr.position})');
      }
      di["購入金額"] = currentPurchaseAmount ?? 0;

      String multiCode = itr.next();
      print('  Parsed multiCode: $multiCode (Iterator position: ${itr.position})');

      int calculatedCombinations = 0;
      String? combinationDisplayString;

      if (multiCode == "1") {
        di["マルチ"] = "あり";
        if (bettingCode == "9") {
          final horseGroups =
          (di["馬番"] as List).map((e) => (e as List).cast<int>()).toList();
          if (method == '軸1頭ながし') {
            method = '軸1頭マルチ';
            final opponents = horseGroups.length > 1 ? horseGroups[1] : [];
            final baseCombinations = _combinations(opponents.length, 2);
            calculatedCombinations = baseCombinations * 6;
            combinationDisplayString = '$baseCombinations × 6';
            print(
                '  3連単マルチ(1頭軸): $combinationDisplayString, method updated to: $method');
          } else if (method == '軸2頭ながし') {
            method = '軸2頭マルチ';
            final opponents = horseGroups.length > 2 ? horseGroups[2] : [];
            calculatedCombinations = opponents.length * 6;
            combinationDisplayString = '${opponents.length} × 6';
            print(
                '  3連単マルチ(2頭軸): $combinationDisplayString, method updated to: $method');
          }
        } else if (bettingCode == "6") {
          method = 'マルチ';
          final opponents = (di["相手"] as List?)?.cast<int>() ?? [];
          calculatedCombinations = opponents.length * 2;
          combinationDisplayString = '${opponents.length} × 2';
          print('  馬単マルチ: $combinationDisplayString, method updated to: $method');
        } else {
          di["マルチ"] = "なし";
        }
      } else {
        di["マルチ"] = "なし";
      }

      if (combinationDisplayString != null) {
        di["組合せ数_表示用"] = combinationDisplayString;
        di["組合せ数"] = calculatedCombinations;
      } else {
        // Fallback to existing calculatePoints logic for non-multi nagashi
        List<int> firstHorses = [];
        List<int> secondHorses = [];
        List<int> thirdHorses = [];
        if (bettingCode == "9") {
          if (di["馬番"].length > 0)
            firstHorses = (di["馬番"][0] as List).cast<int>();
          if (di["馬番"].length > 1)
            secondHorses = (di["馬番"][1] as List).cast<int>();
          if (di["馬番"].length > 2)
            thirdHorses = (di["馬番"][2] as List).cast<int>();

          if (method == '軸1頭ながし' || method == '軸1頭マルチ') {
            di["組合せ数"] = calculatePoints(
                ticketType: bettingDict[bettingCode]!,
                method: method,
                first: firstHorses,
                second: secondHorses.isNotEmpty ? secondHorses : thirdHorses);
          } else if (method == '軸2頭ながし' || method == '軸2頭マルチ') {
            di["組合せ数"] = calculatePoints(
                ticketType: bettingDict[bettingCode]!,
                method: method,
                first: firstHorses,
                second: secondHorses,
                third: thirdHorses);
          }
        } else if (bettingCode == "6" || bettingCode == "8") {
          di["組合せ数"] = calculatePoints(
              ticketType: bettingDict[bettingCode]!,
              method: method,
              first: (di["軸"] as List).cast<int>(),
              second: (di["相手"] as List).cast<int>());
        } else {
          di["組合せ数"] = calculatePoints(
              ticketType: bettingDict[bettingCode]!,
              method: 'ながし',
              first: [di["軸"] as int],
              second: (di["相手"] as List).cast<int>());
        }
      }
      print('  Calculated 組合せ数 (NAGASHI): ${di["組合せ数"]}');
      if (di.containsKey("組合せ数_表示用"))
        print('  組合せ数_表示用: ${di["組合せ数_表示用"]}');

      underDigits[15] = bettingCode;
      if (bettingCode == "6" || bettingCode == "8" || bettingCode == "9") {
        underDigits[16] = wheelCode;
      }
      print(
          '  Updated underDigits for NAGASHI. underDigits[15]: ${underDigits[15]}, [16]: ${underDigits[16]}');

      underDigits[17] = (count ~/ 10).toString();
      underDigits[18] = (count % 10).toString();
      print('  Updated underDigits[17] and [18] for NAGASHI. Count: $count');

      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (NAGASHI): $di');

      print('--- Exited NAGASHI Betting ---');
      break;

    case "3": // フォーメーション
      print('--- Entering FORMATION Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print(
          '  Parsed bettingCode (FORMATION): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      itr.next();

      List<List<int>> horseNumbers = [];
      print('  Parsing horse numbers for FORMATION (3 sets of 18 bits)...');
      for (int j = 0; j < 3; j++) {
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        if (innerList.isNotEmpty) {
          horseNumbers.add(innerList);
        }
        print('    Horse set ${j + 1}: $innerList');
      }
      di["馬番"] = horseNumbers;
      print(
          '  Parsed 馬番 (FORMATION): ${di["馬番"]} (Iterator position: ${itr.position})');

      String purchaseAmountStr = "";
      print(
          '  Reading purchase amount (5 characters) for FORMATION from position: ${itr.position}');
      for (int i = 0; i < 5; i++) {
        if (itr.position < s.length) {
          purchaseAmountStr += itr.next();
        } else {
          print(
              '  WARNING: Ran out of string while parsing purchase amount for FORMATION.');
          break;
        }
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      print(
          '  Parsed 購入金額 (FORMATION): ${di["購入金額"]} (Iterator position: ${itr.position})');

      itr.next();

      underDigits[13] = "2";
      underDigits[14] = bettingCode;
      for (int i = 0; i < di["馬番"].length; i++) {
        String st = (di["馬番"][i] as List).length.toString();
        underDigits[16 + i] = st[st.length - 1];
        if (st.length == 2) {
          underDigits[15] = (int.parse(underDigits[15]) + (1 << i)).toString();
        }
      }
      print(
          '  Updated underDigits for FORMATION. underDigits[13]: ${underDigits[13]}, [14]: ${underDigits[14]} etc.');

      List<int> firstFormation = [];
      List<int> secondFormation = [];
      List<int> thirdFormation = [];

      if (di["馬番"].length > 0)
        firstFormation = (di["馬番"][0] as List).cast<int>();
      if (di["馬番"].length > 1)
        secondFormation = (di["馬番"][1] as List).cast<int>();
      if (di["馬番"].length > 2)
        thirdFormation = (di["馬番"][2] as List).cast<int>();

      di["組合せ数"] = calculatePoints(
        ticketType: bettingDict[bettingCode]!,
        method: 'フォーメーション',
        first: firstFormation,
        second: secondFormation,
        third: thirdFormation,
      );
      print('  Calculated 組合せ数 (FORMATION): ${di["組合せ数"]}');

      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (FORMATION): $di');
      print('--- Exited FORMATION Betting ---');
      break;

    case "4": // クイックピック
      print('--- Entering QUICK PICK Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print(
          '  Parsed bettingCode (QUICK PICK): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      int no = int.parse(itr.next() + itr.next());
      if (no != 0) {
        d["軸"] = no;
        print('  Parsed 軸 (QUICK PICK): ${d["軸"]} (Iterator position: ${itr.position})');
      } else {
        print('  No 軸 for QUICK PICK. (Iterator position: ${itr.position})');
      }

      int positionSpecify = int.parse(itr.next());
      if (bettingCode == "6" || bettingCode == "9") {
        d["着順指定"] = positionSpecify != 0 ? "$positionSpecify着指定" : "なし";
        print(
            '  Parsed 着順指定 (QUICK PICK): ${d["着順指定"]} (Iterator position: ${itr.position})');
      } else {
        print(
            '  No 着順指定 for bettingCode $bettingCode. (Iterator position: ${itr.position})');
      }

      d["組合せ数"] = int.parse(itr.next() + itr.next());
      print(
          '  Parsed 組合せ数 (QUICK PICK): ${d["組合せ数"]} (Iterator position: ${itr.position})');

      String purchaseAmountStr = "";
      print(
          '  Reading purchase amount (5 characters) for QUICK PICK from position: ${itr.position}');
      for (int i = 0; i < 5; i++) {
        if (itr.position < s.length) {
          purchaseAmountStr += itr.next();
        } else {
          print(
              '  WARNING: Ran out of string while parsing purchase amount for QUICK PICK.');
          break;
        }
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      print(
          '  Parsed 購入金額 (QUICK PICK): ${di["購入金額"]} (Iterator position: ${itr.position})');

      itr.move(2);
      print(
          '  Moved 2 positions after amount (QUICK PICK). (Iterator position: ${itr.position})');

      List<List<int>> horseNumbersList = [];
      print(
          '  Parsing horse numbers list for QUICK PICK (${d["組合せ数"]} combinations)...');
      for (int i = 0; i < d["組合せ数"]; i++) {
        List<int> innerList = [];
        for (int j = 0; j < 3; j++) {
          int horseNum = int.parse(itr.next() + itr.next());
          if (horseNum != 0) {
            innerList.add(horseNum);
          }
        }
        horseNumbersList.add(innerList);
        print('    Combination ${i + 1}: $innerList');
      }
      di["馬番"] = horseNumbersList;
      print(
          '  Parsed 馬番 (QUICK PICK, list of combinations): ${di["馬番"]} (Iterator position: ${itr.position})');

      underDigits[15] = bettingCode;
      underDigits[17] = (d["組合せ数"] ~/ 10).toString();
      underDigits[18] = (d["組合せ数"] % 10).toString();
      print(
          '  Updated underDigits for QUICK PICK. underDigits[15]: ${underDigits[15]}, [17]: ${underDigits[17]}, [18]: ${underDigits[18]}');

      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (QUICK PICK): $di');
      print('--- Exited QUICK PICK Betting ---');
      break;

    default:
      print('ERROR: Unknown type code: $typeCode');
      throw ArgumentError("Unknown type code: $typeCode");
  }

  // ★★★ ここから合計金額を計算するロジック ★★★
  int totalAmount = 0;
  if (d.containsKey('購入内容') && d['購入内容'] is List) {
    for (var detail in (d['購入内容'] as List)) {
      if (detail is Map<String, dynamic>) {
        final amount = detail['購入金額'] as int? ?? 0;
        // 通常馬券など、組合せ数がない場合は1として計算
        final combinations = detail['組合せ数'] as int? ?? 1;
        totalAmount += amount * combinations;
      }
    }
  }
  d['合計金額'] = totalAmount;
  // ★★★ ここまで ★★★

  d["下端番号"] = joinWithSpaces(underDigits);

  // ★★★ ログ出力用のprint文を追加 ★★★
  print('--- [DB保存直前データ] パーサーが出力する最終データ ---');
  print(d);
  // ★★★ ここまで追加 ★★★

  print('--- parseHorseracingTicketQr End ---');
  return d;
}

String joinWithSpaces(List<String> underDigits) {
  final buffer = StringBuffer();

  for (int i = 0; i < underDigits.length; i++) {
    buffer.write(underDigits[i]);
    if (i == 12 || i == 25 || i == 33) {
      buffer.write(" ");
    }
  }

  return buffer.toString();
}

class _StringIterator {
  final String _s;
  int _currentPosition = 0;

  _StringIterator(this._s);

  String next() {
    if (_currentPosition >= _s.length) {
      throw StateError("No more elements in the string.");
    }
    return _s[_currentPosition++];
  }

  void move(int offset) {
    _currentPosition += offset;
    if (_currentPosition < 0 || _currentPosition > _s.length) {
      throw RangeError(
          "Invalid position after move. Current position: ${_currentPosition - offset}, offset: $offset, String length: ${_s.length}");
    }
  }

  int get position => _currentPosition;

  set currentPosition(int pos) {
    _currentPosition = pos;
  }

  String peek(int offset) {
    int pos = _currentPosition + offset;
    if (pos >= _s.length || pos < 0) {
      throw RangeError(
          "Peek out of range. Current position: $_currentPosition, offset: $offset, Target position: $pos, String length: ${_s.length}");
    }
    return _s[pos];
  }
}
