import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../view_model/provider/network_activity_provider.dart';
import '../../constants/app_colors.dart';

/// A thin progress bar pinned to the very top of the app, visible on every
/// screen, that appears for the exact duration of any in-flight network
/// request (Supabase Auth or REST — GET/POST/PATCH/PUT/DELETE) and disappears
/// the instant the response comes back.
class NetworkActivityIndicator extends StatelessWidget {
  const NetworkActivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isBusy = context.watch<NetworkActivityProvider>().isBusy;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: isBusy ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: const SizedBox(
          height: 3,
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }
}
