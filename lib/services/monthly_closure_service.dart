import '../models/monthly_closure.dart';
import '../models/monthly_closure_validation.dart';
import 'Database/database_service.dart';

class MonthlyClosureService {
  final DatabaseService _db = DatabaseService();

  Future<void> assertDateOpen(DateTime date) async {
    final ym = formatYearMonth(date);
    if (await _db.isYearMonthClosed(ym)) {
      throw MonthClosedException(ym);
    }
  }

  Future<List<MonthlyClosure>> listClosures() => _db.getMonthlyClosures();

  Future<MonthlyClosureValidationResult> validateBeforeClose(String yearMonth) =>
      _db.validateBeforeMonthClose(yearMonth);

  Future<void> closeMonth({
    required String yearMonth,
    String? closedBy,
    String? notes,
  }) =>
      _db.insertMonthlyClosure(
        yearMonth: yearMonth,
        closedBy: closedBy,
        notes: notes,
      );

  Future<void> reopenMonth(String yearMonth) =>
      _db.deleteMonthlyClosure(yearMonth);
}
