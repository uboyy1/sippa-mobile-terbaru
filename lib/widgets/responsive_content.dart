import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double tablet = 600;
  static const double desktop = 900;
}

class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final Alignment alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= ResponsiveBreakpoints.desktop
        ? 32.0
        : 0.0;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ?? EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: child,
        ),
      ),
    );
  }
}

extension ResponsiveContext on BuildContext {
  bool get isDesktopWidth =>
      MediaQuery.sizeOf(this).width >= ResponsiveBreakpoints.desktop;

  bool get isTabletWidth =>
      MediaQuery.sizeOf(this).width >= ResponsiveBreakpoints.tablet;
}
