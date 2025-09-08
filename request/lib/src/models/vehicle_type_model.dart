class VehicleTypeModel {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final int displayOrder;
  final bool isActive;
  final int passengerCapacity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  VehicleTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.displayOrder,
    required this.isActive,
    required this.passengerCapacity,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory VehicleTypeModel.fromMap(Map<String, dynamic> map) {
    return VehicleTypeModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      icon: map['icon'] ?? 'directions_car',
      displayOrder: map['displayOrder']?.toInt() ?? 0,
      isActive: map['isActive'] ?? true,
      passengerCapacity: map['passengerCapacity']?.toInt() ?? 1,
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
      createdBy: map['createdBy'],
      updatedBy: map['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'displayOrder': displayOrder,
      'isActive': isActive,
      'passengerCapacity': passengerCapacity,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  @override
  String toString() {
    return 'VehicleTypeModel(id: $id, name: $name, passengerCapacity: $passengerCapacity)';
  }
}
