import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_controller.dart';

/// The back office is for staff, so it is English only.
enum AdminSection {
  overview('Overview', Icons.space_dashboard_outlined, '/admin'),
  people('People', Icons.people_alt_outlined, '/admin/people'),
  jobs('Jobs', Icons.work_outline_rounded, '/admin/jobs'),
  payments(
    'Payments',
    Icons.account_balance_wallet_outlined,
    '/admin/payments',
  ),
  withdrawals('Withdrawals', Icons.outbound_outlined, '/admin/withdrawals'),
  support('Support', Icons.support_agent_outlined, '/admin/support'),
  safety('Safety', Icons.shield_outlined, '/admin/safety'),
  services('Services', Icons.design_services_outlined, '/admin/services'),
  reports('Reports', Icons.insert_chart_outlined_rounded, '/admin/reports'),
  audit('Audit log', Icons.history_rounded, '/admin/audit');

  const AdminSection(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

/// Frame for every admin page: a sidebar on wide screens, a drawer on phones.
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    required this.section,
    required this.title,
    required this.body,
    this.actions = const [],
    this.back,
    super.key,
  });

  final AdminSection section;
  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Where the back arrow goes, for detail pages.
  final String? back;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The app's buttons fill the width, which suits forms on a phone but not
    // toolbars and tables.
    final theme = Theme.of(context);
    const compact = Size(64, 44);
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style!.copyWith(
            minimumSize: const WidgetStatePropertyAll(compact),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: theme.outlinedButtonTheme.style!.copyWith(
            minimumSize: const WidgetStatePropertyAll(compact),
          ),
        ),
      ),
      child: Builder(builder: (context) => _frame(context, ref)),
    );
  }

  Widget _frame(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final content = user == null || !user.isAdmin ? const _NoAccess() : body;
    final wide = context.isWide;
    final header = AppBar(
      automaticallyImplyLeading: !wide,
      leading: back != null
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(back!),
            )
          : null,
      title: Text(title),
      actions: [
        ...actions,
        const SizedBox(width: AppTheme.gapSm),
      ],
    );
    if (!wide) {
      return Scaffold(
        backgroundColor: context.palette.page,
        appBar: header,
        drawer: Drawer(
          child: SafeArea(child: _Nav(current: section)),
        ),
        body: content,
      );
    }
    return Scaffold(
      backgroundColor: context.palette.page,
      body: Row(
        children: [
          SizedBox(width: 240, child: _Nav(current: section)),
          VerticalDivider(width: 1, color: context.palette.line),
          Expanded(
            child: Scaffold(
              backgroundColor: context.palette.page,
              appBar: header,
              body: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.current});

  final AdminSection current;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.gapMd),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                const BrandMark(size: 34),
                const SizedBox(width: AppTheme.gapSm),
                Expanded(child: Wordmark(style: context.text.titleMedium)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, AppTheme.gapLg),
            child: Text(
              'Admin',
              style: context.text.labelMedium!.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
          for (final s in AdminSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ListTile(
                dense: true,
                selected: s == current,
                selectedTileColor: context.colors.primaryContainer,
                selectedColor: context.colors.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                leading: Icon(s.icon, size: 20),
                title: Text(s.label, style: context.text.titleSmall),
                onTap: () {
                  Scaffold.maybeOf(context)?.closeDrawer();
                  context.go(s.path);
                },
              ),
            ),
          const Divider(height: AppTheme.gapXl),
          ListTile(
            dense: true,
            leading: const Icon(Icons.exit_to_app_rounded, size: 20),
            title: Text('Back to the app', style: context.text.titleSmall),
            onTap: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      title: 'Admins only',
      message: 'This account is not an admin. Ask the owner to run the admin command for your phone number.',
      action: FilledButton(
        onPressed: () => context.go('/home'),
        child: const Text('Go to the app'),
      ),
    );
  }
}

/// Scrolling page body with consistent padding and a max width.
class AdminPage extends StatelessWidget {
  const AdminPage({required this.children, this.onRefresh, super.key});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pad = context.isWide ? AppTheme.gapXl : AppTheme.gapLg;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(pad, AppTheme.gapSm, pad, AppTheme.gapXxl),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Loading, error and data states for one admin request.
class AdminAsync<T> extends StatelessWidget {
  const AdminAsync({
    required this.value,
    required this.builder,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(AppTheme.gapXl),
        child: SkeletonCards(),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load this',
        message: ApiException.from(error).message,
        action: OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ),
    );
  }
}

/// A white panel with an optional heading row.
class Panel extends StatelessWidget {
  const Panel({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppTheme.gapLg),
    super.key,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      // Material rather than a decorated box, so list rows can paint their
      // highlights on it.
      child: Material(
        color: context.colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: context.palette.line),
        ),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(title!, style: context.text.titleMedium),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: AppTheme.gapMd),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A headline number with a short label.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.note,
    this.icon,
    this.tone = Tone.brand,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final IconData? icon;
  final Tone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                IconTile(icon: icon!, tone: tone, size: 34),
                const SizedBox(width: AppTheme.gapSm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelMedium!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.palette.muted,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.gapSm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.text.headlineSmall),
          ),
          if (note != null) Text(note!, style: muted, maxLines: 2),
        ],
      ),
    );
  }
}

