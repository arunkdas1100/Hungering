import 'package:flutter/material.dart';

class FadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final bool slideUp;

  const FadeSlideTransition({
    super.key,
    required this.child,
    required this.animation,
    this.slideUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            slideUp ? 30 * (1 - animation.value) : 0,
          ),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class StaggeredSlideTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final int index;
  final bool slideUp;

  const StaggeredSlideTransition({
    super.key,
    required this.child,
    required this.animation,
    required this.index,
    this.slideUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final delay = (index * 0.15).clamp(0.0, 1.0);
    final slideAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        delay,
        (delay + 0.5).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeSlideTransition(
      animation: slideAnimation,
      slideUp: slideUp,
      child: child,
    );
  }
}

class PageRouteBuilders {
  static PageRouteBuilder<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  static PageRouteBuilder<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = const Offset(0.0, 0.3);
        var end = Offset.zero;
        var curve = Curves.easeOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
} 