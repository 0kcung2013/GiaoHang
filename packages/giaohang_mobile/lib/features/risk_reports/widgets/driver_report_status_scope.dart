import 'package:flutter/widgets.dart';

/// Mở lại chi tiết báo cáo từ dòng trạng thái trong footer.
class DriverReportStatusScope extends InheritedWidget {
  const DriverReportStatusScope({
    required this.onOpen,
    required super.child,
    super.key,
  });
  final VoidCallback? onOpen;
  static VoidCallback? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DriverReportStatusScope>()
      ?.onOpen;
  @override
  bool updateShouldNotify(DriverReportStatusScope oldWidget) =>
      onOpen != oldWidget.onOpen;
}
