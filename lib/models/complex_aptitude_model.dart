// lib/models/complex_aptitude_model.dart

class ComplexAptitudeStats {
  final int raceCount;
  final int winCount;
  final int placeCount; // 2着以内
  final int showCount;  // 3着以内
  final String recordString; // "1-2-3-4" 形式の度数

  ComplexAptitudeStats({
    this.raceCount = 0,
    this.winCount = 0,
    this.placeCount = 0,
    this.showCount = 0,
    this.recordString = '0-0-0-0',
  });

  // 複勝率
  double get showRate => raceCount > 0 ? (showCount / raceCount) * 100 : 0.0;
}