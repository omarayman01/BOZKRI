import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../view_model/cubit/clients/clients_cubit.dart';
import '../../../view_model/cubit/dashboard/dashboard_cubit.dart';
import '../../../view_model/cubit/deals/deals_cubit.dart';
import '../../../view_model/cubit/item_types/item_types_cubit.dart';
import '../../../view_model/cubit/items/items_cubit.dart';
import '../../../view_model/cubit/suppliers/suppliers_cubit.dart';
import '../../../view_model/provider/clients_cache_provider.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/provider/settings_provider.dart';
import '../../../view_model/provider/suppliers_cache_provider.dart';
import '../../constants/app_colors.dart';
import '../../features/cars_features/cars_screen.dart';
import '../../features/clients_features/clients_screen.dart';
import '../../features/dashboard_features/dashboard_screen.dart';
import '../../features/deals_features/deals_screen.dart';
import '../../features/expenses_features/expenses_screen.dart';
import '../../features/suppliers_features/suppliers_screen.dart';
import 'app_routes.dart';
import 'side_nav_rail.dart';

/// Persistent frame: side rail with four destinations plus a settings gear in
/// the top bar. The body swaps between the primary screens without pushing
/// routes, so the rail never disappears.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapData());
  }

  /// Warms the shared caches once, so pickers everywhere have data.
  Future<void> _bootstrapData() async {
    if (!mounted) return;
    final ClientsCacheProvider clients = context.read<ClientsCacheProvider>();
    final SuppliersCacheProvider suppliers =
        context.read<SuppliersCacheProvider>();
    final ItemsCacheProvider items = context.read<ItemsCacheProvider>();
    final ExpiryProvider expiry = context.read<ExpiryProvider>();

    expiry.setWarningDays(context.read<SettingsProvider>().expiryWarningDays);

    await context.read<ClientsCubit>().load(clients);
    if (!mounted) return;
    await context.read<SuppliersCubit>().load(suppliers);
    if (!mounted) return;
    await context.read<ItemTypesCubit>().load(items);
    if (!mounted) return;
    await context.read<ItemsCubit>().loadAll(items, expiry);
    if (!mounted) return;
    await context.read<DealsCubit>().loadDeals();
    if (!mounted) return;
    await context.read<DashboardCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<NavDestination> destinations = <NavDestination>[
      NavDestination(
        label: l10n.navDeals,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      NavDestination(
        label: l10n.navClients,
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
      ),
      NavDestination(
        label: l10n.navSuppliers,
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
      ),
      NavDestination(
        label: l10n.navCars,
        icon: Icons.directions_car_outlined,
        selectedIcon: Icons.directions_car,
      ),
      NavDestination(
        label: l10n.navExpenses,
        icon: Icons.receipt_outlined,
        selectedIcon: Icons.receipt,
      ),
      NavDestination(
        label: l10n.navDashboard,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        showExpiryBadge: true,
      ),
    ];

    const List<Widget> screens = <Widget>[
      DealsScreen(),
      ClientsScreen(),
      SuppliersScreen(),
      CarsScreen(),
      ExpensesScreen(),
      DashboardScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: <Widget>[
          SideNavRail(
            destinations: destinations,
            selectedIndex: _index,
            onSelected: (int i) => setState(() => _index = i),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                _TopBar(title: destinations[_index].label),
                Expanded(
                  child: IndexedStack(index: _index, children: screens),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Container(
      height: 60,
      padding: const EdgeInsetsDirectional.only(start: 24, end: 12),
      decoration: const BoxDecoration(
        color: AppColors.deepNavy,
        border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
          IconButton(
            tooltip: l10n.settings,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined, color: AppColors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
