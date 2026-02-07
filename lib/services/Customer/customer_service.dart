import '../../models/customer.dart';
import '../database/database_service.dart';

class CustomerService {
  final DatabaseService _db = DatabaseService();

  Future<List<Customer>> getAllCustomers() async {
    return await _db.getCustomers();
  }

  Future<List<Customer>> getActiveCustomers() async {
    return await _db.getActiveCustomers();
  }

  Future<Customer?> getCustomerById(int id) async {
    return await _db.getCustomerById(id);
  }

  Future<int> createCustomer(Customer customer) async {
    return await _db.insertCustomer(customer);
  }

  Future<int> updateCustomer(Customer customer) async {
    return await _db.updateCustomer(customer);
  }

  Future<int> deleteCustomer(int id) async {
    return await _db.deleteCustomer(id);
  }
}
