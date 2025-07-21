// lib/widgets/app_styles.dart

import 'package:flutter/material.dart';

class AppStyles {
  // --- テキストスタイル定義 ---

  // 解析結果画面: 年・回・日の日付表示
  static const TextStyle dateTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 解析結果画面: 開催場表示 (例: 福島)
  static const TextStyle racecourseTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 解析結果画面: レース番号表示 (例: 11)
  static const TextStyle raceNumberTextStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // 解析結果画面: 「レース」という文字の表示
  static const TextStyle raceLabelTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  // 解析結果画面: 購入方式表示 (例: 応援馬券、ながし、ボックス、フォーメーション、クイックピック)
  static const TextStyle shikibetsuMethodTextStyle = TextStyle(
    fontSize: 18, // FittedBoxにより、このサイズを基準に自動調整される
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 購入内容カード: 馬番の数字表示
  static const TextStyle horseNumberTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 購入内容カード: 馬番間の記号表示 (例: ▶, -, ◆)
  static const TextStyle horseNumberSymbolTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 購入内容カード: 各購入金額の表示 (例: 100円)
  static const TextStyle purchaseAmountTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 購入内容カード: マルチ表示 (例: マルチ)
  static const TextStyle multiTextStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // 購入内容カード: ウラ表示 (例: ウラ: あり)
  static const TextStyle uraDisplayTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.black54,
  );

  // 解析結果画面・購入内容カード: 「合計」「軸」「相手」などのラベル表示
  static const TextStyle totalLabelStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 解析結果画面: 合計金額表示
  static const TextStyle totalAmountStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.red,
  );

  // 解析結果画面: 「発売所」という文字のラベル表示
  static const TextStyle salesLocationLabelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // 解析結果画面: 発売所名表示
  static const TextStyle salesLocationTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  // 解析結果画面: エラーメッセージ表示
  static const TextStyle errorMessageStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.red,
  );

  // 解析結果画面: 通常のメッセージ表示 (例: 馬券ではありませんでした)
  static const TextStyle normalMessageStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.black,
  );

  // --- 色とボーダースタイル定義 ---

  // 購入内容カード: 馬番の枠線色
  static const Color horseNumberBorderColor = Colors.black;
  // 購入内容カード: 馬番の背景色
  static const Color horseNumberBackgroundColor = Colors.white;

  // 解析結果画面: 購入方式の四角い枠線のスタイル
  static BoxDecoration purchaseMethodBoxDecoration = BoxDecoration(
    border: Border.all(color: Colors.grey, width: 1.0), // 枠線の色と太さ
    borderRadius: BorderRadius.circular(4.0), // 角丸
  );
}