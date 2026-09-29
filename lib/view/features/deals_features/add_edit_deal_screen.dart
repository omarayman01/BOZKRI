import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/client_model.dart';
import '../../../model/payment_model.dart';
import '../../../model/transaction_model.dart';
import '../../../model/transaction_with_items_model.dart';
import '../../../view_model/cubit/deals/deals_cubit.dart';
import '../../../view_model/cubit/deals/deals_state.dart';
import '../../../view_model/database/local/daos/transactions_dao.dart';
import '../../../view_model/provider/clients_cache_provider.dart';
import '../../../view_model/provider/items_cache_provider.dart';
import '../../../view_model/provider/transaction_draft_provider.dart';
import '../../../view_model/utils/currency_formatter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../constants/app_text_styles.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/date_range_picker_field.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import '../../core/widgets/party_picker.dart';
import '../../core/widgets/primary_button.dart';
import '../clients_features/add_edit_client_screen.dart';
import 'widgets/deal_line_editor.dart';

/// The deal builder: pick a client, add lines (supplier → item cascade with
/// auto-filled editable snapshots), set a discount, then commit.
///
/// State lives in [TransactionDraftProvider]; the commit itself runs through
/// [DealsCubit] as a single Drift transaction.
class AddEditDealScreen extends StatefulWidget {
  const AddEditDealScreen({super.key, this.dealId});

  /// Null for a new deal; set when editing an existing one.
  final int? dealId;

  @override
  State<AddEditDealScreen> createState() => _AddEditDealScreenState();
}

class _AddEditDealScreenState extends State<AddEditDealScreen> {
  final TextEditingController _discount = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _commissionName = TextEditingController();
  final TextEditingController _commissionAmount = TextEditingController();
  bool _loading = true;

