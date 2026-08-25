class OwnerProfile {
  const OwnerProfile({required this.id, required this.name});

  final String id;
  final String name;

  factory OwnerProfile.fromJson(Map<String, dynamic> json) {
    return OwnerProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '؟',
    );
  }
}
