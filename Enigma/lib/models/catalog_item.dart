class CatalogItem {
  final String id;
  final String name;
  final String? shortName;
  final String? city;

  const CatalogItem({
    required this.id,
    required this.name,
    this.shortName,
    this.city,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      shortName: json['short_name'],
      city: json['city'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'short_name': shortName,
      'city': city,
    };
  }

  String get displayName {
    final buffer = StringBuffer(name);
    if (shortName != null && shortName!.trim().isNotEmpty) {
      buffer.write(' (${shortName!.trim()})');
    }
    if (city != null && city!.trim().isNotEmpty) {
      buffer.write(' • ${city!.trim()}');
    }
    return buffer.toString();
  }
}
