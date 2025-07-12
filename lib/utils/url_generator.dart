// lib/utils/url_generator.dart
String generateNetkeibaUrl({
  required String year,
  required String racecourseCode,
  required String round,
  required String day,
  required String race,
}) {
  final suffix = [year, racecourseCode, round, day, race]
      .map((e) => e.toString().padLeft(2, '0'))
      .join();
  return 'https://db.netkeiba.com/race/20$suffix';
}