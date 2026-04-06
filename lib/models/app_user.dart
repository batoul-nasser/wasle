class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? '',
    );
  }
}
