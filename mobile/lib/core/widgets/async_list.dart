import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// A scrolling page for a loaded list: skeletons while loading, a friendly empty
/// state, an error with retry, and pull to refresh throughout.
class AsyncListPage<T> extends StatelessWidget {
  const AsyncListPage({
    required this.value,
    required this.onRefresh,
    required this.empty,
    required this.builder,
    this.header = const [],
    super.key,
  });

  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final List<Widget> Function(BuildContext context, List<T> items) builder;

  /// Shown above the list in every state.
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gapLg,
          AppTheme.gapSm,
          AppTheme.gapLg,
          AppTheme.gapXl,
        ),
        children: [
          ...header,
          ...switch (value) {
            AsyncData(:final value) when value.isNotEmpty => builder(
              context,
              value,
            ),
            AsyncData() => [empty],
            AsyncError(:final error) => [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: tr("Couldn't load this"),
                message: ApiException.from(error).message,
                action: OutlinedButton(
                  onPressed: onRefresh,
                  child: Text(tr('Try again')),
                ),
              ),
            ],
            _ => [const SkeletonCards()],
          },
        ],
      ),
    );
  }
}
