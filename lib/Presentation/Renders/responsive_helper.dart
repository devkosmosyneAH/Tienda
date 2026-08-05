import 'package:flutter/material.dart';

/// Clase auxiliar para manejar diseño responsivo en toda la aplicación
class ResponsiveHelper {
  static const double smallScreenWidth = 600;
  static const double mediumScreenWidth = 900;
  static const double largeScreenWidth = 1200;

  /// Determina si la pantalla es pequeña (móviles)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < smallScreenWidth;
  }

  /// Determina si la pantalla es mediana (tablets pequeñas)
  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= smallScreenWidth &&
        MediaQuery.of(context).size.width < mediumScreenWidth;
  }

  /// Determina si la pantalla es grande (tablets grandes/desktop)
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= mediumScreenWidth;
  }

  /// Obtiene el ancho adaptable para un widget
  static double getAdaptiveWidth(
    BuildContext context, {
    required double smallWidth,
    double? mediumWidth,
    double? largeWidth,
  }) {
    final size = MediaQuery.of(context).size.width;
    if (size < smallScreenWidth) {
      return smallWidth;
    } else if (size < mediumScreenWidth) {
      return mediumWidth ?? smallWidth * 1.2;
    } else {
      return largeWidth ?? smallWidth * 1.5;
    }
  }

  /// Obtiene padding adaptable
  static EdgeInsets getAdaptivePadding(
    BuildContext context, {
    required double smallPadding,
    double? mediumPadding,
    double? largePadding,
  }) {
    final size = MediaQuery.of(context).size.width;
    double padding;

    if (size < smallScreenWidth) {
      padding = smallPadding;
    } else if (size < mediumScreenWidth) {
      padding = mediumPadding ?? smallPadding * 1.2;
    } else {
      padding = largePadding ?? smallPadding * 1.5;
    }

    return EdgeInsets.all(padding);
  }

  /// Obtiene tamaño de fuente adaptable
  static double getAdaptiveFontSize(
    BuildContext context, {
    required double smallSize,
    double? mediumSize,
    double? largeSize,
  }) {
    final size = MediaQuery.of(context).size.width;
    if (size < smallScreenWidth) {
      return smallSize;
    } else if (size < mediumScreenWidth) {
      return mediumSize ?? smallSize + 2;
    } else {
      return largeSize ?? smallSize + 4;
    }
  }

  /// Obtiene el número de columnas para una grid
  static int getGridColumns(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    if (size < smallScreenWidth) {
      return 1;
    } else if (size < mediumScreenWidth) {
      return 2;
    } else {
      return 3;
    }
  }

  /// Verifica si el dispositivo está en modo apaisado
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Obtiene alto adaptable de app bar
  static double getAppBarHeight(BuildContext context) {
    return isSmallScreen(context) ? 80.0 : 80.0;
  }

  /// Obtiene altura máxima adaptable para listas
  static double getListMaxHeight(
    BuildContext context, {
    double smallHeight = 120.0,
    double mediumHeight = 150.0,
    double largeHeight = 200.0,
  }) {
    if (isSmallScreen(context)) {
      return smallHeight;
    } else if (isMediumScreen(context)) {
      return mediumHeight;
    } else {
      return largeHeight;
    }
  }

  /// Obtiene margen adaptable
  static double getAdaptiveMargin(
    BuildContext context, {
    double smallMargin = 8.0,
    double mediumMargin = 12.0,
    double largeMargin = 16.0,
  }) {
    if (isSmallScreen(context)) {
      return smallMargin;
    } else if (isMediumScreen(context)) {
      return mediumMargin;
    } else {
      return largeMargin;
    }
  }

  /// Obtiene el tamaño del icono adaptable
  static double getIconSize(
    BuildContext context, {
    double smallSize = 20.0,
    double mediumSize = 24.0,
    double largeSize = 28.0,
  }) {
    if (isSmallScreen(context)) {
      return smallSize;
    } else if (isMediumScreen(context)) {
      return mediumSize;
    } else {
      return largeSize;
    }
  }
}
