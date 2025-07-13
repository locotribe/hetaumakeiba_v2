// lib/logic/parse.dart

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

  "06": "JRA中山", "07": "JRA中京", "08": "JRA京都", "09": "JRA阪神", "10": "JRA小倉",

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

    if (alternativeCode == "2") {

      d["開催種別"] = "代替";

    } else if (alternativeCode == "7") {

      d["開催種別"] = "継続";

    } else {

      d["開催種別"] = "不明";

    }

  }



// 年をyyyy形式に変換

  int yyYear = int.parse(itr.next() + itr.next());

  int currentYear = DateTime.now().year;

  int century = (currentYear ~/ 100) * 100; // 現在の世紀の始まり (例: 2000)

  int yyyyYear = century + yyYear;

// もしyyYearが現在の年よりもかなり大きい場合（例: 2090年のQRコードを2025年に読み込むなど）、

// 100年前と仮定することも考えられるが、ここではシンプルに現在の世紀に属すると仮定

  if (yyyyYear > currentYear + 10) { // 例: 現在が2025年でyyyyYearが2090の場合

    yyyyYear -= 100;

  }

  d["年"] = yyyyYear;





  d["回"] = int.parse(itr.next() + itr.next());

  d["日"] = int.parse(itr.next() + itr.next());

  d["レース"] = int.parse(itr.next() + itr.next());

  String suffix = [

    (d["年"] as int).toString(), // yyyy形式の年を使用

    racecourseCode,

    (d["回"] as int).toString().padLeft(2, '0'),

    (d["日"] as int).toString().padLeft(2, '0'),

    (d["レース"] as int).toString().padLeft(2, '0'),

  ].join();

  d["URL"] = "https://db.netkeiba.com/race/$suffix"; // URLもyyyy形式に修正

  String typeCode = itr.next();

  d["方式"] = typeDict[typeCode];



  itr.next();



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



  String ticketofficeCode = underDigits.sublist(0, 4).join();

  d["発売所"] =

      ticketofficeDict[ticketofficeCode.substring(2)] ??

          ticketofficeDict[ticketofficeCode.substring(0, 2)] ??

          "不明";



  underDigits[13] = "1";

  underDigits[14] = typeCode;

  d["購入内容"] = [];



  switch (typeCode) {

    case "0": // 通常

    case "5": // 応援馬券

      while (true) {

        String bettingCode = itr.next();

        if (bettingCode == "0") break;



        Map<String, dynamic> di = {};

        di["式別"] = bettingDict[bettingCode];



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

            throw ArgumentError("Unexpected betting_code: $bettingCode");

        }

        int c = (int.parse(ticketFormat) + 1) ~/ 2;

        if (bettingCode == "5" && ticketFormat == "3") {

          c += 1;

        }

        di["馬番"] = [

          for (int i = 0; i < count; i++) int.parse(itr.next() + itr.next()),

        ];

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

        for (int i = 0; i < 5; i++) {

          purchaseAmountStr += itr.next();

        }

        di["購入金額"] = int.parse("${purchaseAmountStr}00");



        if (underDigits[15] == "0" || underDigits[15] == bettingCode) {

          underDigits[15] = bettingCode;

          underDigits[18] = (int.parse(underDigits[18]) + 1).toString();

        } else {

          if (underDigits[16] == "0") {

            underDigits[17] = underDigits[18];

            underDigits[18] = "0";

          }

          underDigits[16] = bettingCode;

          underDigits[18] = (int.parse(underDigits[18]) + 1).toString();

        }

        (d["購入内容"] as List).add(di);

      }

      break;



    case "1": // ボックス

      Map<String, dynamic> di = {};

      String bettingCode = itr.next();

      di["式別"] = bettingDict[bettingCode];



      List<int> nos = [];

      String purchaseAmountStr = "";

      for (int i = 0; i < 5; i++) {

        nos.add(int.parse(itr.next() + itr.next()));

      }

      final originalPos = itr.position;

      itr.move(5);

      String sixth = itr.next();

      String seventh = itr.next();

      itr.currentPosition = originalPos;

      if (!(sixth == "9" && seventh == "0")) {

        for (int i = 0; i < 5; i++) {

          nos.add(int.parse(itr.next() + itr.next()));

        }

      }

      final originalPos2 = itr.position;

      itr.move(5);

      String sixth2 = itr.next();

      String seventh2 = itr.next();

      itr.currentPosition = originalPos2;

      if (!(sixth2 == "9" && seventh2 == "0")) {

        for (int i = 0; i < 8; i++) {

          nos.add(int.parse(itr.next() + itr.next()));

        }

      }

      for (int i = 0; i < 5; i++) {

        purchaseAmountStr += itr.next();

      }

      di["馬番"] = nos.where((x) => x != 0).toList();



      di["購入金額"] = int.parse("${purchaseAmountStr}00");



      underDigits[15] = bettingCode;

      if ((di["馬番"] as List).length < 10) {

        underDigits[17] = (di["馬番"] as List).length.toString();

      } else {

        underDigits[17] = "1";

        underDigits[18] = ((di["馬番"] as List).length % 10).toString();

      }

      (d["購入内容"] as List).add(di);

      break;



    case "2": // ながし

      Map<String, dynamic> di = {};

      String bettingCode = itr.next();

      di["式別"] = bettingDict[bettingCode];



      String wheelCode = itr.next();

      switch (bettingCode) {

        case "6":

          di["ながし"] = wheelExactaDict[wheelCode];

          break;

        case "8":

          di["ながし"] = wheelTrioDict[wheelCode];

          break;

        case "9":

          di["ながし"] = wheelTrifectaDict[wheelCode];

          break;

        default:

          di["ながし"] = "ながし";

      }

      int count = 0;

      if (bettingCode == "6" || bettingCode == "8") {

        List<int> horseNumbers = [];

        for (int j = 0; j < 2; j++) {

          for (int i = 1; i <= 18; i++) {

            if (itr.next() == "1") {

              horseNumbers.add(i);

            }

          }

        }

        di["軸"] = horseNumbers;

        List<int> innerList = [];

        for (int i = 1; i <= 18; i++) {

          if (itr.next() == "1") {

            innerList.add(i);

          }

        }

        di["相手"] = innerList;

        count = innerList.length;

      } else if (bettingCode == "9") {

        List<List<int>> horseNumbers = [];

        for (int j = 0; j < 3; j++) {

          List<int> innerList = [];

          for (int i = 1; i <= 18; i++) {

            if (itr.next() == "1") {

              innerList.add(i);

            }

          }

          horseNumbers.add(innerList);

        }

        di["馬番"] = horseNumbers;

        for (var list in (horseNumbers)) {

          if (list.length > count) {

            count = list.length;

          }

        }

      } else {

        di["軸"] = int.parse(itr.next() + itr.next());

        String purchaseAmountStr = "";

        for (int i = 0; i < 5; i++) {

          purchaseAmountStr += itr.next();

        }

        di["購入金額"] = int.parse("${purchaseAmountStr}00");

        List<int> innerList = [];

        for (int i = 1; i <= 18; i++) {

          if (itr.next() == "1") {

            innerList.add(i);

          }

        }

        di["相手"] = innerList;

        count = innerList.length;

      }

      if (bettingCode == "8" || bettingCode == "9") {

        String purchaseAmountStr = "";

        for (int i = 0; i < 5; i++) {

          purchaseAmountStr += itr.next();

        }

        di["購入金額"] = int.parse("${purchaseAmountStr}00");

      }

      if (bettingCode == "9") {

        String multiCode = itr.next();

        d["マルチ"] = multiCode == "1" ? "あり" : "なし";

        if (multiCode == "1") {

          count += 20;

        }

      }

      underDigits[15] = bettingCode;

      if (bettingCode == "6" || bettingCode == "8" || bettingCode == "9") {

        underDigits[16] = wheelCode;

      }



      underDigits[17] = (count ~/ 10).toString();

      underDigits[18] = (count % 10).toString();

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

        for (int i = 1; i <= 18; i++) {

          if (itr.next() == "1") {

            innerList.add(i);

          }

        }

        if (innerList.isNotEmpty) {

          horseNumbers.add(innerList);

        }

      }

      di["馬番"] = horseNumbers;



      String purchaseAmountStr = "";

      for (int i = 0; i < 5; i++) {

        purchaseAmountStr += itr.next();

      }

      di["購入金額"] = int.parse("${purchaseAmountStr}00");



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

      (d["購入内容"] as List).add(di);

      break;



    case "4": // クイックピック

      Map<String, dynamic> di = {};

      String bettingCode = itr.next();

      di["式別"] = bettingDict[bettingCode];



      int no = int.parse(itr.next() + itr.next());

      if (no != 0) {

        d["軸"] = no;

      }



      int positionSpecify = int.parse(itr.next());

      if (bettingCode == "6" || bettingCode == "9") {

        d["着順指定"] = positionSpecify != 0 ? "$positionSpecify着指定" : "なし";

      }



      d["組合せ数"] = int.parse(itr.next() + itr.next());



      String purchaseAmountStr = "";

      for (int i = 0; i < 5; i++) {

        purchaseAmountStr += itr.next();

      }

      di["購入金額"] = int.parse("${purchaseAmountStr}00");



      itr.move(2);



      List<List<int>> horseNumbersList = [];

      for (int i = 0; i < d["組合せ数"]; i++) {

        List<int> innerList = [];

        for (int j = 0; j < 3; j++) {

          int horseNum = int.parse(itr.next() + itr.next());

          if (horseNum != 0) {

            innerList.add(horseNum);

          }

        }

        horseNumbersList.add(innerList);

      }

      di["馬番"] = horseNumbersList;



      underDigits[15] = bettingCode;

      underDigits[17] = (d["組合せ数"] ~/ 10).toString();

      underDigits[18] = (d["組合せ数"] % 10).toString();

      (d["購入内容"] as List).add(di);

      break;



    default:

      throw ArgumentError("Unknown type code: $typeCode");

  }



  d["下端番号"] = joinWithSpaces(underDigits);

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

      throw RangeError("Invalid position after move.");

    }

  }



  int get position => _currentPosition;



  set currentPosition(int pos) {

    _currentPosition = pos;

  }



  String peek(int offset) {

    int pos = _currentPosition + offset;

    if (pos >= _s.length || pos < 0) {

      throw RangeError("Peek out of range");

    }

    return _s[pos];

  }

}

