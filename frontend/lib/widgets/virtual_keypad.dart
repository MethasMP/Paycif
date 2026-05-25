import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VirtualKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final bool showDecimal;

  const VirtualKeypad({
    super.key,
    required this.onKeyPressed,
    this.showDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKeypadRow(context, ['1', '2', '3']),
          _buildKeypadRow(context, ['4', '5', '6']),
          _buildKeypadRow(context, ['7', '8', '9']),
          _buildKeypadRow(
            context,
            showDecimal ? ['.', '0', '⌫'] : ['', '0', '⌫'],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(BuildContext context, List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox(width: 72, height: 72);
          return _buildKey(context, key);
        }).toList(),
      ),
    );
  }

  Widget _buildKey(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onKeyPressed(label);
        },
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              width: 1,
            ),
          ),
          child: Semantics(
            label: label == '⌫' ? 'Delete' : 'Digit $label',
            button: true,
            child: label == '⌫'
                ? Icon(
                    Icons.backspace_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 22,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
