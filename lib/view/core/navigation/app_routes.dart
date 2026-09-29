import 'package:flutter/material.dart';

import '../../../model/item_model.dart';
import '../../features/cars_features/add_edit_car_screen.dart';
import '../../features/clients_features/add_edit_client_screen.dart';
import '../../features/clients_features/client_detail_screen.dart';
import '../../features/deals_features/add_edit_deal_screen.dart';
import '../../features/deals_features/deal_detail_screen.dart';
import '../../features/deals_features/refund_screen.dart';
import '../../features/auth_features/auth_gate.dart';
import '../../features/settings_features/settings_screen.dart';
import '../../features/suppliers_features/add_edit_item_screen.dart';
import '../../features/suppliers_features/add_edit_supplier_screen.dart';
import '../../features/suppliers_features/supplier_detail_screen.dart';

/// Named routes for the pages pushed on top of the persistent shell.
/// The four primary destinations are tabs inside [MainShell], not routes.
class AppRoutes {
  const AppRoutes._();

  static const String shell = '/';
  static const String settings = '/settings';

  static const String addEditClient = '/clients/edit';
  static const String clientDetail = '/clients/detail';

  static const String addEditSupplier = '/suppliers/edit';
  static const String supplierDetail = '/suppliers/detail';
  static const String addEditItem = '/suppliers/items/edit';

  static const String addEditDeal = '/deals/edit';
  static const String dealDetail = '/deals/detail';
  static const String refund = '/deals/refund';

  static const String addEditCar = '/cars/edit';

  static Route<Object?> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case shell:
        return _page(const AuthGate(), settings);

      case AppRoutes.settings:
        return _page(const SettingsScreen(), settings);

      case addEditClient:
        return _page(
          AddEditClientScreen(client: settings.arguments as dynamic),
          settings,
        );

      case clientDetail:
        return _page(
          ClientDetailScreen(clientId: settings.arguments! as int),
          settings,
        );

      case addEditSupplier:
        return _page(
          AddEditSupplierScreen(supplier: settings.arguments as dynamic),
          settings,
        );

      case supplierDetail:
        return _page(
          SupplierDetailScreen(supplierId: settings.arguments! as int),
          settings,
        );

      case addEditItem:
        final AddEditItemArgs args = settings.arguments! as AddEditItemArgs;
        return _page(
          AddEditItemScreen(supplierId: args.supplierId, item: args.item),
          settings,
        );

      case addEditDeal:
        return _page(
          AddEditDealScreen(dealId: settings.arguments as int?),
          settings,
        );

      case dealDetail:
        return _page(
          DealDetailScreen(dealId: settings.arguments! as int),
          settings,
        );

      case refund:
        return _page(
          RefundScreen(dealId: settings.arguments! as int),
          settings,
        );

      case addEditCar:
        return _page(
          AddEditCarScreen(car: settings.arguments as ItemModel?),
          settings,
        );

      default:
        return _page(
          Scaffold(
            appBar: AppBar(title: const Text('الصفحة غير موجودة')),
            body: Center(child: Text('No route for ${settings.name}')),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute<Object?> _page(Widget child, RouteSettings settings) =>
      MaterialPageRoute<Object?>(builder: (BuildContext _) => child, settings: settings);
}
