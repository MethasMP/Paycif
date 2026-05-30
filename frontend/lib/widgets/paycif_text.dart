import 'package:flutter/material.dart';

enum PaycifTextStyle {
  display,    // 32px / 40px
  h1,         // 24px / 32px
  h2,         // 20px / 28px
  body,       // 16px / 24px
  caption,    // 13px / 20px
  numeric,    // 28px / 36px (tabular nums)
}

class PaycifText extends StatelessWidget {
  final String text;
  final PaycifTextStyle style;
  final Color? color;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final FontWeight? fontWeight;

  const PaycifText(
    this.text, {
    super.key,
    required this.style,
    this.color,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.fontWeight,
  });

  bool _hasThaiCharacters(String text) {
    return RegExp(r'[\u0E00-\u0E7F]').hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    TextStyle? baseStyle;
    double fontSize = 16;
    double defaultLineHeight = 24;

    switch (style) {
      case PaycifTextStyle.display:
        baseStyle = textTheme.displayLarge;
        fontSize = 32;
        defaultLineHeight = 40;
        break;
      case PaycifTextStyle.h1:
        baseStyle = textTheme.headlineLarge;
        fontSize = 24;
        defaultLineHeight = 32;
        break;
      case PaycifTextStyle.h2:
        baseStyle = textTheme.headlineMedium;
        fontSize = 20;
        defaultLineHeight = 28;
        break;
      case PaycifTextStyle.body:
        baseStyle = textTheme.bodyLarge;
        fontSize = 16;
        defaultLineHeight = 24;
        break;
      case PaycifTextStyle.caption:
        baseStyle = textTheme.bodySmall;
        fontSize = 13;
        defaultLineHeight = 20;
        break;
      case PaycifTextStyle.numeric:
        baseStyle = textTheme.displayMedium;
        fontSize = 28;
        defaultLineHeight = 36;
        break;
    }

    // Dynamic line-height adjustment: add +4px if Thai characters exist
    final double adjustedLineHeight = _hasThaiCharacters(text)
        ? defaultLineHeight + 4
        : defaultLineHeight;
    
    final double finalHeightMultiplier = adjustedLineHeight / fontSize;

    return Text(
      text,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      style: baseStyle?.copyWith(
        color: color,
        height: finalHeightMultiplier,
        fontWeight: fontWeight,
      ),
    );
  }
}
