import '../../models/project.dart';
import '../Database/database_service.dart';

class ProjectService {
  final DatabaseService _db = DatabaseService();

  Future<List<Project>> getAllProjects() => _db.getProjects();
  Future<List<Project>> getActiveProjects() => _db.getActiveProjects();
  Future<List<Project>> getProjectsByCustomer(int customerId) => _db.getProjectsByCustomerId(customerId);
  Future<Project?> getProjectById(int id) => _db.getProjectById(id);

  Future<Project> createProject(Project project) async {
    final number = await _generateProjectNumber();
    final p = project.copyWith(projectNumber: number, createdAt: DateTime.now());
    final id = await _db.insertProject(p);
    return p.copyWith(id: id);
  }

  Future<int> updateProject(Project project) => _db.updateProject(project);
  Future<int> deleteProject(int id) => _db.deleteProject(id);

  Future<String> _generateProjectNumber() async {
    final year = DateTime.now().year;
    final seq = await _db.getNextProjectSequence();
    final seqStr = seq.toString().padLeft(3, '0');
    return 'ZAK-$year-$seqStr';
  }
}
