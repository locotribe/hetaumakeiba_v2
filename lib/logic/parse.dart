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
  "8": "3連複", // 「三連複」から「3連複」に統一
  "9": "3連単", // 「三連単」から「3連単」に統一
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

/// 競馬の賭式ごとの組み合わせ数計算ロジックと、各方式の解説をまとめた関数です。
///
/// 以下のDart言語で書かれた`calculatePoints`関数は、指定された賭式（`ticketType`）と方式（`method`）、
/// および選択された馬番のリスト（`first`, `second`, `third`）に基づいて、組み合わせの点数を計算します。
int calculatePoints({
  required String ticketType,
  required String method,
  required List<int> first,
  List<int>? second,
  List<int>? third,
}) {
  // 引数の文字列をトリムして正規化
  // trim() は文字列の先頭と末尾の空白文字（スペース、タブ、改行など）を除去します。
  final normalizedTicketType = ticketType.trim();
  final normalizedMethod = method.trim();

  final f = first;
  final s = second ?? [];
  final t = third ?? [];

  // デバッグ出力 (必要に応じてコメントアウトを解除)
  // print('DEBUG_CALCULATE_POINTS_INTERNAL: Function entry.');
  // print('  normalizedTicketType (value): "$normalizedTicketType"');
  // print('  normalizedMethod (value): "$normalizedMethod"');
  // print('  f (first) value: $f');
  // print('  s (second) value: $s');
  // print('  t (third) value: $t');

  switch (normalizedTicketType) { // normalizedTicketType を使用
    case '3連単': // 「三連単」から「3連単」に統一
    // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 block.');
    // print('DEBUG_CALCULATE_POINTS_INTERNAL: Method string for inner comparison: "$normalizedMethod"');
      switch (normalizedMethod) { // normalizedMethod を使用
        case 'フォーメーション':
          int count = 0;
          // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 フォーメーション case.');
          // print('DEBUG_CALCULATE_POINTS_INTERNAL: Starting 3連単 フォーメーション loop.');
          for (var i in f) {
            for (var j in s) {
              for (var k in t) {
                // print('DEBUG_CALCULATE_POINTS_INTERNAL: Checking combination: i=$i, j=$j, k=$k');
                if (i != j && i != k && j != k) {
                  count++;
                  // print('DEBUG_CALCULATE_POINTS_INTERNAL:   -> Valid combination. Current count: $count');
                } else {
                  // print('DEBUG_CALCULATE_POINTS_INTERNAL:   -> Invalid combination (duplicates found).');
                }
              }
            }
          }
          // print('DEBUG_CALCULATE_POINTS_INTERNAL: Final count for 3連単 フォーメーション: $count');
          return count;
        case 'BOX':
        // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 BOX case.');
          if (f.length < 3) return 0;
          return f.length * (f.length - 1) * (f.length - 2);
        case '軸1頭ながし':
        // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 軸1頭ながし case.');
          return s.length * (s.length - 1);
        case '軸1頭マルチ':
        // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 軸1頭マルチ case.');
          return s.length * (s.length - 1) * 3;
        case '軸2頭ながし':
        // f = 軸馬（2頭）, s = 相手馬（3着候補）
        // 通常流しでは相手馬の頭数がそのまま点数になる
          return s.length;
      // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 軸2頭ながし case.');
        case '軸2頭マルチ':
        // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 軸2頭マルチ case.');
          return s.length * 6;
        default:
        // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連単 DEFAULT case. Method was: "$normalizedMethod"');
          return 0;
      }

    case '3連複': // 「三連複」から「3連複」に統一
    // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 3連複 block.');
      switch (normalizedMethod) { // normalizedMethod を使用
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
    // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 馬単 block.');
      switch (normalizedMethod) { // normalizedMethod を使用
        case 'フォーメーション':
          return f.length * s.length;
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
    // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered 馬連/ワイド/枠連 block.');
      switch (normalizedMethod) { // normalizedMethod を使用
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
    // print('DEBUG_CALCULATE_POINTS_INTERNAL: Entered top-level DEFAULT case. TicketType was: "$normalizedTicketType"');
      return 0;
  }
}

Map<String, dynamic> parseHorseracingTicketQr(String s) {
  List<String> underDigits = List.filled(40, "X");
  for (int i = 0; i < 34; i++) {
    underDigits[i] = "0";
  }

  Map<String, dynamic> d = {};
  d["QR"] = s;
  _StringIterator itr = _StringIterator(s);

  print('--- parseHorseracingTicketQr Start ---'); // 開始
  print('QR String: $s'); // QR文字列全体をログ

  String ticketFormat = itr.next();
  print('Parsed ticketFormat: $ticketFormat (Iterator position: ${itr.position})');

  String racecourseCode = itr.next() + itr.next();
  d["開催場"] = racecourseDict[racecourseCode];
  print('Parsed racecourseCode: $racecourseCode, 開催場: ${d["開催場"]} (Iterator position: ${itr.position})');

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
    print('Parsed alternativeCode: $alternativeCode, 開催種別: ${d["開催種別"]} (Iterator position: ${itr.position})');
  } else {
    print('Parsed alternativeCode: $alternativeCode (no special type). (Iterator position: ${itr.position})');
  }

  d["年"] = int.parse(itr.next() + itr.next());
  d["回"] = int.parse(itr.next() + itr.next());
  d["日"] = int.parse(itr.next() + itr.next());
  d["レース"] = int.parse(itr.next() + itr.next());
  print('Parsed 年: ${d["年"]}, 回: ${d["回"]}, 日: ${d["日"]}, レース: ${d["レース"]} (Iterator position: ${itr.position})');

  String suffix = [
    d["年"],
    racecourseCode,
    d["回"],
    d["日"],
    d["レース"],
  ].map((n) => n.toString().padLeft(2, '0')).join();
  d["URL"] = "https://db.netkeiba.com/race/20$suffix";
  String typeCode = itr.next();
  d["式別"] = typeDict[typeCode];
  print('Parsed typeCode (購入方式): $typeCode, 式別: ${d["式別"]} (Iterator position: ${itr.position})');


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
  d["発売所"] =
      ticketofficeDict[ticketofficeCode.substring(2)] ??
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
        // ループ開始ログ
        print('[Loop Start] itr.position = ${itr.position}');

        // 終了マーカーチェック
        String peekedChar = itr.peek(0);
        print('  [Peek] next char = "$peekedChar"');
        if (peekedChar == "0") {
          itr.next();
          print('  [End Marker] found. Breaking loop. position=${itr.position}');
          break;
        }

        // 1) 式別コード取得
        String bettingCode = itr.next();
        print('  [Parsed] bettingCode = $bettingCode (position=${itr.position})');

        Map<String, dynamic> di = {};
        di["式別"] = bettingDict[bettingCode];
        print('    => 式別: ${di["式別"]}');

        // 2) 馬番の数と値を取得
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
              // 2桁ずつ読み取り
              (() {
                String a = itr.next();
                String b = itr.next();
                print('      [Horse] read = ${a + b}');
                return a + b;
              })(),
            ),
        ];
        print('    => 馬番: ${di["馬番"]} (position=${itr.position})');

        // 3) 式別ごとのマーカー／ウラフラグ消費
        switch (bettingCode) {
          case "6":
          // 馬単：00 or 01 がウラフラグ
            String ura = itr.next() + itr.next();
            di["ウラ"] = (ura == "01") ? "あり" : "なし";
            print('    [Marker] 馬単ウラ = $ura → ${di["ウラ"]} (position=${itr.position})');
            break;

          case "1":
          case "2":
          case "5":
          case "7":
          // 単勝・複勝・馬連・ワイド：必ず00マーカーを捨てる
            String m1 = itr.next(), m2 = itr.next();
            print('    [Marker] consumed for code $bettingCode: $m1$m2 (position=${itr.position})');
            break;

        // 3連系(8,9)はマーカー無し → 何もしない
        }

        // 4) 購入金額 (5桁) を正確に読み取る
        String purchaseAmountStr = "";
        print('    [Amount] start reading 5 digits at position=${itr.position}');
        for (int i = 0; i < 5 && itr.position < s.length; i++) {
          purchaseAmountStr += itr.next();
        }
        print('    [Amount] raw="$purchaseAmountStr"');

        di["購入金額"] =
        (purchaseAmountStr.length == 5) ? int.parse(purchaseAmountStr) * 100 : 0;
        print('    => 購入金額: ${di["購入金額"]} (position=${itr.position})');

        // 5) 下端番号カウンタ更新（既存ロジック踏襲）
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

        // 6) 購入内容リストに追加
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
      print('  Parsed bettingCode (BOX): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      List<int> nos = [];
      String purchaseAmountStr = "";

      // 最初の5つの馬番を読み込み
      print('  Reading first 5 horse numbers (BOX)...');
      for (int i = 0; i < 5; i++) {
        nos.add(int.parse(itr.next() + itr.next()));
      }
      print('  After first 5 horse numbers. Current nos: $nos (Iterator position: ${itr.position})');

      final originalPos = itr.position;
      itr.move(5);
      String sixth = itr.next();
      String seventh = itr.next();
      itr.currentPosition = originalPos;
      print('  Peeked 6th and 7th chars: "$sixth", "$seventh"');
      if (!(sixth == "9" && seventh == "0")) { // 続きの馬番がある場合
        print('  Reading next 5 horse numbers (BOX)...');
        for (int i = 0; i < 5; i++) {
          nos.add(int.parse(itr.next() + itr.next()));
        }
        print('  After next 5 horse numbers. Current nos: $nos (Iterator position: ${itr.position})');
      }

      final originalPos2 = itr.position;
      itr.move(5);
      String sixth2 = itr.next();
      String seventh2 = itr.next();
      itr.currentPosition = originalPos2;
      print('  Peeked 6th2 and 7th2 chars: "$sixth2", "$seventh2"');
      if (!(sixth2 == "9" && seventh2 == "0")) { // さらに続きの馬番がある場合 (最大18頭なので、ここはもう少し細かく条件がいるかも)
        print('  Reading additional 8 horse numbers (BOX)...');
        for (int i = 0; i < 8; i++) { // Max 18 horses, 5 + 5 + 8 = 18
          nos.add(int.parse(itr.next() + itr.next()));
        }
        print('  After additional 8 horse numbers. Current nos: $nos (Iterator position: ${itr.position})');
      }

      print('  Reading purchase amount (5 characters) for BOX from position: ${itr.position}');
      for (int i = 0; i < 5; i++) {
        purchaseAmountStr += itr.next();
      }
      di["馬番"] = nos.where((x) => x != 0).toList();
      print('  Filtered 馬番 (BOX): ${di["馬番"]}');
      print('  Raw purchaseAmountStr (BOX): "$purchaseAmountStr"');

      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      print('  Parsed 購入金額 (BOX): ${di["購入金額"]} (Iterator position: ${itr.position})');


      underDigits[15] = bettingCode;
      if ((di["馬番"] as List).length < 10) {
        underDigits[17] = (di["馬番"] as List).length.toString();
      } else {
        underDigits[17] = "1";
        underDigits[18] = ((di["馬番"] as List).length % 10).toString();
      }
      print('  Updated underDigits for BOX. underDigits[15]: ${underDigits[15]}, [17]: ${underDigits[17]}, [18]: ${underDigits[18]}');
      (d["購入内容"] as List).add(di);

      // calculatePoints関数の呼び出し
      di["組合せ数"] = calculatePoints(
        ticketType: bettingDict[bettingCode]!,
        method: 'BOX',
        first: di["馬番"],
      );
      print('  Calculated 組合せ数 (BOX): ${di["組合せ数"]}');
      print('--- Exited BOX Betting ---');
      break;

    case "2": // ながし
      print('--- Entering NAGASHI Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print('  Parsed bettingCode (NAGASHI): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      String method = ''; // calculatePointsに渡すためのmethod変数
      String wheelCode = itr.next();
      print('  Parsed wheelCode: $wheelCode (Iterator position: ${itr.position})');

      switch (bettingCode) {
        case "6": // 馬単
          di["ながし"] = wheelExactaDict[wheelCode];
          method = 'ながし'; // 馬単のながし
          if (di["ながし"] == "1着ながし" || di["ながし"] == "2着ながし") {
            method = 'ながし';
          }
          print('  馬単ながし: ${di["ながし"]}, method: $method');
          break;
        case "8": // 3連複
          di["ながし"] = wheelTrioDict[wheelCode];
          method = di["ながし"]!; // 3連複の軸1頭ながし、軸2頭ながし
          print('  3連複ながし: ${di["ながし"]}, method: $method');
          break;
        case "9": // 3連単
          di["ながし"] = wheelTrifectaDict[wheelCode];
          method = di["ながし"]!; // 3連単のながし
          if (di["ながし"] == "1着ながし" ||
              di["ながし"] == "2着ながし" ||
              di["ながし"] == "3着ながし") {
            method = '軸1頭ながし';
          } else {
            method = '軸2頭ながし';
          }
          print('  3連単ながし: ${di["ながし"]}, method: $method');
          break;
        default:
          di["ながし"] = "ながし";
          method = 'ながし'; // その他のながし
          print('  Other ながし: ${di["ながし"]}, method: $method');
      }
      int count = 0;
      if (bettingCode == "6" || bettingCode == "8") { // 馬単、3連複
        List<int> horseNumbers = [];
        print('  Parsing axis horses for bettingCode $bettingCode (2 sets of 18 bits)...');
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
        print('  Parsing opponent horses for bettingCode $bettingCode (1 set of 18 bits)...');
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        print('  Parsed 相手: ${di["相手"]} (Iterator position: ${itr.position})');
        count = innerList.length;
        print('  Count (opponent horses): $count');

      } else if (bettingCode == "9") { // 3連単
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
          print('    Horse set ${j+1}: $innerList');
        }
        di["馬番"] = horseNumbers;
        print('  Parsed 馬番 (3連単): ${di["馬番"]} (Iterator position: ${itr.position})');
        for (var list in (horseNumbers)) {
          if (list.length > count) {
            count = list.length; // Max length of any list
          }
        }
        print('  Count (max horse numbers in any set): $count');

      } else { // 馬連・ワイド・枠連のながし (単軸)
        di["軸"] = int.parse(itr.next() + itr.next());
        print('  Parsed 軸 (single horse): ${di["軸"]} (Iterator position: ${itr.position})');

        String purchaseAmountStr = "";
        print('  Reading purchase amount (5 characters) for other NAGASHI from position: ${itr.position}');
        for (int i = 0; i < 5; i++) {
          if (itr.position < s.length) {
            purchaseAmountStr += itr.next();
          } else {
            print('  WARNING: Ran out of string while parsing purchase amount for other NAGASHI.');
            break;
          }
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");
        print('  Parsed 購入金額 (other NAGASHI): ${di["購入金額"]} (Iterator position: ${itr.position})');

        List<int> innerList = [];
        print('  Parsing opponent horses for other NAGASHI (1 set of 18 bits)...');
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        print('  Parsed 相手 (other NAGASHI): ${di["相手"]} (Iterator position: ${itr.position})');
        count = innerList.length;
        print('  Count (opponent horses for other NAGASHI): $count');
      }

      // 3連複・3連単はここで金額を読み込む
      if (bettingCode == "8" || bettingCode == "9") {
        String purchaseAmountStr = "";
        print('  Reading purchase amount (5 characters) for 3連複/3連単 NAGASHI from position: ${itr.position}');
        for (int i = 0; i < 5; i++) {
          if (itr.position < s.length) {
            purchaseAmountStr += itr.next();
          } else {
            print('  WARNING: Ran out of string while parsing purchase amount for 3連複/3連単 NAGASHI.');
            break;
          }
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");
        print('  Parsed 購入金額 (3連複/3連単 NAGASHI): ${di["購入金額"]} (Iterator position: ${itr.position})');
      }

      String multiCode = itr.next();
      print('  Parsed multiCode: $multiCode (Iterator position: ${itr.position})');
      if (bettingCode == "9") {
        d["マルチ"] = multiCode == "1" ? "あり" : "なし";
        if (multiCode == "1") {
          // 3連単マルチの場合、methodを更新
          if (method == '軸1頭ながし') {
            method = '軸1頭マルチ';
          } else if (method == '軸2頭ながし') {
            method = '軸2頭マルチ';
          }
        }
        print('  3連単マルチ: ${d["マルチ"]}, method updated to: $method');
      } else if (bettingCode == "6") { // 馬単のマルチ
        d["マルチ"] = multiCode == "1" ? "あり" : "なし";
        if (multiCode == "1") {
          method = 'マルチ';
        }
        print('  馬単マルチ: ${d["マルチ"]}, method updated to: $method');
      }


      underDigits[15] = bettingCode;
      if (bettingCode == "6" || bettingCode == "8" || bettingCode == "9") {
        underDigits[16] = wheelCode;
      }
      print('  Updated underDigits for NAGASHI. underDigits[15]: ${underDigits[15]}, [16]: ${underDigits[16]}');

      underDigits[17] = (count ~/ 10).toString();
      underDigits[18] = (count % 10).toString();
      print('  Updated underDigits[17] and [18] for NAGASHI. Count: $count');
      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (NAGASHI): $di');


      // calculatePoints関数の呼び出し
      if (bettingCode == "6" || bettingCode == "8") {
        di["組合せ数"] = calculatePoints(
          ticketType: bettingDict[bettingCode]!,
          method: method,
          first: di["軸"],
          second: di["相手"],
        );
      } else if (bettingCode == "9") {
        List<int> firstHorses = [];
        List<int> secondHorses = [];
        List<int> thirdHorses = [];

        if (di["馬番"].length > 0) firstHorses = di["馬番"][0];
        if (di["馬番"].length > 1) secondHorses = di["馬番"][1];
        if (di["馬番"].length > 2) thirdHorses = di["馬番"][2];

        if (method == '軸1頭ながし' || method == '軸1頭マルチ') { // 軸1頭の場合は軸馬と相手馬
          di["組合せ数"] = calculatePoints(
            ticketType: bettingDict[bettingCode]!,
            method: method,
            first: firstHorses,
            second: secondHorses.isNotEmpty ? secondHorses : thirdHorses, // 相手馬のリストを渡す
          );
        } else if (method == '軸2頭ながし' || method == '軸2頭マルチ') { // 軸2頭の場合は軸馬2つと相手馬1つ
          di["組合せ数"] = calculatePoints(
            ticketType: bettingDict[bettingCode]!,
            method: method,
            first: firstHorses, // 軸1
            second: secondHorses, // 軸2
            third: thirdHorses, // 相手
          );
        } else { // その他のケース（本来ここには来ないはずだが念のため）
          di["組合せ数"] = 0;
        }

      } else { // 馬連・ワイド・枠連のながし
        di["組合せ数"] = calculatePoints(
          ticketType: bettingDict[bettingCode]!,
          method: 'ながし',
          first: [di["軸"]],
          second: di["相手"],
        );
      }
      print('  Calculated 組合せ数 (NAGASHI): ${di["組合せ数"]}');
      print('--- Exited NAGASHI Betting ---');
      break;

    case "3": // フォーメーション
      print('--- Entering FORMATION Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print('  Parsed bettingCode (FORMATION): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

      itr.next(); // 常に1文字スキップ

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
        print('    Horse set ${j+1}: $innerList');
      }
      di["馬番"] = horseNumbers;
      print('  Parsed 馬番 (FORMATION): ${di["馬番"]} (Iterator position: ${itr.position})');

      String purchaseAmountStr = "";
      print('  Reading purchase amount (5 characters) for FORMATION from position: ${itr.position}');
      for (int i = 0; i < 5; i++) {
        if (itr.position < s.length) {
          purchaseAmountStr += itr.next();
        } else {
          print('  WARNING: Ran out of string while parsing purchase amount for FORMATION.');
          break;
        }
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      print('  Parsed 購入金額 (FORMATION): ${di["購入金額"]} (Iterator position: ${itr.position})');

      itr.next(); // 常に1文字スキップ

      underDigits[13] = "2";
      underDigits[14] = bettingCode;
      for (int i = 0; i < di["馬番"].length; i++) {
        String st = (di["馬番"][i] as List).length.toString();
        underDigits[16 + i] = st[st.length - 1];
        if (st.length == 2) {
          underDigits[15] = (int.parse(underDigits[15]) + (1 << i)).toString();
        }
      }
      print('  Updated underDigits for FORMATION. underDigits[13]: ${underDigits[13]}, [14]: ${underDigits[14]} etc.');
      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (FORMATION): $di');


      // calculatePoints関数の呼び出し
      List<int> firstFormation = [];
      List<int> secondFormation = [];
      List<int> thirdFormation = [];

      if (di["馬番"].length > 0) firstFormation = di["馬番"][0];
      if (di["馬番"].length > 1) secondFormation = di["馬番"][1];
      if (di["馬番"].length > 2) thirdFormation = di["馬番"][2];

      di["組合せ数"] = calculatePoints(
        ticketType: bettingDict[bettingCode]!,
        method: 'フォーメーション',
        first: firstFormation,
        second: secondFormation,
        third: thirdFormation,
      );
      print('  Calculated 組合せ数 (FORMATION): ${di["組合せ数"]}');
      print('--- Exited FORMATION Betting ---');
      break;

    case "4": // クイックピック
      print('--- Entering QUICK PICK Betting ---');
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];
      print('  Parsed bettingCode (QUICK PICK): $bettingCode, 式別: ${di["式別"]} (Iterator position: ${itr.position})');

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
        print('  Parsed 着順指定 (QUICK PICK): ${d["着順指定"]} (Iterator position: ${itr.position})');
      } else {
        print('  No 着順指定 for bettingCode $bettingCode. (Iterator position: ${itr.position})');
      }


      d["組合せ数"] = int.parse(itr.next() + itr.next());
      print('  Parsed 組合せ数 (QUICK PICK): ${d["組合せ数"]} (Iterator position: ${itr.position})');

      String purchaseAmountStr = "";
      print('  Reading purchase amount (5 characters) for QUICK PICK from position: ${itr.position}');
      for (int i = 0; i < 5; i++) {
        if (itr.position < s.length) {
          purchaseAmountStr += itr.next();
        } else {
          print('  WARNING: Ran out of string while parsing purchase amount for QUICK PICK.');
          break;
        }
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");
      print('  Parsed 購入金額 (QUICK PICK): ${di["購入金額"]} (Iterator position: ${itr.position})');

      itr.move(2);
      print('  Moved 2 positions after amount (QUICK PICK). (Iterator position: ${itr.position})');

      List<List<int>> horseNumbersList = [];
      print('  Parsing horse numbers list for QUICK PICK (${d["組合せ数"]} combinations)...');
      for (int i = 0; i < d["組合せ数"]; i++) {
        List<int> innerList = [];
        for (int j = 0; j < 3; j++) {
          int horseNum = int.parse(itr.next() + itr.next());
          if (horseNum != 0) {
            innerList.add(horseNum);
          }
        }
        horseNumbersList.add(innerList);
        print('    Combination ${i+1}: $innerList');
      }
      di["馬番"] = horseNumbersList;
      print('  Parsed 馬番 (QUICK PICK, list of combinations): ${di["馬番"]} (Iterator position: ${itr.position})');


      underDigits[15] = bettingCode;
      underDigits[17] = (d["組合せ数"] ~/ 10).toString();
      underDigits[18] = (d["組合せ数"] % 10).toString();
      print('  Updated underDigits for QUICK PICK. underDigits[15]: ${underDigits[15]}, [17]: ${underDigits[17]}, [18]: ${underDigits[18]}');
      (d["購入内容"] as List).add(di);
      print('  Added item to 購入内容 (QUICK PICK): $di');
      print('--- Exited QUICK PICK Betting ---');
      break;

    default:
      print('ERROR: Unknown type code: $typeCode');
      throw ArgumentError("Unknown type code: $typeCode");
  }

  d["下端番号"] = joinWithSpaces(underDigits);
  print('Final 下端番号: ${d["下端番号"]}');
  print('--- parseHorseracingTicketQr End ---'); // 終了
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
      throw RangeError("Invalid position after move. Current position: ${_currentPosition - offset}, offset: $offset, String length: ${_s.length}");
    }
  }

  int get position => _currentPosition;

  set currentPosition(int pos) {
    _currentPosition = pos;
  }

  /// Peek ahead without advancing the iterator.
  String peek(int offset) {
    int pos = _currentPosition + offset;
    if (pos >= _s.length || pos < 0) {
      // 範囲外の場合は空文字列を返すか、エラーを投げるか選択
      // 今回はデバッグ目的なので、分かりやすくエラーを投げる
      throw RangeError("Peek out of range. Current position: $_currentPosition, offset: $offset, Target position: $pos, String length: ${_s.length}");
    }
    return _s[pos];
  }
}