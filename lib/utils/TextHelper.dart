
import 'package:flutter/services.dart';

class WordLimitFormatter extends TextInputFormatter {
  final int maxWords;

  WordLimitFormatter(this.maxWords);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {

    // Handle empty text
    if (newValue.text.trim().isEmpty) {
      return newValue;
    }

    final words = newValue.text.trim().split(RegExp(r'\s+'));

    // If within limit, allow typing
    if (words.length <= maxWords) {
      return newValue;
    }

    // If pasting or exceeding, trim to max words
    final limitedText = words.take(maxWords).join(' ');

    // Preserve trailing space if user was typing
    final hasTrailingSpace = newValue.text.endsWith(' ') &&
        limitedText.split(RegExp(r'\s+')).length == maxWords;
    final finalText = hasTrailingSpace ? '$limitedText ' : limitedText;

    return TextEditingValue(
      text: finalText,
      selection: TextSelection.collapsed(offset: finalText.length),
    );
  }
}
