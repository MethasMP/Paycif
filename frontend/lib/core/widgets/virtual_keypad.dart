import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

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
          if (key.isEmpty) return SizedBox(width: 72, height: 72);
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
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppTheme.darkSurfaceSunken : AppTheme.lightSurfaceSunken,
          ),
          child: Semantics(
            label: label == '⌫' ? 'Delete' : 'Digit $label',
            button: true,
            child: label == '⌫'
                ? AppIcon(
                    PhosphorIcons.backspace,
                    color: AppTheme.textSecondaryColor(context),
                    size: AppIconSize.md,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
