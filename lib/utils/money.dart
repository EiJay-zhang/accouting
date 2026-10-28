int centsFromYuan(num yuan) => (yuan * 100).round();

String formatYuan(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$whole.$fraction';
}
