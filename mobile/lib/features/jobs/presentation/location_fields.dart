import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/areas.dart';
import 'job_map.dart';

/// The chosen location: a known area, or the device's position.
class LocationChoice extends ChangeNotifier {
  ServiceArea? area;
  double? _lat;
  double? _lng;
  var _previous = false;

  /// Changes when the map should jump, but not when the person drags it.
  var revision = 0;

  bool get hasValue => _lat != null;
  bool get usingDevice => hasValue && area == null && !_previous;
  bool get usingPrevious => hasValue && _previous;
  double get lat => _lat!;
  double get lng => _lng!;

  void chooseArea(ServiceArea value) {
    area = value;
    _jumpTo(value.lat, value.lng, previous: false);
  }

  void chooseDevice(double lat, double lng) {
    area = null;
    _jumpTo(lat, lng, previous: false);
  }

  /// Reuses the location of an earlier job.
  void choosePrevious(double lat, double lng) {
    area = null;
    _jumpTo(lat, lng, previous: true);
  }

  /// Keeps the chosen area, but refines the exact spot.
  void movePin(double lat, double lng) {
    _lat = lat;
    _lng = lng;
  }

  void _jumpTo(double lat, double lng, {required bool previous}) {
    _lat = lat;
    _lng = lng;
    _previous = previous;
    revision++;
    notifyListeners();
  }
}

/// Picks a location by area name or GPS, so nobody types coordinates.
class LocationPicker extends StatefulWidget {
  const LocationPicker({required this.choice, this.missing = false, super.key});

  final LocationChoice choice;
  final bool missing;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  var _locating = false;

  Future<void> _useDevice() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('denied');
      }
      final position = await Geolocator.getCurrentPosition();
      widget.choice.chooseDevice(position.latitude, position.longitude);
    } catch (_) {
      if (mounted) {
        context.showMessage(
          tr("We couldn't get your location. Choose your area instead."),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.choice,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ServiceArea>(
            initialValue: widget.choice.area,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: widget.choice.usingPrevious
                  ? tr('Same place as before')
                  : widget.choice.usingDevice
                  ? tr('Using your current location')
                  : tr('Choose your area'),
              errorText: widget.missing ? tr('Choose an area') : null,
            ),
            items: [
              for (final area in serviceAreas)
                DropdownMenuItem(value: area, child: Text(area.name)),
            ],
            onChanged: (value) {
              if (value != null) widget.choice.chooseArea(value);
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _locating ? null : _useDevice,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _locating
                    ? tr('Finding you...')
                    : tr('Use my current location'),
              ),
            ),
          ),
          if (widget.choice.usingDevice)
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.gapSm),
              child: Text(
                tr('Location found'),
                style: context.text.bodySmall!.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
          if (widget.choice.hasValue) ...[
            const SizedBox(height: AppTheme.gapSm),
            PinPickerMap(
              key: ValueKey(widget.choice.revision),
              lat: widget.choice.lat,
              lng: widget.choice.lng,
              onMoved: widget.choice.movePin,
            ),
            const SizedBox(height: AppTheme.gapXs),
            Text(
              tr('Drag the map until the pin is on the right place.'),
              style: context.text.bodySmall!.copyWith(
                color: context.palette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
