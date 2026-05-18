class LocationModeOption {
  const LocationModeOption({
    required this.label,
    required this.value,
    required this.description,
  });

  final String label;
  final String value;
  final String description;
}

const List<LocationModeOption> locationModeOptions = [
  LocationModeOption(
    label: 'Battery Saver',
    value: 'battery_saver',
    description: 'Less frequent updates to preserve battery.',
  ),
  LocationModeOption(
    label: 'Balanced',
    value: 'balanced',
    description: 'A steady option for normal group travel.',
  ),
  LocationModeOption(
    label: 'Live',
    value: 'live',
    description: 'Closest to real time while driving together.',
  ),
];
