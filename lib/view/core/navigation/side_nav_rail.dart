import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../view_model/provider/expiry_provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../widgets/app_logo.dart';

/// One destination in the persistent side rail.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.showExpiryBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Dashboard carries the expiry badge count.
  final bool showExpiryBadge;
}

/// Persistent navy side rail with the four primary destinations.
///
/// Directionality: the rail is placed by the parent Row, so in Arabic (RTL)
/// it sits on the right automatically. Directional icons are mirrored here.
class SideNavRail extends StatelessWidget {
  const SideNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final int badge = context.watch<ExpiryProvider>().badgeCount;

    return Container(
      width: AppConstants.navRailWidth,
      color: AppColors.deepNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppLogo(height: 34),
                ),
                const SizedBox(height: 10),
                Text(
                  AppConstants.appNameAr,
                  style: AppTextStyles.navItem.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          const SizedBox(height: 10),
          for (int i = 0; i < destinations.length; i++)
            _NavTile(
              destination: destinations[i],
              isSelected: i == selectedIndex,
              badgeCount: destinations[i].showExpiryBadge ? badge : 0,
              onTap: () => onSelected(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              AppConstants.currencyCode,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.destination,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final NavDestination destination;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: <Widget>[
                Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: isSelected ? AppColors.white : AppColors.secondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    destination.label,
                    style: AppTextStyles.navItem.copyWith(
                      color: isSelected ? AppColors.white : AppColors.secondary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.deepNavy,
                        fontWeight: FontWeight.w700,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
