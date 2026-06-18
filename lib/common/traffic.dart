String formatTrafficBytes(int value, {int fractionDigits = 3}) {
  final units = [
    (label: 'MB', divisor: 1024 * 1024),
    (label: 'GB', divisor: 1024 * 1024 * 1024),
    (label: 'TB', divisor: 1024 * 1024 * 1024 * 1024),
  ];
  var selected = units.first;
  for (final unit in units) {
    if (value >= unit.divisor) {
      selected = unit;
    }
  }
  return '${(value / selected.divisor).toStringAsFixed(fractionDigits)} ${selected.label}';
}

String formatRewardMb(int value) {
  return '+$value MB';
}
