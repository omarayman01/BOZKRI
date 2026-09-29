import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../model/user_profile_model.dart';
import '../../../view_model/cubit/accounts/accounts_cubit.dart';
import '../../../view_model/cubit/accounts/accounts_state.dart';
import '../../../view_model/provider/current_user_provider.dart';
import '../../constants/app_constants.dart';
import '../../core/widgets/error_state_widget.dart';
import '../../core/widgets/loading_widget.dart';
import 'widgets/audit_log_list.dart';
import 'widgets/user_row.dart';

/// Admin-only: approve/deactivate accounts, change roles, and review the
/// action audit trail (Phase 22).
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<AccountsCubit>().load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            tabs: const <Widget>[
              Tab(text: 'المستخدمون'),
              Tab(text: 'سجل النشاط'),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<AccountsCubit, AccountsState>(
            builder: (BuildContext context, AccountsState state) {
              if (state.isLoading && state.users.isEmpty) {
                return const LoadingWidget();
              }
              if (state.isFailure && state.users.isEmpty) {
                return ErrorStateWidget(
                  title: 'تعذر التحميل',
                  message: state.errorMessage ?? '',
                  retryLabel: 'إعادة المحاولة',
                  onRetry: () => context.read<AccountsCubit>().load(),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(AppConstants.contentPadding),
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _UsersList(users: state.users),
                    AuditLogList(entries: state.auditLog),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.users});

  final List<UserProfileModel> users;

  @override
  Widget build(BuildContext context) {
    final String? myId = context.watch<CurrentUserProvider>().userId;

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int i) {
        final UserProfileModel user = users[i];
        return UserRow(user: user, isSelf: user.id == myId);
      },
    );
  }
}
