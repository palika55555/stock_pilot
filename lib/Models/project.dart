enum ProjectStatus {
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const ProjectStatus(this.value);

  static ProjectStatus fromString(String? s) {
    switch (s) {
      case 'completed':
        return ProjectStatus.completed;
      case 'cancelled':
        return ProjectStatus.cancelled;
      default:
        return ProjectStatus.active;
    }
  }

  String get label {
    switch (this) {
      case ProjectStatus.active:
        return 'Aktívna';
      case ProjectStatus.completed:
        return 'Dokončená';
      case ProjectStatus.cancelled:
        return 'Zrušená';
    }
  }
}

class Project {
  final int? id;
  final String projectNumber;
  final String name;
  final ProjectStatus status;
  final int? customerId;
  final String? customerName;
  final String? siteAddress;
  final String? siteCity;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? budget;
  final String? responsiblePerson;
  final String? notes;
  final DateTime createdAt;

  Project({
    this.id,
    required this.projectNumber,
    required this.name,
    this.status = ProjectStatus.active,
    this.customerId,
    this.customerName,
    this.siteAddress,
    this.siteCity,
    this.startDate,
    this.endDate,
    this.budget,
    this.responsiblePerson,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_number': projectNumber,
      'name': name,
      'status': status.value,
      'customer_id': customerId,
      'customer_name': customerName,
      'site_address': siteAddress,
      'site_city': siteCity,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'budget': budget,
      'responsible_person': responsiblePerson,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int?,
      projectNumber: map['project_number'] as String? ?? '',
      name: map['name'] as String? ?? '',
      status: ProjectStatus.fromString(map['status'] as String?),
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      siteAddress: map['site_address'] as String?,
      siteCity: map['site_city'] as String?,
      startDate: map['start_date'] != null ? DateTime.tryParse(map['start_date'] as String) : null,
      endDate: map['end_date'] != null ? DateTime.tryParse(map['end_date'] as String) : null,
      budget: (map['budget'] as num?)?.toDouble(),
      responsiblePerson: map['responsible_person'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Project copyWith({
    int? id,
    String? projectNumber,
    String? name,
    ProjectStatus? status,
    int? customerId,
    String? customerName,
    String? siteAddress,
    String? siteCity,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    String? responsiblePerson,
    String? notes,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      projectNumber: projectNumber ?? this.projectNumber,
      name: name ?? this.name,
      status: status ?? this.status,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      siteAddress: siteAddress ?? this.siteAddress,
      siteCity: siteCity ?? this.siteCity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      responsiblePerson: responsiblePerson ?? this.responsiblePerson,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
