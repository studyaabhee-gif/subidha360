import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/admin_api.dart';
import '../data/admin_ops_api.dart';
import 'admin_widgets.dart';

const _topicLabels = {
  'job': 'A job',
  'payment': 'Payments',
  'account': 'Account',
  'safety': 'Safety',
  'other': 'Other',
};

class AdminSupportPage extends ConsumerWidget {
  const AdminSupportPage({this.status = 'OPEN', this.page = 1, super.key});

  final String status;
  final int page;

  void _go(BuildContext context, {String? status, int page = 1}) => context.go(
    Uri(
      path: '/admin/support',
      queryParameters: {
        'status': status ?? this.status,
        if (page > 1) 'page': '$page',
      },
    ).toString(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (status: status, page: page);
    final value = ref.watch(adminInboxProvider(query));
    return AdminScaffold(
      section: AdminSection.support,
      title: 'Support',
      body: AdminPage(
        onRefresh: () => ref.refresh(adminInboxProvider(query).future),
        children: [
          FilterBar(
            hint: '',
            query: '',
            onSearch: (_) {},
            filters: const {'OPEN': 'Open', 'CLOSED': 'Closed', '': 'All'},
            selected: status,
            onFilter: (s) => _go(context, status: s),
          ),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminInboxProvider(query)),
            builder: (p) => p.items.isEmpty
                ? const EmptyState(
                    icon: Icons.mark_chat_read_outlined,
                    title: 'Inbox clear',
                    message: 'No conversations here.',
                  )
                : Panel(
                    padding: const EdgeInsets.all(AppTheme.gapSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminTable(
                          columns: const [
                            'Subject',
                            'From',
                            'About',
                            'Last message',
                            '',
                          ],
                          onTap: (i) =>
                              context.push('/admin/support/${p.items[i].id}'),
                          rows: [
                            for (final t in p.items)
                              [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: Text(
                                    t.subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.unreadByStaff
                                        ? context.text.titleSmall
                                        : null,
                                  ),
                                ),
                                Text(t.person.label),
                                Text(_topicLabels[t.topic] ?? t.topic),
                                Text(dateTime(t.lastMessageAt)),
                                t.unreadByStaff
                                    ? const Pill(
                                        label: 'Waiting for us',
                                        tone: Tone.warning,
                                      )
                                    : t.status == 'CLOSED'
                                    ? const Pill(
                                        label: 'Closed',
                                        tone: Tone.neutral,
                                      )
                                    : const Pill(
                                        label: 'Answered',
                                        tone: Tone.success,
                                      ),
                              ],
                          ],
                        ),
                        Pager(
                          page: page,
                          hasMore: p.hasMore,
                          onPage: (n) => _go(context, page: n),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminThreadPage extends ConsumerStatefulWidget {
  const AdminThreadPage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<AdminThreadPage> createState() => _AdminThreadPageState();
}

class _AdminThreadPageState extends ConsumerState<AdminThreadPage> {
  final _reply = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(adminThreadProvider(widget.id));
    ref.invalidate(adminInboxProvider);
    ref.invalidate(overviewProvider);
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminOpsApiProvider).reply(widget.id, body);
      _reply.clear();
      _refresh();
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    try {
      await ref.read(adminOpsApiProvider).close(widget.id);
      _refresh();
      if (mounted) context.showMessage('Closed. They can still reply.');
    } catch (error) {
      if (mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminThreadProvider(widget.id));
    return AdminScaffold(
      section: AdminSection.support,
      title: value.value?.thread.subject ?? 'Conversation',
      back: '/admin/support',
      actions: [
        if (value.value?.thread.status == 'OPEN')
          TextButton(onPressed: _close, child: const Text('Close')),
      ],
      body: AdminAsync(
        value: value,
        onRetry: () => ref.invalidate(adminThreadProvider(widget.id)),
        builder: (v) {
          final muted = context.text.bodySmall!.copyWith(
            color: context.palette.muted,
          );
          final t = v.thread;
          return AdminPage(
            children: [
              Panel(
                child: Wrap(
                  spacing: AppTheme.gapLg,
                  runSpacing: AppTheme.gapSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'From ${t.person.label}',
                      style: context.text.titleSmall,
                    ),
                    Text(_topicLabels[t.topic] ?? t.topic, style: muted),
                    TextButton(
                      onPressed: () =>
                          context.push('/admin/people/${t.person.id}'),
                      child: const Text('Their account'),
                    ),
                    if (t.jobId.isNotEmpty)
                      TextButton(
                        onPressed: () => context.push('/admin/jobs/${t.jobId}'),
                        child: const Text('The job'),
                      ),
                  ],
                ),
              ),
              for (final m in v.messages)
                Align(
                  alignment: m.fromStaff
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.gapSm),
                      padding: const EdgeInsets.all(AppTheme.gapMd),
                      decoration: BoxDecoration(
                        color: m.fromStaff
                            ? context.colors.primaryContainer
                            : context.colors.surface,
                        border: Border.all(color: context.palette.line),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.fromStaff ? 'Subidha360 team' : t.person.label,
                            style: context.text.labelMedium,
                          ),
                          SelectableText(m.body),
                          Text(dateTime(m.createdAt), style: muted),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppTheme.gapMd),
              TextField(
                controller: _reply,
                minLines: 3,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Reply (they get a notification)',
                  alignLabelWithHint: true,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send reply'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminSafetyPage extends ConsumerWidget {
  const AdminSafetyPage({this.status = 'OPEN', this.page = 1, super.key});

  final String status;
  final int page;

  void _go(BuildContext context, {String? status, int page = 1}) => context.go(
    Uri(
      path: '/admin/safety',
      queryParameters: {
        'status': status ?? this.status,
        if (page > 1) 'page': '$page',
      },
    ).toString(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (status: status, page: page);
    final value = ref.watch(adminFlagsProvider(query));
    return AdminScaffold(
      section: AdminSection.safety,
      title: 'Safety',
      body: AdminPage(
        onRefresh: () => ref.refresh(adminFlagsProvider(query).future),
        children: [
          FilterBar(
            hint: '',
            query: '',
            onSearch: (_) {},
            filters: const {
              'OPEN': 'To review',
              'REVIEWED': 'Reviewed',
              '': 'All',
            },
            selected: status,
            onFilter: (s) => _go(context, status: s),
          ),
          const InfoBanner(
            title: 'Where flags come from',
            message:
                'People report each other from a job. The system also flags chat '
                'messages that share a phone number or talk about paying outside '
                'the app. Messages are never blocked; you decide what to do.',
          ),
          const SizedBox(height: AppTheme.gapLg),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminFlagsProvider(query)),
            builder: (p) => p.items.isEmpty
                ? const EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'Nothing to review',
                    message: 'No reports or warning signs here.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final f in p.items) FlagCard(flag: f),
                      Pager(
                        page: page,
                        hasMore: p.hasMore,
                        onPage: (n) => _go(context, page: n),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One report or automatic flag, with a review action while it is open.
class FlagCard extends ConsumerWidget {
  const FlagCard({required this.flag, this.showReported = true, super.key});

  final FlagRow flag;
  final bool showReported;

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    final outcome = await context.askForText(
      title: 'Mark as reviewed',
      message:
          'Record what you found and did, for example "Called both sides, '
          'warned the provider" or "Suspended the account".',
      label: 'Outcome',
      action: 'Mark reviewed',
    );
    if (outcome == null || !context.mounted) return;
    try {
      await ref.read(adminOpsApiProvider).reviewFlag(flag.id, outcome);
      ref.invalidate(adminFlagsProvider);
      ref.invalidate(adminUserProvider(flag.reported.id));
      ref.invalidate(overviewProvider);
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = flag;
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Panel(
      child: Wrap(
        spacing: AppTheme.gapLg,
        runSpacing: AppTheme.gapMd,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppTheme.gapSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(f.reasonLabel, style: context.text.titleSmall),
                    Pill(
                      label: f.automatic
                          ? 'Automatic'
                          : 'Reported by ${f.reporter.label}',
                      tone: f.automatic ? Tone.info : Tone.warning,
                    ),
                  ],
                ),
                if (showReported)
                  Text(
                    'About ${f.reported.label}',
                    style: context.text.bodyMedium,
                  ),
                if (f.details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SelectableText('"${f.details}"'),
                  ),
                Text(
                  [
                    dateTime(f.createdAt),
                    if (f.outcome.isNotEmpty) 'Outcome: ${f.outcome}',
                  ].join(' · '),
                  style: muted,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: AppTheme.gapSm,
            runSpacing: AppTheme.gapSm,
            children: [
              if (f.status == 'OPEN')
                FilledButton(
                  onPressed: () => _review(context, ref),
                  child: const Text('Mark reviewed'),
                ),
              if (showReported)
                TextButton(
                  onPressed: () =>
                      context.push('/admin/people/${f.reported.id}'),
                  child: const Text('Their account'),
                ),
              if (f.jobId.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/admin/jobs/${f.jobId}'),
                  child: const Text('The job'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AdminServicesPage extends ConsumerWidget {
  const AdminServicesPage({super.key});

  Future<void> _editService(
    BuildContext context,
    WidgetRef ref,
    CatalogAdminView catalog,
    EditableService? service,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _ServiceSheet(catalog: catalog, service: service),
    );
    if (saved == true) {
      ref.invalidate(adminCatalogProvider);
      if (context.mounted) {
        context.showMessage('Saved. Customers see it within a minute.');
      }
    }
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    EditableCategory c,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _CategorySheet(category: c),
    );
    if (saved == true) ref.invalidate(adminCatalogProvider);
  }

  Future<void> _editHelpline(
    BuildContext context,
    WidgetRef ref,
    CatalogAdminView v,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _SettingsSheet(settings: v.settings),
    );
    if (saved == true) ref.invalidate(adminCatalogProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminCatalogProvider);
    return AdminScaffold(
      section: AdminSection.services,
      title: 'Services and prices',
      actions: [
        if (value.value != null)
          FilledButton.icon(
            onPressed: () => _editService(context, ref, value.value!, null),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New service'),
          ),
      ],
      body: AdminAsync(
        value: value,
        onRetry: () => ref.invalidate(adminCatalogProvider),
        builder: (v) {
          final muted = context.text.bodySmall!.copyWith(
            color: context.palette.muted,
          );
          return AdminPage(
            onRefresh: () => ref.refresh(adminCatalogProvider.future),
            children: [
              Panel(
                title: 'Helpline and company',
                trailing: TextButton(
                  onPressed: () => _editHelpline(context, ref, v),
                  child: const Text('Edit'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Fact(
                      'Helpline',
                      Text(
                        v.helplinePhone.isEmpty
                            ? 'Not set. The Help page offers written support only.'
                            : '${v.helplinePhone}${v.helplineHours.isEmpty ? '' : ' · ${v.helplineHours}'}',
                      ),
                    ),
                    Fact(
                      'Company',
                      Text(
                        (v.settings['company_name'] ?? '').isEmpty
                            ? 'Not set. Nepal requires the registered name, registration number and PAN on the site.'
                            : [
                                v.settings['company_name'],
                                if ((v.settings['registration_no'] ?? '')
                                    .isNotEmpty)
                                  'Reg. no. ${v.settings['registration_no']}',
                                if ((v.settings['pan'] ?? '').isNotEmpty)
                                  'PAN ${v.settings['pan']}',
                              ].join(' · '),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Guide prices set customer expectations; providers still bid. '
                'New categories need an app update, because each has its own icon and photo.',
                style: muted,
              ),
              const SizedBox(height: AppTheme.gapLg),
              for (final c in v.categories)
                Panel(
                  title: c.name,
                  trailing: TextButton(
                    onPressed: () => _editCategory(context, ref, c),
                    child: const Text('Edit category'),
                  ),
                  padding: const EdgeInsets.all(AppTheme.gapLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(c.tagline, style: muted),
                      const SizedBox(height: AppTheme.gapSm),
                      AdminTable(
                        columns: const ['Service', 'Guide price', 'Nepali', ''],
                        onTap: (i) =>
                            _editService(context, ref, v, c.services[i]),
                        rows: [
                          for (final s in c.services)
                            [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${s.guideFromPaisa.asRupeesShort} to ${s.guideToPaisa.asRupeesShort}',
                              ),
                              Text(s.nameNe.isEmpty ? 'In the app' : s.nameNe),
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (s.hidden)
                                    const Pill(
                                      label: 'Hidden',
                                      tone: Tone.neutral,
                                    ),
                                  if (s.popular)
                                    const Pill(
                                      label: 'Popular',
                                      tone: Tone.brand,
                                    ),
                                ],
                              ),
                            ],
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

List<String> _lines(String text) =>
    text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

class _ServiceSheet extends ConsumerStatefulWidget {
  const _ServiceSheet({required this.catalog, this.service});

  final CatalogAdminView catalog;
  final EditableService? service;

  @override
  ConsumerState<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends ConsumerState<_ServiceSheet> {
  final _form = GlobalKey<FormState>();
  late final s = widget.service;
  late final _id = TextEditingController(text: s?.id ?? '');
  late final _name = TextEditingController(text: s?.name ?? '');
  late final _summary = TextEditingController(text: s?.summary ?? '');
  late final _nameNe = TextEditingController(text: s?.nameNe ?? '');
  late final _summaryNe = TextEditingController(text: s?.summaryNe ?? '');
  late final _symptoms = TextEditingController(
    text: s?.symptoms.join('\n') ?? '',
  );
  late final _includes = TextEditingController(
    text: s?.includes.join('\n') ?? '',
  );
  late final _from = TextEditingController(
    text: s == null ? '' : '${s!.guideFromPaisa ~/ 100}',
  );
  late final _to = TextEditingController(
    text: s == null ? '' : '${s!.guideToPaisa ~/ 100}',
  );
  late var _category = s?.categoryId ?? widget.catalog.categories.first.id;
  late var _popular = s?.popular ?? false;
  late var _hidden = s?.hidden ?? false;
  var _busy = false;

  @override
  void dispose() {
    for (final c in [
      _id,
      _name,
      _summary,
      _nameNe,
      _summaryNe,
      _symptoms,
      _includes,
      _from,
      _to,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _rupees(String? t) =>
      (t ?? '').toPaisa == null ? 'Whole rupees, like 800' : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final service = EditableService(
      id: _id.text.trim(),
      categoryId: _category,
      name: _name.text.trim(),
      summary: _summary.text.trim(),
      symptoms: _lines(_symptoms.text),
      includes: _lines(_includes.text),
      guideFromPaisa: _from.text.toPaisa!,
      guideToPaisa: _to.text.toPaisa!,
      popular: _popular,
      nameNe: _nameNe.text.trim(),
      summaryNe: _summaryNe.text.trim(),
      hidden: _hidden,
    );
    setState(() => _busy = true);
    try {
      await ref.read(adminOpsApiProvider).saveService(service);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppTheme.gapMd);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s == null ? 'New service' : 'Edit service',
                style: context.text.titleLarge,
              ),
              const SizedBox(height: AppTheme.gapLg),
              DropdownButtonFormField<int>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in widget.catalog.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              gap,
              TextFormField(
                controller: _id,
                enabled: s == null,
                decoration: const InputDecoration(
                  labelText: 'ID',
                  helperText: 'Lowercase and dashes, like gas-stove. It cannot change later.',
                ),
                validator: (t) =>
                    RegExp(r'^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$')
                        .hasMatch(t ?? '')
                    ? null
                    : '3 to 40 lowercase letters, digits and dashes',
              ),
              gap,
              TextFormField(
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (t) => (t ?? '').trim().length < 3
                    ? 'At least 3 characters'
                    : null,
              ),
              TextFormField(
                controller: _summary,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'One-line summary',
                ),
                validator: (t) => (t ?? '').trim().length < 10
                    ? 'At least 10 characters'
                    : null,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _from,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Guide price from (Rs)',
                      ),
                      validator: _rupees,
                    ),
                  ),
                  const SizedBox(width: AppTheme.gapMd),
                  Expanded(
                    child: TextFormField(
                      controller: _to,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'To (Rs)'),
                      validator: _rupees,
                    ),
                  ),
                ],
              ),
              gap,
              TextFormField(
                controller: _symptoms,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'What people search for, one per line',
                  helperText:
                      'Their words, like "stove not lighting". Up to 12.',
                  alignLabelWithHint: true,
                ),
              ),
              gap,
              TextFormField(
                controller: _includes,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'What is included, one per line',
                  alignLabelWithHint: true,
                ),
              ),
              gap,
              TextFormField(
                controller: _nameNe,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nepali name (optional)',
                  helperText:
                      'Leave empty for services that came with the app.',
                ),
              ),
              TextFormField(
                controller: _summaryNe,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nepali summary (optional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show as popular'),
                value: _popular,
                onChanged: (v) => setState(() => _popular = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hidden'),
                subtitle: const Text(
                  'Customers cannot see or book it. Past jobs keep it.',
                ),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
              const SizedBox(height: AppTheme.gapLg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.category});

  final EditableCategory category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.category.name);
  late final _tagline = TextEditingController(text: widget.category.tagline);
  late final _nameNe = TextEditingController(text: widget.category.nameNe);
  late final _taglineNe = TextEditingController(
    text: widget.category.taglineNe,
  );
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _tagline, _nameNe, _taglineNe]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(adminOpsApiProvider)
          .saveCategory(
            widget.category.id,
            name: _name.text,
            tagline: _tagline.text,
            nameNe: _nameNe.text,
            taglineNe: _taglineNe.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppTheme.gapMd);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit category', style: context.text.titleLarge),
          const SizedBox(height: AppTheme.gapLg),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          gap,
          TextField(
            controller: _tagline,
            decoration: const InputDecoration(labelText: 'Tagline'),
          ),
          gap,
          TextField(
            controller: _nameNe,
            decoration: const InputDecoration(
              labelText: 'Nepali name (optional)',
            ),
          ),
          gap,
          TextField(
            controller: _taglineNe,
            decoration: const InputDecoration(
              labelText: 'Nepali tagline (optional)',
            ),
          ),
          const SizedBox(height: AppTheme.gapLg),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// The helpline and the company details shown in the footer and legal pages.
/// Every field is sent together, because saving replaces them all.
class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.settings});

  final Map<String, String> settings;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

const _settingFields = [
  ('helpline_phone', 'Helpline phone number', '01-5970000'),
  ('helpline_hours', 'When someone answers', '9 AM to 6 PM, Sunday to Friday'),
  ('company_name', 'Registered company name', 'Subidha360 Pvt. Ltd.'),
  (
    'registration_no',
    'Company registration number',
    'From the Office of the Company Registrar',
  ),
  ('pan', 'PAN', '9 digits'),
  ('address', 'Registered address', 'Ward, municipality, district'),
  ('email', 'Contact email', 'help@yourdomain.com'),
];

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  late final _fields = {
    for (final (key, _, _) in _settingFields)
      key: TextEditingController(text: widget.settings[key] ?? ''),
  };
  var _busy = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(adminOpsApiProvider).saveSettings({
        ...widget.settings,
        for (final e in _fields.entries) e.key: e.value.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Helpline and company', style: context.text.titleLarge),
            const SizedBox(height: AppTheme.gapSm),
            Text(
              'The helpline shows on the Help page with a call button. Company '
              'details show in the site footer and the legal pages, as Nepal '
              'requires. Leave a field empty to hide it.',
              style: context.text.bodySmall!.copyWith(
                color: context.palette.muted,
              ),
            ),
            for (final (key, label, hint) in _settingFields) ...[
              const SizedBox(height: AppTheme.gapMd),
              TextField(
                controller: _fields[key],
                keyboardType: key == 'helpline_phone' || key == 'pan'
                    ? TextInputType.phone
                    : key == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                decoration: InputDecoration(labelText: label, hintText: hint),
              ),
            ],
            const SizedBox(height: AppTheme.gapLg),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
