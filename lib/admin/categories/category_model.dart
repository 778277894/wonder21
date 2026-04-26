// lib/categories/category_model.dart
class Category {
  final int id;
  final String name;
  final String? description;
  final bool active;

  Category({
    required this.id,
    required this.name,
    this.description,
    required this.active,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: int.tryParse('${j['category_id'] ?? j['id'] ?? 0}') ?? 0,
        name: '${j['category_name'] ?? j['name'] ?? ''}',
        description: j['description']?.toString(),
        active: (j['active'] is bool)
            ? (j['active'] as bool)
            : ((j['active']?.toString() ?? '0') == '1'),
      );

  Map<String, dynamic> toJson() => {
        'category_id': id,
        'category_name': name,
        'description': description,
        'active': active ? 1 : 0,
      };
}
