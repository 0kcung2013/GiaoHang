import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inline vector so the sign-in mark is available during Flutter hot reload.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M21.35 12.23c0-.71-.06-1.39-.18-2.05H12v3.72h5.24a4.48 4.48 0 0 1-1.94 2.94v2.44h3.14c1.84-1.69 2.91-4.18 2.91-7.05Z"/>
  <path fill="#34A853" d="M12 21.75c2.64 0 4.85-.88 6.44-2.47l-3.14-2.44c-.87.58-1.98.92-3.3.92-2.54 0-4.69-1.72-5.46-4.04H3.3v2.51A9.74 9.74 0 0 0 12 21.75Z"/>
  <path fill="#FBBC05" d="M6.54 13.72a5.85 5.85 0 0 1 0-3.44V7.77H3.3a9.76 9.76 0 0 0 0 8.46l3.24-2.51Z"/>
  <path fill="#EA4335" d="M12 6.24c1.39 0 2.63.48 3.61 1.42l2.8-2.8A9.37 9.37 0 0 0 12 2.25a9.74 9.74 0 0 0-8.7 5.52l3.24 2.51C7.31 7.96 9.46 6.24 12 6.24Z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    _svg,
    width: 22,
    height: 22,
    excludeFromSemantics: true,
  );
}
