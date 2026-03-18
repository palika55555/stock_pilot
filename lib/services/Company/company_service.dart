import '../../models/company.dart';
import '../Database/database_service.dart';
import '../api_sync_service.dart' show syncCompanyToBackend;

class CompanyService {
  final DatabaseService _db = DatabaseService();

  Future<Company?> getCompany() async {
    return await _db.getCompany();
  }

  Future<int> saveCompany(Company company) async {
    final result = await _db.saveCompany(company);
    syncCompanyToBackend().ignore();
    return result;
  }
}
