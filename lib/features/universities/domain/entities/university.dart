class University {
  const University({required this.id, required this.name});

  final String id;
  final String name;

  factory University.fromJson(Map<String, dynamic> json) {
    return University(id: json['id'] as String, name: json['name'] as String);
  }
}
