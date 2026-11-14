import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/provider_api.dart';
import '../domain/provider_models.dart';
import 'provider_widgets.dart';

const maxGalleryPhotos = 12;

/// A provider's own gallery of past work, which customers see on their
/// profile.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  var _busy = false;

  Future<void> _add() async {
    final bytes = await pickOnePhoto(context);
    if (bytes == null || !mounted) return;
    final caption = await context.askForText(
      title: tr('What did you do?'),
      message: tr(
        'A short caption helps customers, like "Kitchen sink fitted".',
      ),
      label: tr('Caption'),
      action: tr('Add photo'),
    );
    if (caption == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(providerApiProvider)
          .addGalleryPhoto(bytes, caption.trim());
      ref.invalidate(galleryProvider(widget.providerId));
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(GalleryPhoto p) async {
    final yes = await context.confirm(
      title: tr('Remove this photo?'),
      message: tr('Customers will no longer see it.'),
      action: tr('Remove'),
      destructive: true,
    );
    if (!yes) return;
    try {
      await ref.read(providerApiProvider).deleteGalleryPhoto(p.id);
      ref.invalidate(galleryProvider(widget.providerId));
    } catch (error) {
      if (mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(galleryProvider(widget.providerId));
    final count = value.value?.length ?? 0;
    return ToolPage(
      title: tr('Past work'),
      onRefresh: () => ref.refresh(galleryProvider(widget.providerId).future),
      bottom: BottomActionBar(
        children: [
          FilledButton.icon(
            onPressed: _busy || count >= maxGalleryPhotos ? null : _add,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(tr('Add photo')),
          ),
        ],
      ),
      children: [
        Text(
          tr(
            'Show customers jobs you are proud of. Only use your own photos, '
            'and leave out faces and house numbers.',
          ),
          style: context.text.bodySmall!.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppTheme.gapLg),
        ToolAsync(
          value: value,
          onRetry: () => ref.invalidate(galleryProvider(widget.providerId)),
          builder: (rows) => rows.isEmpty
              ? EmptyState(
                  icon: Icons.photo_library_outlined,
                  title: tr('No photos yet'),
                  message: tr(
                    'Providers with photos of their work win more jobs.',
                  ),
                )
              : GalleryGrid(
                  providerId: widget.providerId,
                  photos: rows,
                  onDelete: _delete,
                ),
        ),
      ],
    );
  }
}

/// Photos in a grid, two or three across. Shown to the owner with delete
/// buttons and to customers without.
class GalleryGrid extends ConsumerWidget {
  const GalleryGrid({
    required this.providerId,
    required this.photos,
    this.onDelete,
    super.key,
  });

  final String providerId;
  final List<GalleryPhoto> photos;
  final void Function(GalleryPhoto)? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth > 520 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppTheme.gapSm,
          crossAxisSpacing: AppTheme.gapSm,
          childAspectRatio: 0.82,
          children: [
            for (final p in photos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          BytesImage(
                            bytes: ref.watch(
                              galleryPhotoProvider((providerId, p.id)),
                            ),
                          ),
                          if (onDelete != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filledTonal(
                                tooltip: tr('Remove'),
                                onPressed: () => onDelete!(p),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapXs),
                  Text(
                    p.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
