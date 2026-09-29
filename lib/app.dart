import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';
import 'view/constants/app_constants.dart';
import 'view/constants/app_theme.dart';
import 'view/core/navigation/app_routes.dart';
import 'view/core/widgets/network_activity_indicator.dart';
import 'view_model/config/supabase_config.dart';
import 'view_model/cubit/accounts/accounts_cubit.dart';
import 'view_model/cubit/auth/auth_cubit.dart';
import 'view_model/cubit/clients/client_detail_cubit.dart';
import 'view_model/cubit/clients/clients_cubit.dart';
import 'view_model/cubit/dashboard/dashboard_cubit.dart';
import 'view_model/cubit/deals/deals_cubit.dart';
import 'view_model/cubit/expenses/expenses_cubit.dart';
import 'view_model/cubit/item_types/item_types_cubit.dart';
import 'view_model/cubit/items/items_cubit.dart';
import 'view_model/cubit/payments/payments_cubit.dart';
import 'view_model/cubit/refund/refund_cubit.dart';
import 'view_model/cubit/settings/settings_cubit.dart';
import 'view_model/cubit/sync/sync_cubit.dart';
import 'view_model/cubit/suppliers/supplier_detail_cubit.dart';
import 'view_model/cubit/suppliers/suppliers_cubit.dart';
import 'view_model/database/local/app_database.dart';
import 'view_model/provider/clients_cache_provider.dart';
import 'view_model/provider/connectivity_provider.dart';
import 'view_model/provider/current_user_provider.dart';
import 'view_model/provider/network_activity_provider.dart';
import 'view_model/provider/expiry_provider.dart';
import 'view_model/provider/items_cache_provider.dart';
import 'view_model/provider/settings_provider.dart';
import 'view_model/provider/suppliers_cache_provider.dart';
import 'view_model/provider/transaction_draft_provider.dart';
import 'view_model/provider/user_directory_provider.dart';
import 'view_model/repos/accounts_repo.dart';
import 'view_model/repos/accounts_repo_impl.dart';
import 'view_model/repos/auth_repo.dart';
import 'view_model/repos/auth_repo_impl.dart';
import 'view_model/repos/clients_repo.dart';
import 'view_model/repos/clients_repo_impl.dart';
import 'view_model/repos/dashboard_repo.dart';
import 'view_model/repos/dashboard_repo_impl.dart';
import 'view_model/repos/expenses_repo.dart';
import 'view_model/repos/expenses_repo_impl.dart';
import 'view_model/repos/item_types_repo.dart';
import 'view_model/repos/item_types_repo_impl.dart';
import 'view_model/repos/items_repo.dart';
import 'view_model/repos/items_repo_impl.dart';
import 'view_model/repos/payments_repo.dart';
import 'view_model/repos/payments_repo_impl.dart';
import 'view_model/repos/refunds_repo.dart';
import 'view_model/repos/refunds_repo_impl.dart';
import 'view_model/repos/suppliers_repo.dart';
import 'view_model/repos/suppliers_repo_impl.dart';
import 'view_model/repos/transactions_repo.dart';
import 'view_model/repos/transactions_repo_impl.dart';
import 'view_model/sync/sync_engine.dart';
import 'view_model/sync/tracking_http_client.dart';

