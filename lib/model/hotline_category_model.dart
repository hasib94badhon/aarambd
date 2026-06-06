class HotlineCategoryModel {
  final String category;
  final int count;
  final List<String> names;
  final List<String> phones;
  final List<String> photos;

  HotlineCategoryModel({
    required this.category,
    required this.count,
    required this.names,
    required this.phones,
    required this.photos,
  });

  factory HotlineCategoryModel.fromJson(Map<String, dynamic> json) {
    return HotlineCategoryModel(
      category: json['category'] ?? '',
      count: json['count'] ?? 0,
      names: json['names'] != null
          ? json['names'].toString().split(',').map((e) => e.trim()).toList()
          : [],
      phones: json['phones'] != null
          ? json['phones'].toString().split(',').map((e) => e.trim()).toList()
          : [],
      photos: json['photos'] != null
          ? json['photos'].toString().split(',').map((e) => e.trim()).toList()
          : [],
    );
  }
}