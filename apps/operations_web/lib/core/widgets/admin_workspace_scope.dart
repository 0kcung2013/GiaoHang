import 'package:flutter/widgets.dart';

/// Nhúng các công cụ vận hành dưới điều hướng Administrator, giữ quyền server.
class AdminWorkspaceScope extends InheritedWidget {
  const AdminWorkspaceScope({super.key, required super.child});
  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminWorkspaceScope>() != null;
  @override
  bool updateShouldNotify(AdminWorkspaceScope oldWidget) => false;
}
