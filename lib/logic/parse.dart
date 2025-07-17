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
  // デバッグ用ログ: 解析開始時のQRコード文字列
  print('DEBUG: parseHorseracingTicketQr: Parsing QR: $s');

  List<String> underDigits = List.filled(40, "X");
  for (int i = 0; i < 34; i++) {
    underDigits[i] = "0";
  }

  Map<String, dynamic> d = {};
  d["QR"] = s;
  _StringIterator itr = _StringIterator(s);

  String ticketFormat = itr.next(); // 1桁目
  print('DEBUG: parseHorseracingTicketQr: ticketFormat: $ticketFormat, position: ${itr.position}');

  String racecourseCode = itr.next() + itr.next(); // 2-3桁目
  d["開催場"] = racecourseDict[racecourseCode];
  print('DEBUG: parseHorseracingTicketQr: 開催場: ${d["開催場"]}, position: ${itr.position}');

  itr.move(2); // 4-5桁目をスキップ
  print('DEBUG: parseHorseracingTicketQr: After skipping 2 digits, position: ${itr.position}');

  String alternativeCode = itr.next(); // 6桁目
  if (alternativeCode != "0") {
    if (alternativeCode == "2") {
      d["開催種別"] = "代替";
    } else if (alternativeCode == "7") {
      d["開催種別"] = "継続";
    } else {
      d["開催種別"] = "不明";
    }
  }
  print('DEBUG: parseHorseracingTicketQr: 開催種別: ${d["開催種別"]}, position: ${itr.position}');

  d["年"] = int.parse(itr.next() + itr.next()); // 7-8桁目
  d["回"] = int.parse(itr.next() + itr.next()); // 9-10桁目
  d["日"] = int.parse(itr.next() + itr.next()); // 11-12桁目
  d["レース"] = int.parse(itr.next() + itr.next()); // 13-14桁目
  print('DEBUG: parseHorseracingTicketQr: 年: ${d["年"]}, 回: ${d["回"]}, 日: ${d["日"]}, レース: ${d["レース"]}, position: ${itr.position}');

  String suffix = [
    d["年"],
    racecourseCode,
    d["回"],
    d["日"],
    d["レース"],
  ].map((n) => n.toString().padLeft(2, '0')).join();
  d["URL"] = "https://db.netkeiba.com/race/20$suffix";

  String typeCode = itr.next(); // 15桁目 (券種コード)
  d["方式"] = typeDict[typeCode]; // "券種"ではなく"方式"に修正
  print('DEBUG: parseHorseracingTicketQr: 方式: ${d["方式"]}, typeCode: $typeCode, position: ${itr.position}');

  itr.next(); // 16桁目をスキップ (不明なコード)
  print('DEBUG: parseHorseracingTicketQr: After skipping 1 digit, position: ${itr.position}');

  // 下端番号の初期部分を読み込む
  for (int i = 28; i < 34; i++) { // 17-22桁目
    underDigits[i] = itr.next();
  }
  for (int i = 20; i < 26; i++) { // 23-28桁目
    underDigits[i] = itr.next();
  }
  for (int i = 0; i < 13; i++) { // 29-41桁目
    underDigits[i] = itr.next();
  }
  underDigits[26] = itr.next(); // 42桁目
  print('DEBUG: parseHorseracingTicketQr: underDigits initial read, position: ${itr.position}');


  String ticketofficeCode = underDigits.sublist(0, 4).join();
  d["発売所"] =
      ticketofficeDict[ticketofficeCode.substring(2)] ??
          ticketofficeDict[ticketofficeCode.substring(0, 2)] ??
          "不明";
  print('DEBUG: parseHorseracingTicketQr: 発売所: ${d["発売所"]}');

  underDigits[13] = "1";
  underDigits[14] = typeCode;
  d["購入内容"] = [];

  switch (typeCode) {
    case "0": // 通常
    case "5": // 応援馬券
      while (true) {
        print('DEBUG: parseHorseracingTicketQr: --- Start parsing purchase item (type 0/5) at position: ${itr.position} ---');
        String bettingCode = itr.next(); // 式別コード
        print('DEBUG: parseHorseracingTicketQr: bettingCode: $bettingCode, position: ${itr.position}');

        if (bettingCode == "0") {
          print('DEBUG: parseHorseracingTicketQr: End of purchase items (bettingCode 0).');
          break; // 購入内容の終わり
        }

        Map<String, dynamic> di = {};
        di["式別"] = bettingDict[bettingCode];
        print('DEBUG: parseHorseracingTicketQr: 式別: ${di["式別"]}, position: ${itr.position}');

        // 馬番の読み込みロジックを修正
        List<int> horseNumbers = [];
        int numHorsesToRead = 0; // 読み込む馬番の数

        switch (bettingCode) {
          case "1": // 単勝
          case "2": // 複勝
            numHorsesToRead = 1;
            break;
          case "3": // 枠連
          case "5": // 馬連
          case "6": // 馬単
          case "7": // ワイド
            numHorsesToRead = 2;
            break;
          case "8": // 3連複
          case "9": // 3連単
            numHorsesToRead = 3;
            break;
          default:
            throw ArgumentError("Unexpected betting_code for horse number parsing: $bettingCode");
        }

        // 馬番を読み込む
        for (int i = 0; i < numHorsesToRead; i++) {
          String horseNumStr = itr.next() + itr.next();
          horseNumbers.add(int.parse(horseNumStr));
        }
        di["馬番"] = horseNumbers;
        print('DEBUG: parseHorseracingTicketQr: 馬番: ${di["馬番"]}, position: ${itr.position}');

        // ウラ（馬単のみ）の処理
        if (bettingCode == "6") { // 馬単の場合
          String uraCode = itr.next() + itr.next(); // 2桁読み込み
          di["ウラ"] = uraCode == "01" ? "あり" : "なし";
          print('DEBUG: parseHorseracingTicketQr: 馬単ウラ: ${di["ウラ"]}, position: ${itr.position}');
        } else {
          // 馬単以外で、ウラコードが存在しない場合でも、QRコードの構造に合わせて読み飛ばす
          // （もしQRコードの仕様で、単勝/複勝の後に2桁の固定データがあるなら読み飛ばす）
          // 現状の旧ロジックでは単勝・複勝でも2桁読み飛ばしていたので、その挙動を維持
          itr.next(); // 1桁目をスキップ
          itr.next(); // 2桁目をスキップ
          print('DEBUG: parseHorseracingTicketQr: Skipped 2 digits (non-exacta ura), position: ${itr.position}');
        }


        // 購入金額の読み込み
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) { // 5桁読み込み
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00"); // 下2桁は常に00を付加
        print('DEBUG: parseHorseracingTicketQr: 購入金額: ${di["購入金額"]}, position: ${itr.position}');

        // underDigits の更新ロジック (現状維持)
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
        print('DEBUG: parseHorseracingTicketQr: Added purchase item: $di');
      }
      break;

    case "1": // ボックス
      Map<String, dynamic> di = {};
      String bettingCode = itr.next();
      di["式別"] = bettingDict[bettingCode];

      List<int> nos = [];
      String purchaseAmountStr = "";

      // ボックスの馬番読み込みロジックを修正
      // 最大18頭まで対応するため、QRコードの残りの部分を読み込む
      // 実際にはQRコードの仕様に依存するため、このループは仮定に基づく
      while (itr.position < s.length - 5) { // 金額5桁と末尾のコードを残して読み込む
        String horseNumStr = itr.next() + itr.next();
        int horseNum = int.parse(horseNumStr);
        if (horseNum == 0) { // 00が来たら馬番の終わりと判断（仮定）
          itr.move(-2); // 00を読み飛ばしたので戻す
          break;
        }
        nos.add(horseNum);
      }
      di["馬番"] = nos.where((x) => x != 0).toList(); // 0を除外

      // 金額の読み込み
      for (int i = 0; i < 5; i++) {
        purchaseAmountStr += itr.next();
      }
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
          di["ながし"] = "ながし"; // 未定義のながしコードの場合
      }

      int count = 0;
      if (bettingCode == "6" || bettingCode == "8") { // 馬単ながし、3連複ながし（軸1頭/2頭）
        List<int> axisHorseNumbers = [];
        // 軸馬の読み込み (18ビットフラグ形式が2回繰り返される)
        for (int j = 0; j < 2; j++) { // 2つのグループ
          for (int i = 1; i <= 18; i++) {
            if (itr.next() == "1") {
              axisHorseNumbers.add(i);
            }
          }
        }
        di["軸"] = axisHorseNumbers;

        List<int> opponentHorseNumbers = [];
        // 相手馬の読み込み (18ビットフラグ形式)
        for (int i = 1; i <= 18; i++) {
          if (itr.next() == "1") {
            opponentHorseNumbers.add(i);
          }
        }
        di["相手"] = opponentHorseNumbers;
        count = opponentHorseNumbers.length; // 相手馬の数
      } else if (bettingCode == "9") { // 3連単ながし
        List<List<int>> horseNumbers = [];
        for (int j = 0; j < 3; j++) { // 3つのグループ
          List<int> innerList = [];
          for (int i = 1; i <= 18; i++) {
            if (itr.next() == "1") {
              innerList.add(i);
            }
          }
          horseNumbers.add(innerList);
        }
        di["馬番"] = horseNumbers; // フォーメーションと同様に馬番として格納

        // 最大のリストの長さをcountとする
        for (var list in (horseNumbers)) {
          if (list.length > count) {
            count = list.length;
          }
        }
      } else { // その他のながし（単勝ながし、複勝ながしなど、旧ロジックで軸1頭+相手複数だったもの）
        di["軸"] = int.parse(itr.next() + itr.next()); // 軸馬を2桁で読み込み
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) { // 金額5桁
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");
        List<int> innerList = [];
        for (int i = 1; i <= 18; i++) { // 相手馬を18ビットフラグで読み込み
          if (itr.next() == "1") {
            innerList.add(i);
          }
        }
        di["相手"] = innerList;
        count = innerList.length;
      }

      // 3連複ながし、3連単ながしの場合の金額読み込み
      if (bettingCode == "8" || bettingCode == "9") {
        String purchaseAmountStr = "";
        for (int i = 0; i < 5; i++) {
          purchaseAmountStr += itr.next();
        }
        di["購入金額"] = int.parse("${purchaseAmountStr}00");
      }

      // 3連単ながしの場合のマルチコード
      if (bettingCode == "9") {
        String multiCode = itr.next();
        d["マルチ"] = multiCode == "1" ? "あり" : "なし";
        if (multiCode == "1") {
          count += 20; // マルチの場合のカウント加算（QRコード仕様に依存）
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

      itr.next(); // 不明な1桁をスキップ

      List<List<int>> horseNumbers = [];
      for (int j = 0; j < 3; j++) { // 3つのグループ
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

      itr.next(); // 不明な1桁をスキップ

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

      int no = int.parse(itr.next() + itr.next()); // 軸馬
      if (no != 0) {
        d["軸"] = no;
      }

      int positionSpecify = int.parse(itr.next()); // 着順指定
      if (bettingCode == "6" || bettingCode == "9") {
        d["着順指定"] = positionSpecify != 0 ? "$positionSpecify着指定" : "なし";
      }

      d["組合せ数"] = int.parse(itr.next() + itr.next()); // 組合せ数

      String purchaseAmountStr = "";
      for (int i = 0; i < 5; i++) { // 金額5桁
        purchaseAmountStr += itr.next();
      }
      di["購入金額"] = int.parse("${purchaseAmountStr}00");

      itr.move(2); // 不明な2桁をスキップ

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
  print('DEBUG: parseHorseracingTicketQr: Final parsed data: $d');
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
      throw StateError("No more elements in the string. Current position: $_currentPosition, String length: ${_s.length}");
    }
    return _s[_currentPosition++];
  }

  void move(int offset) {
    _currentPosition += offset;
    if (_currentPosition < 0 || _currentPosition > _s.length) {
      throw RangeError("Invalid position after move. Current position: $_currentPosition, String length: ${_s.length}, Offset: $offset");
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
      throw RangeError("Peek out of range. Current position: $_currentPosition, String length: ${_s.length}, Offset: $offset");
    }
    return _s[pos];
  }
}
