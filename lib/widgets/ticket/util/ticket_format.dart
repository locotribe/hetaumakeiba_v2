// lib/widgets/ticket/util/ticket_format.dart

String getStars(int amount) {
  String amountStr = amount.toString();
  int numDigits = amountStr.length;
  if (numDigits >= 6) return '';
  if (numDigits == 5) return '☆';
  if (numDigits == 4) return '☆☆';
  if (numDigits == 3) return '☆☆☆';
  return '';
}

String getTotalAmountStars(int amount) {
  String amountStr = amount.toString();
  int numDigits = amountStr.length;
  if (numDigits >= 7) return '';
  if (numDigits == 6) return '★';
  if (numDigits == 5) return '★★';
  if (numDigits == 4) return '★★★';
  if (numDigits == 3) return '★★★★';
  return '';
}

// 半角数字を全角数字に変換するヘルパー関数
String convertHalfWidthNumbersToFullWidth(String text) {
  return text
      .replaceAll('0', '０')
      .replaceAll('1', '１')
      .replaceAll('2', '２')
      .replaceAll('3', '３')
      .replaceAll('4', '４')
      .replaceAll('5', '５')
      .replaceAll('6', '６')
      .replaceAll('7', '７')
      .replaceAll('8', '８')
      .replaceAll('9', '９');
}

String getHorseNumberSymbol(String shikibetsu, String betType, {String? uraStatus}) {
  if (uraStatus == 'あり') return '◀ ▶';
  if (betType == '通常' || betType == 'フォーメーション' || betType == 'ながし') {
    if (shikibetsu == '馬単' || shikibetsu == '3連単') return '▶';
    if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') return '━';
    if (shikibetsu == 'ワイド') return '◆';
  }
  return '';
}
