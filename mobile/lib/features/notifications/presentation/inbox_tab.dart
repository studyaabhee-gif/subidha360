import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_list.dart';
import '../../../core/widgets/ui.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

class InboxTab extends ConsumerWidget {
  const InboxTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncListPage<AppNotification>(
      value: ref.watch(inboxProvider),
      onRefresh: () => ref.refresh(inboxProvider.future),
      empty: EmptyState(
        icon: Icons.notifications_none_rounded,
        title: tr('Nothing here yet'),
        message: tr('Updates about your jobs and payments will appear here.'),
      ),
      builder: (context, items) {
        final now = DateTime.now();
        final today = items.where((n) => n.createdAt.isSameDayAs(now)).toList();
        final earlier = items
            .where((n) => !n.createdAt.isSameDayAs(now))
            .toList();
        return [
          if (today.isNotEmpty) ...[
            SectionTitle(tr('Today')),
            _Group(items: today),
          ],
          if (earlier.isNotEmpty) ...[
            if (today.isNotEmpty) const SizedBox(height: AppTheme.gapXl),
            SectionTitle(tr('Earlier')),
            _Group(items: earlier),
          ],
        ];
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.items});

  final List<AppNotification> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 70),
            NotificationRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class NotificationRow extends StatelessWidget {
  const NotificationRow({required this.item, super.key});

  final AppNotification item;

  (IconData, Tone) get _look => switch (item.type) {
    'completion.confirm_needed' ||
    'completion.auto_release_warning' => (Icons.schedule_rounded, Tone.warning),
    'dispute.raised' => (Icons.gavel_rounded, Tone.danger),
    'job.cancelled' => (Icons.block_rounded, Tone.neutral),
    'job.completed' ||
    'escrow.resolved' => (Icons.check_circle_rounded, Tone.success),
    'bid.accepted' => (Icons.celebration_rounded, Tone.success),
    'bid.received' => (Icons.sell_rounded, Tone.brand),
    _ => (Icons.work_outline_rounded, Tone.info),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _look;
    final unread = item.readAt == null;
    return InkWell(
      onTap: item.jobId == null
          ? null
          : () => context.push('/jobs/${item.jobId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gapMd + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: icon, tone: tone, size: 42),
            const SizedBox(width: AppTheme.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unread) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.gapSm),
                      ],
                      Expanded(
                        child: Text(
                          tr(item.title),
                          style: context.text.titleSmall,
                        ),
                      ),
                      Text(
                        item.createdAt.timeAgo(),
                        style: context.text.labelSmall!.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
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
