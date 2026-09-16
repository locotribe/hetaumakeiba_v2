// lib/widgets/ticket/util/ticket_fonts.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 馬券ウィジェット用の明朝体（Noto Serif JP）スタイルを返す。
/// google_fonts は太さをフォント名に含めるため、太さは必ずこの引数で渡すこと。
TextStyle ticketMincho({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
  TextLeadingDistribution? leadingDistribution,
}) {
  return GoogleFonts.notoSerifJp(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  ).copyWith(leadingDistribution: leadingDistribution);
}

/// 馬券ウィジェット用のゴシック体（Noto Sans JP）スタイルを返す。
/// google_fonts は太さをフォント名に含めるため、太さは必ずこの引数で渡すこと。
TextStyle ticketGothic({
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
  TextLeadingDistribution? leadingDistribution,
}) {
  return GoogleFonts.notoSansJp(
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
  ).copyWith(leadingDistribution: leadingDistribution);
}
