import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class Breakpoints {
  static const wide = 840.0;
  static const extraWide = 1200.0;
}

extension ResponsiveX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isWide => screenWidth >= Breakpoints.wide;
}

class CenteredListView extends StatelessWidget {
  const CenteredListView({
    super.key,
    required this.children,
    this.maxWidth = 760,
    this.top = 16,
    this.bottom = 24,
    this.side = 20,
  });
  final List<Widget> children;
  final double maxWidth, top, bottom, side;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final extra = box.maxWidth > maxWidth + side * 2 ? (box.maxWidth - maxWidth) / 2 : side;
      return ListView(padding: EdgeInsets.fromLTRB(extra, top, extra, bottom), children: children);
    },
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth <= maxWidth + 48) return child;
      return ColoredBox(
        color: context.colors.background,
        child: Center(
          child: Container(
            width: maxWidth,
            decoration: BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: context.colors.line)),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.left,
    required this.right,
    this.gap = 20,
    this.leftFlex = 3,
    this.rightFlex = 2,
  });
  final List<Widget> left, right;
  final double gap;
  final int leftFlex, rightFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 720) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...left, ...right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: leftFlex,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
          ),
          SizedBox(width: gap),
          Expanded(
            flex: rightFlex,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
          ),
        ],
      );
    },
  );
}
