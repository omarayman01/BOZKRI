import 'package:flutter/material.dart';

import '../../../../model/top_party_model.dart';
import '../../../core/navigation/app_routes.dart';
import 'top_clients_list.dart';

/// Ranked suppliers by their own cost slice, net of refunded cost.
class TopSuppliersList extends StatelessWidget {
  const TopSuppliersList({super.key, required this.suppliers});

  final List<TopPartyModel> suppliers;

  @override
  Widget build(BuildContext context) {
    return TopPartyPanel(
      title: 'أفضل الموردين',
      icon: Icons.store_outlined,
      parties: suppliers,
      valueLabel: 'Cost',
      onTap: (TopPartyModel p) => Navigator.of(context)
          .pushNamed(AppRoutes.supplierDetail, arguments: p.id),
    );
  }
}
