import 'package:device_frame/device_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:giaohang_design/giaohang_design.dart';

/// Displays the app inside a complete phone on every browser window size.
/// The phone scales to fit; its logical screen and safe areas remain mobile.
class MobileBrowserViewport extends StatelessWidget {
  const MobileBrowserViewport({
    super.key,
    required this.child,
    this.enabled = kIsWeb,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return ColoredBox(
      color: AppColors.border,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + keyboardInset,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430, maxHeight: 920),
            child: DeviceFrame(device: Devices.ios.iPhone13, screen: child),
          ),
        ),
      ),
    );
  }
}
