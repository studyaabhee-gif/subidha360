import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/widgets/photo.dart';

/// Names, icons and photos for the category IDs the API uses.
class ServiceCategory {
  const ServiceCategory(this.id, this.slug, this._name, this.icon, this.photo);

  final int id;
  final String slug;
  final String _name;
  final IconData icon;
  final String photo;

  String get name => tr(_name);

  /// For full-width headers.
  String get banner => photo;
}

const serviceCategories = [
  ServiceCategory(
    1,
    'plumbing',
    'Plumbing',
    Icons.plumbing_rounded,
    Photos.plumbing,
  ),
  ServiceCategory(
    2,
    'electrical',
    'Electrical',
    Icons.electrical_services_rounded,
    Photos.electrical,
  ),
  ServiceCategory(
    3,
    'cleaning',
    'Cleaning',
    Icons.cleaning_services_rounded,
    Photos.cleaning,
  ),
  ServiceCategory(
    4,
    'carpentry',
    'Carpentry',
    Icons.carpenter_rounded,
    Photos.carpentry,
  ),
  ServiceCategory(
    5,
    'painting',
    'Painting',
    Icons.format_paint_rounded,
    Photos.painting,
  ),
  ServiceCategory(
    6,
    'appliances',
    'Appliances',
    Icons.kitchen_rounded,
    Photos.appliances,
  ),
  ServiceCategory(
    7,
    'computer',
    'Computer & Wi-Fi',
    Icons.laptop_mac_rounded,
    Photos.computer,
  ),
  ServiceCategory(
    8,
    'pest-control',
    'Pest Control',
    Icons.pest_control_rounded,
    Photos.pest,
  ),
];

const _other = ServiceCategory(
  0,
  '',
  'Service',
  Icons.home_repair_service_rounded,
  Photos.hero,
);

ServiceCategory categoryOf(int id) => serviceCategories.firstWhere(
  (category) => category.id == id,
  orElse: () => _other,
);
