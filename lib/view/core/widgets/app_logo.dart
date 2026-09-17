import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

/// The BOZKRI wordmark, wherever the brand needs to show up: side-nav
/// header, splash, Excel export header.
///
/// `app_logo.png` is a wide wordmark (gold-on-black), not a square icon —
/// this renders it at its own aspect ratio via a fixed [height] rather than
/// forcing a square box. Falls back to a plain square icon if the asset is
/// ever absent, so the app keeps working without it.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 28, this.color = AppColors.secondary});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.appLogoAsset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          Icon(Icons.handshake_outlined, color: color, size: height),
    );
  }
}
