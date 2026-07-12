import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/app_icon.dart';

class SwipeToPaySlider extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final String text;

  /// Defaults to the theme's action color when null.
  final Color? activeColor;

  /// When false the slider ignores drags and renders dimmed
  /// (e.g. while the FX quote is still loading).
  final bool enabled;

  const SwipeToPaySlider({
    super.key,
    required this.onSwipeComplete,
    this.text = 'Swipe to pay',
    this.activeColor,
    this.enabled = true,
  });

  @override
  State<SwipeToPaySlider> createState() => _SwipeToPaySliderState();
}

class _SwipeToPaySliderState extends State<SwipeToPaySlider> with SingleTickerProviderStateMixin {
  double _dragPercentage = 0.0;
  bool _isCompleted = false;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(_resetController);
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _complete() {
    if (_isCompleted) return;
    setState(() {
      _dragPercentage = 1.0;
      _isCompleted = true;
    });
    HapticFeedback.heavyImpact();
    widget.onSwipeComplete();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDragDistance) {
    if (_isCompleted || !widget.enabled) return;
    setState(() {
      _dragPercentage += details.primaryDelta! / maxDragDistance;
      _dragPercentage = _dragPercentage.clamp(0.0, 1.0);
    });
    if (_dragPercentage > 0.0 && _dragPercentage < 1.0) {
      // Subtle tick-tick micro-haptic while dragging
      if ((_dragPercentage * 10).toInt() % 2 == 0) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isCompleted || !widget.enabled) return;
    if (_dragPercentage >= 0.9) {
      _complete();
    } else {
      // Reset back to start
      HapticFeedback.lightImpact();
      _resetAnimation = Tween<double>(
        begin: _dragPercentage,
        end: 0.0,
      ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic))
        ..addListener(() {
          setState(() {
            _dragPercentage = _resetAnimation.value;
          });
        });
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color active = widget.activeColor ?? AppTheme.primaryColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = 64.0;
        final double handleSize = height - 8;
        final double maxDragDistance = width - handleSize - 8;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceSunken : AppTheme.lightSurfaceSunken,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderHairline : AppTheme.lightBorderHairline,
              width: 1.0,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Helper text that fades out as handle is dragged
              Opacity(
                opacity: (1.0 - _dragPercentage * 1.5).clamp(0.0, 1.0),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Completed confirmation spinner
              if (_isCompleted)
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                ),

              // Animated highlight trail
              Positioned(
                left: 4,
                top: 4,
                bottom: 4,
                child: Container(
                  width: handleSize + (_dragPercentage * maxDragDistance),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        active.withValues(alpha: 0.08),
                        active.withValues(alpha: 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              // Swipe Handle button
              Positioned(
                left: 4 + (_dragPercentage * maxDragDistance),
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onHorizontalDragUpdate(details, maxDragDistance),
                  onHorizontalDragEnd: _onHorizontalDragEnd,
                  child: Semantics(
                    button: true,
                    enabled: widget.enabled && !_isCompleted,
                    label: widget.text,
                    // Screen-reader activation: a deliberate double-tap on the
                    // named "Swipe to pay" control is explicit payment intent —
                    // the drag gesture only guards against accidental touches.
                    onTap: (widget.enabled && !_isCompleted) ? _complete : null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: widget.enabled ? 1.0 : 0.45,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: handleSize,
                        height: handleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCompleted ? AppTheme.signalGreen : active,
                          boxShadow: [
                            BoxShadow(
                              color: active.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: AppIcon(
                          PhosphorIcons.caretRight,
                          activeIcon: PhosphorIcons.check,
                          isActive: _isCompleted,
                          color: Colors.white,
                          size: AppIconSize.md,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