/// Lays tiles out in as many columns as fit.
class TileGrid extends StatelessWidget {
  const TileGrid({required this.children, this.minWidth = 220, super.key});

  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = (box.maxWidth / minWidth).floor().clamp(1, 6);
          final width =
              (box.maxWidth - AppTheme.gapMd * (columns - 1)) / columns;
          return Wrap(
            spacing: AppTheme.gapMd,
            runSpacing: AppTheme.gapMd,
            children: [
              for (final c in children) SizedBox(width: width, child: c),
            ],
          );
        },
      ),
    );
  }
}

/// One series of daily bars. A single series needs no legend: the panel title
/// names it. Each bar has a tooltip, and the totals sit in a table elsewhere.
class DailyBars extends StatelessWidget {
  const DailyBars({
    required this.labels,
    required this.values,
    required this.format,
    this.height = 160,
    super.key,
  });

  final List<String> labels;
  final List<int> values;
  final String Function(int value) format;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = values.fold(0, (a, b) => a > b ? a : b);
    final muted = context.text.labelSmall!.copyWith(
      color: context.palette.muted,
    );
    final bar = context.colors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [Text('Peak ${format(top)}', style: muted)]),
        const SizedBox(height: AppTheme.gapSm),
        SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.palette.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${labels[i]}: ${format(values[i])}',
                      waitDuration: Duration.zero,
                      child: Container(
                        // The full column height is the hover target, bigger
                        // than the bar itself.
                        color: Colors.transparent,
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: FractionallySizedBox(
                          heightFactor: top == 0
                              ? 0
                              : (values[i] / top).clamp(0.0, 1.0),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 0),
                            decoration: BoxDecoration(
                              color: values[i] == 0 ? null : bar,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(labels.isEmpty ? '' : labels.first, style: muted),
            const Spacer(),
            Text(labels.isEmpty ? '' : labels.last, style: muted),
          ],
        ),
      ],
    );
  }
}

/// A simple table that scrolls sideways on narrow screens.
class AdminTable extends StatelessWidget {
  const AdminTable({
    required this.columns,
    required this.rows,
    this.numeric = const {},
    this.onTap,
    super.key,
  });

  final List<String> columns;
  final List<List<Widget>> rows;

