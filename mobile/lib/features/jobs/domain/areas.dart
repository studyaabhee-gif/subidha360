import '../../../core/l10n/tr.dart';

/// Well-known areas with approximate centres. Providers are matched by distance,
/// so a neighbourhood centre is accurate enough to start with.
class ServiceArea {
  const ServiceArea(this._name, this.lat, this.lng);

  final String _name;
  final double lat;
  final double lng;

  String get name => tr(_name);
}

const serviceAreas = [
  ServiceArea('Baneshwor, Kathmandu', 27.6915, 85.3420),
  ServiceArea('Thamel, Kathmandu', 27.7154, 85.3123),
  ServiceArea('Lazimpat, Kathmandu', 27.7215, 85.3220),
  ServiceArea('Maharajgunj, Kathmandu', 27.7360, 85.3300),
  ServiceArea('Koteshwor, Kathmandu', 27.6780, 85.3490),
  ServiceArea('Kalanki, Kathmandu', 27.6934, 85.2810),
  ServiceArea('Budhanilkantha, Kathmandu', 27.7770, 85.3620),
  ServiceArea('Patan, Lalitpur', 27.6710, 85.3240),
  ServiceArea('Jawalakhel, Lalitpur', 27.6730, 85.3130),
  ServiceArea('Satdobato, Lalitpur', 27.6580, 85.3250),
  ServiceArea('Bhaktapur Durbar Square', 27.6720, 85.4280),
  ServiceArea('Thimi, Bhaktapur', 27.6810, 85.3880),
  ServiceArea('Lakeside, Pokhara', 28.2096, 83.9590),
  ServiceArea('Mahendrapul, Pokhara', 28.2190, 83.9880),
];
