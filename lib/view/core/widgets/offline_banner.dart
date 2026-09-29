import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../view_model/provider/connectivity_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

/// A full-width, impossible-to-miss warning shown whenever the device has no
/// network path at all. The system keeps working fully offline (every local
/// read/write is unaffected) — this only warns that changes won't reach the
/// shared Supabase project until the connection returns.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isOnline = context.watch<ConnectivityProvider>().isOnline;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isOnline
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey<String>('offline-banner'),
              width: double.infinity,
              color: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.deepNavy),
                  const SizedBox(width: 8),
                  Text(
                    'لا يوجد اتصال بالإنترنت — النظام يعمل محلياً وسيتم رفع التغييرات '
                    'تلقائياً عند عودة الاتصال',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.deepNavy,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
