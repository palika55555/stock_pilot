class PavingStone {
  final int? id;
  final String name;
  final double lengthMm;
  final double widthMm;
  final double thicknessMm;
  final int piecesPerLayer;
  final int layersPerPallet;
  final String? userId;
  final String? createdAt;

  const PavingStone({
    this.id,
    required this.name,
    required this.lengthMm,
    required this.widthMm,
    required this.thicknessMm,
    required this.piecesPerLayer,
    required this.layersPerPallet,
    this.userId,
    this.createdAt,
  });

  double get m2PerPiece => (lengthMm * widthMm) / 1000000;
  double get m2PerLayer => piecesPerLayer * m2PerPiece;
  double get m2PerPallet => layersPerPallet * m2PerLayer;
  int get piecesPerPallet => piecesPerLayer * layersPerPallet;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'length_mm': lengthMm,
        'width_mm': widthMm,
        'thickness_mm': thicknessMm,
        'pieces_per_layer': piecesPerLayer,
        'layers_per_pallet': layersPerPallet,
        'user_id': userId,
        'created_at': createdAt,
      };

  static PavingStone fromMap(Map<String, Object?> map) => PavingStone(
        id: map['id'] as int?,
        name: map['name'] as String,
        lengthMm: (map['length_mm'] as num).toDouble(),
        widthMm: (map['width_mm'] as num).toDouble(),
        thicknessMm: (map['thickness_mm'] as num).toDouble(),
        piecesPerLayer: map['pieces_per_layer'] as int,
        layersPerPallet: map['layers_per_pallet'] as int,
        userId: map['user_id'] as String?,
        createdAt: map['created_at'] as String?,
      );

  PavingStone copyWith({
    int? id,
    String? name,
    double? lengthMm,
    double? widthMm,
    double? thicknessMm,
    int? piecesPerLayer,
    int? layersPerPallet,
    String? userId,
    String? createdAt,
  }) =>
      PavingStone(
        id: id ?? this.id,
        name: name ?? this.name,
        lengthMm: lengthMm ?? this.lengthMm,
        widthMm: widthMm ?? this.widthMm,
        thicknessMm: thicknessMm ?? this.thicknessMm,
        piecesPerLayer: piecesPerLayer ?? this.piecesPerLayer,
        layersPerPallet: layersPerPallet ?? this.layersPerPallet,
        userId: userId ?? this.userId,
        createdAt: createdAt ?? this.createdAt,
      );
}
