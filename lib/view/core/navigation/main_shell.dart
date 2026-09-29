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
import '../../../view_model/cubit/sync/sync_cubit.dart';
import '../../../view_model/cubit/sync/sync_state.dart';
import '../../../view_model/provider/clients_cache_provider.dart';
import '../../../view_model/provider/current_user_provider.dart';
import '../../../view_model/provider/expiry_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/provider/settings_provider.dart';
import '../../../view_model/provider/suppliers_cache_provider.dart';
import '../../constants/app_colors.dart';
import '../../features/accounts_features/accounts_screen.dart';
import '../../features/cars_features/cars_screen.dart';
import '../../features/clients_features/clients_screen.dart';
import '../../features/dashboard_features/dashboard_screen.dart';
import '../../features/deals_features/deals_screen.dart';
import '../../features/expenses_features/expenses_screen.dart';
import '../../features/suppliers_features/suppliers_screen.dart';
import '../widgets/offline_banner.dart';
import '../widgets/sync_status_badge.dart';
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

  /// Tracks the last [SyncCubitState.syncVersion] this shell has already
  /// refreshed the cubits for, so [_onSyncStateChanged] only reloads once per
  /// completed sync instead of on every rebuild.
  int _refreshedSyncVersion = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapData());
  }

  /// Warms the shared caches once, so pickers everywhere have data.
  ///
  /// Pulls from Supabase FIRST, before loading anything into the cubits
  /// below — otherwise a screen could render from local data that predates
  /// whatever changed on another device since this one was last open. Sync
  /// failure (e.g. no internet) is not fatal here: local data still loads
  /// so the app stays fully usable offline, per the offline-first design.
  Future<void> _bootstrapData() async {
    if (!mounted) return;
    final SyncCubit syncCubit = context.read<SyncCubit>();
    await syncCubit.syncNow();
    if (!mounted) return;
    _refreshedSyncVersion = syncCubit.state.syncVersion;
    await _refreshCubits();
  }

  /// Reloads every cubit that mirrors synced data from the local database
  /// into its in-memory/cache state. `syncNow()` only pulls Supabase rows
  /// into SQLite — it does not, by itself, make any screen re-render, since
  /// each cubit only reads the database when explicitly told to. Without
  /// this, a manual "آخر مزامنة" tap (or the 60s background sync) could pull
  /// a brand-new row — e.g. a client added directly in the Supabase table
  /// editor — into the local database while every list on screen kept
  /// showing its stale, already-loaded snapshot.
  Future<void> _refreshCubits() async {
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

  /// Fires on every [SyncCubit] emission; reloads the cubits once per newly
  /// completed sync (manual tap or the periodic background one) so fresh
  /// remote data — including rows added straight in Supabase — shows up
  /// without the user having to restart the app.
  void _onSyncStateChanged(BuildContext context, SyncCubitState state) {
    if (state.status != SyncStatus.synced) return;
    if (state.syncVersion == _refreshedSyncVersion) return;
    _refreshedSyncVersion = state.syncVersion;
    _refreshCubits();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isAdmin = context.watch<CurrentUserProvider>().isAdmin;

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
      if (isAdmin)
        const NavDestination(
          label: 'الحسابات',
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts,
        ),
    ];

    final List<Widget> screens = <Widget>[
      const DealsScreen(),
      const ClientsScreen(),
      const SuppliersScreen(),
      const CarsScreen(),
      const ExpensesScreen(),
      const DashboardScreen(),
      if (isAdmin) const AccountsScreen(),
    ];

    final int index = _index >= destinations.length ? 0 : _index;

    return BlocListener<SyncCubit, SyncCubitState>(
      listener: _onSyncStateChanged,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: <Widget>[
            SideNavRail(
              destinations: destinations,
              selectedIndex: index,
              onSelected: (int i) => setState(() => _index = i),
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _TopBar(title: destinations[index].label),
                  const OfflineBanner(),
                  Expanded(
                    child: IndexedStack(index: index, children: screens),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          const SyncStatusBadge(),
          const SizedBox(width: 8),
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
