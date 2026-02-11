/// Druh produktu – používa sa pri skladoch (napr. klince, montážna pena).
class ProductKind {
  final int? id;
  final String name;

  const ProductKind({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  factory ProductKind.fromMap(Map<String, dynamic> map) {
    return ProductKind(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
    );
  }

  ProductKind copyWith({int? id, String? name}) {
    return ProductKind(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
