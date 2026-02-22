/// Číselník druhov pohybu pre výdajky (Bežná výdajka, Prevodka, Výdaj do spotreby...).
class MovementType {
  final int? id;
  final String code;
  final String name;

  MovementType({this.id, required this.code, required this.name});

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
      };

  factory MovementType.fromMap(Map<String, dynamic> map) => MovementType(
        id: map['id'] as int?,
        code: map['code'] as String? ?? '',
        name: map['name'] as String? ?? '',
      );
}
