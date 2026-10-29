// lib/logic/analysis/age_category.dart
// [追加] 過去分析「年齢」タブ: 年齢の区分と、性齢の文字から年齢を読む関数 (v.2026.10.30+26103002)

/// 年齢別成績の区分（表示順）。7歳以上は母数が小さいので1つにまとめる。
const List<String> kAgeCategories = ['3歳', '4歳', '5歳', '6歳', '7歳以上'];

/// 性齢（'牡3'・'牝10' など）の2文字目以降を年齢として読む。読めなければ null。
int? ageOfSexAndAge(String sexAndAge) {
  final s = sexAndAge.trim();
  if (s.length < 2) return null;
  return int.tryParse(s.substring(1));
}

/// 年齢を区分のラベルへ変換する。3歳未満は集計しないので null。
String? ageCategoryOf(int age) {
  if (age < 3) return null;
  if (age >= 7) return '7歳以上';
  return '$age歳';
}

/// 性齢の列に2種類以上の年齢が含まれるか（年齢混合戦か）。
/// 読めない性齢は数えない。2歳戦・3歳限定戦など同世代戦は false になる。
bool hasMixedAges(Iterable<String> sexAndAges) {
  final ages = <int>{};
  for (final s in sexAndAges) {
    final age = ageOfSexAndAge(s);
    if (age != null) ages.add(age);
  }
  return ages.length >= 2;
}
