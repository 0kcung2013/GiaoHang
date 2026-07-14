part of '../tracking_screen.dart';

class _MapMarkerIcon extends StatelessWidget {
  final Color color;
  final String label;

  const _MapMarkerIcon({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: AppShadow.subtle,
      ),
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