  /// Column indexes to right-align.
  final Set<int> numeric;
  final void Function(int index)? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 40,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            horizontalMargin: AppTheme.gapMd,
            columnSpacing: AppTheme.gapXl,
            headingTextStyle: context.text.labelMedium!.copyWith(
              color: context.palette.muted,
            ),
            columns: [
              for (var i = 0; i < columns.length; i++)
                DataColumn(
                  label: Text(columns[i]),
                  numeric: numeric.contains(i),
                ),
            ],
            rows: [
              for (var r = 0; r < rows.length; r++)
                DataRow(
                  onSelectChanged: onTap == null ? null : (_) => onTap!(r),
                  cells: [for (final c in rows[r]) DataCell(c)],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Previous and next buttons for a paged list.
class Pager extends StatelessWidget {
  const Pager({
    required this.page,
    required this.hasMore,
    required this.onPage,
    super.key,
  });

  final int page;
  final bool hasMore;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (page <= 1 && !hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.gapMd),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppTheme.gapSm,
        runSpacing: AppTheme.gapSm,
        children: [
          OutlinedButton.icon(
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Newer'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.gapMd),
            child: Text('Page $page', style: context.text.labelMedium),
          ),
          OutlinedButton.icon(
            onPressed: hasMore ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Older'),
          ),
        ],
      ),
    );
  }
}

/// Search box that reports on submit, plus a row of filter chips.
class FilterBar extends StatefulWidget {
  const FilterBar({
    required this.hint,
    required this.query,
    required this.onSearch,
    required this.filters,
    required this.selected,
    required this.onFilter,
    super.key,
  });

  final String hint;
  final String query;
  final ValueChanged<String> onSearch;

  /// Value to label, in display order.
  final Map<String, String> filters;
  final String selected;
  final ValueChanged<String> onFilter;

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hint.isNotEmpty)
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: () => widget.onSearch(_controller.text),
                ),
              ),
            ),
          const SizedBox(height: AppTheme.gapMd),
          Wrap(
            spacing: AppTheme.gapSm,
            runSpacing: AppTheme.gapSm,
            children: [
              for (final e in widget.filters.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: widget.selected == e.key,
                  onSelected: (_) => widget.onFilter(e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const jobStatusLabels = {
  'BROADCASTING': 'Collecting bids',
  'ESCALATING': 'Widening search',
  'MANUAL_FALLBACK': 'No provider found',
  'ACCEPTED': 'Booked',
  'IN_PROGRESS': 'Work started',
  'COMPLETED': 'Completed',
  'CANCELLED': 'Cancelled',
  'DISPUTED': 'Disputed',
  'EXPIRED': 'Expired',
};

Tone jobStatusTone(String status) => switch (status) {
  'COMPLETED' => Tone.success,
  'DISPUTED' || 'MANUAL_FALLBACK' => Tone.danger,
  'CANCELLED' || 'EXPIRED' => Tone.neutral,
  'ACCEPTED' || 'IN_PROGRESS' => Tone.info,
  _ => Tone.brand,
};

class JobStatusPill extends StatelessWidget {
  const JobStatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => Pill(
    label: jobStatusLabels[status] ?? status,
    tone: jobStatusTone(status),
  );
}

const entryTypeLabels = {
  'TOP_UP': 'Top-up',
  'ESCROW_HOLD': 'Held for a job',
  'ESCROW_REFUND': 'Refund',
  'PAYOUT': 'Payout',
  'COMMISSION': 'Commission',
  'WITHDRAWAL': 'Withdrawal requested',
  'WITHDRAWAL_PAID': 'Withdrawal sent',
  'WITHDRAWAL_RETURNED': 'Withdrawal returned',
};

String shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "13 Nov 2026, 17:05" in the viewer's local time.
String dateTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.day} ${_months[l.month - 1]} ${l.year}, ${two(l.hour)}:${two(l.minute)}';
}

/// "13 Nov" from "2026-11-13".
String dayLabel(String isoDay) {
  final parts = isoDay.split('-');
  if (parts.length != 3) return isoDay;
  return '${int.parse(parts[2])} ${_months[int.parse(parts[1]) - 1]}';
}

/// Rupees with a sign for ledger amounts.
String signedRupees(int paisa) =>
    paisa > 0 ? '+${paisa.asRupees}' : paisa.asRupees;

/// Copyable ID text.
class IdText extends StatelessWidget {
  const IdText(this.id, {super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      id,
      style: context.text.bodySmall!.copyWith(color: context.palette.muted),
    );
  }
}

/// A label and value on one line, for detail panels.
class Fact extends StatelessWidget {
  const Fact(this.label, this.value, {super.key});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: context.text.bodySmall!.copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}
