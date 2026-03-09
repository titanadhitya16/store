// Helper function to format rupiah with abbreviations
String formatRupiah(double amount) {
  if (amount >= 1000000000) {
    // Billion (Miliar)
    double value = amount / 1000000000;
    return 'Rp ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}M';
  } else if (amount >= 1000000) {
    // Million (Juta)
    double value = amount / 1000000;
    return 'Rp ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}jt';
  } else if (amount >= 100000) {
    // Hundred thousand (Ratusan ribu)
    double value = amount / 1000;
    return 'Rp ${value.toStringAsFixed(0)}rb';
  } else if (amount >= 1000) {
    // Thousand (Ribu)
    double value = amount / 1000;
    return 'Rp ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}rb';
  } else {
    // Less than 1000
    return 'Rp ${amount.toStringAsFixed(0)}';
  }
}
