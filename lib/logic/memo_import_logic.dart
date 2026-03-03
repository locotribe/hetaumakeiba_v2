// lib/logic/memo_import_logic.dart

enum MemoMergeAction {
  skip,
  overwrite,
  conflict,
}

class MemoMergeResult {
  final MemoMergeAction action;
  final String resultText;
  final String existingText;
  final String newText;

  MemoMergeResult({
    required this.action,
    required this.resultText,
    required this.existingText,
    required this.newText,
  });
}

class MemoImportLogic {
  /// 既存のメモ(A)と新しいCSVのメモ(B)を比較し、要件に基づく統合アクションを決定します。
  static MemoMergeResult determineMergeAction(String? existingMemo, String? newMemo) {
    final String a = (existingMemo ?? '').trim();
    final String b = (newMemo ?? '').trim();

    // ルール1 & ルール3(後段): 【完全一致】 A == B、または B が空欄の場合 -> スキップ(Aを維持)
    if (a == b || b.isEmpty) {
      return MemoMergeResult(
        action: MemoMergeAction.skip,
        resultText: a,
        existingText: a,
        newText: b,
      );
    }

    // ルール3(前段): 【情報減少/消失】 B が A に含まれる (A.contains(B)) -> スキップ(Aを維持)
    if (a.contains(b)) {
      return MemoMergeResult(
        action: MemoMergeAction.skip,
        resultText: a,
        existingText: a,
        newText: b,
      );
    }

    // ルール2: 【情報増加】 A が B に含まれる (B.contains(A)) -> 上書き(Bを採用)
    // ※Aが空欄(新規登録)の場合も、任意の文字列は空文字を含むためここでキャッチされます。
    if (b.contains(a)) {
      return MemoMergeResult(
        action: MemoMergeAction.overwrite,
        resultText: b,
        existingText: a,
        newText: b,
      );
    }

    // ルール4: 【競合】 上記以外 (AとBが全く異なる内容) -> 競合状態として返す
    return MemoMergeResult(
      action: MemoMergeAction.conflict,
      resultText: '', // ユーザーに選択させるため、確定結果は持たない
      existingText: a,
      newText: b,
    );
  }
}