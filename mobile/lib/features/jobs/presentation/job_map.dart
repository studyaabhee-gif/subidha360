import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';

/// Turned off in tests, which have no network for map images.
bool mapTilesEnabled = true;

/// How often the customer's screen asks where the provider is.
const _pollEvery = Duration(seconds: 15);

/// How often the provider's phone sends its position.
const _shareEvery = Duration(seconds: 30);

/// Map images with the credit OpenStreetMap's licence requires.
class _Tiles extends StatelessWidget {
  const _Tiles();

  @override
  Widget build(BuildContext context) {
    if (!mapTilesEnabled) return const SizedBox.shrink();
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.subidha360.app',
    );
  }
}

/// The credit OpenStreetMap's licence requires, linking to that licence.
class _Credit extends StatelessWidget {
  const _Credit();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Material(
        color: Colors.white.withValues(alpha: 0.85),
        child: InkWell(
          onTap: () => launchUrl(
            Uri.parse('https://www.openstreetmap.org/copyright'),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              tr('© OpenStreetMap'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall!.copyWith(fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }
}

/// A map to drag until the fixed centre pin sits on the customer's home.
class PinPickerMap extends StatelessWidget {
  const PinPickerMap({
    required this.lat,
    required this.lng,
    required this.onMoved,
    super.key,
  });

  final double lat;
  final double lng;
  final void Function(double lat, double lng) onMoved;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            ColoredBox(
              color: context.palette.skeleton,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 16,
                  minZoom: 6,
                  interactionOptions: const InteractionOptions(
                    // The wheel keeps scrolling the form, so nobody gets stuck on the map.
                    flags:
                        InteractiveFlag.all &
                        ~InteractiveFlag.rotate &
                        ~InteractiveFlag.scrollWheelZoom,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) {
                      onMoved(camera.center.latitude, camera.center.longitude);
                    }
                  },
                ),
                children: const [_Tiles(), _Credit()],
              ),
            ),
            // The tip of the pin marks the centre of the map.
            IgnorePointer(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 40,
                    color: context.colors.secondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a job is. Customers also see their provider arrive, and the assigned
/// provider chooses whether to share their position.
class JobLocationCard extends ConsumerStatefulWidget {
  const JobLocationCard({
    required this.job,
    required this.seeker,
    required this.assigned,
    super.key,
  });

  final Job job;
  final bool seeker;
  final bool assigned;

  @override
  ConsumerState<JobLocationCard> createState() => _JobLocationCardState();
}

class _JobLocationCardState extends ConsumerState<JobLocationCard> {
  late final JobRepository _jobs = ref.read(jobRepositoryProvider);
  Timer? _timer;
  LiveLocation? _live;
  var _sharing = false;

  Job get _job => widget.job;

  @override
  void initState() {
    super.initState();
    if (widget.seeker && _job.status.tracked) {
      _poll();
      _timer = Timer.periodic(_pollEvery, (_) => _poll());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Leaving the screen ends sharing, so nobody is tracked by accident.
    if (_sharing) unawaited(_jobs.stopSharing(_job.id).catchError((_) {}));
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final live = await _jobs.tracking(_job.id);
      if (mounted) setState(() => _live = live);
    } catch (_) {
      // A missed update is fine: the next one follows shortly.
    }
  }

  Future<void> _sendPosition() async {
    final position = await Geolocator.getCurrentPosition();
    await _jobs.shareLocation(_job.id, position.latitude, position.longitude);
  }

  Future<void> _toggleSharing(bool on) async {
    if (!on) {
      _timer?.cancel();
      setState(() => _sharing = false);
      await _jobs.stopSharing(_job.id).catchError((_) {});
      return;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('denied');
      }
      await _sendPosition();
      if (!mounted) return;
      setState(() => _sharing = true);
      _timer = Timer.periodic(_shareEvery, (_) {
        _sendPosition().catchError((_) {});
      });
    } catch (_) {
      if (mounted) {
        context.showMessage(
          tr("We couldn't get your location. Check your location permission."),
        );
      }
    }
  }

  Future<void> _directions(GeoPoint place) => launchUrl(
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${place.lat},${place.lng}',
    ),
    mode: LaunchMode.externalApplication,
  );

  @override
  Widget build(BuildContext context) {
    final place = _job.jobLocation;
    if (place == null) return const SizedBox.shrink();
    final exact = widget.seeker || widget.assigned;
    final live = _live;
    final home = LatLng(place.lat, place.lng);
    final provider = live == null ? null : LatLng(live.lat, live.lng);
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            child: SizedBox(
              height: 190,
              child: ColoredBox(
                color: context.palette.skeleton,
                child: FlutterMap(
                  // Rebuilt for each new position, to keep both pins in view.
                  key: ValueKey(provider),
                  options: MapOptions(
                    initialCenter: home,
                    initialZoom: exact ? 15 : 13,
                    initialCameraFit: provider == null
                        ? null
                        : CameraFit.coordinates(
                            coordinates: [home, provider],
                            padding: const EdgeInsets.all(48),
                            maxZoom: 16,
                          ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    const _Tiles(),
                    if (!exact)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: home,
                            radius: 1000,
                            useRadiusInMeter: true,
                            color: context.colors.primary.withValues(
                              alpha: 0.16,
                            ),
                            borderColor: context.colors.primary,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (exact)
                          Marker(
                            point: home,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 40,
                              color: context.colors.secondary,
                            ),
                          ),
                        if (provider != null)
                          Marker(
                            point: provider,
                            width: 36,
                            height: 36,
                            child: CircleAvatar(
                              backgroundColor: context.colors.primary,
                              child: const Icon(
                                Icons.handyman_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const _Credit(),
                  ],
                ),
              ),
            ),
          ),
          if (!exact)
            Padding(
              padding: const EdgeInsets.all(AppTheme.gapMd),
              child: Text(
                tr(
                  'Approximate area. You see the exact place if you win the job.',
                ),
                style: muted,
              ),
            ),
          if (widget.seeker && _job.status.tracked)
            Padding(
              padding: const EdgeInsets.all(AppTheme.gapMd),
              child: Row(
                children: [
                  Icon(
                    live == null
                        ? Icons.location_disabled_rounded
                        : Icons.near_me_rounded,
                    size: 18,
                    color: live == null
                        ? context.palette.muted
                        : context.colors.primary,
                  ),
                  const SizedBox(width: AppTheme.gapSm),
                  Expanded(
                    child: Text(
                      live == null
                          ? tr('Your provider is not sharing their location.')
                          : tr('Your provider is sharing their live location.'),
                      style: muted,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.assigned) ...[
            if (_job.status.tracked)
              SwitchListTile(
                value: _sharing,
                onChanged: _toggleSharing,
                title: Text(
                  tr('Share my live location'),
                  style: context.text.titleSmall,
                ),
                subtitle: Text(
                  tr(
                    'The customer sees you on the map while this screen is open.',
                  ),
                  style: muted,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gapMd,
                0,
                AppTheme.gapMd,
                AppTheme.gapMd,
              ),
              child: OutlinedButton.icon(
                onPressed: () => _directions(place),
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text(tr('Get directions')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
