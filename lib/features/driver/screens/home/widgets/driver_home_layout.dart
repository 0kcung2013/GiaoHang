import '../../../../../core/constants/app_theme.dart';

/// Encapsulates responsive layout parameters for the Driver Home screen.
class DriverHomeLayout {
  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;
  static const wideStatsMinWidth = 760.0;

  final double horizontalPadding;
  final double topPadding;
  final double sectionGap;
  final double maxContentWidth;

  const DriverHomeLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.sectionGap,
    required this.maxContentWidth,
  });

  factory DriverHomeLayout.fromWidth(double width) {
    if (width >= desktopBreakpoint) {
      return const DriverHomeLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl3,
        maxContentWidth: 1040,
      );
    }

    if (width >= tabletBreakpoint) {
      return const DriverHomeLayout(
        horizontalPadding: AppSpacing.xl3,
        topPadding: AppSpacing.xl3,
        sectionGap: AppSpacing.xl2,
        maxContentWidth: 860,
      );
    }

    return const DriverHomeLayout(
      horizontalPadding: AppSpacing.screenH,
      topPadding: AppSpacing.xl2,
      sectionGap: AppSpacing.xl2,
      maxContentWidth: double.infinity,
    );
  }
}
