import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';
import '../providers/job_providers.dart';

/// The API's limits: photos per job, and bytes per photo.
const maxJobPhotos = 4;
const _maxPhotoBytes = 5 * 1024 * 1024;

const _tile = 92.0;

/// Opens the gallery and returns photos small enough to upload quickly on
/// mobile data. Tells the person about any that are still too large.
Future<List<Uint8List>> pickProblemPhotos(
  BuildContext context, {
  required int room,
}) async {
  final picked = await ImagePicker().pickMultiImage(
    maxWidth: 1600,
    imageQuality: 80,
    limit: room > 1 ? room : null,
  );
  final photos = <Uint8List>[];
  var tooLarge = false;
  for (final file in picked.take(room)) {
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxPhotoBytes) {
      tooLarge = true;
    } else {
      photos.add(bytes);
    }
  }
  if (tooLarge && context.mounted) {
    context.showMessage(tr('Photos can be up to 5 MB. Try a smaller one.'));
  }
  return photos;
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr('Add a photo'),
      excludeSemantics: true,
      child: Material(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: _tile,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  color: context.colors.onPrimaryContainer,
                ),
                const SizedBox(height: AppTheme.gapXs),
                Text(
                  tr('Add photo'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall!.copyWith(
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Collects photos while a job is being written. They upload once it's posted.
class ProblemPhotoPicker extends StatelessWidget {
  const ProblemPhotoPicker({
    required this.photos,
    required this.onChanged,
    super.key,
  });

  final List<Uint8List> photos;
  final ValueChanged<List<Uint8List>> onChanged;

  Future<void> _add(BuildContext context) async {
    final added = await pickProblemPhotos(
      context,
      room: maxJobPhotos - photos.length,
    );
    if (added.isNotEmpty) onChanged([...photos, ...added]);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.gapSm,
      runSpacing: AppTheme.gapSm,
      children: [
        for (var i = 0; i < photos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.memory(
                  photos[i],
                  width: _tile,
                  height: _tile,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton.filledTonal(
                  tooltip: tr('Remove photo'),
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => onChanged([...photos]..removeAt(i)),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        if (photos.length < maxJobPhotos) _AddTile(onTap: () => _add(context)),
      ],
    );
  }
}

/// A job's photos. Providers use them to price the work accurately.
class JobPhotos extends ConsumerStatefulWidget {
  const JobPhotos({required this.job, required this.seeker, super.key});

  final Job job;
  final bool seeker;

  @override
  ConsumerState<JobPhotos> createState() => _JobPhotosState();
}

class _JobPhotosState extends ConsumerState<JobPhotos> {
  var _busy = false;

  Job get _job => widget.job;
  bool get _canEdit => widget.seeker && _job.canChange;

  void _reload() => ref.invalidate(jobDetailProvider(_job.id));

  Future<void> _add() async {
    final added = await pickProblemPhotos(
      context,
      room: maxJobPhotos - _job.photoIds.length,
    );
    if (added.isEmpty) return;
    setState(() => _busy = true);
    try {
      final jobs = ref.read(jobRepositoryProvider);
      for (final photo in added) {
        await jobs.uploadPhoto(_job.id, photo);
      }
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      _reload();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String photoId) async {
    try {
      await ref.read(jobRepositoryProvider).deletePhoto(_job.id, photoId);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      _reload();
    }
  }

  void _open(String photoId, Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (dialog) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                if (_canEdit)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.error,
                    ),
                    onPressed: () {
                      Navigator.of(dialog).pop();
                      _delete(photoId);
                    },
                    child: Text(tr('Delete photo')),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(),
                  child: Text(tr('Close')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_job.photoIds.isEmpty && !_canEdit) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(tr('Photos of the problem')),
        Wrap(
          spacing: AppTheme.gapSm,
          runSpacing: AppTheme.gapSm,
          children: [
            for (final id in _job.photoIds)
              _RemotePhoto(
                jobId: _job.id,
                photoId: id,
                onOpen: (bytes) => _open(id, bytes),
              ),
            if (_canEdit && _job.photoIds.length < maxJobPhotos)
              _AddTile(onTap: _busy ? null : _add),
          ],
        ),
      ],
    );
  }
}

class _RemotePhoto extends ConsumerWidget {
  const _RemotePhoto({
    required this.jobId,
    required this.photoId,
    required this.onOpen,
  });

  final String jobId;
  final String photoId;
  final ValueChanged<Uint8List> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(jobPhotoProvider(jobId, photoId)).value;
    return Semantics(
      button: true,
      label: tr('Open photo'),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: SizedBox.square(
          dimension: _tile,
          child: bytes == null
              ? ColoredBox(color: context.palette.skeleton)
              : InkWell(
                  onTap: () => onOpen(bytes),
                  child: Image.memory(bytes, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }
}