/// Single composition root. There is no DI container: the database, the
/// repositories, the providers and the cubits are all constructed here and
/// handed down through MultiProvider / BlocProvider.value.
///
/// The [AppDatabase] is constructed and awaited before `runApp`, so no screen
/// can ever observe a half-open connection.
Future<Widget> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final NetworkActivityProvider networkActivity = NetworkActivityProvider();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
    httpClient: TrackingHttpClient(networkActivity),
  );

  final AppDatabase database = await AppDatabase.open();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  // ---- Repositories (constructed from the live database) ----
  final AuthRepo authRepo = AuthRepoImpl(Supabase.instance.client);
  final AccountsRepo accountsRepo = AccountsRepoImpl(Supabase.instance.client);
  final ClientsRepo clientsRepo = ClientsRepoImpl(database.clientsDao, database);
  final SuppliersRepo suppliersRepo =
      SuppliersRepoImpl(database.suppliersDao, database);
  final ItemTypesRepo itemTypesRepo =
      ItemTypesRepoImpl(database.itemTypesDao, database);
  final ItemsRepo itemsRepo = ItemsRepoImpl(database.itemsDao, database);
  final TransactionsRepo transactionsRepo =
      TransactionsRepoImpl(database.transactionsDao);
  final PaymentsRepo paymentsRepo = PaymentsRepoImpl(database.paymentsDao);
  final RefundsRepo refundsRepo = RefundsRepoImpl(database.refundsDao);
  final ExpensesRepo expensesRepo =
      ExpensesRepoImpl(database.expensesDao, database);
  final DashboardRepo dashboardRepo = DashboardRepoImpl(database.dashboardDao);

  // ---- Providers (shared in-memory state) ----
  final CurrentUserProvider currentUserProvider = CurrentUserProvider();
  final ConnectivityProvider connectivityProvider = ConnectivityProvider();
  final SettingsProvider settingsProvider = SettingsProvider(prefs);
  final ClientsCacheProvider clientsCache = ClientsCacheProvider();
  final SuppliersCacheProvider suppliersCache = SuppliersCacheProvider();
  final ItemsCacheProvider itemsCache = ItemsCacheProvider();
  final ExpiryProvider expiryProvider =
      ExpiryProvider(warningDays: settingsProvider.expiryWarningDays);
  final TransactionDraftProvider draftProvider = TransactionDraftProvider();
  final UserDirectoryProvider userDirectory = UserDirectoryProvider(accountsRepo);

  // ---- Cubits (async / DB I/O) ----
  final AuthCubit authCubit = AuthCubit(authRepo, currentUserProvider);
  final AccountsCubit accountsCubit = AccountsCubit(accountsRepo);
  final SyncEngine syncEngine =
      SyncEngine(database, Supabase.instance.client, currentUserProvider);
  final SyncCubit syncCubit =
      SyncCubit(syncEngine, connectivityProvider, authCubit);
  final ClientsCubit clientsCubit = ClientsCubit(clientsRepo);
  final ClientDetailCubit clientDetailCubit = ClientDetailCubit(clientsRepo);
  final SuppliersCubit suppliersCubit = SuppliersCubit(suppliersRepo);
  final SupplierDetailCubit supplierDetailCubit =
      SupplierDetailCubit(suppliersRepo);
  final ItemTypesCubit itemTypesCubit = ItemTypesCubit(itemTypesRepo);
  final ItemsCubit itemsCubit = ItemsCubit(itemsRepo);
  final DealsCubit dealsCubit = DealsCubit(transactionsRepo);
  final PaymentsCubit paymentsCubit = PaymentsCubit(paymentsRepo);
  final RefundCubit refundCubit = RefundCubit(refundsRepo, transactionsRepo);
  final ExpensesCubit expensesCubit = ExpensesCubit(expensesRepo, paymentsRepo);
  final DashboardCubit dashboardCubit = DashboardCubit(dashboardRepo);
  final SettingsCubit settingsCubit = SettingsCubit(
    database,
    transactionsRepo: transactionsRepo,
    itemsRepo: itemsRepo,
    itemTypesRepo: itemTypesRepo,
    clientsRepo: clientsRepo,
    suppliersRepo: suppliersRepo,
    expensesRepo: expensesRepo,
    syncEngine: syncEngine,
  );

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<AppDatabase>.value(value: database),
      ChangeNotifierProvider<CurrentUserProvider>.value(
          value: currentUserProvider),
      ChangeNotifierProvider<ConnectivityProvider>.value(
          value: connectivityProvider),
      ChangeNotifierProvider<NetworkActivityProvider>.value(
          value: networkActivity),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ChangeNotifierProvider<ClientsCacheProvider>.value(value: clientsCache),
      ChangeNotifierProvider<SuppliersCacheProvider>.value(
          value: suppliersCache),
      ChangeNotifierProvider<ItemsCacheProvider>.value(value: itemsCache),
      ChangeNotifierProvider<ExpiryProvider>.value(value: expiryProvider),
      ChangeNotifierProvider<TransactionDraftProvider>.value(
          value: draftProvider),
      ChangeNotifierProvider<UserDirectoryProvider>.value(
          value: userDirectory),
      BlocProvider<AuthCubit>.value(value: authCubit),
      BlocProvider<AccountsCubit>.value(value: accountsCubit),
      BlocProvider<SyncCubit>.value(value: syncCubit),
      BlocProvider<ClientsCubit>.value(value: clientsCubit),
      BlocProvider<ClientDetailCubit>.value(value: clientDetailCubit),
      BlocProvider<SuppliersCubit>.value(value: suppliersCubit),
      BlocProvider<SupplierDetailCubit>.value(value: supplierDetailCubit),
      BlocProvider<ItemTypesCubit>.value(value: itemTypesCubit),
      BlocProvider<ItemsCubit>.value(value: itemsCubit),
      BlocProvider<DealsCubit>.value(value: dealsCubit),
      BlocProvider<PaymentsCubit>.value(value: paymentsCubit),
      BlocProvider<RefundCubit>.value(value: refundCubit),
      BlocProvider<ExpensesCubit>.value(value: expensesCubit),
      BlocProvider<DashboardCubit>.value(value: dashboardCubit),
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
    ],
    child: const AgencyApp(),
  );
}

class AgencyApp extends StatelessWidget {
  const AgencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The app is Arabic-only, RTL-only — there is no language toggle.
    return MaterialApp(
      title: AppConstants.appNameAr,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: AppConstants.localeAr,
      supportedLocales: AppConstants.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      initialRoute: AppRoutes.shell,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      builder: (BuildContext context, Widget? child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: <Widget>[
              child ?? const SizedBox.shrink(),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NetworkActivityIndicator(),
              ),
            ],
          ),
        );
      },
    );
  }
}
