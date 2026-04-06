/// Kalendárny mesiac vo formáte YYYY-MM (kľúč v tabuľke monthly_closures).
String formatYearMonth(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Doklady a skladové úpravy v uzavretom mesiaci nie sú povolené.
class MonthClosedException implements Exception {
  final String yearMonth;

  MonthClosedException(this.yearMonth);

  @override
  String toString() =>
      'Obdobie $yearMonth je uzavreté. Doklady a zmeny v tomto mesiaci nie sú povolené.';
}

class MonthlyClosure {
  final String yearMonth;
  final DateTime closedAt;
  final String? closedBy;
  final String? notes;

  const MonthlyClosure({
    required this.yearMonth,
    required this.closedAt,
    this.closedBy,
    this.notes,
  });

  factory MonthlyClosure.fromMap(Map<String, dynamic> map) {
    return MonthlyClosure(
      yearMonth: map['year_month'] as String,
      closedAt: DateTime.tryParse(map['closed_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      closedBy: map['closed_by'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
