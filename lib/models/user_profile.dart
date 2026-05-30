class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String farmName;
  final String location;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.farmName,
    required this.location,
  });

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'SP';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? farmName,
    String? location,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      farmName: farmName ?? this.farmName,
      location: location ?? this.location,
    );
  }
}
