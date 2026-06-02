import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class SwipeToPaySlider extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final String text;
  final Color activeColor;

  const SwipeToPaySlider({
    super.key,
    required this.onSwipeComplete,
    this.text = 'Swipe to pay',
    this.activeColor = const Color(0xFFEF9F27),
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

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDragDistance) {
    if (_isCompleted) return;
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
    if (_isCompleted) return;
    if (_dragPercentage >= 0.9) {
      // Trigger Success
      setState(() {
        _dragPercentage = 1.0;
        _isCompleted = true;
      });
      HapticFeedback.heavyImpact();
      widget.onSwipeComplete();
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
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
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Completed confirmation text
              if (_isCompleted)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                        widget.activeColor.withValues(alpha: 0.1),
                        widget.activeColor.withValues(alpha: 0.3),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCompleted
                          ? Colors.green
                          : widget.activeColor,
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isCompleted ? PhosphorIcons.check : PhosphorIcons.caretRight,
                      color: Colors.black,
                      size: 24,
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
