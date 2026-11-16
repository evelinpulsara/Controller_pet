import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Diseño adaptable (responsive): la misma app se ve bien en celular,
/// tablet y computador (Chrome, Safari...).
///
/// - Celular (< 840 px de ancho): todo a lo ancho y barra de pestañas abajo.
/// - Computador o tablet (≥ 840 px): menú lateral y el contenido centrado con
///   un ancho máximo, para que las tarjetas no se estiren de lado a lado.
class Breakpoints {
  static const wide = 840.0; // a partir de aquí: menú lateral
  static const extraWide = 1200.0; // a partir de aquí: menú lateral con textos
}

extension ResponsiveX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isWide => screenWidth >= Breakpoints.wide;
}

/// Lista con scroll cuyo contenido queda centrado y con un ancho máximo.
/// El scroll sigue ocupando toda la pantalla (la barra queda en el borde).
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

/// Marco para pantallas completas (perfil, contactos, collar...).
/// En pantallas anchas las muestra como una columna centrada, con su barra
/// superior, en lugar de estirarlas de lado a lado.
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

/// Dos columnas en pantallas anchas; una sola (izquierda y luego derecha) en celular.
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
