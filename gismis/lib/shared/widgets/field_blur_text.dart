import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_animations.dart';
import '../../app/theme/app_colors.dart';
import '../models/ai_message.dart';
import 'skeleton_loader.dart';

/// A widget that displays text with blur animation for AI streaming responses.
///
/// Implements state transitions: skeleton → blurred → clear → completed
/// Uses BackdropFilter for blur effect and AnimatedOpacity for smooth transitions.
/// Requirements: 4.4, 4.5, 4.6
class FieldBlurText extends StatefulWidget {
  const FieldBlurText({
    required this.text,
    required this.state,
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  /// The text content to display.
  final String text;

  /// The current field state determining visual appearance.
  final FieldState state;

  /// Optional text style.
  final TextStyle? style;

  /// Maximum number of lines.
  final int? maxLines;

  /// Text overflow behavior.
  final TextOverflow? overflow;

  @override
  State<FieldBlurText> createState() => _FieldBlurTextState();
}

class _FieldBlurTextState extends State<FieldBlurText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blurAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.clearDuration,
    );

    _blurAnimation = Tween<double>(begin: AppAnimations.blurAmount, end: 0)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );

    _opacityAnimation = Tween<double>(begin: AppAnimations.blurOpacity, end: 1)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );

    _updateAnimationState();
  }

  @override
  void didUpdateWidget(FieldBlurText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    switch (widget.state) {
      case FieldState.hidden:
      case FieldState.skeleton:
        _controller.value = 0;
      case FieldState.blurred:
        _controller.value = 0;
      case FieldState.clear:
      case FieldState.completed:
        _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.state) {
      FieldState.hidden => const SizedBox.shrink(),
      FieldState.skeleton => _buildSkeleton(),
      FieldState.blurred => _buildBlurredText(),
      FieldState.clear || FieldState.completed => _buildClearText(),
    };
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLoader.text(height: 16),
        const SizedBox(height: 8),
        SkeletonLoader.text(width: 200),
      ],
    );
  }

  Widget _buildBlurredText() {
    if (widget.text.isEmpty) {
      return _buildSkeleton();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: Stack(
            children: [
              // Blurred text layer
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: _blurAnimation.value,
                  sigmaY: _blurAnimation.value,
                ),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Text(
                    widget.text,
                    style: widget.style,
                    maxLines: widget.maxLines,
                    overflow: widget.overflow,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClearText() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _blurAnimation.value,
              sigmaY: _blurAnimation.value,
            ),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: widget.maxLines,
                overflow: widget.overflow,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A simpler version of FieldBlurText for single-line streaming text.
class StreamingText extends StatelessWidget {
  const StreamingText({
    required this.text,
    required this.isStreaming,
    super.key,
    this.style,
  });

  final String text;
  final bool isStreaming;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, style: style)),
        if (isStreaming) ...[const SizedBox(width: 4), _buildCursor()],
      ],
    );
  }

  Widget _buildCursor() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value * 2).clamp(0, 1) > 0.5 ? 1 : 0,
          child: Container(width: 2, height: 16, color: AppColors.textPrimary),
        );
      },
      onEnd: () {},
    );
  }
}

/// A widget that shows a typing indicator for AI responses.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (1 - (progress * 2 - 1).abs());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