  bool get _isEditing => widget.dealId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareDraft());
  }

  @override
  void dispose() {
    _discount.dispose();
    _notes.dispose();
    _commissionName.dispose();
    _commissionAmount.dispose();
    super.dispose();
  }

  Future<void> _prepareDraft() async {
    final TransactionDraftProvider draft =
        context.read<TransactionDraftProvider>();

    if (!_isEditing) {
      draft.startNew();
      _discount.text = '0';
      setState(() => _loading = false);
      return;
    }

    final DealsCubit deals = context.read<DealsCubit>();
    await deals.loadDeal(widget.dealId!);
    if (!mounted) return;

    final TransactionWithItemsModel? deal = deals.state.selectedDeal;
    if (deal != null) {
      final ClientModel? client =
          context.read<ClientsCacheProvider>().byId(deal.transaction.clientId);
      draft.loadForEdit(deal, client: client);
      _discount.text = '${deal.transaction.discount}';
      _notes.text = deal.transaction.notes ?? '';
      _commissionName.text = deal.transaction.commissionName ?? '';
      _commissionAmount.text =
          deal.transaction.commissionAmount == null ? '' : '${deal.transaction.commissionAmount}';
    }
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final TransactionDraftProvider draft =
        context.read<TransactionDraftProvider>();
    final DealsCubit cubit = context.read<DealsCubit>();
    final ItemsCacheProvider itemsCache = context.read<ItemsCacheProvider>();

    if (_isEditing) {
      final bool confirmed = await ConfirmDialog.show(
        context,
        title: 'حفظ التغييرات على هذه الصفقة؟',
        message: 'سيتم استبدال قيم التكلفة والسعر المحفوظة بالقيم الجديدة.',
        confirmLabel: 'حفظ التغييرات',
        warning: AppLocalizations.of(context).editDealWarning,
      );
      if (!confirmed || !mounted) return;

      final bool ok = await cubit.editDeal(draft, itemsCache: itemsCache);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        _showError(cubit);
      }
      return;
    }

    final int? id = await cubit.commit(draft, itemsCache: itemsCache);
    if (!mounted) return;
    if (id != null) {
      Navigator.of(context).pop(true);
    } else {
      _showError(cubit);
    }
  }

  void _showError(DealsCubit cubit) {
    final String? message = cubit.state.errorMessage;
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
    cubit.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TransactionDraftProvider draft =
        context.watch<TransactionDraftProvider>();
    final ClientsCacheProvider clients = context.watch<ClientsCacheProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? l10n.editDeal : l10n.newDeal)),
      body: _loading
          ? LoadingWidget(message: l10n.loading)
          : Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppConstants.contentPadding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _header(context, draft, clients, l10n),
                            const SizedBox(height: 24),
                            Row(
                              children: <Widget>[
                                Text(l10n.lineItems,
                                    style: AppTextStyles.title),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: draft.client == null
                                      ? null
                                      : () => draft.addLine(
                                            DealLineInput(
                                              itemId: 0,
                                              supplierId: 0,
                                              dealType: draft.dealType,
                                              qty: 1,
                                              unitCost: 0,
                                              unitPrice: 0,
                                            ),
                                          ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: Text(l10n.addLine),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (draft.client == null)
                              EmptyStateWidget(
                                title: l10n.pickClientFirst,
                                icon: Icons.person_search_outlined,
                              )
                            else if (!draft.hasLines)
                              EmptyStateWidget(
                                title: 'لا توجد سطور بعد',
                                message:
                                    'أضف سطراً، اختر مورداً، ثم اختر أحد '
                                    'عناصره المتاحة.',
                                icon: Icons.playlist_add,
                                actionLabel: l10n.addLine,
                                onAction: () => draft.addLine(
                                  DealLineInput(
                                    itemId: 0,
                                    supplierId: 0,
                                    dealType: draft.dealType,
                                    qty: 1,
                                    unitCost: 0,
                                    unitPrice: 0,
                                  ),
                                ),
                              )
                            else
                              for (int i = 0; i < draft.lines.length; i++)
                                DealLineEditor(
                                  key: ValueKey<int>(i),
                                  index: i,
                                  line: draft.lines[i],
                                  dealType: draft.dealType,
                                  onChanged: (DealLineInput line) =>
                                      draft.updateLine(i, line),
                                  onRemove: () => draft.removeLine(i),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _footer(context, draft, l10n),
              ],
            ),
    );
  }

  /// "+" next to the client field — opens the same Add Client form used
  /// from the Clients tab, and selects the newly created client for this
  /// deal on success, without leaving the deal screen.
  Future<void> _addClientInline(
      BuildContext context, TransactionDraftProvider draft) async {
    final ClientModel? created = await Navigator.of(context).push<ClientModel>(
      MaterialPageRoute<ClientModel>(
        builder: (_) => const AddEditClientScreen(),
      ),
    );
    if (created != null) draft.setClient(created);
  }

  Widget _header(
    BuildContext context,
    TransactionDraftProvider draft,
    ClientsCacheProvider clients,
    AppLocalizations l10n,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: ClientPicker(
                          clients: clients.activeClients,
                          selected: draft.client,
                          onSelected: draft.setClient,
                          label: l10n.client,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton(
                          tooltip: 'عميل جديد',
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          color: AppColors.primary,
                          onPressed: () => _addClientInline(context, draft),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<DealType>(
                    value: draft.dealType,
                    decoration: InputDecoration(labelText: l10n.dealType),
                    items: DealType.values
                        .map((DealType t) => DropdownMenuItem<DealType>(
                              value: t,
                              child: Text(_dealTypeLabel(t, l10n)),
                            ))
                        .toList(),
                    onChanged: (DealType? t) =>
                        t == null ? null : draft.setDealType(t),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleDateField(
                    label: l10n.date,
                    value: draft.dateTime,
                    onChanged: (DateTime? v) =>
                        draft.setDateTime(v ?? DateTime.now()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: l10n.notes,
              controller: _notes,
              maxLines: 2,
              onChanged: draft.setNotes,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'اسم العمولة (اختياري)',
                    controller: _commissionName,
                    onChanged: draft.setCommissionName,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppTextField.money(
                    label: 'مبلغ العمولة (اختياري)',
                    controller: _commissionAmount,
                    onChanged: (String raw) => draft
                        .setCommissionAmount(CurrencyFormatter.parse(raw)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<PaymentStatus?>(
                    value: draft.paymentStatusOverride,
                    decoration: const InputDecoration(
                        labelText: 'حالة الدفع (يدوي)'),
                    items: const <DropdownMenuItem<PaymentStatus?>>[
                      DropdownMenuItem<PaymentStatus?>(
                          value: null, child: Text('تلقائي (مشتق)')),
                      DropdownMenuItem<PaymentStatus?>(
                          value: PaymentStatus.paid, child: Text('مدفوع')),
                      DropdownMenuItem<PaymentStatus?>(
                          value: PaymentStatus.unpaid, child: Text('غير مدفوع')),
                    ],
                    onChanged: draft.setPaymentStatusOverride,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, TransactionDraftProvider draft,
      AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 180,
            child: AppTextField.money(
              label: l10n.discount,
              controller: _discount,
              onChanged: (String raw) =>
                  draft.setDiscount(CurrencyFormatter.parse(raw) ?? 0),
            ),
          ),
          const SizedBox(width: 28),
          _Total(label: l10n.subtotal, value: draft.subtotal),
          const SizedBox(width: 24),
          _Total(label: l10n.cost, value: draft.totalCost),
          const SizedBox(width: 24),
          _Total(label: l10n.total, value: draft.total, emphasise: true),
          const SizedBox(width: 24),
          _Total(
            label: l10n.profit,
            value: draft.profit,
            color: draft.profit >= 0 ? AppColors.success : AppColors.danger,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 12),
          BlocBuilder<DealsCubit, DealsState>(
            builder: (BuildContext context, DealsState state) {
              return PrimaryButton(
                label: _isEditing ? l10n.saveChanges : l10n.commitDeal,
                icon: Icons.check,
                isLoading: state.isSaving,
                onPressed: draft.canCommit ? _submit : null,
              );
            },
          ),
        ],
      ),
    );
  }

  static String _dealTypeLabel(DealType type, AppLocalizations l10n) {
    switch (type) {
      case DealType.sell:
        return l10n.dealTypeSell;
      case DealType.rent:
        return l10n.dealTypeRent;
      case DealType.broker:
        return l10n.dealTypeBroker;
      case DealType.service:
        return l10n.dealTypeService;
    }
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    this.color,
    this.emphasise = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(value),
          style: (emphasise ? AppTextStyles.moneyLarge : AppTextStyles.money)
              .copyWith(color: color),
          textDirection: TextDirection.ltr,
        ),
      ],
    );
  }
}
