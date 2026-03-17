import '../../models/company.dart';
import '../Database/database_service.dart';

class CompanyService {
  final DatabaseService _db = DatabaseService();

  Future<Company?> getCompany() async {
    return await _db.getCompany();
  }

  Future<int> saveCompany(Company company) async {
    return await _db.saveCompany(company);
  }
}
