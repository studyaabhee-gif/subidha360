extension PhoneFormat on String {
  /// "+9779812345678" becomes "+977 981-234-5678". Anything else is unchanged.
  String get asDisplayPhone {
    final match = RegExp(r'^\+977(\d{3})(\d{3})(\d{4})$').firstMatch(this);
    if (match == null) return this;
    return '+977 ${match[1]}-${match[2]}-${match[3]}';
  }
}
